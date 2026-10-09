import { z } from 'zod';
import { Quiz, QuestionType, QuizDifficulty } from '../types/quiz.types';
import { v4 as uuidv4 } from 'uuid';

const QuizOptionSchema = z.object({
  id: z.string().optional(),
  optionText: z.string().min(1),
  isCorrect: z.boolean(),
  orderIndex: z.number().optional(),
});

const QuizQuestionSchema = z.object({
  id: z.string().optional(),
  questionText: z.string().min(3),
  questionType: z.enum([
    'multiple_choice',
    'true_false',
    'fill_in_blank',
    'enumeration',
    'essay',
    'identification',
  ]),
  points: z.number().optional().default(1),
  explanation: z.string().optional().default(''),
  orderIndex: z.number().optional(),
  options: z.array(QuizOptionSchema).optional().default([]),
  acceptableAnswers: z.array(z.string()).optional(),
});

const GeneratedQuizSchema = z.object({
  title: z.string().min(2).default('Generated Quiz'),
  description: z.string().optional().default('Offline AI Quiz'),
  category: z.string().optional().default('General'),
  difficulty: z.enum(['easy', 'medium', 'hard', 'mixed']).optional().default('medium'),
  questions: z.array(QuizQuestionSchema).min(1),
});

export class JSONValidator {
  /**
   * Attempt to repair corrupted or imperfect LLM output before JSON parsing.
   */
  static cleanAndRepairJSONString(rawOutput: string): string {
    let cleaned = rawOutput.trim();

    // 1. Remove markdown backticks block wrapper if present
    cleaned = cleaned.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '');

    // 2. Find first '{' and last '}'
    const firstBrace = cleaned.indexOf('{');
    const lastBrace = cleaned.lastIndexOf('}');

    if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }

    // 3. Remove trailing commas before closing braces/brackets
    cleaned = cleaned.replace(/,\s*([}\]])/g, '$1');

    // 4. Fix unescaped control characters inside string literals (common on quantized models)
    cleaned = cleaned.replace(/[\u0000-\u001F]+/g, (match) => {
      if (match === '\n') return '\\n';
      if (match === '\r') return '\\r';
      if (match === '\t') return '\\t';
      return '';
    });

    return cleaned;
  }

  /**
   * Validate and parse LLM text output into a strictly typed Quiz entity.
   */
  static validateAndNormalizeQuiz(rawLLMOutput: string): Quiz {
    const repairedJSON = JSONValidator.cleanAndRepairJSONString(rawLLMOutput);
    let parsedObject: any;

    try {
      parsedObject = JSON.parse(repairedJSON);
    } catch (parseErr: any) {
      throw new Error(`JSON Syntax Error in model output: ${parseErr.message}\nRaw Output Snippet: ${repairedJSON.substring(0, 200)}`);
    }

    // Zod Schema Validation
    const validationResult = GeneratedQuizSchema.safeParse(parsedObject);

    if (!validationResult.success) {
      const issueSummary = validationResult.error.issues
        .map((i) => `${i.path.join('.')}: ${i.message}`)
        .join('; ');
      throw new Error(`Model output schema mismatch: ${issueSummary}`);
    }

    const data = validationResult.data;
    const quizId = uuidv4();
    const now = new Date().toISOString();

    const normalizedQuestions = data.questions.map((q, qIndex) => {
      const questionId = uuidv4();
      const normalizedOptions = q.options.map((opt, oIndex) => ({
        id: uuidv4(),
        questionId,
        optionText: opt.optionText,
        isCorrect: Boolean(opt.isCorrect),
        orderIndex: opt.orderIndex ?? oIndex,
      }));

      return {
        id: questionId,
        quizId,
        questionText: q.questionText,
        questionType: q.questionType as QuestionType,
        points: q.points || 1,
        explanation: q.explanation || '',
        orderIndex: q.orderIndex ?? qIndex,
        options: normalizedOptions,
        acceptableAnswers: q.acceptableAnswers,
      };
    });

    const questionTypes = Array.from(new Set(normalizedQuestions.map((q) => q.questionType)));

    return {
      id: quizId,
      title: data.title,
      description: data.description,
      category: data.category,
      difficulty: data.difficulty as QuizDifficulty,
      questionTypes,
      totalQuestions: normalizedQuestions.length,
      sourceType: 'text',
      createdAt: now,
      updatedAt: now,
      questions: normalizedQuestions,
    };
  }
}

import { QuizGenerationRequest } from '../types/quiz.types';
import { PromptTemplates } from './promptTemplates';

export class PromptBuilder {
  /**
   * Build complete prompt configuration for LLM inference.
   */
  static buildPrompt(request: QuizGenerationRequest, textContent: string): { systemPrompt: string; userPrompt: string } {
    const questionTypesStr = request.allowedQuestionTypes.join(', ');
    const targetAudienceStr = request.targetAudience ? `Target Audience: ${request.targetAudience}\n` : '';
    const additionalInstrStr = request.additionalInstructions ? `Special Instructions: ${request.additionalInstructions}\n` : '';
    const titleStr = request.title ? `Quiz Title Preference: ${request.title}\n` : '';

    const userPrompt = `Generate a ${request.difficulty} difficulty quiz containing EXACTLY ${request.totalQuestions} questions based strictly on the study text provided below.

QUIZ SPECIFICATIONS:
- Number of Questions: ${request.totalQuestions}
- Difficulty: ${request.difficulty}
- Allowed Question Types: ${questionTypesStr}
${titleStr}${targetAudienceStr}${additionalInstrStr}
STUDY TEXT MATERIAL:
"""
${textContent}
"""

Remember: Return ONLY valid JSON adhering to the specified schema.`;

    return {
      systemPrompt: PromptTemplates.SYSTEM_QUIZ_GENERATOR,
      userPrompt,
    };
  }
}

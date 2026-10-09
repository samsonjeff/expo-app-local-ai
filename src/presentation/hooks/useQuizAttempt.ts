import { useState, useCallback } from 'react';
import { Quiz, QuizAttempt, AttemptAnswer } from '../../types/quiz.types';
import { AttemptRepository } from '../../storage/database/attemptRepository';
import { v4 as uuidv4 } from 'uuid';

export function useQuizAttempt(quiz: Quiz) {
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [selectedAnswers, setSelectedAnswers] = useState<Map<string, { selectedOptionId?: string; textResponse?: string }>>(new Map());
  const [startTime] = useState<number>(Date.now());
  const [completedAttempt, setCompletedAttempt] = useState<QuizAttempt | null>(null);

  const selectAnswer = useCallback((questionId: string, answer: { selectedOptionId?: string; textResponse?: string }) => {
    setSelectedAnswers((prev) => {
      const updated = new Map(prev);
      updated.set(questionId, answer);
      return updated;
    });
  }, []);

  const submitQuiz = useCallback(async (): Promise<QuizAttempt> => {
    const questions = quiz.questions || [];
    let totalScore = 0;
    let maxScore = 0;
    const answerRecords: AttemptAnswer[] = [];

    const attemptId = uuidv4();

    for (const q of questions) {
      maxScore += q.points || 1;
      const userAns = selectedAnswers.get(q.id);
      let isCorrect = false;
      let pointsEarned = 0;

      if (q.questionType === 'multiple_choice' || q.questionType === 'true_false') {
        const correctOpt = q.options.find((o) => o.isCorrect);
        if (correctOpt && userAns?.selectedOptionId === correctOpt.id) {
          isCorrect = true;
          pointsEarned = q.points || 1;
        }
      } else if (q.acceptableAnswers && userAns?.textResponse) {
        const normalizedResponse = userAns.textResponse.trim().toLowerCase();
        const matches = q.acceptableAnswers.some((ans) => ans.trim().toLowerCase() === normalizedResponse);
        if (matches) {
          isCorrect = true;
          pointsEarned = q.points || 1;
        }
      }

      totalScore += pointsEarned;

      answerRecords.push({
        id: uuidv4(),
        attemptId,
        questionId: q.id,
        selectedOptionId: userAns?.selectedOptionId,
        textResponse: userAns?.textResponse,
        isCorrect,
        pointsEarned,
      });
    }

    const durationSeconds = Math.round((Date.now() - startTime) / 1000);
    const percentage = maxScore > 0 ? Math.round((totalScore / maxScore) * 100) : 0;

    const attemptData: QuizAttempt = {
      id: attemptId,
      quizId: quiz.id,
      score: totalScore,
      maxScore,
      percentage,
      completedAt: new Date().toISOString(),
      durationSeconds,
      answers: answerRecords,
    };

    const savedAttempt = await AttemptRepository.saveAttempt(attemptData);
    setCompletedAttempt(savedAttempt);
    return savedAttempt;
  }, [quiz, selectedAnswers, startTime]);

  return {
    currentQuestionIndex,
    currentQuestion: (quiz.questions || [])[currentQuestionIndex],
    totalQuestions: (quiz.questions || []).length,
    selectedAnswers,
    completedAttempt,
    setCurrentQuestionIndex,
    selectAnswer,
    submitQuiz,
  };
}

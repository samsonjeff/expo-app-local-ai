import { useState, useCallback } from 'react';
import { QuizGenerationRequest, Quiz } from '../../types/quiz.types';
import { JobProgress } from '../../types/queue.types';
import { JobQueueManager } from '../../orchestration/jobQueue';

export function useQuizGenerator() {
  const [isGenerating, setIsGenerating] = useState(false);
  const [progress, setProgress] = useState<JobProgress>({
    step: 'IDLE',
    percentage: 0,
    message: 'Ready to generate',
  });
  const [generatedQuiz, setGeneratedQuiz] = useState<Quiz | null>(null);
  const [error, setError] = useState<string | null>(null);

  const generateQuiz = useCallback(async (request: QuizGenerationRequest): Promise<Quiz | null> => {
    setIsGenerating(true);
    setError(null);
    setGeneratedQuiz(null);

    try {
      const quiz = await JobQueueManager.startQuizGenerationJob(request, (p) => {
        setProgress(p);
      });
      setGeneratedQuiz(quiz);
      return quiz;
    } catch (err: any) {
      setError(err.message || 'Quiz generation failed.');
      return null;
    } finally {
      setIsGenerating(false);
    }
  }, []);

  return {
    isGenerating,
    progress,
    generatedQuiz,
    error,
    generateQuiz,
  };
}

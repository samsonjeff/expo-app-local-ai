import { useState, useCallback, useEffect } from 'react';
import { Quiz } from '../../types/quiz.types';
import { QuizRepository } from '../../storage/database/quizRepository';

export function useQuizRepository() {
  const [quizzes, setQuizzes] = useState<Quiz[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const fetchQuizzes = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await QuizRepository.getAllQuizzes();
      setQuizzes(data);
    } catch (err: any) {
      setError(err.message || 'Failed to load quizzes');
    } finally {
      setLoading(false);
    }
  }, []);

  const getQuizById = useCallback(async (id: string): Promise<Quiz | null> => {
    return await QuizRepository.getQuizById(id);
  }, []);

  const deleteQuiz = useCallback(async (id: string): Promise<boolean> => {
    const success = await QuizRepository.deleteQuiz(id);
    if (success) {
      setQuizzes((prev) => prev.filter((q) => q.id !== id));
    }
    return success;
  }, []);

  const searchQuizzes = useCallback(async (query: string) => {
    setLoading(true);
    try {
      const results = await QuizRepository.searchQuizzes(query);
      setQuizzes(results);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  const exportQuizJSON = useCallback(async (id: string): Promise<string | null> => {
    return await QuizRepository.exportQuizToJSON(id);
  }, []);

  useEffect(() => {
    fetchQuizzes();
  }, [fetchQuizzes]);

  return {
    quizzes,
    loading,
    error,
    refreshQuizzes: fetchQuizzes,
    getQuizById,
    deleteQuiz,
    searchQuizzes,
    exportQuizJSON,
  };
}

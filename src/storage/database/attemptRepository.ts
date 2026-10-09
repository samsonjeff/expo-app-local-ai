import { getDatabase } from './db';
import { QuizAttempt, AttemptAnswer } from '../../types/quiz.types';
import { v4 as uuidv4 } from 'uuid';

export class AttemptRepository {
  /**
   * Save a completed user quiz attempt along with individual question answers.
   */
  static async saveAttempt(attempt: Omit<QuizAttempt, 'id'> & { id?: string }): Promise<QuizAttempt> {
    const db = await getDatabase();
    const attemptId = attempt.id || uuidv4();

    await db.withTransactionAsync(async () => {
      // 1. Insert Attempt Summary Header
      await db.runAsync(
        `INSERT INTO attempts 
          (id, quiz_id, score, max_score, percentage, completed_at, duration_seconds) 
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          attemptId,
          attempt.quizId,
          attempt.score,
          attempt.maxScore,
          attempt.percentage,
          attempt.completedAt || new Date().toISOString(),
          attempt.durationSeconds,
        ]
      );

      // 2. Insert Attempt Answers
      if (attempt.answers && attempt.answers.length > 0) {
        for (const ans of attempt.answers) {
          await db.runAsync(
            `INSERT INTO attempt_answers 
              (id, attempt_id, question_id, selected_option_id, text_response, is_correct, points_earned) 
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [
              ans.id || uuidv4(),
              attemptId,
              ans.questionId,
              ans.selectedOptionId || null,
              ans.textResponse || null,
              ans.isCorrect ? 1 : 0,
              ans.pointsEarned,
            ]
          );
        }
      }
    });

    return (await AttemptRepository.getAttemptById(attemptId))!;
  }

  /**
   * Get all attempts for a given quiz ID.
   */
  static async getAttemptsByQuizId(quizId: string): Promise<QuizAttempt[]> {
    const db = await getDatabase();
    const rows = await db.getAllAsync<any>(
      `SELECT * FROM attempts WHERE quiz_id = ? ORDER BY datetime(completed_at) DESC`,
      [quizId]
    );

    return rows.map((row) => ({
      id: row.id,
      quizId: row.quiz_id,
      score: row.score,
      maxScore: row.max_score,
      percentage: row.percentage,
      completedAt: row.completed_at,
      durationSeconds: row.duration_seconds,
    }));
  }

  /**
   * Get attempt detail with specific answer breakdown.
   */
  static async getAttemptById(attemptId: string): Promise<QuizAttempt | null> {
    const db = await getDatabase();
    const row = await db.getFirstAsync<any>(`SELECT * FROM attempts WHERE id = ?`, [attemptId]);

    if (!row) return null;

    const answerRows = await db.getAllAsync<any>(
      `SELECT * FROM attempt_answers WHERE attempt_id = ?`,
      [attemptId]
    );

    const answers: AttemptAnswer[] = answerRows.map((aRow) => ({
      id: aRow.id,
      attemptId: aRow.attempt_id,
      questionId: aRow.question_id,
      selectedOptionId: aRow.selected_option_id,
      textResponse: aRow.text_response,
      isCorrect: Boolean(aRow.is_correct),
      pointsEarned: aRow.points_earned,
    }));

    return {
      id: row.id,
      quizId: row.quiz_id,
      score: row.score,
      maxScore: row.max_score,
      percentage: row.percentage,
      completedAt: row.completed_at,
      durationSeconds: row.duration_seconds,
      answers,
    };
  }

  /**
   * Get user quiz stats summary (total attempts, average score %, highest score %).
   */
  static async getQuizStats(quizId: string): Promise<{ totalAttempts: number; avgPercentage: number; maxPercentage: number }> {
    const db = await getDatabase();
    const result = await db.getFirstAsync<any>(
      `SELECT COUNT(*) as count, AVG(percentage) as avg_pct, MAX(percentage) as max_pct FROM attempts WHERE quiz_id = ?`,
      [quizId]
    );

    return {
      totalAttempts: result?.count || 0,
      avgPercentage: Math.round(result?.avg_pct || 0),
      maxPercentage: Math.round(result?.max_pct || 0),
    };
  }
}

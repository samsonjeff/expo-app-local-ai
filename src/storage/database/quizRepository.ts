import { getDatabase } from './db';
import { Quiz, QuizQuestion, QuizOption, QuestionType } from '../../types/quiz.types';
import { v4 as uuidv4 } from 'uuid';

export class QuizRepository {
  /**
   * Save a newly generated or updated quiz with its questions and options.
   */
  static async saveQuiz(quiz: Quiz): Promise<Quiz> {
    const db = await getDatabase();
    const quizId = quiz.id || uuidv4();
    const now = new Date().toISOString();

    await db.withTransactionAsync(async () => {
      // 1. Insert Quiz Header
      await db.runAsync(
        `INSERT OR REPLACE INTO quizzes 
          (id, title, description, category, difficulty, question_types, total_questions, source_type, source_filename, created_at, updated_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          quizId,
          quiz.title,
          quiz.description,
          quiz.category || 'General',
          quiz.difficulty,
          JSON.stringify(quiz.questionTypes),
          quiz.totalQuestions,
          quiz.sourceType,
          quiz.sourceFilename || null,
          quiz.createdAt || now,
          now,
        ]
      );

      // 2. Insert Questions & Options
      if (quiz.questions && quiz.questions.length > 0) {
        for (let qIndex = 0; qIndex < quiz.questions.length; qIndex++) {
          const q = quiz.questions[qIndex];
          const questionId = q.id || uuidv4();

          await db.runAsync(
            `INSERT OR REPLACE INTO questions 
              (id, quiz_id, question_text, question_type, points, explanation, order_index, acceptable_answers) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [
              questionId,
              quizId,
              q.questionText,
              q.questionType,
              q.points || 1,
              q.explanation || '',
              q.orderIndex ?? qIndex,
              q.acceptableAnswers ? JSON.stringify(q.acceptableAnswers) : null,
            ]
          );

          // Insert Options if available
          if (q.options && q.options.length > 0) {
            for (let oIndex = 0; oIndex < q.options.length; oIndex++) {
              const opt = q.options[oIndex];
              const optionId = opt.id || uuidv4();

              await db.runAsync(
                `INSERT OR REPLACE INTO options 
                  (id, question_id, option_text, is_correct, order_index) 
                 VALUES (?, ?, ?, ?, ?)`,
                [
                  optionId,
                  questionId,
                  opt.optionText,
                  opt.isCorrect ? 1 : 0,
                  opt.orderIndex ?? oIndex,
                ]
              );
            }
          }
        }
      }
    });

    return (await QuizRepository.getQuizById(quizId))!;
  }

  /**
   * Get all quizzes (summary list) ordered by latest created.
   */
  static async getAllQuizzes(): Promise<Quiz[]> {
    const db = await getDatabase();
    const rows = await db.getAllAsync<any>(
      `SELECT * FROM quizzes ORDER BY datetime(created_at) DESC`
    );

    return rows.map((row) => ({
      id: row.id,
      title: row.title,
      description: row.description,
      category: row.category,
      difficulty: row.difficulty,
      questionTypes: JSON.parse(row.question_types || '[]'),
      totalQuestions: row.total_questions,
      sourceType: row.source_type,
      sourceFilename: row.source_filename,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));
  }

  /**
   * Get full quiz detail by ID, including nested questions and options.
   */
  static async getQuizById(id: string): Promise<Quiz | null> {
    const db = await getDatabase();
    const quizRow = await db.getFirstAsync<any>(`SELECT * FROM quizzes WHERE id = ?`, [id]);

    if (!quizRow) return null;

    const questionRows = await db.getAllAsync<any>(
      `SELECT * FROM questions WHERE quiz_id = ? ORDER BY order_index ASC`,
      [id]
    );

    const questions: QuizQuestion[] = [];

    for (const qRow of questionRows) {
      const optionRows = await db.getAllAsync<any>(
        `SELECT * FROM options WHERE question_id = ? ORDER BY order_index ASC`,
        [qRow.id]
      );

      const options: QuizOption[] = optionRows.map((oRow) => ({
        id: oRow.id,
        questionId: oRow.question_id,
        optionText: oRow.option_text,
        isCorrect: Boolean(oRow.is_correct),
        orderIndex: oRow.order_index,
      }));

      questions.push({
        id: qRow.id,
        quizId: qRow.quiz_id,
        questionText: qRow.question_text,
        questionType: qRow.question_type as QuestionType,
        points: qRow.points,
        explanation: qRow.explanation,
        orderIndex: qRow.order_index,
        acceptableAnswers: qRow.acceptable_answers ? JSON.parse(qRow.acceptable_answers) : undefined,
        options,
      });
    }

    return {
      id: quizRow.id,
      title: quizRow.title,
      description: quizRow.description,
      category: quizRow.category,
      difficulty: quizRow.difficulty,
      questionTypes: JSON.parse(quizRow.question_types || '[]'),
      totalQuestions: quizRow.total_questions,
      sourceType: quizRow.source_type,
      sourceFilename: quizRow.source_filename,
      createdAt: quizRow.created_at,
      updatedAt: quizRow.updated_at,
      questions,
    };
  }

  /**
   * Delete quiz by ID.
   */
  static async deleteQuiz(id: string): Promise<boolean> {
    const db = await getDatabase();
    const result = await db.runAsync(`DELETE FROM quizzes WHERE id = ?`, [id]);
    return result.changes > 0;
  }

  /**
   * Search quizzes by title or category keyword.
   */
  static async searchQuizzes(query: string): Promise<Quiz[]> {
    const db = await getDatabase();
    const pattern = `%${query}%`;
    const rows = await db.getAllAsync<any>(
      `SELECT * FROM quizzes WHERE title LIKE ? OR category LIKE ? ORDER BY datetime(created_at) DESC`,
      [pattern, pattern]
    );

    return rows.map((row) => ({
      id: row.id,
      title: row.title,
      description: row.description,
      category: row.category,
      difficulty: row.difficulty,
      questionTypes: JSON.parse(row.question_types || '[]'),
      totalQuestions: row.total_questions,
      sourceType: row.source_type,
      sourceFilename: row.source_filename,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));
  }

  /**
   * Export full quiz to JSON format for offline backup or sharing.
   */
  static async exportQuizToJSON(id: string): Promise<string | null> {
    const quiz = await QuizRepository.getQuizById(id);
    if (!quiz) return null;
    return JSON.stringify(quiz, null, 2);
  }
}

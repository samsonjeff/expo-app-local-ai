import 'package:sqflite/sqflite.dart';
import '../../models/attempt.dart';
import 'app_database.dart';

class AttemptRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<void> saveAttempt(QuizAttempt attempt) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'quiz_attempts',
        {
          'id': attempt.id,
          'quiz_id': attempt.quizId,
          'started_at': attempt.startedAt.toIso8601String(),
          'completed_at': attempt.completedAt?.toIso8601String(),
          'score': attempt.score,
          'total_possible_score': attempt.totalPossibleScore,
          'percentage': attempt.percentage,
          'time_spent_seconds': attempt.timeSpentSeconds,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete('user_answers', where: 'attempt_id = ?', whereArgs: [attempt.id]);

      for (final ans in attempt.answers) {
        await txn.insert('user_answers', {
          'id': ans.id,
          'attempt_id': attempt.id,
          'question_id': ans.questionId,
          'selected_option_id': ans.selectedOptionId,
          'text_answer': ans.textAnswer,
          'is_correct': ans.isCorrect ? 1 : 0,
          'earned_points': ans.earnedPoints,
          'feedback': ans.feedback,
        });
      }
    });
  }

  Future<List<QuizAttempt>> getAttemptsForQuiz(String quizId) async {
    final db = await _db;
    final rows = await db.query(
      'quiz_attempts',
      where: 'quiz_id = ?',
      whereArgs: [quizId],
      orderBy: 'started_at DESC',
    );

    final attempts = <QuizAttempt>[];
    for (final row in rows) {
      final attemptId = row['id'] as String;
      final answerRows = await db.query('user_answers', where: 'attempt_id = ?', whereArgs: [attemptId]);
      final answers = answerRows.map((a) => UserAnswer(
        id: a['id'] as String,
        attemptId: attemptId,
        questionId: a['question_id'] as String,
        selectedOptionId: a['selected_option_id'] as String?,
        textAnswer: a['text_answer'] as String?,
        isCorrect: (a['is_correct'] as int) == 1,
        earnedPoints: a['earned_points'] as int,
        feedback: a['feedback'] as String? ?? '',
      )).toList();

      attempts.add(QuizAttempt(
        id: attemptId,
        quizId: quizId,
        startedAt: DateTime.parse(row['started_at'] as String),
        completedAt: row['completed_at'] != null ? DateTime.parse(row['completed_at'] as String) : null,
        score: row['score'] as int,
        totalPossibleScore: row['total_possible_score'] as int,
        percentage: (row['percentage'] as num).toDouble(),
        timeSpentSeconds: row['time_spent_seconds'] as int,
        answers: answers,
      ));
    }
    return attempts;
  }
}

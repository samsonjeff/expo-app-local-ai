import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../models/quiz.dart';
import 'app_database.dart';

class QuizRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<void> saveQuiz(Quiz quiz) async {
    final db = await _db;
    await db.transaction((txn) async {
      // 1. Insert or update quiz
      await txn.insert(
        'quizzes',
        {
          'id': quiz.id,
          'title': quiz.title,
          'description': quiz.description,
          'category': quiz.category,
          'difficulty': quiz.difficulty.value,
          'source_document_id': quiz.sourceDocumentId,
          'created_at': quiz.createdAt.toIso8601String(),
          'updated_at': quiz.updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Remove existing questions/options for this quiz if updating
      await txn.delete('questions', where: 'quiz_id = ?', whereArgs: [quiz.id]);

      // 3. Insert questions and options
      for (int i = 0; i < quiz.questions.length; i++) {
        final q = quiz.questions[i];
        await txn.insert('questions', {
          'id': q.id,
          'quiz_id': quiz.id,
          'question_text': q.questionText,
          'question_type': q.questionType.value,
          'points': q.points,
          'explanation': q.explanation,
          'order_index': q.orderIndex,
          'acceptable_answers_json': jsonEncode(q.acceptableAnswers),
        });

        for (int j = 0; j < q.options.length; j++) {
          final opt = q.options[j];
          await txn.insert('options', {
            'id': opt.id,
            'question_id': q.id,
            'option_text': opt.optionText,
            'is_correct': opt.isCorrect ? 1 : 0,
            'order_index': opt.orderIndex,
          });
        }
      }
    });
  }

  Future<Quiz?> getQuizById(String quizId) async {
    final db = await _db;
    final quizRows = await db.query('quizzes', where: 'id = ?', whereArgs: [quizId]);
    if (quizRows.isEmpty) return null;

    final qRow = quizRows.first;
    final questions = await getQuestionsForQuiz(quizId);

    return Quiz(
      id: qRow['id'] as String,
      title: qRow['title'] as String,
      description: qRow['description'] as String? ?? '',
      category: qRow['category'] as String? ?? 'General',
      difficulty: QuizDifficulty.fromString(qRow['difficulty'] as String? ?? 'medium'),
      sourceDocumentId: qRow['source_document_id'] as String?,
      createdAt: DateTime.parse(qRow['created_at'] as String),
      updatedAt: DateTime.parse(qRow['updated_at'] as String),
      questions: questions,
    );
  }

  Future<List<QuizQuestion>> getQuestionsForQuiz(String quizId) async {
    final db = await _db;
    final questionRows = await db.query(
      'questions',
      where: 'quiz_id = ?',
      whereArgs: [quizId],
      orderBy: 'order_index ASC',
    );

    final questions = <QuizQuestion>[];
    for (final qMap in questionRows) {
      final qId = qMap['id'] as String;
      final optionRows = await db.query(
        'options',
        where: 'question_id = ?',
        whereArgs: [qId],
        orderBy: 'order_index ASC',
      );

      final options = optionRows.map((oMap) => QuizOption(
        id: oMap['id'] as String,
        optionText: oMap['option_text'] as String,
        isCorrect: (oMap['is_correct'] as int) == 1,
        orderIndex: oMap['order_index'] as int,
      )).toList();

      final acceptableJson = qMap['acceptable_answers_json'] as String? ?? '[]';
      final acceptableList = (jsonDecode(acceptableJson) as List<dynamic>)
          .map((e) => e.toString())
          .toList();

      questions.add(QuizQuestion(
        id: qId,
        questionText: qMap['question_text'] as String,
        questionType: QuestionType.fromString(qMap['question_type'] as String),
        points: (qMap['points'] as int?) ?? 1,
        explanation: qMap['explanation'] as String? ?? '',
        orderIndex: (qMap['order_index'] as int?) ?? 0,
        options: options,
        acceptableAnswers: acceptableList,
      ));
    }

    return questions;
  }

  Future<List<Quiz>> getAllQuizzes() async {
    final db = await _db;
    final rows = await db.query('quizzes', orderBy: 'created_at DESC');
    final quizzes = <Quiz>[];
    for (final row in rows) {
      final quizId = row['id'] as String;
      final questions = await getQuestionsForQuiz(quizId);
      quizzes.add(Quiz(
        id: quizId,
        title: row['title'] as String,
        description: row['description'] as String? ?? '',
        category: row['category'] as String? ?? 'General',
        difficulty: QuizDifficulty.fromString(row['difficulty'] as String? ?? 'medium'),
        sourceDocumentId: row['source_document_id'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        questions: questions,
      ));
    }
    return quizzes;
  }

  Future<void> deleteQuiz(String quizId) async {
    final db = await _db;
    await db.delete('quizzes', where: 'id = ?', whereArgs: [quizId]);
  }
}

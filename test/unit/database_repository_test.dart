import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app_local_ai/models/attempt.dart';
import 'package:quiz_app_local_ai/models/quiz.dart';
import 'package:quiz_app_local_ai/storage/database/app_database.dart';
import 'package:quiz_app_local_ai/storage/database/attempt_repository.dart';
import 'package:quiz_app_local_ai/storage/database/quiz_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database Repositories', () {
    late QuizRepository quizRepo;
    late AttemptRepository attemptRepo;

    setUp(() async {
      // Use in-memory SQLite database for isolated unit tests
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      AppDatabase.setMockDatabase(db);

      // Initialize tables
      await db.execute('PRAGMA foreign_keys = ON;');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS documents (
          id TEXT PRIMARY KEY,
          file_name TEXT NOT NULL,
          file_path TEXT NOT NULL,
          type TEXT NOT NULL,
          file_size_bytes INTEGER NOT NULL,
          character_count INTEGER DEFAULT 0,
          estimated_tokens INTEGER DEFAULT 0,
          uploaded_at TEXT NOT NULL
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quizzes (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT DEFAULT '',
          category TEXT DEFAULT 'General',
          difficulty TEXT DEFAULT 'medium',
          source_document_id TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS questions (
          id TEXT PRIMARY KEY,
          quiz_id TEXT NOT NULL,
          question_text TEXT NOT NULL,
          question_type TEXT NOT NULL,
          points INTEGER DEFAULT 1,
          explanation TEXT DEFAULT '',
          order_index INTEGER DEFAULT 0,
          acceptable_answers_json TEXT DEFAULT '[]',
          FOREIGN KEY (quiz_id) REFERENCES quizzes (id) ON DELETE CASCADE
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS options (
          id TEXT PRIMARY KEY,
          question_id TEXT NOT NULL,
          option_text TEXT NOT NULL,
          is_correct INTEGER NOT NULL,
          order_index INTEGER DEFAULT 0,
          FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quiz_attempts (
          id TEXT PRIMARY KEY,
          quiz_id TEXT NOT NULL,
          started_at TEXT NOT NULL,
          completed_at TEXT,
          score INTEGER DEFAULT 0,
          total_possible_score INTEGER DEFAULT 0,
          percentage REAL DEFAULT 0.0,
          time_spent_seconds INTEGER DEFAULT 0,
          FOREIGN KEY (quiz_id) REFERENCES quizzes (id) ON DELETE CASCADE
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_answers (
          id TEXT PRIMARY KEY,
          attempt_id TEXT NOT NULL,
          question_id TEXT NOT NULL,
          selected_option_id TEXT,
          text_answer TEXT,
          is_correct INTEGER NOT NULL,
          earned_points INTEGER DEFAULT 0,
          feedback TEXT DEFAULT '',
          FOREIGN KEY (attempt_id) REFERENCES quiz_attempts (id) ON DELETE CASCADE,
          FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
        );
      ''');

      // Clear existing records between tests
      await db.delete('user_answers');
      await db.delete('quiz_attempts');
      await db.delete('options');
      await db.delete('questions');
      await db.delete('quizzes');
      await db.delete('documents');

      quizRepo = QuizRepository();
      attemptRepo = AttemptRepository();
    });

    test('saves and retrieves quiz with questions and options', () async {
      final quiz = Quiz(
        title: 'Operating Systems',
        category: 'Computer Science',
        questions: [
          QuizQuestion(
            questionText: 'What is a deadlock?',
            questionType: QuestionType.multipleChoice,
            options: [
              QuizOption(optionText: 'A circular wait state', isCorrect: true),
              QuizOption(optionText: 'A fast thread', isCorrect: false),
            ],
          ),
        ],
      );

      await quizRepo.saveQuiz(quiz);

      final fetched = await quizRepo.getQuizById(quiz.id);
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('Operating Systems'));
      expect(fetched.questions.length, equals(1));
      expect(fetched.questions.first.options.length, equals(2));
      expect(fetched.questions.first.options.first.isCorrect, isTrue);
    });

    test('deleting a quiz cascades to questions, options, and attempts', () async {
      final quiz = Quiz(
        title: 'Cascade Test',
        questions: [
          QuizQuestion(
            questionText: 'Test question',
            questionType: QuestionType.trueFalse,
            options: [
              QuizOption(optionText: 'True', isCorrect: true),
              QuizOption(optionText: 'False', isCorrect: false),
            ],
          ),
        ],
      );
      await quizRepo.saveQuiz(quiz);

      final attempt = QuizAttempt(
        quizId: quiz.id,
        score: 1,
        totalPossibleScore: 1,
        percentage: 100.0,
      );
      await attemptRepo.saveAttempt(attempt);

      // Verify exists
      expect(await quizRepo.getQuizById(quiz.id), isNotNull);
      final attemptsBefore = await attemptRepo.getAttemptsForQuiz(quiz.id);
      expect(attemptsBefore.length, equals(1));

      // Delete Quiz
      await quizRepo.deleteQuiz(quiz.id);

      // Verify cascade
      expect(await quizRepo.getQuizById(quiz.id), isNull);
      final attemptsAfter = await attemptRepo.getAttemptsForQuiz(quiz.id);
      expect(attemptsAfter.isEmpty, isTrue);
    });
  });
}

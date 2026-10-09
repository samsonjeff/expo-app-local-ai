import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app_local_ai/inference/mock_llama_bridge.dart';
import 'package:quiz_app_local_ai/models/quiz.dart';
import 'package:quiz_app_local_ai/orchestration/json_validator.dart';
import 'package:quiz_app_local_ai/orchestration/prompt_builder.dart';
import 'package:quiz_app_local_ai/storage/database/app_database.dart';
import 'package:quiz_app_local_ai/storage/database/quiz_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Question Uniqueness & Deduplication Logic', () {
    test('Quiz.normalizeText collapses whitespace, strips prefixes and trailing punctuation', () {
      expect(
        Quiz.normalizeText('  1. What is Flutter?  '),
        equals('what is flutter'),
      );
      expect(
        Quiz.normalizeText('Question 4: What is Flutter!'),
        equals('what is flutter'),
      );
      expect(
        Quiz.normalizeText('Q1 -   What   is   Flutter??'),
        equals('what is flutter'),
      );
    });

    test('Quiz.deduplicateQuestions eliminates duplicate questions and re-indexes orderIndex', () {
      final questions = [
        QuizQuestion(
          questionText: 'What is a Dart Isolate?',
          questionType: QuestionType.multipleChoice,
          orderIndex: 0,
        ),
        QuizQuestion(
          questionText: 'What is a Dart Isolate?', // exact duplicate
          questionType: QuestionType.multipleChoice,
          orderIndex: 1,
        ),
        QuizQuestion(
          questionText: 'what is a dart isolate?', // case-insensitive duplicate
          questionType: QuestionType.multipleChoice,
          orderIndex: 2,
        ),
        QuizQuestion(
          questionText: '2. What is a Dart Isolate??', // prefix & punctuation duplicate
          questionType: QuestionType.multipleChoice,
          orderIndex: 3,
        ),
        QuizQuestion(
          questionText: 'How do Dart Isolates communicate?', // distinct question
          questionType: QuestionType.multipleChoice,
          orderIndex: 4,
        ),
      ];

      final unique = Quiz.deduplicateQuestions(questions);

      expect(unique.length, equals(2));
      expect(unique[0].questionText, equals('What is a Dart Isolate?'));
      expect(unique[0].orderIndex, equals(0));
      expect(unique[1].questionText, equals('How do Dart Isolates communicate?'));
      expect(unique[1].orderIndex, equals(1));
    });

    test('Quiz.deduplicateOptions removes duplicate options within questions', () {
      final options = [
        QuizOption(optionText: 'Memory Sharing', isCorrect: false),
        QuizOption(optionText: 'Message Passing', isCorrect: true),
        QuizOption(optionText: 'memory sharing', isCorrect: false), // duplicate
      ];

      final uniqueOpts = Quiz.deduplicateOptions(options);
      expect(uniqueOpts.length, equals(2));
      expect(uniqueOpts[0].optionText, equals('Memory Sharing'));
      expect(uniqueOpts[0].orderIndex, equals(0));
      expect(uniqueOpts[1].optionText, equals('Message Passing'));
      expect(uniqueOpts[1].orderIndex, equals(1));
    });

    test('Quiz.fromJson automatically deduplicates repeated questions from raw JSON', () {
      final jsonPayload = {
        'title': 'Operating Systems',
        'questions': [
          {
            'questionText': 'Explain paging and segmentation.',
            'questionType': 'essay',
            'points': 5,
          },
          {
            'questionText': 'Explain paging and segmentation.', // duplicate
            'questionType': 'essay',
            'points': 5,
          },
          {
            'questionText': 'What is a page fault?', // unique
            'questionType': 'multiple_choice',
            'points': 1,
          },
        ],
      };

      final quiz = Quiz.fromJson(jsonPayload);
      expect(quiz.totalQuestions, equals(2));
      expect(quiz.questions[0].questionText, equals('Explain paging and segmentation.'));
      expect(quiz.questions[0].orderIndex, equals(0));
      expect(quiz.questions[1].questionText, equals('What is a page fault?'));
      expect(quiz.questions[1].orderIndex, equals(1));
    });

    test('JsonValidator.validateAndNormalizeQuiz deduplicates questions from LLM output', () {
      const rawJson = '''
{
  "title": "Database Systems",
  "questions": [
    {
      "questionText": "What does ACID stand for?",
      "questionType": "identification",
      "acceptableAnswers": ["Atomicity, Consistency, Isolation, Durability"]
    },
    {
      "questionText": "what does acid stand for?",
      "questionType": "identification",
      "acceptableAnswers": ["ACID"]
    },
    {
      "questionText": "What does ACID stand for?",
      "questionType": "identification",
      "acceptableAnswers": ["ACID"]
    }
  ]
}
''';

      final quiz = JsonValidator.validateAndNormalizeQuiz(rawJson);
      expect(quiz.totalQuestions, equals(1));
      expect(quiz.questions.first.questionText, equals('What does ACID stand for?'));
    });
  });

  group('MockLlamaBridge Question Generation Uniqueness', () {
    late MockLlamaBridge bridge;

    setUp(() async {
      bridge = MockLlamaBridge();
      await bridge.loadModel('mock-model.gguf');
    });

    tearDown(() async {
      await bridge.unloadModel();
    });

    test('generates 10 completely unique questions without any repetition for default topic quiz', () async {
      final prompt = PromptBuilder.buildQuizPrompt(
        topic: 'Flutter Architecture',
        questionCount: 10,
        questionTypes: ['multiple_choice'],
      );

      final buffer = StringBuffer();
      await for (final chunk in bridge.generate(prompt)) {
        buffer.write(chunk.token);
      }

      final quiz = JsonValidator.validateAndNormalizeQuiz(buffer.toString());

      expect(quiz.totalQuestions, equals(10));

      final normalizedTexts = quiz.questions.map((q) => Quiz.normalizeText(q.questionText)).toSet();
      // Ensure that all 10 questions have strictly distinct normalized text
      expect(normalizedTexts.length, equals(10), reason: 'Every generated question must have unique text');
    });

    test('generates 15 unique questions across multiple question types without duplication', () async {
      final prompt = PromptBuilder.buildQuizPrompt(
        topic: 'Cell Biology',
        questionCount: 15,
        questionTypes: ['multiple_choice', 'true_false', 'identification', 'enumeration', 'essay'],
      );

      final buffer = StringBuffer();
      await for (final chunk in bridge.generate(prompt)) {
        buffer.write(chunk.token);
      }

      final quiz = JsonValidator.validateAndNormalizeQuiz(buffer.toString());

      expect(quiz.totalQuestions, equals(15));

      final normalizedTexts = quiz.questions.map((q) => Quiz.normalizeText(q.questionText)).toSet();
      expect(normalizedTexts.length, equals(15), reason: 'All 15 questions across mixed types must be unique');
    });

    test('generates unique questions even when study material contains only a single short sentence', () async {
      final prompt = PromptBuilder.buildQuizPrompt(
        content: 'Photosynthesis converts light energy into chemical energy stored in glucose.',
        questionCount: 8,
        questionTypes: ['multiple_choice'],
      );

      final buffer = StringBuffer();
      await for (final chunk in bridge.generate(prompt)) {
        buffer.write(chunk.token);
      }

      final quiz = JsonValidator.validateAndNormalizeQuiz(buffer.toString());

      expect(quiz.totalQuestions, equals(8));

      final normalizedTexts = quiz.questions.map((q) => Quiz.normalizeText(q.questionText)).toSet();
      expect(normalizedTexts.length, equals(8), reason: 'All 8 questions must be unique despite sparse source text');
    });
  });

  group('QuizRepository Database Uniqueness & Idempotency', () {
    late QuizRepository quizRepo;

    setUp(() async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      AppDatabase.setMockDatabase(db);

      await db.execute('PRAGMA foreign_keys = ON;');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quizzes (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT DEFAULT '',
          category TEXT DEFAULT 'General',
          difficulty TEXT DEFAULT 'medium',
          assessment_mode TEXT DEFAULT 'quiz',
          passing_score INTEGER DEFAULT 70,
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

      await db.delete('options');
      await db.delete('questions');
      await db.delete('quizzes');

      quizRepo = QuizRepository();
    });

    test('saveQuiz deduplicates questions idempotently before inserting into database', () async {
      final quiz = Quiz(
        title: 'Concurrency Patterns',
        questions: [
          QuizQuestion(
            questionText: 'What is a mutex?',
            questionType: QuestionType.multipleChoice,
            options: [QuizOption(optionText: 'Mutual exclusion lock', isCorrect: true)],
          ),
          QuizQuestion(
            questionText: 'What is a mutex?', // duplicate
            questionType: QuestionType.multipleChoice,
            options: [QuizOption(optionText: 'Mutual exclusion lock', isCorrect: true)],
          ),
        ],
      );

      await quizRepo.saveQuiz(quiz);

      final fetched = await quizRepo.getQuizById(quiz.id);
      expect(fetched, isNotNull);
      expect(fetched!.questions.length, equals(1));
      expect(fetched.questions.first.questionText, equals('What is a mutex?'));
    });

    test('getQuestionsForQuiz deduplicates legacy duplicate rows present in database', () async {
      final db = await AppDatabase.database;
      const quizId = 'legacy-quiz-123';

      await db.insert('quizzes', {
        'id': quizId,
        'title': 'Legacy Quiz with Duplicates',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Directly insert raw duplicate rows into database simulating pre-fix database state
      await db.insert('questions', {
        'id': 'q1',
        'quiz_id': quizId,
        'question_text': 'What is SQL?',
        'question_type': 'multiple_choice',
        'order_index': 0,
      });
      await db.insert('questions', {
        'id': 'q2',
        'quiz_id': quizId,
        'question_text': 'What is SQL?', // identical text
        'question_type': 'multiple_choice',
        'order_index': 1,
      });
      await db.insert('questions', {
        'id': 'q3',
        'quiz_id': quizId,
        'question_text': 'What is NoSQL?', // unique
        'question_type': 'multiple_choice',
        'order_index': 2,
      });

      final retrievedQuestions = await quizRepo.getQuestionsForQuiz(quizId);

      expect(retrievedQuestions.length, equals(2));
      expect(retrievedQuestions[0].questionText, equals('What is SQL?'));
      expect(retrievedQuestions[0].orderIndex, equals(0));
      expect(retrievedQuestions[1].questionText, equals('What is NoSQL?'));
      expect(retrievedQuestions[1].orderIndex, equals(1));
    });
  });
}

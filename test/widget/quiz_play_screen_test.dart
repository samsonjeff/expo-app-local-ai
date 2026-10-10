import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app_local_ai/models/quiz.dart';
import 'package:quiz_app_local_ai/presentation/screens/home_screen.dart';
import 'package:quiz_app_local_ai/presentation/screens/quiz_play_screen.dart';
import 'package:quiz_app_local_ai/presentation/screens/results_screen.dart';
import 'package:quiz_app_local_ai/providers/quiz_providers.dart';
import 'package:quiz_app_local_ai/storage/database/app_database.dart';
import 'package:quiz_app_local_ai/storage/database/quiz_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestQuizzesNotifier extends QuizzesNotifier {
  final List<Quiz> _initial;
  _TestQuizzesNotifier(this._initial);

  @override
  Future<List<Quiz>> build() async => _initial;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Quiz sampleExam;

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
        assessment_mode TEXT DEFAULT 'exam',
        passing_score INTEGER DEFAULT 75,
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

    sampleExam = Quiz(
      id: 'exam-1',
      title: 'Operating Systems Final Exam',
      assessmentMode: AssessmentMode.exam,
      difficulty: QuizDifficulty.hard,
      passingScore: 75,
      questions: [
        QuizQuestion(
          id: 'q1',
          questionText: 'What is a deadlock in OS?',
          questionType: QuestionType.multipleChoice,
          points: 1,
          options: [
            QuizOption(id: 'opt1', optionText: 'Circular wait condition', isCorrect: true),
            QuizOption(id: 'opt2', optionText: 'High CPU utilization', isCorrect: false),
          ],
        ),
        QuizQuestion(
          id: 'q2',
          questionText: 'Paging prevents external fragmentation.',
          questionType: QuestionType.trueFalse,
          points: 1,
          options: [
            QuizOption(id: 'opt_true', optionText: 'True', isCorrect: true),
            QuizOption(id: 'opt_false', optionText: 'False', isCorrect: false),
          ],
        ),
        QuizQuestion(
          id: 'q3',
          questionText: 'What algorithm prevents priority inversion?',
          questionType: QuestionType.identification,
          points: 2,
          acceptableAnswers: ['Priority Inheritance'],
        ),
        QuizQuestion(
          id: 'q4',
          questionText: 'Enumerate three IPC mechanisms.',
          questionType: QuestionType.enumeration,
          points: 3,
          acceptableAnswers: ['Pipes', 'Shared Memory', 'Message Queues'],
        ),
        QuizQuestion(
          id: 'q5',
          questionText: 'Explain the working of virtual memory management.',
          questionType: QuestionType.essay,
          points: 5,
          explanation: 'Rubric: Page tables, TLB cache, and page fault handling.',
        ),
      ],
    );

    final quizRepo = QuizRepository();
    await quizRepo.saveQuiz(sampleExam);
  });

  testWidgets('QuizPlayScreen renders all question types and completes exam submission', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: QuizPlayScreen(quiz: sampleExam, isPracticeMode: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Question 1 (Multiple Choice)
    expect(find.text('Operating Systems Final Exam'), findsOneWidget);
    expect(find.text('What is a deadlock in OS?'), findsOneWidget);
    expect(find.text('Circular wait condition'), findsOneWidget);

    // Select Option 1
    await tester.tap(find.text('Circular wait condition'));
    await tester.pumpAndSettle();

    // Tap Next
    await tester.tap(find.text('Next Question'));
    await tester.pumpAndSettle();

    // 2. Question 2 (True/False)
    expect(find.text('Paging prevents external fragmentation.'), findsOneWidget);
    expect(find.text('True'), findsOneWidget);
    expect(find.text('False'), findsOneWidget);

    await tester.tap(find.text('True'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next Question'));
    await tester.pumpAndSettle();

    // 3. Question 3 (Identification)
    expect(find.text('What algorithm prevents priority inversion?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Priority Inheritance');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next Question'));
    await tester.pumpAndSettle();

    // 4. Question 4 (Enumeration)
    expect(find.text('Enumerate three IPC mechanisms.'), findsOneWidget);
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));
    await tester.enterText(textFields.at(0), 'Pipes');
    await tester.enterText(textFields.at(1), 'Shared Memory');
    await tester.enterText(textFields.at(2), 'Message Queues');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next Question'));
    await tester.pumpAndSettle();

    // 5. Question 5 (Essay)
    expect(find.text('Explain the working of virtual memory management.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'Virtual memory translates virtual addresses to physical pages using page tables and TLBs to handle faults.',
    );
    await tester.pumpAndSettle();

    // Last question shows "Submit Assessment"
    expect(find.text('Submit Assessment'), findsOneWidget);
    await tester.tap(find.text('Submit Assessment'));
    await tester.pumpAndSettle();

    // Confirmation dialog
    expect(find.text('Submit Assessment?'), findsOneWidget);
    expect(find.text('Submit & Grade'), findsOneWidget);
    await tester.tap(find.text('Submit & Grade'));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // Should transition to ResultsScreen
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('Assessment Passed!'), findsOneWidget);
  });

  testWidgets('HomeScreen Take Exam button launches exam flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizzesProvider.overrideWith(() => _TestQuizzesNotifier([sampleExam])),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Find Take Exam button on quiz card
    final takeExamBtn = find.text('Take Exam');
    expect(takeExamBtn, findsOneWidget);

    await tester.ensureVisible(takeExamBtn);
    await tester.pumpAndSettle();

    await tester.tap(takeExamBtn);
    await tester.pumpAndSettle();

    // Should directly launch QuizPlayScreen
    expect(find.byType(QuizPlayScreen), findsOneWidget);
    expect(find.text('Operating Systems Final Exam'), findsOneWidget);
  });

  testWidgets('True/False questions are fully responsive even without explicit options', (tester) async {
    final tfQuiz = Quiz(
      id: 'tf-quiz',
      title: 'True False Verification Test',
      assessmentMode: AssessmentMode.exam,
      passingScore: 100,
      questions: [
        QuizQuestion(
          id: 'tf1',
          questionText: 'Flutter compiles to native ARM code.',
          questionType: QuestionType.trueFalse,
          points: 1,
          options: const [], // Empty options to test resilience
          acceptableAnswers: ['True'],
        ),
      ],
    );

    await tester.runAsync(() async {
      await QuizRepository().saveQuiz(tfQuiz);
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: QuizPlayScreen(quiz: tfQuiz, isPracticeMode: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should render True and False buttons
    expect(find.text('True'), findsOneWidget);
    expect(find.text('False'), findsOneWidget);

    // Tap True
    await tester.tap(find.text('True'));
    await tester.pumpAndSettle();

    // Submit
    await tester.tap(find.text('Submit Assessment'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit & Grade'));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // Verified: passed with correct grade
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('Assessment Passed!'), findsOneWidget);
  });
}

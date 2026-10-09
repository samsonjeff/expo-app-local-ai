import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app_local_ai/models/quiz.dart';
import 'package:quiz_app_local_ai/services/quiz_export_service.dart';

void main() {
  group('QuizExportService', () {
    late Quiz sampleQuiz;

    setUp(() {
      sampleQuiz = Quiz(
        title: 'Cellular Biology Exam',
        category: 'Science',
        assessmentMode: AssessmentMode.exam,
        difficulty: QuizDifficulty.hard,
        passingScore: 75,
        questions: [
          QuizQuestion(
            questionText: 'Which organelle produces ATP through cellular respiration?',
            questionType: QuestionType.multipleChoice,
            points: 1,
            explanation: 'Mitochondria are the powerhouses of eukaryotic cells.',
            options: [
              QuizOption(optionText: 'Mitochondria', isCorrect: true),
              QuizOption(optionText: 'Ribosome', isCorrect: false),
              QuizOption(optionText: 'Endoplasmic Reticulum', isCorrect: false),
            ],
          ),
          QuizQuestion(
            questionText: 'Plant cells possess rigid cellulose cell walls.',
            questionType: QuestionType.trueFalse,
            points: 1,
            explanation: 'True. Plant cells have cellulose-based cell walls.',
            options: [
              QuizOption(optionText: 'True', isCorrect: true),
              QuizOption(optionText: 'False', isCorrect: false),
            ],
          ),
          QuizQuestion(
            questionText: 'Identify the pigment responsible for absorbing light in photosynthesis.',
            questionType: QuestionType.identification,
            points: 2,
            explanation: 'Chlorophyll is located in the thylakoid membranes.',
            acceptableAnswers: ['Chlorophyll'],
          ),
          QuizQuestion(
            questionText: 'Enumerate the three stages of aerobic cellular respiration.',
            questionType: QuestionType.enumeration,
            points: 3,
            explanation: 'Glycolysis, Krebs Cycle (Citric Acid Cycle), and Oxidative Phosphorylation.',
            acceptableAnswers: ['Glycolysis', 'Krebs Cycle', 'Oxidative Phosphorylation'],
          ),
          QuizQuestion(
            questionText: 'Explain how ATP synthase utilizes a proton gradient to synthesize ATP.',
            questionType: QuestionType.essay,
            points: 5,
            explanation: 'AI Rubric Key:\n• Chemiosmosis explanation (2 pts)\n• Proton-motive force mechanism (2 pts)\n• Clarity (1 pt)',
            acceptableAnswers: [],
          ),
        ],
      );
    });

    test('generates student test paper without revealing answers', () {
      final formatted = QuizExportService.generateFormattedText(sampleQuiz, includeAnswerKey: false);

      expect(formatted, contains('CELLULAR BIOLOGY EXAM'));
      expect(formatted, contains('STUDENT ASSESSMENT PAPER'));
      expect(formatted, contains('Name: _______________________________'));
      expect(formatted, contains('Which organelle produces ATP'));
      expect(formatted, contains('[ ] (A) Mitochondria'));
      expect(formatted, isNot(contains('<-- CORRECT ANSWER')));
      expect(formatted, isNot(contains('*** TEACHER ANSWER KEY & GRADING RUBRIC ***')));
    });

    test('generates teacher answer key revealing correct answers and essay rubric', () {
      final formatted = QuizExportService.generateFormattedText(sampleQuiz, includeAnswerKey: true);

      expect(formatted, contains('*** TEACHER ANSWER KEY & GRADING RUBRIC ***'));
      expect(formatted, contains('<-- CORRECT ANSWER'));
      expect(formatted, contains('CORRECT ANSWER: Chlorophyll'));
      expect(formatted, contains('ACCEPTABLE ITEMS:'));
      expect(formatted, contains('Glycolysis'));
      expect(formatted, contains('AI RUBRIC KEY & MODEL ANSWER:'));
      expect(formatted, contains('Chemiosmosis explanation'));
    });

    test('generates valid PDF bytes without exceptions', () async {
      final studentPdfBytes = await QuizExportService.generatePdfBytes(sampleQuiz, includeAnswerKey: false);
      expect(studentPdfBytes.isNotEmpty, isTrue);
      expect(studentPdfBytes.length, greaterThan(100));

      final teacherPdfBytes = await QuizExportService.generatePdfBytes(sampleQuiz, includeAnswerKey: true);
      expect(teacherPdfBytes.isNotEmpty, isTrue);
      expect(teacherPdfBytes.length, greaterThan(100));
    });
  });
}

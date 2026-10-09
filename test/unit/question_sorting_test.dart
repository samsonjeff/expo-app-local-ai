import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app_local_ai/inference/mock_llama_bridge.dart';
import 'package:quiz_app_local_ai/models/quiz.dart';
import 'package:quiz_app_local_ai/orchestration/json_validator.dart';
import 'package:quiz_app_local_ai/orchestration/prompt_builder.dart';

void main() {
  group('Question Type Sorting & Section Grouping', () {
    test('QuestionType sortPriority puts multipleChoice first and essay last', () {
      expect(QuestionType.multipleChoice.sortPriority, equals(1));
      expect(QuestionType.trueFalse.sortPriority, equals(2));
      expect(QuestionType.fillInBlank.sortPriority, equals(3));
      expect(QuestionType.identification.sortPriority, equals(4));
      expect(QuestionType.enumeration.sortPriority, equals(5));
      expect(QuestionType.essay.sortPriority, equals(6));

      expect(QuestionType.multipleChoice.sortPriority < QuestionType.trueFalse.sortPriority, isTrue);
      expect(QuestionType.trueFalse.sortPriority < QuestionType.identification.sortPriority, isTrue);
      expect(QuestionType.identification.sortPriority < QuestionType.essay.sortPriority, isTrue);
    });

    test('Quiz.sortQuestionsByType groups mixed questions into clean sequential sections', () {
      final mixed = [
        QuizQuestion(
          id: 'q1',
          questionText: 'Discuss system design tradeoffs.',
          questionType: QuestionType.essay,
          orderIndex: 0,
        ),
        QuizQuestion(
          id: 'q2',
          questionText: 'What is a widget?',
          questionType: QuestionType.multipleChoice,
          orderIndex: 1,
        ),
        QuizQuestion(
          id: 'q3',
          questionText: 'Name the keyword used to declare a variable once.',
          questionType: QuestionType.identification,
          orderIndex: 2,
        ),
        QuizQuestion(
          id: 'q4',
          questionText: 'Dart is single-threaded.',
          questionType: QuestionType.trueFalse,
          orderIndex: 3,
        ),
        QuizQuestion(
          id: 'q5',
          questionText: 'What is Riverpod?',
          questionType: QuestionType.multipleChoice,
          orderIndex: 4,
        ),
        QuizQuestion(
          id: 'q6',
          questionText: 'State 3 SOLID principles.',
          questionType: QuestionType.enumeration,
          orderIndex: 5,
        ),
      ];

      final sorted = Quiz.sortQuestionsByType(mixed);

      expect(sorted.length, equals(6));

      // Multiple Choice first (order preserved)
      expect(sorted[0].id, equals('q2'));
      expect(sorted[0].questionType, equals(QuestionType.multipleChoice));
      expect(sorted[0].orderIndex, equals(0));

      expect(sorted[1].id, equals('q5'));
      expect(sorted[1].questionType, equals(QuestionType.multipleChoice));
      expect(sorted[1].orderIndex, equals(1));

      // True/False second
      expect(sorted[2].id, equals('q4'));
      expect(sorted[2].questionType, equals(QuestionType.trueFalse));
      expect(sorted[2].orderIndex, equals(2));

      // Identification third
      expect(sorted[3].id, equals('q3'));
      expect(sorted[3].questionType, equals(QuestionType.identification));
      expect(sorted[3].orderIndex, equals(3));

      // Enumeration fourth
      expect(sorted[4].id, equals('q6'));
      expect(sorted[4].questionType, equals(QuestionType.enumeration));
      expect(sorted[4].orderIndex, equals(4));

      // Essay last
      expect(sorted[5].id, equals('q1'));
      expect(sorted[5].questionType, equals(QuestionType.essay));
      expect(sorted[5].orderIndex, equals(5));
    });

    test('JsonValidator.validateAndNormalizeQuiz produces sorted sections by question type', () {
      const rawJson = '''
{
  "title": "Flutter Architecture Test",
  "questions": [
    {
      "questionText": "Explain Isolate memory model.",
      "questionType": "essay",
      "points": 5
    },
    {
      "questionText": "Flutter compiles to native code.",
      "questionType": "true_false",
      "points": 1
    },
    {
      "questionText": "What widget handles touch?",
      "questionType": "multiple_choice",
      "options": [
        {"optionText": "GestureDetector", "isCorrect": true},
        {"optionText": "Text", "isCorrect": false}
      ]
    },
    {
      "questionText": "What command runs tests?",
      "questionType": "identification",
      "acceptableAnswers": ["flutter test"]
    }
  ]
}
''';

      final quiz = JsonValidator.validateAndNormalizeQuiz(rawJson);

      expect(quiz.questions.length, equals(4));
      expect(quiz.questions[0].questionType, equals(QuestionType.multipleChoice));
      expect(quiz.questions[1].questionType, equals(QuestionType.trueFalse));
      expect(quiz.questions[2].questionType, equals(QuestionType.identification));
      expect(quiz.questions[3].questionType, equals(QuestionType.essay));
      expect(quiz.questions.last.questionType, equals(QuestionType.essay));
    });

    test('MockLlamaBridge generates grouped sections for 30 questions (10 MC, 10 T/F, 10 ID)', () async {
      final bridge = MockLlamaBridge();
      await bridge.loadModel('mock.gguf');

      final prompt = PromptBuilder.buildQuizPrompt(
        topic: 'Operating Systems',
        questionCount: 30,
        questionTypes: ['multiple_choice', 'true_false', 'identification'],
      );

      final buffer = StringBuffer();
      await for (final chunk in bridge.generate(prompt)) {
        buffer.write(chunk.token);
      }

      await bridge.unloadModel();

      final quiz = JsonValidator.validateAndNormalizeQuiz(buffer.toString());

      expect(quiz.totalQuestions, equals(30));

      // Questions 0-9 should be Multiple Choice
      for (int i = 0; i < 10; i++) {
        expect(quiz.questions[i].questionType, equals(QuestionType.multipleChoice),
            reason: 'Question $i should be multiple choice');
      }

      // Questions 10-19 should be True/False
      for (int i = 10; i < 20; i++) {
        expect(quiz.questions[i].questionType, equals(QuestionType.trueFalse),
            reason: 'Question $i should be true/false');
      }

      // Questions 20-29 should be Identification
      for (int i = 20; i < 30; i++) {
        expect(quiz.questions[i].questionType, equals(QuestionType.identification),
            reason: 'Question $i should be identification');
      }
    });
  });
}

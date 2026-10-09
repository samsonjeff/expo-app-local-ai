import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app_local_ai/models/quiz.dart';
import 'package:quiz_app_local_ai/orchestration/json_validator.dart';

void main() {
  group('JsonValidator', () {
    test('cleans markdown backticks and repairs trailing commas', () {
      const rawOutput = '''
```json
{
  "title": "Quantum Physics Basics",
  "description": "Intro to quantum mechanics",
  "category": "Physics",
  "difficulty": "medium",
  "questions": [
    {
      "questionText": "What is the smallest discrete unit of energy?",
      "questionType": "multiple_choice",
      "points": 1,
      "explanation": "A quantum is the minimum amount of any physical entity.",
      "options": [
        { "optionText": "Quantum", "isCorrect": true, },
        { "optionText": "Proton", "isCorrect": false, },
      ],
      "acceptableAnswers": ["Quantum",],
    },
  ],
}
```
''';

      final quiz = JsonValidator.validateAndNormalizeQuiz(rawOutput);
      expect(quiz.title, equals('Quantum Physics Basics'));
      expect(quiz.questions.length, equals(1));
      expect(quiz.questions.first.questionType, equals(QuestionType.multipleChoice));
      expect(quiz.questions.first.options.length, equals(2));
      expect(quiz.questions.first.options.first.isCorrect, isTrue);
    });

    test('throws FormatException if json is severely malformed', () {
      expect(
        () => JsonValidator.validateAndNormalizeQuiz('Hello this is not JSON at all'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

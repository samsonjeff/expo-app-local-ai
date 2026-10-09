import '../models/quiz.dart';
import 'prompt_templates.dart';

class PromptBuilder {
  static String buildQuizPrompt({
    String? content,
    String? topic,
    int questionCount = 5,
    String difficulty = 'medium',
    List<String> questionTypes = const ['multiple_choice'],
    String assessmentMode = 'quiz',
    int passingScore = 70,
  }) {
    // Sort question types according to standard pedagogical assessment order
    final sortedTypes = List<String>.from(questionTypes)
      ..sort((a, b) => QuestionType.fromString(a).sortPriority.compareTo(QuestionType.fromString(b).sortPriority));
    final typesStr = sortedTypes.join(', ');
    final contextText = (content != null && content.trim().isNotEmpty)
        ? 'STUDY MATERIAL:\n"""\n${content.trim()}\n"""'
        : 'TOPIC: $topic';

    return '''${PromptTemplates.systemQuizGenerator}

INSTRUCTIONS FOR THIS GENERATION TASK:
1. Target Question Count: $questionCount
2. Target Difficulty Level: $difficulty
3. Assessment Mode: ${assessmentMode.toUpperCase()}
4. Passing Score Threshold: $passingScore%
5. Allowed Question Types: [$typesStr]
6. Base all questions strictly on the context below.
7. STRICT UNIQUENESS: Generate exactly $questionCount unique questions. Do not repeat any question or test the exact same concept twice.
8. GROUP & SORT BY QUESTION TYPE: Group questions sequentially by type into natural sections. Order the questions as:
   - First: Multiple Choice ('multiple_choice')
   - Second: True or False ('true_false')
   - Third: Fill in the Blank / Identification ('fill_in_blank', 'identification')
   - Fourth: Enumeration ('enumeration')
   - Last: Essay questions ('essay') at the very end of the assessment.

$contextText

REMINDER: Return ONLY raw JSON without markdown codeblocks or explanations.
''';
  }
}

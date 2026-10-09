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
    final typesStr = questionTypes.join(', ');
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

$contextText

REMINDER: Return ONLY raw JSON without markdown codeblocks or explanations.
''';
  }
}

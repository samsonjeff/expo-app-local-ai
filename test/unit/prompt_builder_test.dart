import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app_local_ai/orchestration/prompt_builder.dart';

void main() {
  group('PromptBuilder', () {
    test('builds prompt from topic', () {
      final prompt = PromptBuilder.buildQuizPrompt(
        topic: 'Dart Isolates',
        questionCount: 5,
        difficulty: 'medium',
        questionTypes: ['multiple_choice', 'true_false'],
      );

      expect(prompt, contains('Dart Isolates'));
      expect(prompt, contains('Target Question Count: 5'));
      expect(prompt, contains('multiple_choice, true_false'));
      expect(prompt, contains('CRITICAL REQUIREMENT: You MUST respond ONLY with a valid JSON object'));
    });

    test('builds prompt from material content', () {
      final prompt = PromptBuilder.buildQuizPrompt(
        content: 'Photosynthesis occurs in chloroplasts.',
        questionCount: 3,
        difficulty: 'easy',
      );

      expect(prompt, contains('STUDY MATERIAL:'));
      expect(prompt, contains('Photosynthesis occurs in chloroplasts.'));
    });
  });
}

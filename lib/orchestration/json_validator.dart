import 'dart:convert';
import '../models/quiz.dart';

class JsonValidator {
  static String cleanAndRepairJsonString(String rawOutput) {
    var cleaned = rawOutput.trim();

    // 1. Remove markdown backticks block wrapper if present
    cleaned = cleaned.replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*```$', caseSensitive: false), '');

    // 2. Find first '{' and last '}'
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }

    // 3. Remove trailing commas before closing braces/brackets
    cleaned = cleaned.replaceAllMapped(
      RegExp(r',\s*([}\]])'),
      (match) => match.group(1)!,
    );

    return cleaned;
  }

  static Quiz validateAndNormalizeQuiz(
    String rawLlmOutput, {
    String? sourceDocumentId,
    AssessmentMode? assessmentMode,
    int? passingScore,
  }) {
    final repairedJson = cleanAndRepairJsonString(rawLlmOutput);

    dynamic parsed;
    try {
      parsed = jsonDecode(repairedJson);
    } catch (e) {
      throw FormatException(
        'Failed to parse LLM output as JSON: $e\nRaw Output Snippet: '
        '${repairedJson.length > 200 ? repairedJson.substring(0, 200) : repairedJson}',
      );
    }

    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON root to be an object');
    }

    // Ensure questions array is present
    final questionsList = parsed['questions'];
    if (questionsList is! List || questionsList.isEmpty) {
      throw const FormatException('Generated JSON does not contain any questions');
    }

    final map = Map<String, dynamic>.from(parsed);
    if (sourceDocumentId != null) {
      map['sourceDocumentId'] = sourceDocumentId;
    }
    if (assessmentMode != null) {
      map['assessmentMode'] = assessmentMode.value;
    }
    if (passingScore != null) {
      map['passingScore'] = passingScore;
    }

    final quiz = Quiz.fromJson(map);

    if (quiz.questions.isEmpty) {
      throw const FormatException('Generated JSON does not contain any valid unique questions');
    }

    // Sort questions by pedagogical question type hierarchy (Multiple Choice -> True/False -> Identification -> Enumeration -> Essay)
    return quiz.sortedByType();
  }
}

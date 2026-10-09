import 'dart:async';
import 'dart:convert';
import '../models/inference.dart';
import 'llama_bridge.dart';

class MockLlamaBridge implements LlamaBridge {
  bool _isLoaded = false;
  bool _isStopped = false;

  @override
  bool get isModelLoaded => _isLoaded;

  @override
  Future<void> loadModel(
    String modelPath, {
    int contextSize = 4096,
    int threads = 4,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _isLoaded = true;
    _isStopped = false;
  }

  @override
  Stream<GenerationChunk> generate(
    String prompt, {
    GenerationOptions options = const GenerationOptions(),
  }) async* {
    if (!_isLoaded) {
      throw StateError('Cannot generate: model is not loaded');
    }
    _isStopped = false;

    // Dynamically synthesize questions reflecting the actual prompt and uploaded document content
    final responseJson = _synthesizeQuizFromPrompt(prompt);

    final chunkSize = 12;
    int tokenCount = 0;

    for (int i = 0; i < responseJson.length; i += chunkSize) {
      if (_isStopped) break;

      final end = (i + chunkSize < responseJson.length) ? i + chunkSize : responseJson.length;
      final piece = responseJson.substring(i, end);
      tokenCount += 1;

      yield GenerationChunk(
        token: piece,
        totalTokensSoFar: tokenCount,
        isDone: false,
      );

      await Future.delayed(const Duration(milliseconds: 8));
    }

    yield GenerationChunk(
      token: '',
      totalTokensSoFar: tokenCount,
      isDone: true,
    );
  }

  String _synthesizeQuizFromPrompt(String prompt) {
    String title = "Study Material Assessment";
    String description = "Quiz generated directly from your uploaded material.";
    String materialSnippet = "";

    // Extract STUDY MATERIAL content if present
    final materialRegex = RegExp(r'STUDY MATERIAL:\s*"""([\s\S]*?)"""');
    final match = materialRegex.firstMatch(prompt);

    if (match != null && match.group(1) != null) {
      final raw = match.group(1)!.trim();
      if (raw.isNotEmpty) {
        materialSnippet = raw;
        // Grab first non-empty line as title or context hint
        final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.length > 3).toList();
        if (lines.isNotEmpty) {
          title = lines.first;
          if (title.length > 50) title = "${title.substring(0, 47)}...";
        }
      }
    } else {
      final topicRegex = RegExp(r'TOPIC:\s*(.*)');
      final topicMatch = topicRegex.firstMatch(prompt);
      if (topicMatch != null) {
        title = topicMatch.group(1)?.trim() ?? title;
      }
    }

    // Parse sentences/paragraphs from document
    List<String> keyFacts = [];
    if (materialSnippet.isNotEmpty) {
      keyFacts = materialSnippet
          .split(RegExp(r'\. |\n+'))
          .map((s) => s.replaceAll(RegExp(r'[^\w\s\-,]'), '').trim())
          .where((s) => s.length > 20 && s.length < 160)
          .toList();
    }

    final questions = <Map<String, dynamic>>[];

    if (keyFacts.length >= 2) {
      // 1. Multiple Choice from fact 1
      final fact1 = keyFacts[0];
      final words1 = fact1.split(' ').where((w) => w.length > 4).toList();
      final keyWord1 = words1.isNotEmpty ? words1.first : "the primary concept";

      questions.add({
        "questionText": "Based on the reading: What is true regarding $keyWord1?",
        "questionType": "multiple_choice",
        "points": 1,
        "explanation": "Derived directly from text: '$fact1'.",
        "options": [
          {"optionText": fact1, "isCorrect": true},
          {"optionText": "It is completely unrelated to the core topic discussed.", "isCorrect": false},
          {"optionText": "It was refuted by the author in the concluding remarks.", "isCorrect": false},
          {"optionText": "None of the above statements apply.", "isCorrect": false}
        ],
        "acceptableAnswers": [fact1]
      });

      // 2. True / False from fact 2
      final fact2 = keyFacts[1];
      questions.add({
        "questionText": "According to the document: '$fact2'.",
        "questionType": "true_false",
        "points": 1,
        "explanation": "Direct statement from the source document.",
        "options": [
          {"optionText": "True", "isCorrect": true},
          {"optionText": "False", "isCorrect": false}
        ],
        "acceptableAnswers": ["True"]
      });

      // 3. Question from fact 3 if available
      if (keyFacts.length >= 3) {
        final fact3 = keyFacts[2];
        final words3 = fact3.split(' ').where((w) => w.length > 5).toList();
        final keyWord3 = words3.isNotEmpty ? words3.last : "the subject";

        questions.add({
          "questionText": "Which core principle from the text involves $keyWord3?",
          "questionType": "multiple_choice",
          "points": 1,
          "explanation": "Refer to: '$fact3'.",
          "options": [
            {"optionText": fact3, "isCorrect": true},
            {"optionText": "Standard baseline assumption without empirical support", "isCorrect": false},
            {"optionText": "An outdated theory replaced by modern alternatives", "isCorrect": false},
            {"optionText": "An unverified hypothesis mentioned in passing", "isCorrect": false}
          ],
          "acceptableAnswers": [fact3]
        });
      }
    } else {
      // Fallback if document text is very short or topic only
      questions.addAll([
        {
          "questionText": "What is the primary subject addressed in '$title'?",
          "questionType": "multiple_choice",
          "points": 1,
          "explanation": "The material focuses on fundamental concepts related to $title.",
          "options": [
            {"optionText": "Core principles and foundational analysis of $title", "isCorrect": true},
            {"optionText": "Historical linguistics and phonetics", "isCorrect": false},
            {"optionText": "Quantum electrodynamics", "isCorrect": false},
            {"optionText": "Marine biology ecosystems", "isCorrect": false}
          ],
          "acceptableAnswers": ["Core principles and foundational analysis of $title"]
        },
        {
          "questionText": "The material provides practical examples and key principles for understanding $title.",
          "questionType": "true_false",
          "points": 1,
          "explanation": "True. The material introduces core ideas for study and review.",
          "options": [
            {"optionText": "True", "isCorrect": true},
            {"optionText": "False", "isCorrect": false}
          ],
          "acceptableAnswers": ["True"]
        }
      ]);
    }

    final quizData = {
      "title": title,
      "description": description,
      "category": "Study Material",
      "difficulty": "medium",
      "questions": questions
    };

    return jsonEncode(quizData);
  }

  @override
  Future<void> stopGeneration() async {
    _isStopped = true;
  }

  @override
  Future<void> unloadModel() async {
    _isLoaded = false;
    _isStopped = false;
  }
}

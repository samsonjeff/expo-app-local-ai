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
    await Future.delayed(const Duration(milliseconds: 120));
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

    final chunkSize = 16;
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

      await Future.delayed(const Duration(milliseconds: 6));
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

    // 1. Extract Target Question Count
    int targetCount = 5;
    final countMatch = RegExp(r'Target Question Count:\s*(\d+)').firstMatch(prompt);
    if (countMatch != null) {
      targetCount = int.tryParse(countMatch.group(1)!) ?? 5;
    }

    // 2. Extract Difficulty
    String difficulty = "medium";
    final diffMatch = RegExp(r'Target Difficulty Level:\s*(\w+)').firstMatch(prompt);
    if (diffMatch != null) {
      difficulty = diffMatch.group(1)!.toLowerCase();
    }

    // 3. Extract Assessment Mode
    String assessmentMode = "quiz";
    final modeMatch = RegExp(r'Assessment Mode:\s*(\w+)').firstMatch(prompt);
    if (modeMatch != null) {
      assessmentMode = modeMatch.group(1)!.toLowerCase();
    }

    // 4. Extract Allowed Question Types
    List<String> allowedTypes = ['multiple_choice'];
    final typesMatch = RegExp(r'Allowed Question Types:\s*\[(.*?)\]').firstMatch(prompt);
    if (typesMatch != null) {
      final rawTypes = typesMatch.group(1)!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (rawTypes.isNotEmpty) {
        allowedTypes = rawTypes;
      }
    }

    // 5. Extract STUDY MATERIAL content if present
    final materialRegex = RegExp(r'STUDY MATERIAL:\s*"""([\s\S]*?)"""');
    final match = materialRegex.firstMatch(prompt);

    if (match != null && match.group(1) != null) {
      final raw = match.group(1)!.trim();
      if (raw.isNotEmpty) {
        materialSnippet = raw;
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

    if (assessmentMode == 'exam') {
      description = "Comprehensive examination evaluating core competencies in $title.";
    }

    // Parse sentences / paragraphs from document
    List<String> keyFacts = [];
    if (materialSnippet.isNotEmpty) {
      keyFacts = materialSnippet
          .split(RegExp(r'\. |\n+'))
          .map((s) => s.replaceAll(RegExp(r'[^\w\s\-,]'), '').trim())
          .where((s) => s.length > 20 && s.length < 180)
          .toList();
    }

    if (keyFacts.isEmpty) {
      keyFacts = [
        "Foundational principles and structural taxonomy of $title",
        "Practical implementation paradigms and standard methodologies",
        "Empirical evaluation and performance trade-offs in modern workflows",
        "Safety guarantees, fault isolation, and state verification rules",
        "Architectural synthesis, lifecycle management, and resource bounds",
      ];
    }

    final questions = <Map<String, dynamic>>[];

    for (int i = 0; i < targetCount; i++) {
      final qType = allowedTypes[i % allowedTypes.length];
      final fact = keyFacts[i % keyFacts.length];
      final words = fact.split(' ').where((w) => w.length > 4).toList();
      final keyword = words.isNotEmpty ? words[i % words.length] : "the subject";

      switch (qType) {
        case 'true_false':
          final isTrue = (i % 2 == 0);
          questions.add({
            "questionText": isTrue
                ? "According to the lesson material, '$fact'."
                : "The material states that $keyword is universally deprecated and irrelevant.",
            "questionType": "true_false",
            "points": 1,
            "explanation": isTrue
                ? "True. This is a verified fact directly derived from the course material: '$fact'."
                : "False. The material emphasizes that $keyword is vital rather than deprecated.",
            "options": [
              {"optionText": "True", "isCorrect": isTrue},
              {"optionText": "False", "isCorrect": !isTrue}
            ],
            "acceptableAnswers": [isTrue ? "True" : "False"]
          });
          break;

        case 'identification':
          questions.add({
            "questionText": "Identification: What term designates the concept regarding '$fact'?",
            "questionType": "identification",
            "points": 2,
            "explanation": "The target term is '$keyword' based directly on: '$fact'.",
            "options": [],
            "acceptableAnswers": [keyword, keyword.toLowerCase(), keyword.toUpperCase()]
          });
          break;

        case 'enumeration':
          questions.add({
            "questionText": "Enumeration: Enumerate three key components or aspects related to $keyword.",
            "questionType": "enumeration",
            "points": 3,
            "explanation": "Expected items derived from course context: Primary Concept, Supporting Framework, and Application Domain.",
            "options": [],
            "acceptableAnswers": [
              "Primary Concept",
              "Supporting Framework",
              "Application Domain"
            ]
          });
          break;

        case 'essay':
          questions.add({
            "questionText": "Essay: Discuss the importance and practical implications of '$fact' in relation to $title.",
            "questionType": "essay",
            "points": 5,
            "explanation": "AI Rubric Key (Total: 5 Points):\n"
                "• Conceptual Accuracy (2 pts): Clearly explains the principle involving $keyword.\n"
                "• Analysis & Application (2 pts): Details relevant practical use cases and implications.\n"
                "• Coherence & Clarity (1 pt): Structured logically with appropriate terminology.\n\n"
                "Model Answer: A comprehensive answer must reference '$fact', demonstrate how it guides decision-making, and outline real-world execution constraints.",
            "options": [],
            "acceptableAnswers": []
          });
          break;

        case 'multiple_choice':
        default:
          questions.add({
            "questionText": "Which statement accurately describes the role of $keyword in $title?",
            "questionType": "multiple_choice",
            "points": 1,
            "explanation": "Directly based on the material: '$fact'.",
            "options": [
              {"optionText": fact, "isCorrect": true},
              {"optionText": "It represents an unverified hypothesis dismissed by authorities.", "isCorrect": false},
              {"optionText": "It is an auxiliary detail with zero bearing on overall results.", "isCorrect": false},
              {"optionText": "It is completely superseded by legacy practices.", "isCorrect": false}
            ],
            "acceptableAnswers": [fact]
          });
          break;
      }
    }

    final quizData = {
      "title": title,
      "description": description,
      "category": "Course Study Material",
      "difficulty": difficulty,
      "assessmentMode": assessmentMode,
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

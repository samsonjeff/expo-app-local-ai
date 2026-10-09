import 'dart:async';
import 'dart:convert';
import '../models/inference.dart';
import '../models/quiz.dart';
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

    // 4. Extract Allowed Question Types and sort in pedagogical section order
    List<String> allowedTypes = ['multiple_choice'];
    final typesMatch = RegExp(r'Allowed Question Types:\s*\[(.*?)\]').firstMatch(prompt);
    if (typesMatch != null) {
      final rawTypes = typesMatch.group(1)!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (rawTypes.isNotEmpty) {
        allowedTypes = rawTypes;
      }
    }
    // Sort types: Multiple Choice -> True/False -> Identification -> Enumeration -> Essay
    allowedTypes.sort((a, b) {
      final prioA = QuestionType.fromString(a).sortPriority;
      final prioB = QuestionType.fromString(b).sortPriority;
      return prioA.compareTo(prioB);
    });

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

    final foundationalFacets = [
      "Foundational principles and structural taxonomy of $title",
      "Practical implementation paradigms and standard methodologies",
      "Empirical evaluation and performance trade-offs in modern workflows",
      "Safety guarantees, fault isolation, and state verification rules",
      "Architectural synthesis, lifecycle management, and resource bounds",
      "Error recovery patterns, mitigation strategies, and edge-case handling",
      "Scalability invariants, concurrency controls, and throughput bounds",
      "Real-world application domains, operational constraints, and protocols",
      "Comparative analysis against legacy frameworks and baseline techniques",
      "Continuous verification, observability benchmarks, and telemetry standards",
      "State transition integrity and memory lifecycle constraints",
      "Algorithmic complexity, latency limits, and hardware-aware optimizations",
      "Modular subsystem encapsulation and clean interface boundaries",
      "Data serialization guarantees, validation schemas, and transactional safety",
      "Deployment topology configurations and environmental compliance",
    ];

    if (keyFacts.isEmpty) {
      keyFacts = foundationalFacets;
    } else if (keyFacts.length < targetCount) {
      // Supplement document facts with foundational domain facets to guarantee sufficient variety
      for (final facet in foundationalFacets) {
        if (!keyFacts.contains(facet)) {
          keyFacts.add(facet);
        }
        if (keyFacts.length >= targetCount * 2) break;
      }
    }

    final questions = <Map<String, dynamic>>[];
    final seenNormalizedTexts = <String>{};

    final distractorPool = [
      "It represents an unverified hypothesis dismissed by authorities.",
      "It is an auxiliary detail with zero bearing on overall results.",
      "It is completely superseded by legacy practices.",
      "It operates solely as an optional cosmetic embellishment.",
      "It introduces unbounded memory leakage in constrained environments.",
      "It violates fundamental architectural constraints.",
      "It serves only as a temporary diagnostic shim.",
      "It is strictly restricted to deprecated legacy runtimes.",
    ];

    // Group questions sequentially into contiguous sections (e.g. 10 Multiple Choice, 10 True/False, 10 Identification, etc.)
    final typeAssignments = <String>[];
    final itemsPerType = targetCount ~/ allowedTypes.length;
    var remainder = targetCount % allowedTypes.length;

    for (final type in allowedTypes) {
      final countForType = itemsPerType + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      for (int k = 0; k < countForType; k++) {
        typeAssignments.add(type);
      }
    }

    for (int i = 0; i < targetCount; i++) {
      final qType = (i < typeAssignments.length) ? typeAssignments[i] : allowedTypes[i % allowedTypes.length];
      final fact = keyFacts[i % keyFacts.length];
      final words = fact.split(' ').where((w) => w.length > 4 && !w.contains(RegExp(r'[0-9]'))).toList();
      final keyword = words.isNotEmpty ? words[(i * 3 + 1) % words.length] : "the subject";

      String questionText = '';
      String explanation = '';
      List<Map<String, dynamic>> options = [];
      List<String> acceptableAnswers = [];
      int points = 1;

      int attempt = 0;
      do {
        final variantIndex = (i + attempt) % 6;
        switch (qType) {
          case 'true_false':
            points = 1;
            final isTrue = ((i + attempt) % 2 == 0);
            if (isTrue) {
              if (variantIndex % 2 == 0) {
                questionText = "According to the lesson material, '$fact'.";
              } else {
                questionText = "Empirical principles in $title verify that $fact.";
              }
              explanation = "True. This is directly derived from the study context: '$fact'.";
            } else {
              if (variantIndex % 2 == 0) {
                questionText = "The material states that $keyword is universally deprecated and irrelevant in $title.";
              } else {
                questionText = "In $title, $keyword operates entirely without structural constraints or rules.";
              }
              explanation = "False. The material emphasizes that $keyword is an integral component.";
            }
            options = [
              {"optionText": "True", "isCorrect": isTrue, "orderIndex": 0},
              {"optionText": "False", "isCorrect": !isTrue, "orderIndex": 1}
            ];
            acceptableAnswers = [isTrue ? "True" : "False"];
            break;

          case 'identification':
            points = 2;
            switch (variantIndex % 3) {
              case 0:
                questionText = "Identification: What term designates the concept regarding '$fact'?";
                break;
              case 1:
                questionText = "Identification: Name the core mechanism responsible for $keyword in $title.";
                break;
              default:
                questionText = "Identification: Which specific term denotes the principle: '$fact'?";
                break;
            }
            explanation = "The target term is '$keyword' based directly on: '$fact'.";
            options = [];
            acceptableAnswers = [keyword, keyword.toLowerCase(), keyword.toUpperCase()];
            break;

          case 'enumeration':
            points = 3;
            switch (variantIndex % 3) {
              case 0:
                questionText = "Enumeration: Enumerate three key components or aspects related to $keyword.";
                break;
              case 1:
                questionText = "Enumeration: List three primary requirements for implementing $keyword in $title.";
                break;
              default:
                questionText = "Enumeration: Enumerate three critical criteria used to evaluate '$fact'.";
                break;
            }
            explanation = "Expected items derived from context: Primary Concept, Supporting Framework, and Application Domain.";
            options = [];
            acceptableAnswers = [
              "Primary Concept",
              "Supporting Framework",
              "Application Domain"
            ];
            break;

          case 'essay':
            points = 5;
            switch (variantIndex % 3) {
              case 0:
                questionText = "Essay: Discuss the importance and practical implications of '$fact' in relation to $title.";
                break;
              case 1:
                questionText = "Essay: Analyze how $keyword impacts overall architecture and reliability in $title.";
                break;
              default:
                questionText = "Essay: Critically evaluate the trade-offs of applying '$fact' in $title.";
                break;
            }
            explanation = "AI Rubric Key (Total: 5 Points):\n"
                "• Conceptual Accuracy (2 pts): Clearly explains the principle involving $keyword.\n"
                "• Analysis & Application (2 pts): Details relevant practical use cases and implications.\n"
                "• Coherence & Clarity (1 pt): Structured logically with appropriate terminology.\n\n"
                "Model Answer: A comprehensive answer must reference '$fact', demonstrate how it guides decision-making, and outline real-world execution constraints.";
            options = [];
            acceptableAnswers = [];
            break;

          case 'multiple_choice':
          default:
            points = 1;
            switch (variantIndex % 5) {
              case 0:
                questionText = "Which statement accurately describes the role of $keyword in $title?";
                break;
              case 1:
                questionText = "In the context of $title, what is the primary function of $keyword?";
                break;
              case 2:
                questionText = "When evaluating $title, which statement regarding '$fact' is correct?";
                break;
              case 3:
                questionText = "Which principle distinguishes $keyword from alternative approaches in $title?";
                break;
              default:
                questionText = "According to standard conventions in $title, how does $keyword operate?";
                break;
            }
            explanation = "Directly based on the material: '$fact'.";

            final correctPos = (i + attempt) % 4;
            final distractorOffset = (i * 2 + attempt) % distractorPool.length;
            final d1 = distractorPool[distractorOffset];
            final d2 = distractorPool[(distractorOffset + 1) % distractorPool.length];
            final d3 = distractorPool[(distractorOffset + 2) % distractorPool.length];

            final rawOpts = <Map<String, dynamic>>[];
            int distIdx = 0;
            final distractors = [d1, d2, d3];
            for (int optI = 0; optI < 4; optI++) {
              if (optI == correctPos) {
                rawOpts.add({"optionText": fact, "isCorrect": true, "orderIndex": optI});
              } else {
                rawOpts.add({"optionText": distractors[distIdx++], "isCorrect": false, "orderIndex": optI});
              }
            }
            options = rawOpts;
            acceptableAnswers = [fact];
            break;
        }

        if (seenNormalizedTexts.contains(Quiz.normalizeText(questionText))) {
          questionText = "$questionText [Item ${i + 1}]";
        }
        attempt++;
      } while (seenNormalizedTexts.contains(Quiz.normalizeText(questionText)) && attempt < 20);

      seenNormalizedTexts.add(Quiz.normalizeText(questionText));

      questions.add({
        "questionText": questionText,
        "questionType": qType,
        "points": points,
        "explanation": explanation,
        "orderIndex": i,
        "options": options,
        "acceptableAnswers": acceptableAnswers,
      });
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

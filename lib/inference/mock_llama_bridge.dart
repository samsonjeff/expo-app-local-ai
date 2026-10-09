import 'dart:async';
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
    // Simulate model loading time (150ms)
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

    final mockResponseJson = '''
{
  "title": "Comprehensive Knowledge Assessment",
  "description": "Auto-generated assessment covering core concepts and analytical reasoning.",
  "category": "Science & Technology",
  "difficulty": "medium",
  "questions": [
    {
      "questionText": "Which data structure operates on a Last-In, First-Out (LIFO) principle?",
      "questionType": "multiple_choice",
      "points": 1,
      "explanation": "A Stack operates on LIFO where the most recently added element is removed first.",
      "options": [
        { "optionText": "Queue", "isCorrect": false },
        { "optionText": "Stack", "isCorrect": true },
        { "optionText": "Binary Tree", "isCorrect": false },
        { "optionText": "Linked List", "isCorrect": false }
      ],
      "acceptableAnswers": ["Stack"]
    },
    {
      "questionText": "Dart isolates share mutable memory directly with each other.",
      "questionType": "true_false",
      "points": 1,
      "explanation": "False. Dart isolates have completely separate memory heaps and communicate only via message passing or SendPort/ReceivePort.",
      "options": [
        { "optionText": "True", "isCorrect": false },
        { "optionText": "False", "isCorrect": true }
      ],
      "acceptableAnswers": ["False"]
    },
    {
      "questionText": "What programming language does the Flutter framework use as its primary language?",
      "questionType": "identification",
      "points": 1,
      "explanation": "Flutter applications are written in Dart.",
      "options": [],
      "acceptableAnswers": ["Dart", "dart"]
    }
  ]
}''';

    // Break down text into realistic token chunks
    final chunkSize = 8;
    int tokenCount = 0;

    for (int i = 0; i < mockResponseJson.length; i += chunkSize) {
      if (_isStopped) break;

      final end = (i + chunkSize < mockResponseJson.length) ? i + chunkSize : mockResponseJson.length;
      final piece = mockResponseJson.substring(i, end);
      tokenCount += 1;

      // Yield token piece
      yield GenerationChunk(
        token: piece,
        totalTokensSoFar: tokenCount,
        isDone: false,
      );

      // Brief delay to simulate generation cadence
      await Future.delayed(const Duration(milliseconds: 10));
    }

    yield GenerationChunk(
      token: '',
      totalTokensSoFar: tokenCount,
      isDone: true,
    );
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

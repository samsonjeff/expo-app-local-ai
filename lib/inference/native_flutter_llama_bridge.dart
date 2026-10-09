import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_llama/flutter_llama.dart';
import '../models/inference.dart';
import 'llama_bridge.dart';

/// Production implementation of [LlamaBridge] utilizing the native `flutter_llama`
/// engine backed by `llama.cpp` (Metal on iOS/macOS, Vulkan on Android).
class NativeFlutterLlamaBridge implements LlamaBridge {
  final FlutterLlama _engine = FlutterLlama.instance;
  bool _isLoaded = false;
  bool _isGenerating = false;

  @override
  bool get isModelLoaded => _isLoaded;

  @override
  Future<void> loadModel(
    String modelPath, {
    int contextSize = 4096,
    int threads = 4,
  }) async {
    if (_isLoaded) {
      await unloadModel();
    }

    try {
      final config = LlamaConfig(
        modelPath: modelPath,
        contextSize: contextSize,
        nThreads: threads,
        nGpuLayers: defaultTargetPlatform == TargetPlatform.android ? -1 : 0,
        batchSize: 512,
        useGpu: defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS,
        verbose: false,
      );

      final success = await _engine.loadModel(config);
      if (!success) {
        throw StateError('Native llama.cpp engine failed to load model at: $modelPath');
      }
      _isLoaded = true;
    } catch (e) {
      _isLoaded = false;
      rethrow;
    }
  }

  @override
  Stream<GenerationChunk> generate(
    String prompt, {
    GenerationOptions options = const GenerationOptions(),
  }) async* {
    if (!_isLoaded) {
      throw StateError('Cannot generate: native llama model is not loaded in memory.');
    }

    _isGenerating = true;
    int tokenCount = 0;

    final params = GenerationParams(
      prompt: prompt,
      maxTokens: options.maxTokens,
      temperature: options.temperature,
      topP: options.topP,
      stopSequences: options.stopSequences,
    );

    try {
      await for (final token in _engine.generateStream(params)) {
        if (!_isGenerating) break;
        tokenCount++;
        yield GenerationChunk(
          token: token,
          totalTokensSoFar: tokenCount,
          isDone: false,
        );
      }
    } finally {
      _isGenerating = false;
      yield GenerationChunk(
        token: '',
        totalTokensSoFar: tokenCount,
        isDone: true,
      );
    }
  }

  @override
  Future<void> stopGeneration() async {
    _isGenerating = false;
  }

  @override
  Future<void> unloadModel() async {
    try {
      if (_isLoaded) {
        await _engine.unloadModel();
      }
    } finally {
      _isLoaded = false;
      _isGenerating = false;
    }
  }
}

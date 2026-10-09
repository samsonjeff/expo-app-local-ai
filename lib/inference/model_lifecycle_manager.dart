import 'dart:async';
import 'llama_bridge.dart';

class ModelLifecycleManager {
  final LlamaBridge bridge;
  bool _isLocked = false;

  ModelLifecycleManager({required this.bridge});

  bool get isModelLoaded => bridge.isModelLoaded;
  bool get isLocked => _isLocked;

  Future<T> executeWithModel<T>({
    required String modelPath,
    required Future<T> Function() action,
    int contextSize = 4096,
    int threads = 4,
  }) async {
    if (_isLocked) {
      throw StateError('Inference engine is currently busy with another active job.');
    }

    _isLocked = true;
    try {
      if (!bridge.isModelLoaded) {
        await bridge.loadModel(modelPath, contextSize: contextSize, threads: threads);
      }
      return await action();
    } finally {
      // Memory safety rule: Always unload model weights from RAM on completion or error
      try {
        await bridge.unloadModel();
      } catch (_) {}
      _isLocked = false;
    }
  }

  Future<void> handleLowMemoryWarning() async {
    if (!_isLocked && bridge.isModelLoaded) {
      await bridge.unloadModel();
    }
  }
}

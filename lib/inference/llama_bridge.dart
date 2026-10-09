import '../models/inference.dart';

abstract class LlamaBridge {
  bool get isModelLoaded;

  Future<void> loadModel(
    String modelPath, {
    int contextSize = 4096,
    int threads = 4,
  });

  Stream<GenerationChunk> generate(
    String prompt, {
    GenerationOptions options = const GenerationOptions(),
  });

  Future<void> stopGeneration();

  Future<void> unloadModel();
}

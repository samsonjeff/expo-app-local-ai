import '../models/inference.dart';

class ModelCatalog {
  static const ModelSpec qwen1_7B = ModelSpec(
    id: 'qwen3-1.7b-q4_k_m',
    name: 'Qwen 1.7B (Instruct Q4_K_M)',
    filename: 'qwen3-1.7b-instruct-q4_k_m.gguf',
    tier: HardwareTier.low,
    parameterCountMillion: 1700,
    quantization: 'Q4_K_M',
    fileSizeBytes: 1250000000, // ~1.25 GB
    requiredRamMb: 2100,
    downloadUrl: 'https://huggingface.co/Qwen/Qwen1.5-1.8B-Chat-GGUF/resolve/main/qwen1_5-1_8b-chat-q4_k_m.gguf',
  );

  static const ModelSpec phi4Mini = ModelSpec(
    id: 'phi-4-mini-q4_k_m',
    name: 'Phi-4-mini (Instruct Q4_K_M)',
    filename: 'phi-4-mini-instruct-q4_k_m.gguf',
    tier: HardwareTier.high,
    parameterCountMillion: 3800,
    quantization: 'Q4_K_M',
    fileSizeBytes: 2400000000, // ~2.4 GB
    requiredRamMb: 3400,
    downloadUrl: 'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf',
  );

  static List<ModelSpec> get allModels => [qwen1_7B, phi4Mini];

  static ModelSpec getRecommendedModel(HardwareTier tier) {
    switch (tier) {
      case HardwareTier.high:
        return phi4Mini;
      case HardwareTier.low:
        return qwen1_7B;
    }
  }
}

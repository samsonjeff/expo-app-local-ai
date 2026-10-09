enum HardwareTier {
  low('low', '4GB RAM - Qwen 1.7B'),
  high('high', '6GB-8GB+ RAM - Phi-4-mini');

  final String id;
  final String label;
  const HardwareTier(this.id, this.label);
}

class HardwareProfile {
  final int totalRamMb;
  final int availableRamMb;
  final HardwareTier tier;
  final int recommendedThreads;
  final int recommendedContextSize;

  const HardwareProfile({
    required this.totalRamMb,
    required this.availableRamMb,
    required this.tier,
    this.recommendedThreads = 4,
    this.recommendedContextSize = 4096,
  });

  bool get hasSufficientRamForInference => availableRamMb >= 1200;
}

class ModelSpec {
  final String id;
  final String name;
  final String filename;
  final HardwareTier tier;
  final int parameterCountMillion;
  final String quantization;
  final int fileSizeBytes;
  final int requiredRamMb;
  final String downloadUrl;

  const ModelSpec({
    required this.id,
    required this.name,
    required this.filename,
    required this.tier,
    required this.parameterCountMillion,
    required this.quantization,
    required this.fileSizeBytes,
    required this.requiredRamMb,
    required this.downloadUrl,
  });
}

class GenerationChunk {
  final String token;
  final int totalTokensSoFar;
  final bool isDone;

  const GenerationChunk({
    required this.token,
    required this.totalTokensSoFar,
    this.isDone = false,
  });
}

class GenerationOptions {
  final double temperature;
  final double topP;
  final int maxTokens;
  final int threads;
  final List<String> stopSequences;

  const GenerationOptions({
    this.temperature = 0.2,
    this.topP = 0.9,
    this.maxTokens = 2048,
    this.threads = 4,
    this.stopSequences = const ['<|im_end|>', '<|endoftext|>', '</s>'],
  });
}

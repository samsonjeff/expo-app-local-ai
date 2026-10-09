import { ModelPreset } from '../types/inference.types';

export const MODEL_PRESETS: ModelPreset[] = [
  {
    id: 'phi-4-mini-q4',
    name: 'Phi-4-mini (3.8B Q4_K_M)',
    parameterCount: '3.8B',
    quantization: 'Q4_K_M',
    ramRequirementMB: 2800,
    diskSizeMB: 2400,
    filename: 'phi-4-mini-instruct-q4_k_m.gguf',
    downloadUrl: 'https://huggingface.co/microsoft/Phi-4-mini-instruct-GGUF/resolve/main/Phi-4-mini-instruct-Q4_K_M.gguf',
    ramTier: 'high',
    description: 'Best reasoning & multi-format question accuracy. Recommended for 6GB-8GB RAM devices.',
  },
  {
    id: 'gemma-3n-e4b-q4',
    name: 'Gemma 3n / Gemma 4 (E4B Q4)',
    parameterCount: '4B (Eff)',
    quantization: 'Q4_K_M',
    ramRequirementMB: 2000,
    diskSizeMB: 1900,
    filename: 'gemma-3n-e4b-instruct-q4_k_m.gguf',
    downloadUrl: 'https://huggingface.co/google/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
    ramTier: 'mid',
    description: 'Fast instruction-following for structured JSON quiz generation. Recommended for 4GB-6GB RAM devices.',
  },
  {
    id: 'qwen3-1.7b-q4',
    name: 'Qwen3 (1.7B Q4_K_M)',
    parameterCount: '1.7B',
    quantization: 'Q4_K_M',
    ramRequirementMB: 1200,
    diskSizeMB: 1100,
    filename: 'qwen3-1.7b-instruct-q4_k_m.gguf',
    downloadUrl: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
    ramTier: 'low',
    description: 'Lightweight footprint for 4GB RAM devices with tight memory budget.',
  },
];

export function getPresetById(id: string): ModelPreset {
  return MODEL_PRESETS.find((p) => p.id === id) || MODEL_PRESETS[0];
}

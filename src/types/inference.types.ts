export type RAMTier = 'low' | 'mid' | 'high';

export interface DeviceRAMInfo {
  totalRAMMB: number;
  availableRAMMB: number;
  tier: RAMTier;
  recommendedModelId: string;
}

export interface ModelPreset {
  id: string;
  name: string;
  parameterCount: string; // e.g. "3.8B", "1.7B"
  quantization: string; // e.g. "Q4_K_M"
  ramRequirementMB: number; // e.g. 2500 for 2.5GB
  diskSizeMB: number;
  filename: string;
  downloadUrl: string;
  ramTier: RAMTier;
  description: string;
}

export type InferenceState = 'unloaded' | 'loading' | 'ready' | 'generating' | 'error';

export interface GenerationParams {
  prompt: string;
  systemPrompt?: string;
  temperature?: number;
  topP?: number;
  maxTokens?: number;
  stopSequences?: string[];
}

export type TokenStreamCallback = (token: string, fullText: string) => void;

export interface InferenceEngineStatus {
  state: InferenceState;
  loadedModelId: string | null;
  ramUsageMB: number;
  lastError: string | null;
}

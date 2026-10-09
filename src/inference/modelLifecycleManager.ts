import { LlamaBridge } from './llamaBridge';
import { ModelDownloader } from '../storage/filesystem/modelDownloader';
import { getPresetById, MODEL_PRESETS } from './modelTiers';
import { RAMDetector } from './ramDetector';
import { InferenceState, InferenceEngineStatus, ModelPreset } from '../types/inference.types';

export class ModelLifecycleManager {
  private static currentState: InferenceState = 'unloaded';
  private static activeModelPreset: ModelPreset | null = null;
  private static lastErrorMessage: string | null = null;

  /**
   * Get current state of the inference engine.
   */
  static getStatus(): InferenceEngineStatus {
    return {
      state: ModelLifecycleManager.currentState,
      loadedModelId: ModelLifecycleManager.activeModelPreset?.id || null,
      ramUsageMB: ModelLifecycleManager.activeModelPreset?.ramRequirementMB || 0,
      lastError: ModelLifecycleManager.lastErrorMessage,
    };
  }

  /**
   * Automatically select the optimal model preset for this device's RAM tier.
   */
  static async resolveAutoModelPreset(): Promise<ModelPreset> {
    const ramInfo = await RAMDetector.getRAMInfo();
    return getPresetById(ramInfo.recommendedModelId);
  }

  /**
   * Load GGUF model into memory right before generation starts.
   */
  static async loadModelForGeneration(requestedModelId?: string): Promise<ModelPreset> {
    try {
      ModelLifecycleManager.currentState = 'loading';
      ModelLifecycleManager.lastErrorMessage = null;

      const preset = requestedModelId 
        ? getPresetById(requestedModelId)
        : await ModelLifecycleManager.resolveAutoModelPreset();

      // Check if model file exists locally
      const isDownloaded = await ModelDownloader.isModelDownloaded(preset);
      if (!isDownloaded) {
        throw new Error(
          `Model file '${preset.filename}' is not downloaded. Download model weights first.`
        );
      }

      const modelFilePath = ModelDownloader.getModelFilePath(preset);
      await LlamaBridge.loadModel(modelFilePath);

      ModelLifecycleManager.activeModelPreset = preset;
      ModelLifecycleManager.currentState = 'ready';

      return preset;
    } catch (err: any) {
      ModelLifecycleManager.currentState = 'error';
      ModelLifecycleManager.lastErrorMessage = err.message || 'Failed to load AI model';
      throw err;
    }
  }

  /**
   * Unload AI model from RAM immediately after generation completes or fails.
   */
  static async unloadModelAfterGeneration(): Promise<void> {
    try {
      await LlamaBridge.unloadModel();
    } catch (err) {
      console.warn('Error during explicit model unload:', err);
    } finally {
      ModelLifecycleManager.activeModelPreset = null;
      ModelLifecycleManager.currentState = 'unloaded';
    }
  }

  /**
   * Execute a generation block with explicit load & unload lifecycle safety (auto-cleanup).
   */
  static async executeScopedInference<T>(
    modelId: string | undefined,
    inferenceTask: () => Promise<T>
  ): Promise<T> {
    await ModelLifecycleManager.loadModelForGeneration(modelId);
    try {
      ModelLifecycleManager.currentState = 'generating';
      const result = await inferenceTask();
      return result;
    } finally {
      await ModelLifecycleManager.unloadModelAfterGeneration();
    }
  }
}

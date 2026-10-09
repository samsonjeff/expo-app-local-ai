import * as FileSystem from 'expo-file-system/legacy';
import { FileStorageManager } from './fileStorage';
import { ModelPreset } from '../../types/inference.types';

export interface DownloadProgress {
  totalBytesWritten: number;
  totalBytesExpectedToWrite: number;
  percentage: number;
}

export type DownloadProgressCallback = (progress: DownloadProgress) => void;

export class ModelDownloader {
  /**
   * Get full local URI path for model preset GGUF file.
   */
  static getModelFilePath(preset: ModelPreset): string {
    return `${FileStorageManager.getModelsDirectory()}${preset.filename}`;
  }

  /**
   * Check if GGUF model file exists locally on device disk.
   */
  static async isModelDownloaded(preset: ModelPreset): Promise<boolean> {
    const filePath = ModelDownloader.getModelFilePath(preset);
    const info = await FileSystem.getInfoAsync(filePath);
    return info.exists && (info.size || 0) > 1000000; // > 1MB sanity check
  }

  /**
   * Check if device has enough free disk storage before downloading model file.
   */
  static async hasEnoughStorage(preset: ModelPreset): Promise<{ hasEnough: boolean; freeBytes: number; requiredBytes: number }> {
    const freeBytes = await FileStorageManager.getFreeDiskSpaceBytes();
    const requiredBytes = preset.diskSizeMB * 1024 * 1024 * 1.1; // 10% safety buffer
    return {
      hasEnough: freeBytes >= requiredBytes,
      freeBytes,
      requiredBytes,
    };
  }

  /**
   * Download GGUF model weight file from HuggingFace/URL with progress updates.
   */
  static async downloadModel(
    preset: ModelPreset,
    onProgress?: DownloadProgressCallback
  ): Promise<string> {
    await FileStorageManager.initStorageDirectories();
    const targetPath = ModelDownloader.getModelFilePath(preset);

    const downloadResumable = FileSystem.createDownloadResumable(
      preset.downloadUrl,
      targetPath,
      {},
      (downloadProgress) => {
        const total = downloadProgress.totalBytesExpectedToWrite;
        const current = downloadProgress.totalBytesWritten;
        const percentage = total > 0 ? Math.round((current / total) * 100) : 0;
        if (onProgress) {
          onProgress({
            totalBytesWritten: current,
            totalBytesExpectedToWrite: total,
            percentage,
          });
        }
      }
    );

    const result = await downloadResumable.downloadAsync();
    if (!result || !result.uri) {
      throw new Error(`Failed to download model weights for ${preset.name}`);
    }

    return result.uri;
  }
}

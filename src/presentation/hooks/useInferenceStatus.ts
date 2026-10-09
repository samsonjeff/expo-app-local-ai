import { useState, useEffect, useCallback } from 'react';
import { DeviceRAMInfo, ModelPreset, InferenceEngineStatus } from '../../types/inference.types';
import { RAMDetector } from '../../inference/ramDetector';
import { MODEL_PRESETS, getPresetById } from '../../inference/modelTiers';
import { ModelDownloader, DownloadProgress } from '../../storage/filesystem/modelDownloader';
import { ModelLifecycleManager } from '../../inference/modelLifecycleManager';

export function useInferenceStatus() {
  const [ramInfo, setRamInfo] = useState<DeviceRAMInfo | null>(null);
  const [status, setStatus] = useState<InferenceEngineStatus>(ModelLifecycleManager.getStatus());
  const [downloadProgress, setDownloadProgress] = useState<DownloadProgress | null>(null);
  const [isDownloading, setIsDownloading] = useState<boolean>(false);
  const [downloadedModels, setDownloadedModels] = useState<Record<string, boolean>>({});

  const checkModelsDownloadedState = useCallback(async () => {
    const map: Record<string, boolean> = {};
    for (const preset of MODEL_PRESETS) {
      map[preset.id] = await ModelDownloader.isModelDownloaded(preset);
    }
    setDownloadedModels(map);
  }, []);

  const refreshStatus = useCallback(async () => {
    const info = await RAMDetector.getRAMInfo();
    setRamInfo(info);
    setStatus(ModelLifecycleManager.getStatus());
    await checkModelsDownloadedState();
  }, [checkModelsDownloadedState]);

  const downloadModelPreset = useCallback(async (presetId: string) => {
    const preset = getPresetById(presetId);
    setIsDownloading(true);
    setDownloadProgress({ totalBytesWritten: 0, totalBytesExpectedToWrite: 0, percentage: 0 });

    try {
      await ModelDownloader.downloadModel(preset, (p) => {
        setDownloadProgress(p);
      });
      await checkModelsDownloadedState();
    } catch (err: any) {
      throw err;
    } finally {
      setIsDownloading(false);
      setDownloadProgress(null);
    }
  }, [checkModelsDownloadedState]);

  useEffect(() => {
    refreshStatus();
  }, [refreshStatus]);

  return {
    ramInfo,
    status,
    allModelPresets: MODEL_PRESETS,
    downloadedModels,
    isDownloading,
    downloadProgress,
    refreshStatus,
    downloadModelPreset,
  };
}

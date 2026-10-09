import * as Device from 'expo-device';
import { DeviceRAMInfo, RAMTier } from '../types/inference.types';
import { MODEL_PRESETS } from './modelTiers';

export class RAMDetector {
  /**
   * Get device total memory and determine appropriate RAM tier.
   */
  static async getRAMInfo(): Promise<DeviceRAMInfo> {
    let totalRAMBytes = Device.totalMemory || 0;
    
    // Fallback if expo-device totalMemory returns 0 (e.g. web or simulator)
    if (!totalRAMBytes || totalRAMBytes === 0) {
      totalRAMBytes = 4 * 1024 * 1024 * 1024; // Default assume 4GB
    }

    const totalRAMMB = Math.round(totalRAMBytes / (1024 * 1024));
    let tier: RAMTier = 'low';

    if (totalRAMMB >= 5800) {
      tier = 'high'; // 6GB - 8GB+ RAM
    } else if (totalRAMMB >= 3800) {
      tier = 'mid';  // 4GB - 6GB RAM
    } else {
      tier = 'low';  // Under 4GB RAM floor
    }

    // Pick recommended model based on tier
    const recommendedPreset = MODEL_PRESETS.find((p) => p.ramTier === tier) || MODEL_PRESETS[MODEL_PRESETS.length - 1];

    return {
      totalRAMMB,
      availableRAMMB: Math.round(totalRAMMB * 0.6), // Estimated available after OS overhead
      tier,
      recommendedModelId: recommendedPreset.id,
    };
  }
}

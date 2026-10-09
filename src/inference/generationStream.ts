import { LlamaBridge } from './llamaBridge';
import { GenerationParams, TokenStreamCallback } from '../types/inference.types';

export class GenerationStream {
  /**
   * Stream LLM text completion token-by-token.
   */
  static async runStream(
    params: GenerationParams,
    onToken?: TokenStreamCallback
  ): Promise<string> {
    return await LlamaBridge.generateCompletion(params, onToken);
  }
}

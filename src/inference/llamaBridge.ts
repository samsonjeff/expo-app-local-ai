import { GenerationParams, TokenStreamCallback } from '../types/inference.types';

// Interface matching llama.rn LlamaContext contract
export interface NativeLlamaContext {
  completion: (
    params: {
      prompt: string;
      temperature?: number;
      top_p?: number;
      max_tokens?: number;
      stop?: string[];
    },
    callback: (data: { token: string }) => void
  ) => Promise<{ text: string }>;
  release: () => Promise<void>;
}

export class LlamaBridge {
  private static activeContext: NativeLlamaContext | null = null;
  private static isNativeAvailable: boolean | null = null;

  /**
   * Check if native llama.rn module is compiled and available in the current environment.
   */
  static isNativeLlamaSupported(): boolean {
    if (LlamaBridge.isNativeAvailable !== null) {
      return LlamaBridge.isNativeAvailable;
    }

    try {
      // Check for native module existence via require
      const llamaRn = require('llama.rn');
      LlamaBridge.isNativeAvailable = Boolean(llamaRn && llamaRn.initLlama);
    } catch {
      LlamaBridge.isNativeAvailable = false;
    }

    return LlamaBridge.isNativeAvailable;
  }

  /**
   * Load GGUF model file into native memory (llama.cpp context).
   */
  static async loadModel(modelFilePath: string, contextSize: number = 2048): Promise<NativeLlamaContext> {
    if (LlamaBridge.activeContext) {
      await LlamaBridge.unloadModel();
    }

    if (LlamaBridge.isNativeLlamaSupported()) {
      const { initLlama } = require('llama.rn');
      LlamaBridge.activeContext = await initLlama({
        model: modelFilePath,
        n_ctx: contextSize,
        n_threads: 4,
        use_mlock: true, // Lock memory to prevent swap jank
        n_gpu_layers: 0, // CPU inference for mobile stability
      });
      return LlamaBridge.activeContext!;
    } else {
      // Dev / Simulator fallback mock engine
      LlamaBridge.activeContext = LlamaBridge.createDevFallbackContext();
      return LlamaBridge.activeContext;
    }
  }

  /**
   * Run completion streaming tokens.
   */
  static async generateCompletion(
    params: GenerationParams,
    onToken?: TokenStreamCallback
  ): Promise<string> {
    if (!LlamaBridge.activeContext) {
      throw new Error('No model loaded. Call loadModel() before starting inference.');
    }

    let fullText = '';
    const formattedPrompt = params.systemPrompt 
      ? `<|system|>\n${params.systemPrompt}\n<|user|>\n${params.prompt}\n<|assistant|>\n`
      : params.prompt;

    const result = await LlamaBridge.activeContext.completion(
      {
        prompt: formattedPrompt,
        temperature: params.temperature ?? 0.7,
        top_p: params.topP ?? 0.9,
        max_tokens: params.maxTokens ?? 1024,
        stop: params.stopSequences ?? ['<|end|>', '<|user|>', '</s>', '```\n\n'],
      },
      (data) => {
        if (data && data.token) {
          fullText += data.token;
          if (onToken) {
            onToken(data.token, fullText);
          }
        }
      }
    );

    return result.text || fullText;
  }

  /**
   * Unload GGUF model from RAM immediately to free memory.
   */
  static async unloadModel(): Promise<void> {
    if (LlamaBridge.activeContext) {
      try {
        await LlamaBridge.activeContext.release();
      } catch (err) {
        console.warn('Error releasing llama context:', err);
      } finally {
        LlamaBridge.activeContext = null;
      }
    }
  }

  /**
   * Fallback engine for development in Expo Go or web preview.
   * Generates valid JSON quiz structure to allow frontend development without native C++ compilation.
   */
  private static createDevFallbackContext(): NativeLlamaContext {
    return {
      completion: async (params, callback) => {
        const devQuizResponse = JSON.stringify(
          {
            title: 'Sample Offline AI Generated Quiz',
            description: 'Generated using Local AI Inference Engine',
            category: 'Computer Science',
            difficulty: 'medium',
            questions: [
              {
                questionText: 'Which layer handles GGUF model loading and explicit memory release in this app?',
                questionType: 'multiple_choice',
                points: 1,
                explanation: 'The AI Inference Layer isolates native llama.rn calls to manage RAM budget on 4GB devices.',
                options: [
                  { optionText: 'AI Inference Layer', isCorrect: true },
                  { optionText: 'Frontend Presentation Layer', isCorrect: false },
                  { optionText: 'Local SQLite Layer', isCorrect: false },
                  { optionText: 'HTTP Server Layer', isCorrect: false },
                ],
              },
              {
                questionText: 'On-device LLMs run completely offline without needing remote servers.',
                questionType: 'true_false',
                points: 1,
                explanation: 'GGUF models run directly in-process via native C++ llama.cpp bindings.',
                options: [
                  { optionText: 'True', isCorrect: true },
                  { optionText: 'False', isCorrect: false },
                ],
              },
              {
                questionText: 'What is the primary recommended model for 6GB-8GB RAM devices?',
                questionType: 'multiple_choice',
                points: 1,
                explanation: 'Phi-4-mini (3.8B Q4_K_M) provides the best reasoning-per-GB for multi-format quizzes.',
                options: [
                  { optionText: 'Phi-4-mini (3.8B)', isCorrect: true },
                  { optionText: 'GPT-4o', isCorrect: false },
                  { optionText: 'Claude 3.5 Sonnet', isCorrect: false },
                  { optionText: 'Llama 70B', isCorrect: false },
                ],
              },
            ],
          },
          null,
          2
        );

        // Simulate streaming token output token by token
        const tokens = devQuizResponse.split(/(.{1,5})/g).filter(Boolean);
        let accumulated = '';

        for (const token of tokens) {
          accumulated += token;
          callback({ token });
          await new Promise((res) => setTimeout(res, 15));
        }

        return { text: accumulated };
      },
      release: async () => {
        // Dev fallback release cleanup
      },
    };
  }
}

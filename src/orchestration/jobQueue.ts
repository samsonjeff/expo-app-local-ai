import { QuizGenerationRequest, Quiz } from '../types/quiz.types';
import { JobProgress, JobProgressCallback, GenerationJob } from '../types/queue.types';
import { DocumentParser } from './documentParser';
import { DocumentChunker } from './documentChunker';
import { PromptBuilder } from './promptBuilder';
import { ModelLifecycleManager } from '../inference/modelLifecycleManager';
import { GenerationStream } from '../inference/generationStream';
import { JSONValidator } from './jsonValidator';
import { QuizRepository } from '../storage/database/quizRepository';
import { v4 as uuidv4 } from 'uuid';

export class JobQueueManager {
  private static activeJobs: Map<string, GenerationJob> = new Map();

  /**
   * Submit and start a new quiz generation background job.
   */
  static async startQuizGenerationJob(
    request: QuizGenerationRequest,
    onProgress?: JobProgressCallback
  ): Promise<Quiz> {
    const jobId = uuidv4();
    const job: GenerationJob = {
      id: jobId,
      request,
      progress: {
        step: 'IDLE',
        percentage: 0,
        message: 'Initializing job queue...',
      },
      createdAt: new Date().toISOString(),
      cancelRequested: false,
    };

    JobQueueManager.activeJobs.set(jobId, job);

    const updateProgress = (step: JobProgress['step'], percentage: number, message: string, extra?: Partial<JobProgress>) => {
      job.progress = {
        step,
        percentage,
        message,
        ...extra,
      };
      if (onProgress) {
        onProgress(job.progress);
      }
    };

    try {
      // Step 1: Parse or Extract Text Material
      updateProgress('PARSING_DOCUMENT', 10, 'Processing input study materials...');
      let sourceText = request.sourceText || '';

      if (request.documentId) {
        const chunks = await DocumentParser.loadDocumentChunks(request.documentId);
        sourceText = chunks.map((c) => c.content).join('\n\n');
      } else if (request.topic && !sourceText) {
        sourceText = `Topic: ${request.topic}. Generate comprehensive quiz questions testing knowledge of ${request.topic}.`;
      }

      if (!sourceText || sourceText.trim().length === 0) {
        throw new Error('No study text, topic, or document content provided for quiz generation.');
      }

      if (job.cancelRequested) throw new Error('Job cancelled by user.');

      // Step 2: Context Chunking check
      updateProgress('CHUNKING_TEXT', 20, 'Preparing context windows for AI model...');
      const chunks = DocumentChunker.chunkText(sourceText);
      const textToUse = chunks[0].content; // Use primary content window

      if (job.cancelRequested) throw new Error('Job cancelled by user.');

      // Build Prompts
      const { systemPrompt, userPrompt } = PromptBuilder.buildPrompt(request, textToUse);

      // Step 3: Load Model into RAM (Inference Layer memory isolation)
      updateProgress('LOADING_MODEL', 35, 'Loading AI model weights into device memory...');
      const preset = await ModelLifecycleManager.loadModelForGeneration();

      if (job.cancelRequested) {
        await ModelLifecycleManager.unloadModelAfterGeneration();
        throw new Error('Job cancelled by user.');
      }

      // Step 4: Run Inference with streaming token updates
      updateProgress('GENERATING_INFERENCE', 50, `Generating quiz questions using ${preset.name}...`);
      let generatedRawText = '';

      try {
        generatedRawText = await GenerationStream.runStream(
          {
            prompt: userPrompt,
            systemPrompt,
            temperature: 0.7,
            topP: 0.9,
            maxTokens: 1500,
          },
          (token, fullText) => {
            if (job.cancelRequested) return;
            const approxProgress = Math.min(85, 50 + Math.floor((fullText.length / 1500) * 35));
            updateProgress('GENERATING_INFERENCE', approxProgress, `Generating quiz questions... (${fullText.length} chars)`, {
              streamingText: fullText,
            });
          }
        );
      } finally {
        // ALWAYS unload model immediately after generation finishes to free RAM!
        updateProgress('GENERATING_INFERENCE', 88, 'Unloading AI model from memory to free RAM...');
        await ModelLifecycleManager.unloadModelAfterGeneration();
      }

      if (job.cancelRequested) throw new Error('Job cancelled by user.');

      // Step 5: Validate JSON & Repair Schema
      updateProgress('VALIDATING_JSON', 92, 'Validating and repairing generated quiz structure...');
      const parsedQuiz = JSONValidator.validateAndNormalizeQuiz(generatedRawText);

      // Attach request metadata
      if (request.title) parsedQuiz.title = request.title;
      parsedQuiz.difficulty = request.difficulty;
      parsedQuiz.sourceType = request.documentId ? 'document' : request.sourceText ? 'text' : 'topic';

      // Step 6: Save to SQLite Database
      updateProgress('SAVING_QUIZ', 97, 'Saving quiz into SQLite database...');
      const savedQuiz = await QuizRepository.saveQuiz(parsedQuiz);

      // Step 7: Complete
      updateProgress('COMPLETE', 100, 'Quiz successfully generated and saved!', {
        generatedQuizId: savedQuiz.id,
      });

      return savedQuiz;
    } catch (error: any) {
      updateProgress('FAILED', job.progress.percentage, `Generation failed: ${error.message}`, {
        error: error.message,
      });
      throw error;
    } finally {
      JobQueueManager.activeJobs.delete(jobId);
    }
  }

  /**
   * Request cancellation of a running generation job.
   */
  static cancelJob(jobId: string): void {
    const job = JobQueueManager.activeJobs.get(jobId);
    if (job) {
      job.cancelRequested = true;
    }
  }
}

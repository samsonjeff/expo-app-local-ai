export type JobStep =
  | 'IDLE'
  | 'PARSING_DOCUMENT'
  | 'CHUNKING_TEXT'
  | 'LOADING_MODEL'
  | 'GENERATING_INFERENCE'
  | 'VALIDATING_JSON'
  | 'SAVING_QUIZ'
  | 'COMPLETE'
  | 'FAILED';

export interface JobProgress {
  step: JobStep;
  percentage: number; // 0 to 100
  message: string;
  streamingText?: string;
  generatedQuizId?: string;
  error?: string;
}

export type JobProgressCallback = (progress: JobProgress) => void;

export interface GenerationJob {
  id: string;
  request: import('./quiz.types').QuizGenerationRequest;
  progress: JobProgress;
  createdAt: string;
  cancelRequested: boolean;
}

// Layer 1: Types & Presentation Bridge
export * from './types/quiz.types';
export * from './types/inference.types';
export * from './types/document.types';
export * from './types/queue.types';

export { useQuizGenerator } from './presentation/hooks/useQuizGenerator';
export { useQuizRepository } from './presentation/hooks/useQuizRepository';
export { useQuizAttempt } from './presentation/hooks/useQuizAttempt';
export { useInferenceStatus } from './presentation/hooks/useInferenceStatus';
export { useDocumentManager } from './presentation/hooks/useDocumentManager';
export { QuizAppProvider, useQuizAppContext } from './presentation/context/QuizAppContext';

// Layer 2: Application / Orchestration Layer
export { JobQueueManager } from './orchestration/jobQueue';
export { PromptBuilder } from './orchestration/promptBuilder';
export { PromptTemplates } from './orchestration/promptTemplates';
export { DocumentChunker } from './orchestration/documentChunker';
export { DocumentParser } from './orchestration/documentParser';
export { JSONValidator } from './orchestration/jsonValidator';

// Layer 3: AI Inference Layer
export { LlamaBridge } from './inference/llamaBridge';
export { ModelLifecycleManager } from './inference/modelLifecycleManager';
export { RAMDetector } from './inference/ramDetector';
export { MODEL_PRESETS, getPresetById } from './inference/modelTiers';

// Layer 4: Local Storage / Backend Layer
export { getDatabase, closeDatabase } from './storage/database/db';
export { QuizRepository } from './storage/database/quizRepository';
export { AttemptRepository } from './storage/database/attemptRepository';
export { DocumentRepository } from './storage/database/documentRepository';
export { FileStorageManager } from './storage/filesystem/fileStorage';
export { ModelDownloader } from './storage/filesystem/modelDownloader';

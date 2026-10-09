export interface TextChunk {
  id: string;
  chunkIndex: number;
  content: string;
  wordCount: number;
  estimatedTokens: number;
}

export interface DocumentMetadata {
  id: string;
  filename: string;
  filePath: string;
  fileSize: number;
  mimeType: string;
  chunkCount: number;
  totalWords: number;
  extractedText?: string;
  createdAt: string;
}

export interface DocumentChunkingOptions {
  maxTokensPerChunk?: number; // e.g. 1500 tokens
  overlapTokens?: number;     // e.g. 200 tokens overlap
}

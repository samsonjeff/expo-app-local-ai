import { TextChunk, DocumentChunkingOptions } from '../types/document.types';

export class DocumentChunker {
  /**
   * Estimates token count from word count (~0.75 words per token or ~4 chars per token).
   */
  static estimateTokenCount(text: string): number {
    if (!text) return 0;
    return Math.ceil(text.length / 4);
  }

  /**
   * Split a long document string into overlapping chunks.
   */
  static chunkText(text: string, options: DocumentChunkingOptions = {}): TextChunk[] {
    const maxTokens = options.maxTokensPerChunk || 1200; // conservative chunk size
    const overlapTokens = options.overlapTokens || 150;

    const estimatedTotalTokens = DocumentChunker.estimateTokenCount(text);
    
    // If text easily fits in one chunk, return immediately
    if (estimatedTotalTokens <= maxTokens) {
      const wordCount = text.trim().split(/\s+/).length;
      return [
        {
          id: 'chunk_0',
          chunkIndex: 0,
          content: text.trim(),
          wordCount,
          estimatedTokens: estimatedTotalTokens,
        },
      ];
    }

    const paragraphs = text.split(/\n\s*\n/);
    const chunks: TextChunk[] = [];
    let currentChunkText = '';
    let currentChunkTokens = 0;
    let chunkIndex = 0;

    for (const paragraph of paragraphs) {
      const paragraphTokens = DocumentChunker.estimateTokenCount(paragraph);

      if (currentChunkTokens + paragraphTokens > maxTokens && currentChunkText.length > 0) {
        // Save current chunk
        const wordCount = currentChunkText.trim().split(/\s+/).length;
        chunks.push({
          id: `chunk_${chunkIndex}`,
          chunkIndex,
          content: currentChunkText.trim(),
          wordCount,
          estimatedTokens: currentChunkTokens,
        });

        chunkIndex++;

        // Keep last portion for overlap
        const words = currentChunkText.split(/\s+/);
        const overlapWordsCount = Math.min(words.length, Math.ceil(overlapTokens * 0.75));
        const overlapText = words.slice(words.length - overlapWordsCount).join(' ');

        currentChunkText = overlapText + '\n\n' + paragraph;
        currentChunkTokens = DocumentChunker.estimateTokenCount(currentChunkText);
      } else {
        currentChunkText += (currentChunkText ? '\n\n' : '') + paragraph;
        currentChunkTokens += paragraphTokens;
      }
    }

    // Push final chunk
    if (currentChunkText.trim().length > 0) {
      const wordCount = currentChunkText.trim().split(/\s+/).length;
      chunks.push({
        id: `chunk_${chunkIndex}`,
        chunkIndex,
        content: currentChunkText.trim(),
        wordCount,
        estimatedTokens: currentChunkTokens,
      });
    }

    return chunks;
  }
}

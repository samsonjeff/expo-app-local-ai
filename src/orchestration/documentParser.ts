import { DocumentMetadata, TextChunk } from '../types/document.types';
import { DocumentChunker } from './documentChunker';
import { FileStorageManager } from '../storage/filesystem/fileStorage';
import { DocumentRepository } from '../storage/database/documentRepository';
import { v4 as uuidv4 } from 'uuid';

export class DocumentParser {
  /**
   * Process raw text input string and prepare document record with chunks.
   */
  static async processRawText(
    text: string,
    filename: string = 'pasted_text.txt'
  ): Promise<{ metadata: DocumentMetadata; chunks: TextChunk[] }> {
    const docId = uuidv4();
    const savedPath = await FileStorageManager.saveDocumentFile(`${docId}_${filename}`, text);
    const chunks = DocumentChunker.chunkText(text);

    const words = text.trim().split(/\s+/).filter(Boolean);
    const metadata: DocumentMetadata = {
      id: docId,
      filename,
      filePath: savedPath,
      fileSize: new TextEncoder().encode(text).length,
      mimeType: 'text/plain',
      chunkCount: chunks.length,
      totalWords: words.length,
      extractedText: text,
      createdAt: new Date().toISOString(),
    };

    await DocumentRepository.saveDocument(metadata);

    return { metadata, chunks };
  }

  /**
   * Load existing document from DB & filesystem and split into chunks.
   */
  static async loadDocumentChunks(docId: string): Promise<TextChunk[]> {
    const docMeta = await DocumentRepository.getDocumentById(docId);
    if (!docMeta) {
      throw new Error(`Document not found for ID: ${docId}`);
    }

    let text = docMeta.extractedText;
    if (!text) {
      text = await FileStorageManager.readDocumentFile(docMeta.filePath);
    }

    return DocumentChunker.chunkText(text);
  }
}

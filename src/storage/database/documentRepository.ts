import { getDatabase } from './db';
import { DocumentMetadata } from '../../types/document.types';

export class DocumentRepository {
  static async saveDocument(doc: DocumentMetadata): Promise<DocumentMetadata> {
    const db = await getDatabase();
    await db.runAsync(
      `INSERT OR REPLACE INTO documents 
        (id, filename, file_path, file_size, mime_type, chunk_count, total_words, extracted_text, created_at) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        doc.id,
        doc.filename,
        doc.filePath,
        doc.fileSize,
        doc.mimeType,
        doc.chunkCount,
        doc.totalWords,
        doc.extractedText || null,
        doc.createdAt,
      ]
    );
    return doc;
  }

  static async getAllDocuments(): Promise<DocumentMetadata[]> {
    const db = await getDatabase();
    const rows = await db.getAllAsync<any>(
      `SELECT id, filename, file_path, file_size, mime_type, chunk_count, total_words, created_at FROM documents ORDER BY datetime(created_at) DESC`
    );

    return rows.map((row) => ({
      id: row.id,
      filename: row.filename,
      filePath: row.file_path,
      fileSize: row.file_size,
      mimeType: row.mime_type,
      chunkCount: row.chunk_count,
      totalWords: row.total_words,
      createdAt: row.created_at,
    }));
  }

  static async getDocumentById(id: string): Promise<DocumentMetadata | null> {
    const db = await getDatabase();
    const row = await db.getFirstAsync<any>(`SELECT * FROM documents WHERE id = ?`, [id]);

    if (!row) return null;

    return {
      id: row.id,
      filename: row.filename,
      filePath: row.file_path,
      fileSize: row.file_size,
      mimeType: row.mime_type,
      chunkCount: row.chunk_count,
      totalWords: row.total_words,
      extractedText: row.extracted_text,
      createdAt: row.created_at,
    };
  }

  static async deleteDocument(id: string): Promise<boolean> {
    const db = await getDatabase();
    const result = await db.runAsync(`DELETE FROM documents WHERE id = ?`, [id]);
    return result.changes > 0;
  }
}

import mammoth from 'mammoth';

declare const Buffer: any;

export class DocumentExtractor {
  /**
   * Extract plain text from PDF uint8 array buffer.
   */
  static async extractTextFromPDFBuffer(pdfBuffer: Uint8Array): Promise<string> {
    try {
      const pdfParse = require('pdf-parse');
      const data = await pdfParse(Buffer.from(pdfBuffer));
      return data.text || '';
    } catch (err: any) {
      throw new Error(`Failed to parse PDF document text: ${err.message}`);
    }
  }

  /**
   * Extract plain text from DOCX uint8 array buffer.
   */
  static async extractTextFromDOCXBuffer(docxBuffer: Uint8Array): Promise<string> {
    try {
      const result = await mammoth.extractRawText({ buffer: Buffer.from(docxBuffer) });
      return result.value || '';
    } catch (err: any) {
      throw new Error(`Failed to parse DOCX document text: ${err.message}`);
    }
  }

  /**
   * Detect file format by extension or MIME type and extract clean text.
   */
  static async extractTextFromFile(
    fileData: Uint8Array,
    filename: string,
    mimeType?: string
  ): Promise<string> {
    const ext = filename.toLowerCase().split('.').pop();

    if (ext === 'pdf' || mimeType === 'application/pdf') {
      return await DocumentExtractor.extractTextFromPDFBuffer(fileData);
    }

    if (ext === 'docx' || mimeType === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      return await DocumentExtractor.extractTextFromDOCXBuffer(fileData);
    }

    // Default assume UTF-8 plain text / markdown / txt
    return new TextDecoder('utf-8').decode(fileData);
  }
}

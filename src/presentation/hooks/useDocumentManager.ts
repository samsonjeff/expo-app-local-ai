import { useState, useCallback, useEffect } from 'react';
import { DocumentMetadata } from '../../types/document.types';
import { DocumentRepository } from '../../storage/database/documentRepository';
import { DocumentParser } from '../../orchestration/documentParser';

export function useDocumentManager() {
  const [documents, setDocuments] = useState<DocumentMetadata[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const fetchDocuments = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const list = await DocumentRepository.getAllDocuments();
      setDocuments(list);
    } catch (err: any) {
      setError(err.message || 'Failed to load documents');
    } finally {
      setLoading(false);
    }
  }, []);

  const addTextDocument = useCallback(async (rawText: string, filename: string): Promise<DocumentMetadata> => {
    setLoading(true);
    try {
      const { metadata } = await DocumentParser.processRawText(rawText, filename);
      await fetchDocuments();
      return metadata;
    } catch (err: any) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, [fetchDocuments]);

  const deleteDocument = useCallback(async (id: string): Promise<boolean> => {
    const success = await DocumentRepository.deleteDocument(id);
    if (success) {
      setDocuments((prev) => prev.filter((d) => d.id !== id));
    }
    return success;
  }, []);

  useEffect(() => {
    fetchDocuments();
  }, [fetchDocuments]);

  return {
    documents,
    loading,
    error,
    refreshDocuments: fetchDocuments,
    addTextDocument,
    deleteDocument,
  };
}

import * as FileSystem from 'expo-file-system/legacy';

const BASE_DIR = FileSystem.documentDirectory || FileSystem.cacheDirectory || '';
const MODELS_DIR = `${BASE_DIR}models/`;
const DOCUMENTS_DIR = `${BASE_DIR}documents/`;
const EXPORTS_DIR = `${BASE_DIR}exports/`;

export class FileStorageManager {
  /**
   * Ensure local app storage directories exist.
   */
  static async initStorageDirectories(): Promise<void> {
    await FileStorageManager.ensureDirectoryExists(MODELS_DIR);
    await FileStorageManager.ensureDirectoryExists(DOCUMENTS_DIR);
    await FileStorageManager.ensureDirectoryExists(EXPORTS_DIR);
  }

  private static async ensureDirectoryExists(dirPath: string): Promise<void> {
    const dirInfo = await FileSystem.getInfoAsync(dirPath);
    if (!dirInfo.exists) {
      await FileSystem.makeDirectoryAsync(dirPath, { intermediates: true });
    }
  }

  static getModelsDirectory(): string {
    return MODELS_DIR;
  }

  static getDocumentsDirectory(): string {
    return DOCUMENTS_DIR;
  }

  static getExportsDirectory(): string {
    return EXPORTS_DIR;
  }

  /**
   * Save uploaded text or file content to documents directory.
   */
  static async saveDocumentFile(filename: string, content: string): Promise<string> {
    await FileStorageManager.initStorageDirectories();
    const filePath = `${DOCUMENTS_DIR}${filename}`;
    await FileSystem.writeAsStringAsync(filePath, content, {
      encoding: FileSystem.EncodingType.UTF8,
    });
    return filePath;
  }

  /**
   * Read file content from storage.
   */
  static async readDocumentFile(filePath: string): Promise<string> {
    return await FileSystem.readAsStringAsync(filePath, {
      encoding: FileSystem.EncodingType.UTF8,
    });
  }

  /**
   * Check available disk space in bytes.
   */
  static async getFreeDiskSpaceBytes(): Promise<number> {
    return await FileSystem.getFreeDiskStorageAsync();
  }

  /**
   * Delete file from local filesystem.
   */
  static async deleteFile(filePath: string): Promise<boolean> {
    const info = await FileSystem.getInfoAsync(filePath);
    if (info.exists) {
      await FileSystem.deleteAsync(filePath, { idempotent: true });
      return true;
    }
    return false;
  }
}

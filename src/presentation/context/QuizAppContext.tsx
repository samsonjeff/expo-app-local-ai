import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { getDatabase } from '../../storage/database/db';
import { FileStorageManager } from '../../storage/filesystem/fileStorage';
import { RAMDetector } from '../../inference/ramDetector';
import { DeviceRAMInfo } from '../../types/inference.types';

interface QuizAppContextValue {
  isInitialized: boolean;
  initError: string | null;
  ramInfo: DeviceRAMInfo | null;
}

const QuizAppContext = createContext<QuizAppContextValue>({
  isInitialized: false,
  initError: null,
  ramInfo: null,
});

export const QuizAppProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [isInitialized, setIsInitialized] = useState(false);
  const [initError, setInitError] = useState<string | null>(null);
  const [ramInfo, setRamInfo] = useState<DeviceRAMInfo | null>(null);

  useEffect(() => {
    async function initializeBackendSystem() {
      try {
        // 1. Initialize local filesystem storage folders
        await FileStorageManager.initStorageDirectories();

        // 2. Initialize SQLite Database tables & indexes
        await getDatabase();

        // 3. Detect device system RAM and determine AI tier
        const memoryInfo = await RAMDetector.getRAMInfo();
        setRamInfo(memoryInfo);

        setIsInitialized(true);
      } catch (err: any) {
        console.error('Failed to initialize Quiz App backend system:', err);
        setInitError(err.message || 'Initialization error');
      }
    }

    initializeBackendSystem();
  }, []);

  return (
    <QuizAppContext.Provider value={{ isInitialized, initError, ramInfo }}>
      {children}
    </QuizAppContext.Provider>
  );
};

export const useQuizAppContext = () => useContext(QuizAppContext);

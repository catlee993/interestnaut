import { createContext, useContext, useState, ReactNode } from 'react';

export type MediaType = 'music' | 'movies' | 'tv';

interface MediaContextType {
  currentMedia: MediaType;
  setCurrentMedia: (media: MediaType) => void;
}

const MediaContext = createContext<MediaContextType | undefined>(undefined);

export function useMedia() {
  const context = useContext(MediaContext);
  if (!context) {
    throw new Error('useMedia must be used within a MediaProvider');
  }
  return context;
}

export function MediaProvider({ children }: { children: ReactNode }) {
  const [currentMedia, setCurrentMedia] = useState<MediaType>('music');

  return (
    <MediaContext.Provider value={{ currentMedia, setCurrentMedia }}>
      {children}
    </MediaContext.Provider>
  );
} 
import { useEffect, useState, useRef } from "react";
import "./App.css";
import { session, spotify } from "../wailsjs/go/models";
import { SuggestionProvider } from "./contexts/SuggestionContext";
import { SuggestionDisplay } from "./components/suggestions/SuggestionDisplay";
import { useToast } from "./hooks/useToast";
import { LoadingSkeleton } from "./components/tracks/LoadingSkeleton";
import { NowPlayingBar } from "./components/player/NowPlayingBar";
import { SearchSection } from "./components/search/SearchSection";
import { LibrarySection } from "./components/library/LibrarySection";
import { useAuth } from "./hooks/useAuth";
import { useTracks } from "./hooks/useTracks";
import { usePlayer } from "./contexts/PlayerContext";
import { PlayerProvider } from "./contexts/PlayerContext";

// Add type declarations for Wails modules
declare module "../wailsjs/go/bindings/Music" {
  export function GetAuthStatus(): Promise<boolean>;
  export function GetCurrentUser(): Promise<spotify.UserProfile | null>;
  export function GetSavedTracks(
    limit?: number,
    offset?: number,
  ): Promise<spotify.SavedTracks | null>;
  export function GetValidToken(): Promise<string>;
  export function PausePlaybackOnDevice(deviceId: string): Promise<void>;
  export function PlayTrackOnDevice(
    deviceId: string,
    trackUri: string,
  ): Promise<void>;
  export function ProvideSuggestionFeedback(
    outcome: session.Outcome,
    trackName: string,
    artistName: string,
    albumName: string,
  ): Promise<void>;
  export function RemoveTrack(trackId: string): Promise<void>;
  export function RequestNewSuggestion(): Promise<spotify.SuggestedTrackInfo | null>;
  export function SaveTrack(trackId: string): Promise<void>;
  export function SearchTracks(
    query: string,
    limit?: number,
  ): Promise<spotify.SimpleTrack[]>;
}

// Add type declarations for models
declare module "../wailsjs/go/models" {
  export interface SavedTracks {
    items: Array<{
      track: {
        id: string;
        name: string;
        artists: Array<{
          name: string;
        }>;
      };
    }>;
  }
}

// Add type declarations for Spotify Web Playback SDK
declare global {
  interface Window {
    onSpotifyWebPlaybackSDKReady: () => void;
    Spotify: {
      Player: new (config: {
        name: string;
        getOAuthToken: (callback: (token: string) => void) => void;
        volume: number;
      }) => {
        addListener: (
          event: string,
          callback: (data: { device_id: string }) => void,
        ) => void;
        connect: () => Promise<void>;
        disconnect: () => void;
      };
    };
  }
}

// Add type declarations for toast
interface Toast {
  message: string;
  type: "success" | "error" | "info" | "warning" | "skip" | "dislike";
}

interface AuthStatus extends Record<string, any> {
  isAuthenticated: boolean;
}

const ITEMS_PER_PAGE = 20;

// Create a separate component for the app content to use hooks
function AppContent() {
  const { toast, showToast } = useToast();
  const {
    user,
    setUser,
    isAuthenticated,
    setIsAuthenticated,
    startAuthPolling,
    handleClearCreds,
  } = useAuth();

  const {
    savedTracks,
    setSavedTracks,
    searchResults,
    isLoading,
    error,
    currentPage,
    totalTracks,
    loadSavedTracks,
    handleSearch,
    handleSave,
    handleRemove,
    handleNextPage,
    handlePrevPage,
  } = useTracks(ITEMS_PER_PAGE);

  const { nowPlayingTrack, isPlaybackPaused, handlePlay, handlePlayPause } =
    usePlayer();

  const hasInitialized = useRef(false);

  useEffect(() => {
    const initializeApp = async () => {
      if (hasInitialized.current) return;
      hasInitialized.current = true;

      try {
        console.log("[initializeApp] Starting initialization...");
        const loadAppData = async () => {
          console.log("[initializeApp] Loading app data...");
          await loadSavedTracks(1);
          console.log("[initializeApp] App data loaded");
        };

        startAuthPolling(loadAppData);
      } catch (error) {
        console.error("[initializeApp] Error initializing app:", error);
        showToast({ message: "Error initializing app", type: "error" });
      }
    };

    initializeApp();
  }, []);

  // Add effect to reload tracks when auth state changes
  useEffect(() => {
    if (isAuthenticated) {
      loadSavedTracks(1);
    }
  }, [isAuthenticated]);

  // Add toast timeout cleanup
  useEffect(() => {
    if (toast) {
      const timer = setTimeout(() => {
        showToast(null);
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [toast, showToast]);

  return (
    <div id="App">
      {toast && (
        <div className={`toast ${toast.type}`} role="alert">
          {toast.message}
        </div>
      )}
      <div className="top-section">
        <div className="top-section-content">
          <div className="user-controls">
            {user && (
              <div className="user-info">
                {user.images?.[0]?.url && (
                  <img
                    src={user.images[0].url}
                    alt={user.display_name}
                    className="user-avatar"
                  />
                )}
                <span className="user-name" color="green">
                  Connected as {user.display_name}
                </span>
              </div>
            )}
            <button onClick={handleClearCreds} className="clear-auth-button">
              Clear Auth
            </button>
          </div>
          <header>
            <h1 className="app-title">Spotify Library</h1>
            <SearchSection
              onSearch={handleSearch}
              searchResults={searchResults}
              savedTracks={savedTracks}
              isLoading={isLoading}
              nowPlayingTrack={nowPlayingTrack}
              isPlaybackPaused={isPlaybackPaused}
              onPlay={handlePlay}
              onSave={handleSave}
              onRemove={handleRemove}
            />
          </header>
        </div>
      </div>

      <div className="main-content">
        {error && (
          <div className="error-message">
            <span>⚠️</span>
            {error}
          </div>
        )}

        <SuggestionProvider>
          <SuggestionDisplay />
        </SuggestionProvider>

        {isLoading ? (
          <LoadingSkeleton />
        ) : (
          <LibrarySection
            savedTracks={savedTracks}
            currentPage={currentPage}
            totalTracks={totalTracks}
            itemsPerPage={ITEMS_PER_PAGE}
            nowPlayingTrack={nowPlayingTrack}
            isPlaybackPaused={isPlaybackPaused}
            onPlay={handlePlay}
            onSave={handleSave}
            onRemove={handleRemove}
            onNextPage={handleNextPage}
            onPrevPage={handlePrevPage}
          />
        )}
      </div>

      {nowPlayingTrack && (
        <NowPlayingBar
          track={nowPlayingTrack}
          isPlaybackPaused={isPlaybackPaused}
          onPlayPause={handlePlayPause}
        />
      )}
    </div>
  );
}

// Main App component that provides context
function App() {
  return (
    <PlayerProvider>
      <AppContent />
    </PlayerProvider>
  );
}

export default App;

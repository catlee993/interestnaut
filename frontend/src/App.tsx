import { useEffect, useState, useRef } from "react";
import "./App.css";
import { session, spotify, MovieWithSavedStatus } from "@wailsjs/go/models";
import { SuggestionProvider } from "@/components/music/suggestions/SuggestionContext";
import { SuggestionDisplay } from "@/components/music/suggestions/SuggestionDisplay";
import { NowPlayingBar } from "@/components/music/player/NowPlayingBar";
import { LibrarySection } from "@/components/music/library/LibrarySection";
import { MovieSection } from "@/components/movies/MovieSection";
import { MusicSection, MusicSectionHandle } from "@/components/music/MusicSection";
import { useAuth } from "@/components/music/hooks/useAuth";
import { useTracks } from "@/components/music/hooks/useTracks";
import { usePlayer } from "@/components/music/player/PlayerContext";
import { usePlaybackControl } from "@/components/music/hooks/usePlaybackControl";
import { PlayerProvider } from "@/components/music/player/PlayerContext";
import { MediaProvider, useMedia } from "@/contexts/MediaContext";
import {
  ThemeProvider,
  CssBaseline,
  Box,
  Container,
  SnackbarContent,
} from "@mui/material";
import { theme } from "./theme";
import { SnackbarProvider, useSnackbar } from "notistack";
import { MediaHeader } from "@/components/common/MediaHeader";
import { SpotifyUserControl } from "@/components/music/SpotifyUserControl";
import { styled } from "@mui/material/styles";

// Add type declarations for Wails modules
declare module "@wailsjs/go/bindings/Music" {
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

declare module "@wailsjs/go/bindings/Movies" {
  export function SearchMovies(query: string): Promise<MovieWithSavedStatus[]>;
  export function SaveMovie(movieId: number): Promise<void>;
  export function RemoveMovie(movieId: number): Promise<void>;
}

// Add type declarations for models
declare module "@wailsjs/go/models" {
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

  export interface MovieWithSavedStatus {
    id: number;
    title: string;
    overview: string;
    poster_path: string;
    release_date: string;
    vote_average: number;
    vote_count: number;
    genres: string[];
    isSaved: boolean;
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
  const { enqueueSnackbar } = useSnackbar();
  const { user, isAuthenticated, startAuthPolling, handleClearCreds } =
    useAuth();
  const { currentMedia } = useMedia();

  const {
    savedTracks,
    searchResults,
    isLoading: musicLoading,
    error: musicError,
    currentPage,
    totalTracks,
    handleSearch: handleMusicSearch,
    handleSave,
    handleRemove,
    handleNextPage,
    handlePrevPage,
    loadSavedTracks,
  } = useTracks(ITEMS_PER_PAGE);

  const {
    nowPlayingTrack,
    isPlaybackPaused,
    handlePlay: playerHandlePlay,
    handlePlayPause,
    setNowPlayingTrack,
    setNextTrack,
  } = usePlayer();

  const { handlePlay } = usePlaybackControl(
    savedTracks,
    setNowPlayingTrack,
    setNextTrack,
    playerHandlePlay,
  );

  const hasInitialized = useRef(false);
  
  // Reference to the MusicSection component to access its methods
  const musicSectionRef = useRef<MusicSectionHandle>(null);

  // Handler to clear search results
  const handleClearSearch = () => {
    // If we have a reference to the music section, tell it to hide search results
    if (musicSectionRef.current) {
      musicSectionRef.current.handleClearSearch();
    }
    // Also clear the search query
    handleMusicSearch("");
  };

  // Add effect to reload tracks when auth state changes
  useEffect(() => {
    if (isAuthenticated) {
      console.log("[App] Authentication detected, loading saved tracks...");
      // Use a slight delay to ensure authentication is fully processed
      setTimeout(() => {
        loadSavedTracks(1);
      }, 500);
    }
  }, [isAuthenticated, loadSavedTracks]);

  // Separate initialization effect that doesn't depend on authentication state
  useEffect(() => {
    const initializeApp = async () => {
      if (hasInitialized.current) return;
      hasInitialized.current = true;

      try {
        console.log("[initializeApp] Starting initialization...");
        startAuthPolling(async () => {
          console.log(
            "[initializeApp] Authentication successful, loading app data...",
          );
          await loadSavedTracks(1);
          console.log("[initializeApp] App data loaded");
        });
      } catch (error) {
        console.error("[initializeApp] Error initializing app:", error);
        enqueueSnackbar("Error initializing app", { variant: "error" });
      }
    };

    initializeApp();
  }, []); // Only run once on mount

  return (
    <Box
      id="App"
      sx={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}
    >
      <MediaHeader
        additionalControl={
          user && currentMedia === "music" ? (
            <SpotifyUserControl
              user={user}
              onClearAuth={handleClearCreds}
              currentMedia={currentMedia}
            />
          ) : null
        }
        onSearch={handleMusicSearch}
        onClearSearch={handleClearSearch}
      />

      <Container
        maxWidth="lg"
        sx={{
          flex: 1,
          display: "flex",
          flexDirection: "column",
          pb: 8,
        }}
      >
        {currentMedia === "music" ? (
          <MusicSection
            ref={musicSectionRef}
            searchResults={searchResults}
            savedTracks={savedTracks}
            currentPage={currentPage}
            totalTracks={totalTracks}
            itemsPerPage={ITEMS_PER_PAGE}
            nowPlayingTrack={nowPlayingTrack}
            isPlaybackPaused={isPlaybackPaused}
            onPlay={handlePlay}
            onSave={handleSave}
            onRemove={handleRemove}
            onSearch={handleMusicSearch}
            onNextPage={handleNextPage}
            onPrevPage={handlePrevPage}
          />
        ) : (
          <MovieSection />
        )}
      </Container>
      {nowPlayingTrack && <NowPlayingBar />}
    </Box>
  );
}

// Main App component that provides context
function App() {
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <SnackbarProvider
        maxSnack={3}
        anchorOrigin={{
          vertical: "top",
          horizontal: "center",
        }}
        Components={{
          default: (props) => (
            <SnackbarContent
              {...props}
              style={{
                backgroundColor:
                  props.style?.backgroundColor || theme.palette.grey[800],
                color: props.style?.color || "#fff",
                ...props.style,
              }}
            />
          ),
        }}
      >
        <MediaProvider>
          <PlayerProvider>
            <SuggestionProvider>
              <AppContent />
            </SuggestionProvider>
          </PlayerProvider>
        </MediaProvider>
      </SnackbarProvider>
    </ThemeProvider>
  );
}

export default App;

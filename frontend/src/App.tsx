import { useEffect, useState, useRef } from "react";
import "./App.css";
import { session, spotify, MovieWithSavedStatus } from "../wailsjs/go/models";
import { SuggestionProvider } from "@/components/music/suggestions/SuggestionContext";
import { SuggestionDisplay } from "@/components/music/suggestions/SuggestionDisplay";
import { NowPlayingBar } from "@/components/music/player/NowPlayingBar";
import { SearchSection } from "@/components/music/search/SearchSection";
import { LibrarySection } from "@/components/music/library/LibrarySection";
import { MovieSection } from "@/components/movies/MovieSection";
import { useAuth } from "./hooks/useAuth";
import { useTracks } from "./hooks/useTracks";
import { usePlayer } from "@/components/music/player/PlayerContext";
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
import { Header } from "@/components/layout/Header";

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

declare module "../wailsjs/go/bindings/Movies" {
  export function SearchMovies(query: string): Promise<MovieWithSavedStatus[]>;
  export function SaveMovie(movieId: number): Promise<void>;
  export function RemoveMovie(movieId: number): Promise<void>;
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
        enqueueSnackbar("Error initializing app", { variant: "error" });
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

  return (
    <Box
      id="App"
      sx={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}
    >
      <Header user={user} />
      <Container
        maxWidth="lg"
        sx={{ flex: 1, display: "flex", flexDirection: "column" }}
      >
        {currentMedia === "music" ? (
          <>
            <SuggestionDisplay />
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
          </>
        ) : (
          <MovieSection />
        )}
      </Container>
      {currentMedia === "music" && nowPlayingTrack && <NowPlayingBar />}
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

import { useEffect, useState, useRef, forwardRef } from "react";
import "./App.css";
import { session, spotify, MovieWithSavedStatus } from "@wailsjs/go/models";
import { SuggestionProvider } from "@/components/music/suggestions/SuggestionContext";
import { SuggestionDisplay } from "@/components/music/suggestions/SuggestionDisplay";
import { NowPlayingBar } from "@/components/music/player/NowPlayingBar";
import { LibrarySection } from "@/components/music/library/LibrarySection";
import { MovieSection } from "@/components/movies/MovieSection";
import {
  MusicSection,
  MusicSectionHandle,
} from "@/components/music/MusicSection";
import { useAuth } from "@/components/music/hooks/useAuth";
import { useTracks } from "@/components/music/hooks/useTracks";
import { usePlayer } from "@/components/music/player/PlayerContext";
import { usePlaybackControl } from "@/components/music/hooks/usePlaybackControl";
import { PlayerProvider } from "@/components/music/player/PlayerContext";
import { MediaProvider, useMedia } from "@/contexts/MediaContext";
import { SettingsProvider } from "@/contexts/SettingsContext";
import {
  ThemeProvider,
  CssBaseline,
  Box,
  Container,
  SnackbarContent,
  SnackbarContentProps,
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
  export function SetInitialMovies(movieId: number): Promise<void>;
  export function GetInitialMovies(): Promise<Record<string, any>>;
  export function HasValidCredentials(): Promise<boolean>;
  export function RefreshCredentials(): Promise<boolean>;
  export function GetMovieSuggestion(): Promise<{ movie: MovieWithSavedStatus; reason: string } | null>;
  export function ProvideSuggestionFeedback(outcome: session.Outcome, movieId: number): Promise<void>;
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
    director?: string;
    writer?: string;
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
  const { user, isAuthenticated, startAuthPolling, handleClearCreds, refreshUserProfile } =
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
  const movieSectionRef = useRef<any>(null);

  // Handler for music search
  const handleMusicSearchFromHeader = (query: string) => {
    console.log(`[App] Music search requested: "${query}"`);
    if (currentMedia === "music") {
      handleMusicSearch(query);
    }
  };

  // Handler for movie search
  const handleMovieSearchFromHeader = (query: string) => {
    console.log(`[App] Movie search requested: "${query}"`);
    // Call the search method on MovieSection component via ref
    if (currentMedia === "movies" && movieSectionRef.current) {
      // If the MovieSection exposes the handleSearch method, call it
      if (movieSectionRef.current.handleSearch) {
        movieSectionRef.current.handleSearch(query);
      }
    }
  };

  // Handler to clear search results based on current media type
  const handleClearSearch = () => {
    if (currentMedia === "music") {
      // Clear music search
      if (musicSectionRef.current) {
        musicSectionRef.current.handleClearSearch();
      }
      // Also clear the search query
      handleMusicSearch("");
    } else if (currentMedia === "movies") {
      // Clear movie search
      if (movieSectionRef.current && movieSectionRef.current.handleClearSearch) {
        movieSectionRef.current.handleClearSearch();
      }
    }
  };

  // Add effect to reload tracks when auth state changes
  useEffect(() => {
    if (isAuthenticated) {
      console.log("[App] Authentication detected, loading saved tracks...");
      // Ensure we have the latest user data
      refreshUserProfile();
      // Use a slight delay to ensure authentication is fully processed
      setTimeout(() => {
        loadSavedTracks(1);
      }, 500);
    }
  }, [isAuthenticated, loadSavedTracks, refreshUserProfile]);

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
          isAuthenticated && currentMedia === "music" ? (
            <SpotifyUserControl
              user={user}
              onClearAuth={handleClearCreds}
              currentMedia={currentMedia}
            />
          ) : null
        }
        onSearch={
          currentMedia === "music" 
            ? handleMusicSearchFromHeader 
            : handleMovieSearchFromHeader
        }
        onClearSearch={handleClearSearch}
        currentMedia={currentMedia}
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
          <MovieSection ref={movieSectionRef} />
        )}
      </Container>
      {nowPlayingTrack && <NowPlayingBar />}
    </Box>
  );
}

// Define a type for the custom snackbar props
interface CustomSnackbarProps extends SnackbarContentProps {
  style?: React.CSSProperties;
  // Add notistack specific props
  anchorOrigin?: {
    vertical: 'top' | 'bottom';
    horizontal: 'left' | 'center' | 'right';
  };
  autoHideDuration?: number | null;
  hideIconVariant?: boolean;
  iconVariant?: Record<string, React.ReactNode>;
  persist?: boolean;
}

// Create custom snackbar components using forwardRef
const SuccessSnackbar = forwardRef<HTMLDivElement, CustomSnackbarProps>(({ style, ...props }, ref) => {
  // Filter out notistack props that shouldn't be passed to DOM
  const {
    anchorOrigin,
    autoHideDuration,
    hideIconVariant,
    iconVariant,
    persist,
    ...contentProps
  } = props;

  return (
    <SnackbarContent
      ref={ref}
      {...contentProps}
      style={{
        backgroundColor: "var(--primary-color)",
        color: "#fff",
        borderRadius: "8px",
        boxShadow: "0 4px 12px rgba(123, 104, 238, 0.3)",
        fontWeight: 500,
        ...style,
      }}
    />
  );
});

const ErrorSnackbar = forwardRef<HTMLDivElement, CustomSnackbarProps>(({ style, ...props }, ref) => {
  // Filter out notistack props that shouldn't be passed to DOM
  const {
    anchorOrigin,
    autoHideDuration,
    hideIconVariant,
    iconVariant,
    persist,
    ...contentProps
  } = props;

  return (
    <SnackbarContent
      ref={ref}
      {...contentProps}
      style={{
        backgroundColor: "var(--purple-red)",
        color: "#fff",
        borderRadius: "8px",
        boxShadow: "0 4px 12px rgba(194, 59, 133, 0.3)",
        fontWeight: 500,
        ...style,
      }}
    />
  );
});

const WarningSnackbar = forwardRef<HTMLDivElement, CustomSnackbarProps>(({ style, ...props }, ref) => {
  // Filter out notistack props that shouldn't be passed to DOM
  const {
    anchorOrigin,
    autoHideDuration,
    hideIconVariant,
    iconVariant,
    persist,
    ...contentProps
  } = props;

  return (
    <SnackbarContent
      ref={ref}
      {...contentProps}
      style={{
        backgroundColor: "#FFBB33", // Standard warning yellow
        color: "#000",
        borderRadius: "8px",
        boxShadow: "0 4px 12px rgba(255, 187, 51, 0.3)",
        fontWeight: 500,
        ...style,
      }}
    />
  );
});

const SkipSnackbar = forwardRef<HTMLDivElement, CustomSnackbarProps>(({ style, ...props }, ref) => {
  // Filter out notistack props that shouldn't be passed to DOM
  const {
    anchorOrigin,
    autoHideDuration,
    hideIconVariant,
    iconVariant,
    persist,
    ...contentProps
  } = props;

  return (
    <SnackbarContent
      ref={ref}
      {...contentProps}
      style={{
        backgroundColor: "#4169E1", // RoyalBlue - a more distinctive blue
        color: "#fff",
        borderRadius: "8px",
        boxShadow: "0 4px 12px rgba(65, 105, 225, 0.3)",
        fontWeight: 500,
        ...style,
      }}
    />
  );
});

const InfoSnackbar = forwardRef<HTMLDivElement, CustomSnackbarProps>(({ style, ...props }, ref) => {
  // Filter out notistack props that shouldn't be passed to DOM
  const {
    anchorOrigin,
    autoHideDuration,
    hideIconVariant,
    iconVariant,
    persist,
    ...contentProps
  } = props;

  return (
    <SnackbarContent
      ref={ref}
      {...contentProps}
      style={{
        backgroundColor: "var(--primary-hover)",
        color: "#fff",
        borderRadius: "8px",
        boxShadow: "0 4px 12px rgba(147, 112, 219, 0.3)",
        fontWeight: 500,
        ...style,
      }}
    />
  );
});

const DefaultSnackbar = forwardRef<HTMLDivElement, CustomSnackbarProps>(({ style, ...props }, ref) => {
  // Filter out notistack props that shouldn't be passed to DOM
  const {
    anchorOrigin,
    autoHideDuration,
    hideIconVariant,
    iconVariant,
    persist,
    ...contentProps
  } = props;

  return (
    <SnackbarContent
      ref={ref}
      {...contentProps}
      style={{
        backgroundColor: "var(--surface-color)",
        color: "#fff",
        borderRadius: "8px",
        boxShadow: "0 4px 12px rgba(0, 0, 0, 0.2)",
        borderLeft: "4px solid var(--primary-color)",
        fontWeight: 500,
        ...style,
      }}
    />
  );
});

// Add display names to components for better debugging
SuccessSnackbar.displayName = 'SuccessSnackbar';
ErrorSnackbar.displayName = 'ErrorSnackbar';
WarningSnackbar.displayName = 'WarningSnackbar';
SkipSnackbar.displayName = 'SkipSnackbar';
InfoSnackbar.displayName = 'InfoSnackbar';
DefaultSnackbar.displayName = 'DefaultSnackbar';

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
          success: SuccessSnackbar,
          error: ErrorSnackbar,
          warning: WarningSnackbar,
          info: InfoSnackbar,
          default: DefaultSnackbar,
          skip: SkipSnackbar,
        } as any}
        onClose={() => console.log("[DEBUG-SNACKBAR] A snackbar was closed")}
        TransitionProps={{
          onEnter: () => console.log("[DEBUG-SNACKBAR] Snackbar transition enter"),
          onExited: () => console.log("[DEBUG-SNACKBAR] Snackbar transition exited")
        }}
      >
        <MediaProvider>
          <SettingsProvider>
            <PlayerProvider>
              <SuggestionProvider>
                <AppContent />
              </SuggestionProvider>
            </PlayerProvider>
          </SettingsProvider>
        </MediaProvider>
      </SnackbarProvider>
    </ThemeProvider>
  );
}

export default App;

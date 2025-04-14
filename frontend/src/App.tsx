import { useEffect, useState, useRef } from "react";
import "./App.css";
import { session, spotify } from "../wailsjs/go/models";
import { SuggestionProvider } from "@/components/music/suggestions/SuggestionContext";
import { SuggestionDisplay } from "@/components/music/suggestions/SuggestionDisplay";
import { LoadingSkeleton } from "@/components/music/tracks/LoadingSkeleton";
import { NowPlayingBar } from "@/components/music/player/NowPlayingBar";
import { SearchSection } from "@/components/music/search/SearchSection";
import { LibrarySection } from "@/components/music/library/LibrarySection";
import { useAuth } from "./hooks/useAuth";
import { useTracks } from "./hooks/useTracks";
import { usePlayer } from "@/components/music/player/PlayerContext";
import { PlayerProvider } from "@/components/music/player/PlayerContext";
import {
  ThemeProvider,
  CssBaseline,
  Box,
  Stack,
  Typography,
  Avatar,
  Button,
  Container,
  SnackbarContent,
} from "@mui/material";
import { theme } from "./theme";
import { SnackbarProvider, useSnackbar } from "notistack";

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
      <Box
        className="top-section"
        sx={{ backgroundColor: theme.palette.background.paper, padding: 1 }}
      >
        <Container maxWidth="lg" sx={{ px: 0 }}>
          <Stack spacing={1}>
            <Box
              className="user-controls"
              sx={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
              }}
            >
              {user && (
                <Stack direction="row" spacing={2} alignItems="center">
                  {user.images?.[0]?.url && (
                    <Avatar
                      src={user.images[0].url}
                      alt={user.display_name}
                      sx={{ width: 40, height: 40 }}
                    />
                  )}
                  <Typography variant="body1" color="text.primary">
                    Connected as {user.display_name}
                  </Typography>
                </Stack>
              )}
              <Button
                variant="outlined"
                color="secondary"
                onClick={handleClearCreds}
                sx={{ textTransform: "none" }}
              >
                Clear Auth
              </Button>
            </Box>

            <Box component="header">
              <Typography variant="h4" component="h1" sx={{ mb: 2 }}>
                Spotify Library
              </Typography>
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
            </Box>
          </Stack>
        </Container>
      </Box>

      <Box className="main-content" sx={{ flex: 1, padding: 0.25 }}>
        <Container maxWidth={false} sx={{ px: 0.25 }}>
          {error && (
            <Box
              className="error-message"
              sx={{
                mb: 2,
                p: 2,
                backgroundColor: theme.palette.error.light,
                borderRadius: 1,
              }}
            >
              <Stack direction="row" spacing={1} alignItems="center">
                <Typography>⚠️</Typography>
                <Typography>{error}</Typography>
              </Stack>
            </Box>
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
              onNextPage={handleNextPage}
              onPrevPage={handlePrevPage}
              nowPlayingTrack={nowPlayingTrack}
              isPlaybackPaused={isPlaybackPaused}
              onPlay={handlePlay}
              onSave={handleSave}
              onRemove={handleRemove}
            />
          )}
        </Container>
      </Box>

      <Box
        sx={{
          position: 'fixed',
          bottom: 0,
          left: 0,
          right: 0,
          backgroundColor: theme.palette.background.paper,
          borderTop: `1px solid ${theme.palette.divider}`,
          zIndex: 1000,
        }}
      >
        <NowPlayingBar />
      </Box>
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
        <PlayerProvider>
          <SuggestionProvider>
            <AppContent />
          </SuggestionProvider>
        </PlayerProvider>
      </SnackbarProvider>
    </ThemeProvider>
  );
}

export default App;

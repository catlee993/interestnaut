import {
  createContext,
  useContext,
  useState,
  ReactNode,
  useEffect,
  useCallback,
} from "react";
import { spotify } from "@wailsjs/go/models";
import { PlayTrackOnDevice, PausePlaybackOnDevice } from "@wailsjs/go/bindings/Music";
import { useSpotifyPlayer } from "../hooks/useSpotifyPlayer";
import { usePlaybackState } from "../hooks/usePlaybackState";
import { useContinuousPlayback } from "../hooks/useContinuousPlayback";

// Define a type for track to simplify code
type Track = spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | null;

interface PlayerContextType {
  // State
  nowPlayingTrack: Track;
  isPlaybackPaused: boolean;
  spotifyPlayer: any;
  spotifyDeviceId: string | null;
  currentPosition: number;
  duration: number;
  isContinuousPlayback: boolean;
  
  // Actions
  setNextTrack: (track: Track) => void;
  setNowPlayingTrack: (track: Track) => void;
  handlePlay: (track: Track | string) => Promise<void>;
  stopPlayback: () => Promise<void>;
  handlePlayPause: () => void;
  seekTo: (position: number) => void;
  setContinuousPlayback: (enabled: boolean) => void;
  updateSavedTracks: (tracks: spotify.SavedTracks, page: number) => void;
  testContinuousPlayback: () => boolean;
  playNextTrack: () => Promise<void>;
}

// Default context value
const defaultContext: PlayerContextType = {
  nowPlayingTrack: null,
  isPlaybackPaused: true,
  spotifyPlayer: null,
  spotifyDeviceId: null,
  currentPosition: 0,
  duration: 0,
  isContinuousPlayback: false,
  
  setNextTrack: () => {},
  setNowPlayingTrack: () => {},
  handlePlay: async () => {},
  stopPlayback: async () => {},
  handlePlayPause: () => {},
  seekTo: () => {},
  setContinuousPlayback: () => {},
  updateSavedTracks: () => {},
  testContinuousPlayback: () => false,
  playNextTrack: async () => {},
};

// Create the context
export const PlayerContext = createContext<PlayerContextType>(defaultContext);

interface PlayerProviderProps {
  children: ReactNode;
}

export function PlayerProvider({ children }: PlayerProviderProps): JSX.Element {
  // Track state
  const [nowPlayingTrack, setNowPlayingTrack] = useState<Track>(null);
  const [nextTrack, setNextTrack] = useState<Track>(null);
  
  // Use the Spotify Player hook
  const {
    spotifyPlayer,
    spotifyDeviceId,
    isInitializing,
    initializePlayer,
  } = useSpotifyPlayer();
  
  // Use the Playback State hook
  const {
    isPaused: isPlaybackPaused,
    currentPosition,
    duration,
    updatePlaybackState,
    seekTo,
  } = usePlaybackState(spotifyPlayer);
  
  // Internal state setter for isPlaybackPaused
  const setIsPlaybackPaused = useCallback((isPaused: boolean) => {
    // No direct setter from usePlaybackState, so we call updatePlaybackState
    // and let the hook handle the state update
    updatePlaybackState();
  }, [updatePlaybackState]);
  
  // Use Continuous Playback hook
  const {
    isContinuousPlayback,
    setContinuousPlayback,
    updateSavedTracks: updateTracksInPlayback,
    handleTrackEnd,
    playNextTrack: playNext,
    testContinuousPlayback,
    isTrackEnded,
  } = useContinuousPlayback({
    spotifyDeviceId,
    setNowPlayingTrack,
    setNextTrack,
    setIsPlaybackPaused,
  });

  // Set up listener for player state changes to detect track end
  useEffect(() => {
    if (!spotifyPlayer) return;
    
    const onStateChange = async (state: any) => {
      if (!state) return;
      
      // If track has ended, handle it
      if (isTrackEnded(state)) {
        if (isContinuousPlayback) {
          await handleTrackEnd(state);
        } else {
          // Just update UI state
          setIsPlaybackPaused(true);
        }
      }
    };
    
    spotifyPlayer.addListener('player_state_changed', onStateChange);
    
    return () => {
      spotifyPlayer.removeListener('player_state_changed', onStateChange);
    };
  }, [spotifyPlayer, isContinuousPlayback, handleTrackEnd, isTrackEnded, setIsPlaybackPaused]);

  // A wrapper for updateSavedTracks to pass the nowPlayingTrack
  const updateSavedTracks = useCallback((tracks: spotify.SavedTracks, page: number) => {
    updateTracksInPlayback(tracks, page, nowPlayingTrack);
  }, [updateTracksInPlayback, nowPlayingTrack]);

  // Handle track play functionality
  const handlePlay = useCallback(async (trackOrUri: Track | string) => {
    if (!spotifyPlayer || !spotifyDeviceId) {
      console.log("Spotify player not ready. Attempting to reinitialize...");
      await initializePlayer();
      // Wait a bit for the player to initialize
      await new Promise((resolve) => setTimeout(resolve, 1000));
      if (!spotifyPlayer || !spotifyDeviceId) {
        console.error("Failed to initialize player after retry");
        return;
      }
    }

    const trackUri = typeof trackOrUri === "string" 
      ? trackOrUri 
      : trackOrUri?.uri || null;
      
    if (!trackUri) {
      console.error("No track URI provided");
      return;
    }

    try {
      await PlayTrackOnDevice(spotifyDeviceId, trackUri);
      
      if (typeof trackOrUri !== "string" && trackOrUri !== null) {
        setNowPlayingTrack(trackOrUri);
      }
      
      // Ensure playback state is updated
      await updatePlaybackState();
    } catch (error) {
      console.error("Failed to play track:", error);
      
      // If the error is due to device not being active, try to reinitialize
      if (
        error instanceof Error &&
        (error.message.includes("No active device") ||
          error.message.includes("Device not found"))
      ) {
        console.log("Device not found, attempting to reinitialize player...");
        await initializePlayer();
        // Wait a bit for the player to initialize
        await new Promise((resolve) => setTimeout(resolve, 1000));
        // Try playing again after reinitialization
        if (spotifyDeviceId) {
          await PlayTrackOnDevice(spotifyDeviceId, trackUri);
          if (typeof trackOrUri !== "string" && trackOrUri !== null) {
            setNowPlayingTrack(trackOrUri);
          }
          await updatePlaybackState();
        }
      }
    }
  }, [spotifyPlayer, spotifyDeviceId, initializePlayer, updatePlaybackState]);

  // Stop playback
  const stopPlayback = useCallback(async () => {
    if (spotifyPlayer && spotifyDeviceId) {
      try {
        await PausePlaybackOnDevice(spotifyDeviceId);
        setNowPlayingTrack(null);
        await updatePlaybackState();
      } catch (error: unknown) {
        const errorMessage =
          error instanceof Error
            ? error.message
            : "Unknown error occurred while pausing playback";
        console.error("[stopPlayback]", errorMessage);
      }
    }
  }, [spotifyPlayer, spotifyDeviceId, updatePlaybackState]);

  // Handle play/pause toggle
  const handlePlayPause = useCallback(async () => {
    if (!nowPlayingTrack || !spotifyPlayer) return;

    try {
      if (isPlaybackPaused) {
        // Resume playback
        await spotifyPlayer.resume();
      } else {
        // Pause playback
        await spotifyPlayer.pause();
      }
      await updatePlaybackState();
    } catch (error: unknown) {
      const errorMessage =
        error instanceof Error
          ? error.message
          : "Unknown error occurred while toggling playback";
      console.error("[handlePlayPause]", errorMessage);
    }
  }, [nowPlayingTrack, spotifyPlayer, isPlaybackPaused, updatePlaybackState]);

  // Find and update the wrapper for playNextTrack
  const playNextTrack = useCallback(async () => {
    // Call the hook's playNext but ignore the return value
    await playNext();
    // Function signature expects a Promise<void> return
  }, [playNext]);

  // Create the context value object
  const contextValue: PlayerContextType = {
    // State
    nowPlayingTrack,
    isPlaybackPaused,
    spotifyPlayer,
    spotifyDeviceId,
    currentPosition,
    duration,
    isContinuousPlayback,
    
    // Actions
    setNextTrack,
    setNowPlayingTrack,
    handlePlay,
    stopPlayback,
    handlePlayPause,
    seekTo,
    setContinuousPlayback,
    updateSavedTracks,
    testContinuousPlayback,
    playNextTrack,
  };

  return (
    <PlayerContext.Provider value={contextValue}>
      {children}
    </PlayerContext.Provider>
  );
}

export function usePlayer() {
  const context = useContext(PlayerContext);
  if (context === undefined) {
    throw new Error("usePlayer must be used within a PlayerProvider");
  }
  return context;
}

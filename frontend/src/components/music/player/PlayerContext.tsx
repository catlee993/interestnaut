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
import { useSettings } from "@/contexts/SettingsContext";
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
  stopPlayback: () => Promise<boolean>;
  handlePlayPause: () => void;
  seekTo: (position: number) => void;
  setContinuousPlayback: (enabled: boolean) => void;
  updateSavedTracks: (tracks: spotify.SavedTracks, page: number) => void;
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
  stopPlayback: async () => false,
  handlePlayPause: () => {},
  seekTo: () => {},
  setContinuousPlayback: () => {},
  updateSavedTracks: () => {},
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
  
  // Use the settings context
  const { isContinuousPlayback } = useSettings();
  
  // Use the Spotify Player hook
  const {
    spotifyPlayer,
    spotifyDeviceId,
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
  const setIsPlaybackPaused = useCallback(() => {
    // No direct setter from usePlaybackState, so we call updatePlaybackState
    // and let the hook handle the state update
    updatePlaybackState();
  }, [updatePlaybackState]);
  
  // Use Continuous Playback hook
  const {
    setContinuousPlayback,
    updateSavedTracks: updateTracksInPlayback,
    handleTrackEnd,
    playNextTrack: playNext,
    isTrackEnded,
  } = useContinuousPlayback({
    spotifyDeviceId,
    setNowPlayingTrack,
    setNextTrack,
    setIsPlaybackPaused,
  });

  // Add effect to ensure isContinuousPlayback setting is applied when changed
  useEffect(() => {
    console.log("[PlayerContext] Continuous playback setting:", isContinuousPlayback);
  }, [isContinuousPlayback]);

  // Wrapper for setContinuousPlayback to handle UI state updates
  const handleSetContinuousPlayback = useCallback((enabled: boolean) => {
    console.log("[PlayerContext] Setting continuous playback to:", enabled);
    setContinuousPlayback(enabled);
  }, [setContinuousPlayback]);

  // A wrapper for updateSavedTracks to pass the nowPlayingTrack
  const updateSavedTracks = useCallback((tracks: spotify.SavedTracks, page: number) => {
    updateTracksInPlayback(tracks, page, nowPlayingTrack);
  }, [updateTracksInPlayback, nowPlayingTrack]);

  // Stop playback
  const stopPlayback = useCallback(async () => {
    if (spotifyPlayer && spotifyDeviceId) {
      try {
        console.debug('Attempting to stop playback');
        
        let stopSuccessful = false;
        
        // Explicitly pause via the SDK
        try {
          await spotifyPlayer.pause();
          stopSuccessful = true;
        } catch (sdkError) {
          console.debug('SDK pause failed, trying API', sdkError);
          try {
            await PausePlaybackOnDevice(spotifyDeviceId);
            stopSuccessful = true;
          } catch (apiError) {
            console.error('Failed to stop playback via API:', apiError);
          }
        }
        
        // Dispatch an event to prevent false track end detection
        window.dispatchEvent(new CustomEvent('trackStopped'));
        
        // Update state
        await updatePlaybackState();
        
        // When continuous playback is off, we want to keep the track in the UI
        // Only clear nowPlayingTrack if we successfully stopped AND continuous playback is on
        if (stopSuccessful && isContinuousPlayback) {
          setNowPlayingTrack(null);
        }
        
        return stopSuccessful;
      } catch (error) {
        console.error('Error stopping playback:', error);
        // Update state but don't clear nowPlayingTrack on error
        await updatePlaybackState();
        return false;
      }
    }
    return false;
  }, [spotifyPlayer, spotifyDeviceId, updatePlaybackState, isContinuousPlayback]);

  // Set up listener for player state changes to detect track end
  useEffect(() => {
    if (!spotifyPlayer) return;
    
    const onStateChange = async (state: any) => {
      if (!state) return;
      
      // If track has ended, handle it
      if (isTrackEnded(state)) {
        // Use the context value directly
        console.log("[PlayerContext] Track end detected", { 
          isContinuousPlayback
        });
        
        if (isContinuousPlayback) {
          console.log("[PlayerContext] Initiating continuous playback");
          const success = await handleTrackEnd(state);
          if (!success) {
            console.log("[PlayerContext] Continuous playback failed, updating UI state");
            setIsPlaybackPaused();
          }
        } else {
          console.log("[PlayerContext] No continuous playback, updating UI state");
          // Be extra explicit about stopping playback when continuous playback is off
          await stopPlayback();
          setIsPlaybackPaused();
        }
      }
    };
    
    spotifyPlayer.addListener('player_state_changed', onStateChange);
    
    return () => {
      spotifyPlayer.removeListener('player_state_changed', onStateChange);
    };
  }, [spotifyPlayer, isContinuousPlayback, handleTrackEnd, isTrackEnded, setIsPlaybackPaused, stopPlayback]);

  // Handle track play functionality
  const handlePlay = useCallback(async (trackOrUri: Track | string) => {
    if (!spotifyPlayer || !spotifyDeviceId) {
      await initializePlayer();
      // Wait a bit for the player to initialize
      await new Promise((resolve) => setTimeout(resolve, 1000));
      if (!spotifyPlayer || !spotifyDeviceId) return;
    }

    const trackUri = typeof trackOrUri === "string" 
      ? trackOrUri 
      : trackOrUri?.uri || null;
      
    // Debug logging to check if URI is present
    console.log("[PlayerContext] Playing track:", { 
      isString: typeof trackOrUri === "string",
      extractedUri: trackUri,
      currentTrackId: nowPlayingTrack?.id,
      newTrackId: typeof trackOrUri !== "string" ? trackOrUri?.id : "unknown",
      isPaused: isPlaybackPaused
    });
      
    if (!trackUri) {
      console.error("[PlayerContext] Cannot play track - missing URI:", trackOrUri);
      return;
    }

    try {
      // Reset player state to avoid issues when switching tracks
      if (nowPlayingTrack && nowPlayingTrack.id !== (typeof trackOrUri !== "string" ? trackOrUri?.id : null)) {
        console.log("[PlayerContext] Switching tracks, resetting player state");
      }

      // Important: Update the nowPlayingTrack BEFORE attempting to play
      // This ensures the UI updates even if the API call fails
      if (typeof trackOrUri !== "string" && trackOrUri !== null) {
        console.log("[PlayerContext] Setting nowPlayingTrack to:", trackOrUri.id);
        setNowPlayingTrack(trackOrUri);
      }
      
      // Dispatch trackStarted event to prevent false track end detection
      window.dispatchEvent(new Event('trackStarted'));
      
      try {
        // Clear previous playback errors
        window.dispatchEvent(new Event('clearPlaybackErrors'));
        
        // Attempt to play the track
        await PlayTrackOnDevice(spotifyDeviceId, trackUri);
      } catch (playError) {
        console.error("[PlayerContext] Error playing track, but UI state was already updated:", playError);
        // Even if the API call fails, we still show the track as the current one
        // but we'll mark it as paused since playback didn't succeed
        await updatePlaybackState();
      }
      
      // Ensure playback state is updated
      await updatePlaybackState();
    } catch (error) {
      console.error("[PlayerContext] Critical error in handlePlay:", error);
      
      // Even on critical errors, maintain the UI state if we can
      if (typeof trackOrUri !== "string" && trackOrUri !== null) {
        setNowPlayingTrack(trackOrUri);
      }
      
      // If the error is due to device not being active, try to reinitialize
      if (
        error instanceof Error &&
        (error.message.includes("No active device") ||
          error.message.includes("Device not found"))
      ) {
        try {
          await initializePlayer();
          // Wait a bit for the player to initialize
          await new Promise((resolve) => setTimeout(resolve, 1000));
          
          // Try playing again after reinitialization
          if (spotifyDeviceId) {
            // Set the track again for UI consistency
            if (typeof trackOrUri !== "string" && trackOrUri !== null) {
              setNowPlayingTrack(trackOrUri);
            }
            
            window.dispatchEvent(new Event('trackStarted'));
            
            await PlayTrackOnDevice(spotifyDeviceId, trackUri);
            await updatePlaybackState();
          }
        } catch (retryError) {
          console.error("[PlayerContext] Failed even after player reinitialization:", retryError);
          // Ensure we still update the playback state to maintain UI consistency
          await updatePlaybackState();
        }
      } else {
        // For other errors, still ensure playback state is updated for UI consistency
        await updatePlaybackState();
      }
    }
  }, [spotifyPlayer, spotifyDeviceId, initializePlayer, updatePlaybackState, nowPlayingTrack, isPlaybackPaused]);

  // Handle play/pause toggle
  const handlePlayPause = useCallback(async () => {
    if (!nowPlayingTrack || !spotifyPlayer) {
      console.log("[PlayerContext] Cannot toggle play/pause - missing track or player");
      return;
    }

    try {
      // First update the playback state to get the current state
      await updatePlaybackState();
      
      console.log("[PlayerContext] Toggle play/pause for track:", {
        trackId: nowPlayingTrack.id,
        currentState: isPlaybackPaused ? "paused" : "playing"
      });
      
      if (isPlaybackPaused) {
        console.log("[PlayerContext] Resuming playback for track:", nowPlayingTrack.id);
        
        // Make sure we still have the track in state before resuming
        if (!nowPlayingTrack) {
          console.error("[PlayerContext] Cannot resume - track was cleared");
          return;
        }
        
        // Resume playback
        await spotifyPlayer.resume();
      } else {
        console.log("[PlayerContext] Pausing playback for track:", nowPlayingTrack.id);
        // Pause playback
        await spotifyPlayer.pause();
      }
      
      // Important: Don't clear the nowPlayingTrack when pausing
      // This keeps the UI consistent
      
      // Update state after action to reflect the new state
      await updatePlaybackState();
    } catch (error) {
      console.error("[PlayerContext] Play/pause error:", error);
      // Force update state even on error to ensure UI is consistent
      await updatePlaybackState();
    }
  }, [nowPlayingTrack, spotifyPlayer, isPlaybackPaused, updatePlaybackState]);

  // Wrapper for playNextTrack
  const playNextTrack = useCallback(async () => {
    await playNext();
  }, [playNext]);

  // Add a useEffect to set up global error handling for 404 errors during playback
  useEffect(() => {
    const originalOnError = window.onerror;
    
    // Global error handler to suppress 404 errors from Spotify playback
    window.onerror = function(message, source, lineno, colno, error) {
      if (
        message && 
        (
          (typeof message === 'string' && message.includes('404')) ||
          (typeof message === 'object' && message.toString().includes('404')) ||
          (source && source.includes('spotify')) ||
          (error && error.message && error.message.includes('404'))
        )
      ) {
        // Suppress Spotify 404 error
        return true;
      }
      
      // For other errors, use the original handler if it exists
      if (originalOnError) {
        return originalOnError(message, source, lineno, colno, error);
      }
      
      return false;
    };
    
    // Handler for unhandled promise rejections
    const handleUnhandledRejection = (event: PromiseRejectionEvent) => {
      if (
        event.reason && 
        (
          (event.reason.message && (
            event.reason.message.includes('404') || 
            event.reason.message.includes('PlayLoad')
          )) ||
          (event.reason.toString && event.reason.toString().includes('404'))
        )
      ) {
        // Suppress Spotify playback errors
        event.preventDefault();
      }
    };
    
    window.addEventListener('unhandledrejection', handleUnhandledRejection);
    
    // Clean up
    return () => {
      window.onerror = originalOnError;
      window.removeEventListener('unhandledrejection', handleUnhandledRejection);
    };
  }, []);

  // Add a listener for playback errors in spotifyPlayer
  useEffect(() => {
    if (!spotifyPlayer) return;
    
    const handlePlaybackError = (error: any) => {
      // If it's a 404 during track loading, mark that we're still in startup
      if (error.message && error.message.includes('404')) {
        // Dispatch a trackStarted event to ensure we have protection against false track end
        window.dispatchEvent(new Event('trackStarted'));
      }
    };
    
    spotifyPlayer.addListener('playback_error', handlePlaybackError);
    
    return () => {
      spotifyPlayer.removeListener('playback_error', handlePlaybackError);
    };
  }, [spotifyPlayer]);

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
    setContinuousPlayback: handleSetContinuousPlayback,
    updateSavedTracks,
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

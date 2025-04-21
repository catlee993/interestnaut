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

type Track = spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | null;

interface PlayerContextType {
  nowPlayingTrack: Track;
  isPlaybackPaused: boolean;
  spotifyPlayer: any;
  spotifyDeviceId: string | null;
  currentPosition: number;
  duration: number;
  isContinuousPlayback: boolean;
  
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

export const PlayerContext = createContext<PlayerContextType>(defaultContext);

interface PlayerProviderProps {
  children: ReactNode;
}

export function PlayerProvider({ children }: PlayerProviderProps): JSX.Element {
  const [nowPlayingTrack, setNowPlayingTrack] = useState<Track>(null);
  const [nextTrack, setNextTrack] = useState<Track>(null);
  
  const { isContinuousPlayback } = useSettings();
  
  const {
    spotifyPlayer,
    spotifyDeviceId,
    initializePlayer,
  } = useSpotifyPlayer();
  
  const {
    isPaused: isPlaybackPaused,
    currentPosition,
    duration,
    updatePlaybackState,
    seekTo,
  } = usePlaybackState(spotifyPlayer);
  
  const setIsPlaybackPaused = useCallback(() => {
    updatePlaybackState();
  }, [updatePlaybackState]);
  
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

  useEffect(() => {
    console.log("[PlayerContext] Continuous playback setting:", isContinuousPlayback);
  }, [isContinuousPlayback]);

  const handleSetContinuousPlayback = useCallback((enabled: boolean) => {
    console.log("[PlayerContext] Setting continuous playback to:", enabled);
    setContinuousPlayback(enabled);
  }, [setContinuousPlayback]);

  const updateSavedTracks = useCallback((tracks: spotify.SavedTracks, page: number) => {
    updateTracksInPlayback(tracks, page, nowPlayingTrack);
  }, [updateTracksInPlayback, nowPlayingTrack]);

  const stopPlayback = useCallback(async () => {
    if (spotifyPlayer && spotifyDeviceId) {
      try {
        console.debug('Attempting to stop playback');
        
        let stopSuccessful = false;
        
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
        
        window.dispatchEvent(new CustomEvent('trackStopped'));
        
        await updatePlaybackState();
        
        if (stopSuccessful && isContinuousPlayback) {
          setNowPlayingTrack(null);
        }
        
        return stopSuccessful;
      } catch (error) {
        console.error('Error stopping playback:', error);
        await updatePlaybackState();
        return false;
      }
    }
    return false;
  }, [spotifyPlayer, spotifyDeviceId, updatePlaybackState, isContinuousPlayback]);

  useEffect(() => {
    if (!spotifyPlayer) return;
    
    const onStateChange = async (state: any) => {
      if (!state) return;
      
      if (isTrackEnded(state)) {
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

  const handlePlay = useCallback(async (trackOrUri: Track | string) => {
    if (!spotifyPlayer || !spotifyDeviceId) {
      await initializePlayer();
      await new Promise((resolve) => setTimeout(resolve, 1000));
      if (!spotifyPlayer || !spotifyDeviceId) return;
    }

    const trackUri = typeof trackOrUri === "string" 
      ? trackOrUri 
      : trackOrUri?.uri || null;
      
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
      if (nowPlayingTrack && nowPlayingTrack.id !== (typeof trackOrUri !== "string" ? trackOrUri?.id : null)) {
        console.log("[PlayerContext] Switching tracks, resetting player state");
      }

      if (typeof trackOrUri !== "string" && trackOrUri !== null) {
        console.log("[PlayerContext] Setting nowPlayingTrack to:", trackOrUri.id);
        setNowPlayingTrack(trackOrUri);
      }
      
      window.dispatchEvent(new Event('trackStarted'));
      
      try {
        window.dispatchEvent(new Event('clearPlaybackErrors'));
        
        await PlayTrackOnDevice(spotifyDeviceId, trackUri);
      } catch (playError) {
        console.error("[PlayerContext] Error playing track, but UI state was already updated:", playError);
        await updatePlaybackState();
      }
      
      await updatePlaybackState();
    } catch (error) {
      console.error("[PlayerContext] Critical error in handlePlay:", error);
      
      if (typeof trackOrUri !== "string" && trackOrUri !== null) {
        setNowPlayingTrack(trackOrUri);
      }
      
      if (
        error instanceof Error &&
        (error.message.includes("No active device") ||
          error.message.includes("Device not found"))
      ) {
        try {
          await initializePlayer();
          await new Promise((resolve) => setTimeout(resolve, 1000));
          
          if (spotifyDeviceId) {
            if (typeof trackOrUri !== "string" && trackOrUri !== null) {
              setNowPlayingTrack(trackOrUri);
            }
            
            window.dispatchEvent(new Event('trackStarted'));
            
            await PlayTrackOnDevice(spotifyDeviceId, trackUri);
            await updatePlaybackState();
          }
        } catch (retryError) {
          console.error("[PlayerContext] Failed even after player reinitialization:", retryError);
          await updatePlaybackState();
        }
      } else {
        await updatePlaybackState();
      }
    }
  }, [spotifyPlayer, spotifyDeviceId, initializePlayer, updatePlaybackState, nowPlayingTrack, isPlaybackPaused]);

  const handlePlayPause = useCallback(async () => {
    if (!nowPlayingTrack || !spotifyPlayer) {
      console.log("[PlayerContext] Cannot toggle play/pause - missing track or player");
      return;
    }

    try {
      await updatePlaybackState();
      
      console.log("[PlayerContext] Toggle play/pause for track:", {
        trackId: nowPlayingTrack.id,
        currentState: isPlaybackPaused ? "paused" : "playing"
      });
      
      if (isPlaybackPaused) {
        console.log("[PlayerContext] Resuming playback for track:", nowPlayingTrack.id);
        
        if (!nowPlayingTrack) {
          console.error("[PlayerContext] Cannot resume - track was cleared");
          return;
        }
        
        await spotifyPlayer.resume();
      } else {
        console.log("[PlayerContext] Pausing playback for track:", nowPlayingTrack.id);
        await spotifyPlayer.pause();
      }
      
      await updatePlaybackState();
    } catch (error) {
      console.error("[PlayerContext] Play/pause error:", error);
      await updatePlaybackState();
    }
  }, [nowPlayingTrack, spotifyPlayer, isPlaybackPaused, updatePlaybackState]);

  const playNextTrack = useCallback(async () => {
    await playNext();
  }, [playNext]);

  useEffect(() => {
    const originalOnError = window.onerror;
    
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
        return true;
      }
      
      if (originalOnError) {
        return originalOnError(message, source, lineno, colno, error);
      }
      
      return false;
    };
    
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
        event.preventDefault();
      }
    };
    
    window.addEventListener('unhandledrejection', handleUnhandledRejection);
    
    return () => {
      window.onerror = originalOnError;
      window.removeEventListener('unhandledrejection', handleUnhandledRejection);
    };
  }, []);

  useEffect(() => {
    if (!spotifyPlayer) return;
    
    const handlePlaybackError = (error: any) => {
      if (error.message && error.message.includes('404')) {
        window.dispatchEvent(new Event('trackStarted'));
      }
    };
    
    spotifyPlayer.addListener('playback_error', handlePlaybackError);
    
    return () => {
      spotifyPlayer.removeListener('playback_error', handlePlaybackError);
    };
  }, [spotifyPlayer]);

  const contextValue: PlayerContextType = {
    nowPlayingTrack,
    isPlaybackPaused,
    spotifyPlayer,
    spotifyDeviceId,
    currentPosition,
    duration,
    isContinuousPlayback,
    
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

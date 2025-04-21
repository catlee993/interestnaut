import { useCallback, useEffect, useRef, useState } from "react";

/**
 * A hook that manages playback state, including position, duration, and play/pause state
 */
export function usePlaybackState(spotifyPlayer: any) {
  const [isPaused, setIsPaused] = useState(true);
  const [currentPosition, setCurrentPosition] = useState(0);
  const [duration, setDuration] = useState(0);

  const positionInterval = useRef<NodeJS.Timeout | null>(null);
  
  const updatePlaybackState = useCallback(async () => {
    if (!spotifyPlayer) return;
    
    try {
      const state = await spotifyPlayer.getCurrentState();
      if (!state) {
        setIsPaused(true);
        setCurrentPosition(0);
        setDuration(0);
        return;
      }
      
      setIsPaused(state.paused);
      setCurrentPosition(state.position);
      if (state.duration !== duration) {
        setDuration(state.duration);
      }
    } catch (error) {
      // Silently handle errors to avoid console noise
    }
  }, [spotifyPlayer, duration]);
  
  useEffect(() => {
    if (!spotifyPlayer) {
      if (positionInterval.current) {
        clearInterval(positionInterval.current);
        positionInterval.current = null;
      }
      return;
    }
    
    const trackPosition = async () => {
      await updatePlaybackState();
    };
    
    trackPosition();
    
    if (positionInterval.current) {
      clearInterval(positionInterval.current);
    }
    
    positionInterval.current = setInterval(trackPosition, 1000);
    
    return () => {
      if (positionInterval.current) {
        clearInterval(positionInterval.current);
        positionInterval.current = null;
      }
    };
  }, [spotifyPlayer, updatePlaybackState]);
  
  const seekTo = useCallback(
    async (position: number) => {
      if (!spotifyPlayer) return;
      try {
        await spotifyPlayer.seek(position);
        setCurrentPosition(position);
      } catch (error) {
        // Silently handle errors to avoid console noise
      }
    },
    [spotifyPlayer]
  );
  
  return {
    isPaused,
    currentPosition,
    duration,
    updatePlaybackState,
    seekTo
  };
} 
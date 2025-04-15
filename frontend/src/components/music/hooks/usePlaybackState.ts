import { useCallback, useEffect, useRef, useState } from "react";

/**
 * A hook that manages playback state, including position, duration, and play/pause state
 */
export function usePlaybackState(spotifyPlayer: any) {
  const [isPaused, setIsPaused] = useState(true);
  const [currentPosition, setCurrentPosition] = useState(0);
  const [duration, setDuration] = useState(0);

  // References for tracking state
  const positionInterval = useRef<NodeJS.Timeout | null>(null);
  
  // Update play/pause state when player state changes
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
  
  // Start tracking position with interval
  useEffect(() => {
    if (!spotifyPlayer) {
      // Clear interval if player is not available
      if (positionInterval.current) {
        clearInterval(positionInterval.current);
        positionInterval.current = null;
      }
      return;
    }
    
    // Set up position tracking
    const trackPosition = async () => {
      await updatePlaybackState();
    };
    
    // Call immediately and then set interval
    trackPosition();
    
    // Clear any existing interval
    if (positionInterval.current) {
      clearInterval(positionInterval.current);
    }
    
    // Update position every second
    positionInterval.current = setInterval(trackPosition, 1000);
    
    // Cleanup on unmount
    return () => {
      if (positionInterval.current) {
        clearInterval(positionInterval.current);
        positionInterval.current = null;
      }
    };
  }, [spotifyPlayer, updatePlaybackState]);
  
  // Seek to a specific position
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
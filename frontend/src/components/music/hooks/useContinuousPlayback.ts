import { useCallback, useRef, useState, useEffect } from "react";
import { spotify } from "@wailsjs/go/models";
import { GetContinuousPlayback } from "@wailsjs/go/bindings/Settings";
import { PlayTrackOnDevice } from "@wailsjs/go/bindings/Music";

// Constants for debugging
const DEBUG_MODE = true;

const debugLog = (...args: any[]) => {
  if (DEBUG_MODE) {
    console.log(...args);
  }
};

type Track = spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo;

interface UseContinuousPlaybackOptions {
  spotifyDeviceId: string | null;
  setNowPlayingTrack: (track: Track | null) => void;
  setNextTrack: (track: Track | null) => void;
  setIsPlaybackPaused: (isPaused: boolean) => void;
}

export function useContinuousPlayback({
  spotifyDeviceId,
  setNowPlayingTrack,
  setNextTrack,
  setIsPlaybackPaused,
}: UseContinuousPlaybackOptions) {
  const [isContinuousPlayback, setIsContinuousPlayback] = useState(false);
  const savedTracksRef = useRef<spotify.SavedTrackItem[]>([]);
  const currentTrackIndexRef = useRef<number>(-1);
  const totalTracksRef = useRef<number>(0);
  const currentPageRef = useRef<number>(1);
  const isHandlingTrackEnd = useRef(false);
  const currentlyPlayingTrackIdRef = useRef<string | null>(null);
  const isStartingNewTrackRef = useRef(false);
  const startTrackTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // Load continuous playback setting
  useEffect(() => {
    const loadContinuousPlaybackSetting = async () => {
      try {
        console.log("[useContinuousPlayback] Loading continuous playback setting");
        const enabled = await GetContinuousPlayback();
        console.log(`[useContinuousPlayback] Continuous playback setting: ${enabled}`);
        setIsContinuousPlayback(enabled);
      } catch (error) {
        console.error("[useContinuousPlayback] Error loading continuous playback setting:", error);
      }
    };
    
    loadContinuousPlaybackSetting();
  }, []);

  // Update saved tracks reference
  const updateSavedTracks = useCallback((tracks: spotify.SavedTracks, page: number, nowPlayingTrack: Track | null) => {
    debugLog(`[useContinuousPlayback] Updating saved tracks: ${tracks.items.length} tracks on page ${page}`);
    
    if (tracks.items && tracks.items.length > 0) {
      savedTracksRef.current = tracks.items;
      currentPageRef.current = page;
      totalTracksRef.current = tracks.total || 0;
      
      debugLog(`[useContinuousPlayback] Saved tracks updated. Total tracks: ${totalTracksRef.current}`);
      
      // If we have a currently playing track, try to find its index
      if (nowPlayingTrack) {
        // Log the currently playing track for debugging
        debugLog(`[useContinuousPlayback] Looking for track: ${nowPlayingTrack.name} (ID: ${nowPlayingTrack.id})`);
        
        const index = tracks.items.findIndex(item => 
          item.track && item.track.id === nowPlayingTrack.id
        );
        
        if (index !== -1) {
          debugLog(`[useContinuousPlayback] Current track found at index ${index}`);
          // If we're getting a different index than before, log it to debug
          if (currentTrackIndexRef.current !== -1 && currentTrackIndexRef.current !== index) {
            debugLog(`[useContinuousPlayback] WARNING: Track index changed from ${currentTrackIndexRef.current} to ${index}`);
          }
          currentTrackIndexRef.current = index;
          currentlyPlayingTrackIdRef.current = nowPlayingTrack.id || null;
          
          // Set next track if possible
          if (index < tracks.items.length - 1 && tracks.items[index + 1]?.track) {
            const nextTrackToSet = tracks.items[index + 1].track;
            if (nextTrackToSet) {
              setNextTrack(nextTrackToSet);
              debugLog(`[useContinuousPlayback] Next track set to: ${nextTrackToSet.name}`);
            }
          }
        } else {
          debugLog(`[useContinuousPlayback] Current track not found in saved tracks`);
          // Reset index if track isn't in the current page
          if (nowPlayingTrack.id && currentlyPlayingTrackIdRef.current === nowPlayingTrack.id) {
            debugLog(`[useContinuousPlayback] Current track may be on a different page`);
          } else {
            debugLog(`[useContinuousPlayback] Resetting track index as track is not in library`);
            currentTrackIndexRef.current = -1;
          }
        }
      }
    }
  }, [setNextTrack]);

  // Add a function to mark when we're starting a new track
  const markTrackStart = useCallback(() => {
    isStartingNewTrackRef.current = true;
    
    // Clear any existing timeout
    if (startTrackTimeoutRef.current) {
      clearTimeout(startTrackTimeoutRef.current);
    }
    
    // Set a timeout to reset the flag after 2 seconds
    startTrackTimeoutRef.current = setTimeout(() => {
      isStartingNewTrackRef.current = false;
      debugLog('[useContinuousPlayback] Track start protection period ended');
    }, 2000);
  }, []);

  // Listen for track start notifications
  useEffect(() => {
    // Create a custom event listener for when a track starts
    const handleTrackStart = (event: Event) => {
      debugLog('[useContinuousPlayback] Track start event received');
      markTrackStart();
    };
    
    window.addEventListener('trackStarted', handleTrackStart);
    
    return () => {
      window.removeEventListener('trackStarted', handleTrackStart);
      if (startTrackTimeoutRef.current) {
        clearTimeout(startTrackTimeoutRef.current);
      }
    };
  }, [markTrackStart]);

  // Handle track end and start playing next track
  const handleTrackEnd = useCallback(async (state: any) => {
    // Don't handle track end events if we're in the "starting new track" protection period
    if (isStartingNewTrackRef.current) {
      debugLog('[useContinuousPlayback] Ignoring track end during track start protection period');
      return false;
    }

    if (!isContinuousPlayback || currentTrackIndexRef.current < 0) {
      debugLog("[useContinuousPlayback] Continuous playback disabled or no track index");
      return false;
    }
    
    if (isHandlingTrackEnd.current) {
      debugLog('[useContinuousPlayback] Already handling track change, skipping');
      return false;
    }
    
    debugLog('[useContinuousPlayback] Handling track end');
    isHandlingTrackEnd.current = true;
    
    const nextIndex = currentTrackIndexRef.current + 1;
    if (nextIndex < savedTracksRef.current.length && savedTracksRef.current[nextIndex]?.track) {
      try {
        const nextTrackToPlay = savedTracksRef.current[nextIndex].track;
        if (!nextTrackToPlay || !nextTrackToPlay.uri || !spotifyDeviceId) {
          console.log("[useContinuousPlayback] Invalid next track or missing device ID");
          isHandlingTrackEnd.current = false;
          return false;
        }
        
        debugLog(`[useContinuousPlayback] Playing next track: ${nextTrackToPlay.name}`);
        
        // Play the next track
        await PlayTrackOnDevice(spotifyDeviceId, nextTrackToPlay.uri);
        debugLog('[useContinuousPlayback] Played next track via API');
        
        // Update state
        setNowPlayingTrack(nextTrackToPlay);
        currentTrackIndexRef.current = nextIndex;
        currentlyPlayingTrackIdRef.current = nextTrackToPlay.id || null;
        
        // Set the next track if available
        if (nextIndex < savedTracksRef.current.length - 1 && savedTracksRef.current[nextIndex + 1]?.track) {
          const nextTrackToSet = savedTracksRef.current[nextIndex + 1].track;
          if (nextTrackToSet) {
            setNextTrack(nextTrackToSet);
          } else {
            setNextTrack(null);
          }
        } else {
          setNextTrack(null);
        }
        
        setIsPlaybackPaused(false);
        
        // Reset debounce flag after a delay
        setTimeout(() => {
          isHandlingTrackEnd.current = false;
          debugLog('[useContinuousPlayback] Ready to handle next track end');
        }, 2000);
        
        return true;
      } catch (error) {
        console.error('[useContinuousPlayback] Failed to play next track:', error);
        isHandlingTrackEnd.current = false;
        return false;
      }
    } else {
      debugLog('[useContinuousPlayback] No more tracks available');
      isHandlingTrackEnd.current = false;
      return false;
    }
  }, [isContinuousPlayback, spotifyDeviceId, setNowPlayingTrack, setNextTrack, setIsPlaybackPaused]);

  // Manual playNextTrack function for user-initiated next track
  const playNextTrack = useCallback(async () => {
    if (currentTrackIndexRef.current < 0) {
      console.log("[useContinuousPlayback] No current track index, cannot play next track");
      return false;
    }
    
    if (isHandlingTrackEnd.current) {
      console.log("[useContinuousPlayback] Already handling track transition, skipping");
      return false;
    }
    
    // Manually create a fake state object to pass to handleTrackEnd
    const fakeState = { 
      paused: true, 
      position: 0, 
      duration: 1 
    };
    
    return handleTrackEnd(fakeState);
  }, [handleTrackEnd]);

  // A test function for debugging
  const testContinuousPlayback = useCallback(() => {
    debugLog("[useContinuousPlayback] Testing continuous playback");
    
    if (currentTrackIndexRef.current < 0 || !savedTracksRef.current.length) {
      debugLog("[useContinuousPlayback] No current track index or no saved tracks");
      return false;
    }
    
    debugLog(`[useContinuousPlayback] Current track index: ${currentTrackIndexRef.current}`);
    debugLog(`[useContinuousPlayback] Continuous playback enabled: ${isContinuousPlayback}`);
    debugLog(`[useContinuousPlayback] Total tracks: ${totalTracksRef.current}`);
    debugLog(`[useContinuousPlayback] Current page: ${currentPageRef.current}`);
    
    if (isContinuousPlayback) {
      const nextIndex = currentTrackIndexRef.current + 1;
      if (nextIndex < savedTracksRef.current.length && savedTracksRef.current[nextIndex]?.track) {
        const nextTrack = savedTracksRef.current[nextIndex].track;
        debugLog(`[useContinuousPlayback] Next track would be: ${nextTrack?.name}`);
        return true;
      } else {
        debugLog("[useContinuousPlayback] No next track available");
        return false;
      }
    } else {
      debugLog("[useContinuousPlayback] Continuous playback is disabled");
      return false;
    }
  }, [isContinuousPlayback]);

  // Make the test functions available globally for console debugging
  useEffect(() => {
    if (typeof window !== 'undefined') {
      (window as any).testContinuousPlayback = testContinuousPlayback;
      (window as any).playNextTrack = playNextTrack;
    }
    
    return () => {
      if (typeof window !== 'undefined') {
        delete (window as any).testContinuousPlayback;
        delete (window as any).playNextTrack;
      }
    };
  }, [testContinuousPlayback, playNextTrack]);

  return {
    isContinuousPlayback,
    setContinuousPlayback: setIsContinuousPlayback,
    updateSavedTracks,
    handleTrackEnd,
    playNextTrack,
    testContinuousPlayback,
    isTrackEnded: (state: any) => state.paused && state.position === 0 && state.duration > 0,
    markTrackStart
  };
} 
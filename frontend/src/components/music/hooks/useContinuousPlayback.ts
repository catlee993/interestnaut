import { useCallback, useRef, useState, useEffect } from "react";
import { spotify } from "@wailsjs/go/models";
import { PlayTrackOnDevice } from "@wailsjs/go/bindings/Music";
import { useSettings } from "@/contexts/SettingsContext";

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
  // Use settings from context instead of local state
  const { isContinuousPlayback, setContinuousPlayback } = useSettings();

  const savedTracksRef = useRef<spotify.SavedTrackItem[]>([]);
  const currentTrackIndexRef = useRef<number>(-1);
  const totalTracksRef = useRef<number>(0);
  const currentPageRef = useRef<number>(1);
  const isHandlingTrackEnd = useRef(false);
  const currentlyPlayingTrackIdRef = useRef<string | null>(null);
  const isStartingNewTrackRef = useRef(false);
  const startTrackTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // Update saved tracks reference
  const updateSavedTracks = useCallback(
    (
      tracks: spotify.SavedTracks,
      page: number,
      nowPlayingTrack: Track | null,
    ) => {
      if (tracks.items && tracks.items.length > 0) {
        savedTracksRef.current = tracks.items;
        currentPageRef.current = page;
        totalTracksRef.current = tracks.total || 0;

        // If we have a currently playing track, try to find its index
        if (nowPlayingTrack) {
          const index = tracks.items.findIndex(
            (item) => item.track && item.track.id === nowPlayingTrack.id,
          );

          if (index !== -1) {
            currentTrackIndexRef.current = index;
            currentlyPlayingTrackIdRef.current = nowPlayingTrack.id || null;

            // Set next track if possible
            if (
              index < tracks.items.length - 1 &&
              tracks.items[index + 1]?.track
            ) {
              const nextTrackToSet = tracks.items[index + 1].track;
              if (nextTrackToSet) {
                setNextTrack(nextTrackToSet);
              }
            }
          } else {
            // Reset index if track isn't in the current page
            if (
              nowPlayingTrack.id &&
              currentlyPlayingTrackIdRef.current === nowPlayingTrack.id
            ) {
              // Current track may be on a different page
            } else {
              currentTrackIndexRef.current = -1;
            }
          }
        }
      }
    },
    [setNextTrack],
  );

  // Simple function to mark when we're starting a new track
  const markTrackStart = useCallback(() => {
    isStartingNewTrackRef.current = true;

    // Clear any existing timeout
    if (startTrackTimeoutRef.current) {
      clearTimeout(startTrackTimeoutRef.current);
    }

    // Set a timeout to reset the flag after 2 seconds
    startTrackTimeoutRef.current = setTimeout(() => {
      isStartingNewTrackRef.current = false;
    }, 2000);
  }, []);

  // Listen for track start notifications
  useEffect(() => {
    // Create a custom event listener for when a track starts
    const handleTrackStart = () => {
      markTrackStart();
    };

    window.addEventListener("trackStarted", handleTrackStart);

    return () => {
      window.removeEventListener("trackStarted", handleTrackStart);
      if (startTrackTimeoutRef.current) {
        clearTimeout(startTrackTimeoutRef.current);
      }
    };
  }, [markTrackStart]);

  // Handle track end and start playing next track
  const handleTrackEnd = useCallback(
    async (state: any) => {
      // Don't handle track end events if we're in the "starting new track" protection period
      if (isStartingNewTrackRef.current) {
        console.log(
          "[ContinuousPlayback] Ignoring track end during protection period",
        );
        return false;
      }

      // Simply use the context value instead of checking backend
      console.log(
        "[ContinuousPlayback] Handling track end, continuous playback enabled:",
        isContinuousPlayback,
      );

      if (!isContinuousPlayback || currentTrackIndexRef.current < 0) {
        console.log(
          "[ContinuousPlayback] Not handling end - feature disabled or no current track",
        );
        return false;
      }

      if (isHandlingTrackEnd.current) {
        console.log("[ContinuousPlayback] Already handling track end");
        return false;
      }

      isHandlingTrackEnd.current = true;
      console.log("[ContinuousPlayback] Track ended, playing next track");

      const nextIndex = currentTrackIndexRef.current + 1;
      if (
        nextIndex < savedTracksRef.current.length &&
        savedTracksRef.current[nextIndex]?.track
      ) {
        try {
          const nextTrackToPlay = savedTracksRef.current[nextIndex].track;
          if (!nextTrackToPlay || !nextTrackToPlay.uri || !spotifyDeviceId) {
            console.log(
              "[ContinuousPlayback] Cannot play next track - missing data",
            );
            isHandlingTrackEnd.current = false;
            return false;
          }

          // Play the next track
          console.log(
            "[ContinuousPlayback] Playing next track:",
            nextTrackToPlay.name,
          );
          await PlayTrackOnDevice(spotifyDeviceId, nextTrackToPlay.uri);

          // Update state
          setNowPlayingTrack(nextTrackToPlay);
          currentTrackIndexRef.current = nextIndex;
          currentlyPlayingTrackIdRef.current = nextTrackToPlay.id || null;

          // Set the next track if available
          if (
            nextIndex < savedTracksRef.current.length - 1 &&
            savedTracksRef.current[nextIndex + 1]?.track
          ) {
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
          }, 2000);

          return true;
        } catch (error) {
          console.error(
            "[ContinuousPlayback] Error playing next track:",
            error,
          );
          isHandlingTrackEnd.current = false;
          return false;
        }
      } else {
        console.log("[ContinuousPlayback] No next track available");
        isHandlingTrackEnd.current = false;
        return false;
      }
    },
    [
      isContinuousPlayback,
      spotifyDeviceId,
      setNowPlayingTrack,
      setNextTrack,
      setIsPlaybackPaused,
    ],
  );

  // Manual playNextTrack function for user-initiated next track
  const playNextTrack = useCallback(async () => {
    if (currentTrackIndexRef.current < 0) {
      return false;
    }

    if (isHandlingTrackEnd.current) {
      return false;
    }

    // Manually create a fake state object to pass to handleTrackEnd
    const fakeState = {
      paused: true,
      position: 0,
      duration: 1,
    };

    return handleTrackEnd(fakeState);
  }, [handleTrackEnd]);

  return {
    isContinuousPlayback,
    setContinuousPlayback,
    updateSavedTracks,
    handleTrackEnd,
    playNextTrack,
    // Simple track end detection
    isTrackEnded: (state: any) => {
      if (!state) return false;

      const { paused, position, duration } = state;

      // end detection: paused at position 0 with duration > 0
      const trackEnded = paused && position === 0 && duration > 0;

      if (trackEnded) {
        console.log("[ContinuousPlayback] Track end detected:", {
          paused,
          position,
          duration,
        });
      }

      return trackEnded;
    },
    markTrackStart,
  };
}

import { useCallback, useState, useEffect } from "react";
import { spotify } from "@wailsjs/go/models";
import {
  PlayTrackOnDevice,
  PausePlaybackOnDevice,
} from "@wailsjs/go/bindings/Music";
import { useSpotifyPlayer } from "./useSpotifyPlayer";
import { usePlaybackState } from "./usePlaybackState";
import { usePlayer } from "../player/PlayerContext";

// Define Track type to encompass different Spotify track types
type Track = spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo;

/**
 * Hook for managing track playback and queue
 */
export function useTrackManager() {
  const { spotifyPlayer, spotifyDeviceId, isInitializing } = useSpotifyPlayer();

  const { isPaused, currentPosition, duration, updatePlaybackState, seekTo } =
    usePlaybackState(spotifyPlayer);

  // For continuous playback features, we still need PlayerContext
  const playerContext = usePlayer();

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentTrack, setCurrentTrack] = useState<Track | null>(null);
  const [nextTrack, setNextTrack] = useState<Track | null>(null);

  // Sync our state with PlayerContext
  useEffect(() => {
    setCurrentTrack(playerContext.nowPlayingTrack);
  }, [playerContext.nowPlayingTrack]);

  /**
   * Play a track on the current device
   */
  const playTrack = useCallback(
    async (track: Track) => {
      if (!spotifyDeviceId) {
        setError("No active Spotify device");
        return;
      }

      setIsLoading(true);
      setError(null);

      try {
        const trackUri = track.uri;
        if (!trackUri) {
          throw new Error("Track URI is missing");
        }

        await PlayTrackOnDevice(spotifyDeviceId, trackUri);
        setCurrentTrack(track);

        // Sync with PlayerContext
        playerContext.setNowPlayingTrack(track);

        // Update state after playing
        await updatePlaybackState();

        // Set next track if available in the library
        if (track.id) {
          playerContext.setNextTrack(nextTrack);
        }
      } catch (err) {
        const errorMessage =
          err instanceof Error ? err.message : "Unknown error playing track";
        setError(errorMessage);
      } finally {
        setIsLoading(false);
      }
    },
    [spotifyDeviceId, updatePlaybackState, playerContext, nextTrack],
  );

  /**
   * Play the next track in queue
   */
  const playNextTrack = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      await playerContext.playNextTrack();
      await updatePlaybackState();
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : "Unknown error playing next track";
      setError(errorMessage);
    } finally {
      setIsLoading(false);
    }
  }, [playerContext, updatePlaybackState]);

  /**
   * Toggle play/pause for the current track
   */
  const togglePlayPause = useCallback(async () => {
    if (!spotifyPlayer || !currentTrack) return;

    try {
      if (isPaused) {
        await spotifyPlayer.resume();
      } else {
        await spotifyPlayer.pause();
      }
      await updatePlaybackState();
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : "Unknown error toggling playback";
      setError(errorMessage);
    }
  }, [spotifyPlayer, currentTrack, isPaused, updatePlaybackState]);

  /**
   * Stop current playback
   */
  const stopPlayback = useCallback(async () => {
    if (!spotifyDeviceId) return;

    try {
      await PausePlaybackOnDevice(spotifyDeviceId);
      setCurrentTrack(null);
      playerContext.setNowPlayingTrack(null);
      await updatePlaybackState();
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : "Unknown error stopping playback";
      setError(errorMessage);
    }
  }, [spotifyDeviceId, updatePlaybackState, playerContext]);

  /**
   * Update next track to be played
   */
  const updateNextTrack = useCallback(
    (track: Track | null) => {
      setNextTrack(track);
      playerContext.setNextTrack(track);
    },
    [playerContext],
  );

  return {
    currentTrack,
    nextTrack,
    isPlaybackPaused: isPaused,
    currentPosition,
    duration,
    isContinuousPlayback: playerContext.isContinuousPlayback,
    isLoading: isLoading || isInitializing,
    error,

    playTrack,
    playNextTrack,
    togglePlayPause,
    stopPlayback,
    setNextTrack: updateNextTrack,
    seekTo,
    setContinuousPlayback: playerContext.setContinuousPlayback,
  };
}

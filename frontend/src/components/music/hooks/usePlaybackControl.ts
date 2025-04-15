import { useCallback } from "react";
import { spotify } from "@wailsjs/go/models";

/**
 * Hook to handle playback control logic that integrates with the Spotify library
 */
export function usePlaybackControl(
  savedTracks: spotify.SavedTracks | null,
  setNowPlayingTrack: (
    track:
      | spotify.Track
      | spotify.SimpleTrack
      | spotify.SuggestedTrackInfo
      | null,
  ) => void,
  setNextTrack: (
    track:
      | spotify.Track
      | spotify.SimpleTrack
      | spotify.SuggestedTrackInfo
      | null,
  ) => void,
  playerHandlePlay: (
    track: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo,
  ) => Promise<void>,
) {
  /**
   * Handles playing a track and setting up the next track from library if available
   */
  const handlePlay = useCallback(
    async (
      track: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo,
    ) => {
      console.log(`[PlaybackControl] Play track: ${track.name}`);

      // Update the nowPlayingTrack state directly
      setNowPlayingTrack(track);

      // Check if we're playing from the library
      if (savedTracks?.items) {
        const trackIndex = savedTracks.items.findIndex(
          (item) => item.track && item.track.id === track.id,
        );

        if (trackIndex !== -1) {
          console.log(
            `[PlaybackControl] Playing track from library at index ${trackIndex}`,
          );

          // Set the next track if available
          const nextIndex = trackIndex + 1;
          if (
            nextIndex < savedTracks.items.length &&
            savedTracks.items[nextIndex]?.track
          ) {
            const nextTrack = savedTracks.items[nextIndex].track;
            console.log(
              `[PlaybackControl] Setting next track: ${nextTrack?.name}`,
            );
            setNextTrack(nextTrack);
          } else {
            console.log("[PlaybackControl] No next track available");
            setNextTrack(null);
          }
        }
      }

      // Call the player's handlePlay function
      await playerHandlePlay(track);
    },
    [savedTracks, setNowPlayingTrack, setNextTrack, playerHandlePlay],
  );

  return { handlePlay };
}

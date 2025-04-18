import {
  createContext,
  useContext,
  useState,
  ReactNode,
  useEffect,
  useRef,
} from "react";
import { spotify, session } from "@wailsjs/go/models";
import {
  ProvideSuggestionFeedback,
  RequestNewSuggestion,
  SaveTrack,
} from "@wailsjs/go/bindings/Music";
import { useSnackbar } from "notistack";
import { usePlayer } from "@/components/music/player/PlayerContext";
import { useSuggestionCache } from "@/hooks/useSuggestionCache";
import { MediaSuggestionItem } from "@/components/common/MediaSuggestionDisplay";
import { SuggestionCache } from "@/utils/suggestionCache";

interface SuggestionContextType {
  suggestedTrack: spotify.SuggestedTrackInfo | null;
  suggestionError: string | null;
  suggestionContext: string | null;
  currentSuggestionOutcome: session.Outcome;
  hasLikedCurrentSuggestion: boolean;
  hasAddedCurrentSuggestion: boolean;
  isProcessingLibrary: boolean;
  isFetchingSuggestion: boolean;
  handleRequestSuggestion: () => Promise<void>;
  handleSkipSuggestion: () => Promise<void>;
  handleSuggestionFeedback: (feedbackType: "like" | "dislike") => Promise<void>;
  handleAddToLibrary: () => Promise<void>;
}

const SuggestionContext = createContext<SuggestionContextType | undefined>(
  undefined,
);

interface SuggestionProviderProps {
  children: ReactNode;
}

interface SuggestionState {
  outcome: session.Outcome;
  hasLiked: boolean;
  hasAdded: boolean;
  isProcessing: boolean;
}

// Helper to convert SuggestedTrackInfo to MediaSuggestionItem for caching
const mapTrackToMediaItem = (
  track: spotify.SuggestedTrackInfo,
): MediaSuggestionItem => {
  console.log("[SuggestionContext] Converting track to MediaItem:", track);

  if (!track) {
    console.error(
      "[SuggestionContext] Cannot map null track to MediaSuggestionItem",
    );
    return {
      id: "",
      title: "",
    };
  }

  const item: MediaSuggestionItem = {
    id: track.id || "",
    title: track.name || "",
    artist: track.artist || "",
    description: track.album || "",
    imageUrl: track.albumArtUrl || "",
    playUrl: track.previewUrl || "", // Save the preview URL for playback
    uri: track.uri || "", // Save the Spotify URI
  };

  console.log("[SuggestionContext] Converted to MediaItem:", item);
  return item;
};

// Helper to convert MediaSuggestionItem back to spotify.SuggestedTrackInfo
const mapMediaItemToTrack = (
  item: MediaSuggestionItem,
): spotify.SuggestedTrackInfo => {
  if (!item) {
    console.error(
      "[SuggestionContext] Cannot map null MediaSuggestionItem to Spotify track",
    );
    return {
      id: "",
      name: "",
      artist: "",
      album: "",
      albumArtUrl: "",
      reason: "",
    };
  }

  console.log(
    "[SuggestionContext] Converting MediaSuggestionItem to Spotify track:",
    item,
  );

  const track: spotify.SuggestedTrackInfo = {
    id: String(item.id) || "",
    name: item.title || "",
    artist: item.artist || "",
    album: item.description || "",
    albumArtUrl: item.imageUrl || "",
    previewUrl: item.playUrl || "", // Restore the preview URL
    uri: item.uri || "", // Restore the Spotify URI
    reason: "", // Will be set from the cached reason
  };

  console.log("[SuggestionContext] Converted to Spotify track:", track);
  return track;
};

// Helper function to parse error objects consistently
const parseErrorMessage = (
  error: any,
  defaultMessage: string = "An error occurred",
): string => {
  if (typeof error === "string") {
    return error;
  } else if (error?.error) {
    if (typeof error.error === "string") {
      return error.error;
    } else if (error.error?.message) {
      return error.error.message;
    }
  } else if (error?.message) {
    return error.message;
  }
  return defaultMessage;
};

export function SuggestionProvider({
  children,
}: SuggestionProviderProps): JSX.Element {
  const { enqueueSnackbar } = useSnackbar();
  const { stopPlayback, nowPlayingTrack } = usePlayer();

  // Use the suggestion cache hook for music media type
  const {
    cachedItem,
    cachedReason,
    isValidating,
    saveSuggestion,
    clearSuggestion,
  } = useSuggestionCache("music");

  const [suggestedTrack, setSuggestedTrack] =
    useState<spotify.SuggestedTrackInfo | null>(null);
  const [suggestionError, setSuggestionError] = useState<string | null>(null);
  const [suggestionContext, setSuggestionContext] = useState<string | null>(
    null,
  );
  const [suggestionState, setSuggestionState] = useState<SuggestionState>({
    outcome: session.Outcome.pending,
    hasLiked: false,
    hasAdded: false,
    isProcessing: false,
  });
  const [isFetchingSuggestion, setIsFetchingSuggestion] = useState(false);
  const hasRequestedInitial = useRef(false);
  const isRequestInProgress = useRef(false);

  // Set suggested track from cache when available
  useEffect(() => {
    console.log("[SuggestionCache] Checking cache:", {
      cachedItem: cachedItem ? JSON.stringify(cachedItem) : "null",
      cachedReason,
    });
    if (cachedItem && cachedReason && !suggestedTrack) {
      console.log(
        "[SuggestionCache] Restoring from cache, checking playback URLs:",
        {
          playUrl: cachedItem.playUrl,
          uri: cachedItem.uri,
        },
      );
      const track = mapMediaItemToTrack(cachedItem);
      track.reason = cachedReason;
      console.log(
        "[SuggestionCache] Track after mapping, checking playback URLs:",
        {
          previewUrl: track.previewUrl,
          uri: track.uri,
        },
      );
      setSuggestedTrack(track);
      setSuggestionContext(cachedReason);
      setSuggestionState((prev) => ({
        ...prev,
        hasLiked: false,
        hasAdded: false,
        outcome: session.Outcome.pending,
      }));
      console.log("[SuggestionCache] Restored track:", JSON.stringify(track));

      // Mark as having requested initial suggestion to prevent the other effect from triggering
      hasRequestedInitial.current = true;
    }
  }, [cachedItem, cachedReason, suggestedTrack]);

  // Check if suggestedTrack state was properly updated
  useEffect(() => {
    console.log(
      "[SuggestionContext] Current suggestedTrack state:",
      suggestedTrack ? JSON.stringify(suggestedTrack) : "null",
    );
  }, [suggestedTrack]);

  // Only request an initial suggestion if we don't have one cached
  // This needs to run AFTER the cache effect
  useEffect(() => {
    // Wait until we know if there's a cached item
    if (!hasRequestedInitial.current && cachedItem !== null) {
      hasRequestedInitial.current = true;

      // If there's cached data, use that; otherwise request new suggestion
      if (cachedItem && cachedReason) {
        console.log(
          "[SuggestionContext] Using cached suggestion instead of requesting new one",
        );
        // We'll let the other useEffect handle setting the suggestion from cache
      } else {
        console.log(
          "[SuggestionContext] No cached suggestion found, requesting new one",
        );
        handleRequestSuggestion();
      }
    }
  }, [cachedItem, cachedReason]);

  const handleToast = (
    message: string,
    variant: "success" | "error" | "warning" | "info" | "skip",
  ) => {
    // Truncate long toast messages more aggressively
    const truncatedMessage =
      message.length > 200 ? message.substring(0, 200) + "..." : message;

    enqueueSnackbar(truncatedMessage, {
      variant: variant as any,
      anchorOrigin: {
        vertical: "top",
        horizontal: "center",
      },
    });
  };

  const handleRequestSuggestion = async () => {
    if (suggestionState.isProcessing || isRequestInProgress.current) {
      console.log("Skipping suggestion request - already processing");
      return;
    }

    try {
      isRequestInProgress.current = true;
      setIsFetchingSuggestion(true);
      setSuggestionError(null);
      setSuggestionState((prev) => ({ ...prev, isProcessing: true }));
      const suggestion = await RequestNewSuggestion();
      if (suggestion) {
        console.log(
          "[SuggestionContext] Received new suggestion:",
          JSON.stringify(suggestion),
        );
        setSuggestedTrack(suggestion);
        setSuggestionContext(suggestion.reason || null);
        setSuggestionState((prev) => ({
          ...prev,
          outcome: session.Outcome.pending,
          hasLiked: false,
          hasAdded: false,
        }));

        // Cache the suggestion only if it has all required data
        if (
          suggestion &&
          suggestion.reason &&
          suggestion.id &&
          suggestion.name &&
          suggestion.artist
        ) {
          const mediaItem = mapTrackToMediaItem(suggestion);
          console.log("[SuggestionCache] Saving to cache:", {
            mediaItem: JSON.stringify(mediaItem),
            reason: suggestion.reason,
          });
          saveSuggestion(mediaItem, suggestion.reason);

          // Verify the suggestion was cached properly
          setTimeout(() => {
            const cached = SuggestionCache.getItem("music");
            console.log(
              "[SuggestionCache] Verification of cached item after save:",
              {
                cachedItem: cached.item ? JSON.stringify(cached.item) : null,
                cachedReason: cached.reason,
              },
            );
          }, 100);
        } else {
          console.log(
            "[SuggestionCache] Not caching suggestion - missing required data",
          );
        }
      }
    } catch (error: any) {
      console.error("Error requesting suggestion:", error);
      const errorMessage = parseErrorMessage(error, "Failed to get suggestion");

      // Clear any cached suggestion on error
      clearSuggestion();
      console.log("[SuggestionCache] Cleared cache due to suggestion error");

      // Store full error message in suggestionError for display
      setSuggestionError(errorMessage);

      // Use truncated message for toast
      handleToast(errorMessage, "error");
    } finally {
      isRequestInProgress.current = false;
      setIsFetchingSuggestion(false);
      setSuggestionState((prev) => ({ ...prev, isProcessing: false }));
    }
  };

  const handleSkipSuggestion = async () => {
    if (!suggestedTrack || suggestionState.isProcessing) return;

    try {
      // Store track info before clearing the state
      const trackToSkip = {
        name: suggestedTrack.name,
        artist: suggestedTrack.artist,
        album: suggestedTrack.album,
      };

      // Mark as processing first
      setSuggestionState((prev) => ({ ...prev, isProcessing: true }));

      // Check if the track has already been liked or added
      if (!suggestionState.hasLiked && !suggestionState.hasAdded) {
        await ProvideSuggestionFeedback(
          session.Outcome.skipped,
          trackToSkip.name,
          trackToSkip.artist,
          trackToSkip.album,
        );

        setSuggestionState((prev) => ({
          ...prev,
          outcome: session.Outcome.skipped,
        }));

        const message = `Skipped "${trackToSkip.name}"`;
        enqueueSnackbar(message, { variant: "skip" as any });
      }

      setSuggestedTrack(null);
      clearSuggestion();

      await stopPlayback();

      window.scrollTo({ top: 0, behavior: "smooth" });
      await handleRequestSuggestion();
    } catch (error: any) {
      console.error("Error skipping suggestion:", error);
      const errorMessage = parseErrorMessage(error, "Failed to skip track");

      setSuggestionState((prev) => ({
        ...prev,
        outcome: session.Outcome.pending,
      }));
      setSuggestionError(errorMessage);
      handleToast(errorMessage, "error");
    } finally {
      setSuggestionState((prev) => ({ ...prev, isProcessing: false }));
    }
  };

  const handleSuggestionFeedback = async (feedbackType: "like" | "dislike") => {
    if (!suggestedTrack || suggestionState.isProcessing) return;

    try {
      const outcome =
        feedbackType === "like"
          ? session.Outcome.liked
          : session.Outcome.disliked;

      // Send feedback to backend first
      await ProvideSuggestionFeedback(
        outcome,
        suggestedTrack.name,
        suggestedTrack.artist,
        suggestedTrack.album,
      );

      // Update UI state after successful backend call
      if (feedbackType === "like") {
        setSuggestionState((prev) => ({
          ...prev,
          outcome: outcome,
          hasLiked: true,
        }));
        handleToast("Like recorded", "success");

        // Keep the liked song in cache - we might want to see it again
      } else {
        setSuggestionState((prev) => ({ ...prev, isProcessing: true }));

        // Clear the cached suggestion on dislike - we definitely don't want to see it again
        console.log(
          "[SuggestionCache] Clearing cache due to disliked suggestion",
        );
        clearSuggestion();

        // Important: Make sure we clear the current track before stopping playback
        const currentTrack = suggestedTrack;
        setSuggestedTrack(null);

        // Only stop playback if the disliked track is currently playing
        const isCurrentlyPlaying = nowPlayingTrack?.id === suggestedTrack.id;
        if (isCurrentlyPlaying) {
          console.log(
            "Stopping playback after disliking currently playing track",
          );
          await stopPlayback();
        } else {
          console.log(
            "Disliked track is not currently playing, not stopping playback",
          );
        }

        // Only update state after potentially stopping playback
        setSuggestionState((prev) => ({
          ...prev,
          outcome: outcome,
          hasAdded: false,
        }));
        handleToast("Dislike recorded", "error");

        // Short delay before requesting a new suggestion
        window.scrollTo({ top: 0, behavior: "smooth" });

        // Add a small delay to ensure playback state is fully updated
        setTimeout(async () => {
          try {
            await handleRequestSuggestion();
          } finally {
            // Make sure to always reset processing state
            setSuggestionState((prev) => ({ ...prev, isProcessing: false }));
          }
        }, 1000);

        return; // Exit early since we're handling cleanup in setTimeout
      }
    } catch (error) {
      console.error("Error providing suggestion feedback:", error);
      const errorMessage = parseErrorMessage(
        error,
        "Failed to record feedback",
      );

      handleToast(errorMessage, "error");
      setSuggestionState((prev) => ({
        ...prev,
        outcome: session.Outcome.pending,
        hasLiked: false,
        hasAdded: false,
      }));
    } finally {
      if (feedbackType === "dislike") {
        // Only set processing to false for "like" case
        // For "dislike", we handle it in the setTimeout above
        if (feedbackType !== "dislike") {
          setSuggestionState((prev) => ({ ...prev, isProcessing: false }));
        }
      }
    }
  };

  const handleAddToLibrary = async () => {
    if (!suggestedTrack || suggestionState.isProcessing) return;

    try {
      setSuggestionState((prev) => ({ ...prev, isProcessing: true }));

      // SaveTrack only takes a track ID
      await SaveTrack(suggestedTrack.id);

      // After successfully saving, update feedback record
      await ProvideSuggestionFeedback(
        session.Outcome.added,
        suggestedTrack.name,
        suggestedTrack.artist,
        suggestedTrack.album,
      );

      setSuggestionState((prev) => ({
        ...prev,
        outcome: session.Outcome.added,
        hasAdded: true,
      }));

      // Clear the cached suggestion after adding to library
      // We don't need to see it again as a suggestion since it's now in the library
      console.log(
        "[SuggestionCache] Clearing cache after adding track to library",
      );
      clearSuggestion();

      handleToast(
        `Added "${suggestedTrack.name}" by ${suggestedTrack.artist} to your library`,
        "success",
      );

      // Get a new recommendation after adding to library
      const currentTrack = suggestedTrack;
      setSuggestedTrack(null);
      await handleRequestSuggestion();
    } catch (error: any) {
      console.error("Error adding to library:", error);
      const errorMessage = parseErrorMessage(
        error,
        "Failed to add track to library",
      );

      // Store full error message in suggestionError for display
      setSuggestionError(errorMessage);

      // Toast will use truncated message from handleToast function
      handleToast(errorMessage, "error");

      // Don't clear the cache on error - the user might want to try again
    } finally {
      setSuggestionState((prev) => ({ ...prev, isProcessing: false }));
    }
  };

  const value: SuggestionContextType = {
    suggestedTrack,
    suggestionError,
    suggestionContext,
    currentSuggestionOutcome: suggestionState.outcome,
    hasLikedCurrentSuggestion: suggestionState.hasLiked,
    hasAddedCurrentSuggestion: suggestionState.hasAdded,
    isProcessingLibrary: suggestionState.isProcessing,
    isFetchingSuggestion: isFetchingSuggestion || isValidating,
    handleRequestSuggestion,
    handleSkipSuggestion,
    handleSuggestionFeedback,
    handleAddToLibrary,
  };

  return (
    <SuggestionContext.Provider
      value={{
        suggestedTrack,
        suggestionError,
        suggestionContext,
        currentSuggestionOutcome: suggestionState.outcome,
        hasLikedCurrentSuggestion: suggestionState.hasLiked,
        hasAddedCurrentSuggestion: suggestionState.hasAdded,
        isProcessingLibrary: suggestionState.isProcessing,
        isFetchingSuggestion: isFetchingSuggestion || isValidating,
        handleRequestSuggestion,
        handleSkipSuggestion,
        handleSuggestionFeedback,
        handleAddToLibrary,
      }}
    >
      {children}
    </SuggestionContext.Provider>
  );
}

export function useSuggestion() {
  const context = useContext(SuggestionContext);
  if (context === undefined) {
    throw new Error("useSuggestion must be used within a SuggestionProvider");
  }
  return context;
}

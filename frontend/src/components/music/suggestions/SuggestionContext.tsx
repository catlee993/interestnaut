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

export function SuggestionProvider({
  children,
}: SuggestionProviderProps): JSX.Element {
  const { enqueueSnackbar } = useSnackbar();
  const { stopPlayback } = usePlayer();
  const [suggestedTrack, setSuggestedTrack] =
    useState<spotify.SuggestedTrackInfo | null>(null);
  const [suggestionError, setSuggestionError] = useState<string | null>(null);
  const [suggestionContext, setSuggestionContext] = useState<string | null>(null);
  const [suggestionState, setSuggestionState] = useState<SuggestionState>({
    outcome: session.Outcome.pending,
    hasLiked: false,
    hasAdded: false,
    isProcessing: false,
  });
  const [isFetchingSuggestion, setIsFetchingSuggestion] = useState(false);
  const hasRequestedInitial = useRef(false);
  const isRequestInProgress = useRef(false);

  const handleToast = (
    message: string,
    variant: "success" | "error" | "warning" | "info",
  ) => {
    enqueueSnackbar(message, {
      variant,
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
      setSuggestionState(prev => ({ ...prev, isProcessing: true }));
      const suggestion = await RequestNewSuggestion();
      if (suggestion) {
        setSuggestedTrack(suggestion);
        setSuggestionContext(suggestion.reason || null);
        setSuggestionState(prev => ({ ...prev, outcome: session.Outcome.pending }));
      }
    } catch (error: any) {
      console.error("Error requesting suggestion:", error);
      let errorMessage = "Failed to get suggestion";

      // Parse the error message
      if (typeof error === "string") {
        errorMessage = error;
      } else if (error?.error) {
        if (typeof error.error === "string") {
          errorMessage = error.error;
        } else if (error.error?.message) {
          errorMessage = error.error.message;
        }
      } else if (error?.message) {
        errorMessage = error.message;
      }

      setSuggestionError(errorMessage);
      handleToast(errorMessage, "error");
    } finally {
      isRequestInProgress.current = false;
      setIsFetchingSuggestion(false);
      setSuggestionState(prev => ({ ...prev, isProcessing: false }));
    }
  };

  useEffect(() => {
    if (!hasRequestedInitial.current) {
      hasRequestedInitial.current = true;
      handleRequestSuggestion();
    }
  }, []);

  const handleSkipSuggestion = async () => {
    if (!suggestedTrack || suggestionState.isProcessing) return;

    try {
      setSuggestionState(prev => ({ ...prev, isProcessing: true }));
      setSuggestedTrack(null);

      // Only send skip feedback if the track hasn't been liked or added
      if (!suggestionState.hasLiked && !suggestionState.hasAdded) {
        await ProvideSuggestionFeedback(
          session.Outcome.skipped,
          suggestedTrack.name,
          suggestedTrack.artist,
          suggestedTrack.album,
        );

        setSuggestionState(prev => ({ ...prev, outcome: session.Outcome.skipped }));
        handleToast("Skipped suggestion", "warning");
      }

      // Stop playback when skipping
      await stopPlayback();
      window.scrollTo({ top: 0, behavior: "smooth" });
      await handleRequestSuggestion();
    } catch (error: any) {
      console.error("Error skipping suggestion:", error);
      let errorMessage = "Failed to skip track";
      if (error?.error) {
        if (typeof error.error === "string") {
          errorMessage = error.error;
        } else if (error.error?.message) {
          errorMessage = error.error.message;
        }
      } else if (error?.message) {
        errorMessage = error.message;
      }
      setSuggestionState(prev => ({ ...prev, outcome: session.Outcome.pending }));
      setSuggestionError(errorMessage);
      handleToast(errorMessage, "error");
    } finally {
      setSuggestionState(prev => ({ ...prev, isProcessing: false }));
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
        setSuggestionState(prev => ({ ...prev, outcome: outcome, hasLiked: true }));
        handleToast("Like recorded", "success");
      } else {
        setSuggestionState(prev => ({ ...prev, isProcessing: true }));
        setSuggestedTrack(null);
        setSuggestionState(prev => ({ ...prev, outcome: outcome, hasAdded: false }));
        handleToast("Dislike recorded", "error");
        // Stop playback when disliking
        await stopPlayback();
        window.scrollTo({ top: 0, behavior: "smooth" });
        await handleRequestSuggestion();
      }
    } catch (error) {
      console.error("Error providing suggestion feedback:", error);
      handleToast("Failed to record feedback", "error");
      setSuggestionState(prev => ({ ...prev, outcome: session.Outcome.pending, hasLiked: false, hasAdded: false }));
    } finally {
      if (feedbackType === "dislike") {
        setSuggestionState(prev => ({ ...prev, isProcessing: false }));
      }
    }
  };

  const handleAddToLibrary = async () => {
    if (!suggestedTrack || suggestionState.isProcessing) return;

    try {
      setSuggestionState(prev => ({ ...prev, isProcessing: true }));

      // First save the track to Spotify library
      await SaveTrack(suggestedTrack.id);

      setSuggestionState({
        outcome: session.Outcome.added,
        hasLiked: true,
        hasAdded: true,
        isProcessing: false,
      });

      await ProvideSuggestionFeedback(
        session.Outcome.added,
        suggestedTrack.name,
        suggestedTrack.artist,
        suggestedTrack.album,
      );

      handleToast("Added to library", "success");

      // Reload the likes after adding to library
      await handleRequestSuggestion();

      // Trigger a refresh of saved tracks
      const event = new CustomEvent("refreshSavedTracks");
      window.dispatchEvent(event);
    } catch (error: any) {
      console.error("Error adding to library:", error);
      let errorMessage = "Failed to add to library";
      if (error?.error) {
        if (typeof error.error === "string") {
          errorMessage = error.error;
        } else if (error.error?.message) {
          errorMessage = error.error.message;
        }
      } else if (error?.message) {
        errorMessage = error.message;
      }
      setSuggestionState({
        outcome: session.Outcome.pending,
        hasLiked: false,
        hasAdded: false,
        isProcessing: false,
      });
      setSuggestionError(errorMessage);
      handleToast(errorMessage, "error");
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
    isFetchingSuggestion,
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
        isFetchingSuggestion,
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

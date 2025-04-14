import {
  createContext,
  useContext,
  useState,
  ReactNode,
  useEffect,
  useRef,
} from "react";
import { spotify } from "../../../../wailsjs/go/models";
import { session } from "../../../../wailsjs/go/models";
import {
  ProvideSuggestionFeedback,
  RequestNewSuggestion,
  SaveTrack,
} from "../../../../wailsjs/go/bindings/Music";
import { useSnackbar } from "notistack";

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

export function SuggestionProvider({
  children,
}: SuggestionProviderProps): JSX.Element {
  const { enqueueSnackbar } = useSnackbar();
  const [suggestedTrack, setSuggestedTrack] =
    useState<spotify.SuggestedTrackInfo | null>(null);
  const [suggestionError, setSuggestionError] = useState<string | null>(null);
  const [suggestionContext, setSuggestionContext] = useState<string | null>(
    null,
  );
  const [currentSuggestionOutcome, setCurrentSuggestionOutcome] =
    useState<session.Outcome>(session.Outcome.pending);
  const [hasLikedCurrentSuggestion, setHasLikedCurrentSuggestion] =
    useState(false);
  const [hasAddedCurrentSuggestion, setHasAddedCurrentSuggestion] =
    useState(false);
  const [isProcessingLibrary, setIsProcessingLibrary] = useState(false);
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
    if (isProcessingLibrary || isRequestInProgress.current) {
      console.log("Skipping suggestion request - already processing");
      return;
    }

    try {
      isRequestInProgress.current = true;
      setIsFetchingSuggestion(true);
      setSuggestionError(null);
      setIsProcessingLibrary(true);
      const suggestion = await RequestNewSuggestion();
      if (suggestion) {
        setSuggestedTrack(suggestion);
        setSuggestionContext(suggestion.reason || null);
        setCurrentSuggestionOutcome(session.Outcome.pending);
        setHasLikedCurrentSuggestion(false);
        setHasAddedCurrentSuggestion(false);
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
      setIsProcessingLibrary(false);
    }
  };

  useEffect(() => {
    if (!hasRequestedInitial.current) {
      hasRequestedInitial.current = true;
      handleRequestSuggestion();
    }
  }, []);

  const handleSkipSuggestion = async () => {
    if (!suggestedTrack || isProcessingLibrary) return;

    try {
      setIsProcessingLibrary(true);
      setSuggestedTrack(null);

      // Only send skip feedback if the track hasn't been liked or added
      if (!hasLikedCurrentSuggestion && !hasAddedCurrentSuggestion) {
        await ProvideSuggestionFeedback(
          session.Outcome.skipped,
          suggestedTrack.name,
          suggestedTrack.artist,
          suggestedTrack.album,
        );

        setCurrentSuggestionOutcome(session.Outcome.skipped);
        handleToast("Skipped suggestion", "warning");
      }

      window.scrollTo({ top: 0, behavior: 'smooth' });
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
      setCurrentSuggestionOutcome(session.Outcome.pending);
      setSuggestionError(errorMessage);
      handleToast(errorMessage, "error");
    } finally {
      setIsProcessingLibrary(false);
    }
  };

  const handleSuggestionFeedback = async (feedbackType: "like" | "dislike") => {
    if (!suggestedTrack || isProcessingLibrary) return;

    try {
      setIsProcessingLibrary(true);
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
      setCurrentSuggestionOutcome(outcome);
      if (feedbackType === "like") {
        setHasLikedCurrentSuggestion(true);
        handleToast("Like recorded", "success");
      } else {
        setSuggestedTrack(null);
        handleToast("Dislike recorded", "error");
        window.scrollTo({ top: 0, behavior: 'smooth' });
        await handleRequestSuggestion();
      }
    } catch (error) {
      console.error("Error providing suggestion feedback:", error);
      handleToast("Failed to record feedback", "error");
      setCurrentSuggestionOutcome(session.Outcome.pending);
      setHasLikedCurrentSuggestion(false);
      setHasAddedCurrentSuggestion(false);
    } finally {
      setIsProcessingLibrary(false);
    }
  };

  const handleAddToLibrary = async () => {
    if (!suggestedTrack || isProcessingLibrary) return;

    try {
      setIsProcessingLibrary(true);

      // First save the track to Spotify library
      await SaveTrack(suggestedTrack.id);

      setCurrentSuggestionOutcome(session.Outcome.added);
      setHasAddedCurrentSuggestion(true);
      setHasLikedCurrentSuggestion(true); // Adding to library implies liking

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
      const event = new CustomEvent('refreshSavedTracks');
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
      setCurrentSuggestionOutcome(session.Outcome.pending);
      setHasAddedCurrentSuggestion(false);
      setHasLikedCurrentSuggestion(false);
      setSuggestionError(errorMessage);
      handleToast(errorMessage, "error");
    } finally {
      setIsProcessingLibrary(false);
    }
  };

  const value: SuggestionContextType = {
    suggestedTrack,
    suggestionError,
    suggestionContext,
    currentSuggestionOutcome,
    hasLikedCurrentSuggestion,
    hasAddedCurrentSuggestion,
    isProcessingLibrary,
    isFetchingSuggestion,
    handleRequestSuggestion,
    handleSkipSuggestion,
    handleSuggestionFeedback,
    handleAddToLibrary,
  };

  return (
    <SuggestionContext.Provider value={value}>
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

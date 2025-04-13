import {
  createContext,
  useContext,
  useState,
  ReactNode,
  useEffect,
  useRef,
} from "react";
import { spotify } from "../../wailsjs/go/models";
import { session } from "../../wailsjs/go/models";
import {
  ProvideSuggestionFeedback,
  RequestNewSuggestion,
} from "../../wailsjs/go/bindings/Music";
import { useSnackbar } from 'notistack';
import { Box, Typography, Stack, Button, Card, CardContent, CardMedia, CircularProgress } from "@mui/material";
import { PlayArrow, SkipNext, ThumbUp, ThumbDown, Add } from '@mui/icons-material';

interface SuggestionContextType {
  suggestedTrack: spotify.SuggestedTrackInfo | null;
  suggestionError: string | null;
  suggestionContext: string | null;
  currentSuggestionOutcome: session.Outcome;
  hasLikedCurrentSuggestion: boolean;
  isProcessingLibrary: boolean;
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
  const [isProcessingLibrary, setIsProcessingLibrary] = useState(false);
  const hasRequestedInitial = useRef(false);

  const handleToast = (message: string, variant: 'success' | 'error' | 'warning' | 'info') => {
    enqueueSnackbar(message, { 
      variant,
      anchorOrigin: {
        vertical: 'bottom',
        horizontal: 'center',
      },
    });
  };

  const handleRequestSuggestion = async () => {
    if (isProcessingLibrary) {
      console.log("Skipping suggestion request - already processing");
      return;
    }
    
    try {
      setSuggestionError(null);
      setIsProcessingLibrary(true);
      const suggestion = await RequestNewSuggestion();
      if (suggestion) {
        setSuggestedTrack(suggestion);
        setSuggestionContext(suggestion.reason || null);
        setCurrentSuggestionOutcome(session.Outcome.pending);
        setHasLikedCurrentSuggestion(false);
      }
    } catch (error: any) {
      console.error("Error requesting suggestion:", error);
      let errorMessage = "Failed to get suggestion";
      if (error?.error) {
        if (typeof error.error === 'string') {
          errorMessage = error.error;
        } else if (error.error?.message) {
          errorMessage = error.error.message;
        }
      } else if (error?.message) {
        errorMessage = error.message;
      }
      setSuggestionError(errorMessage);
      setSuggestedTrack(null);
      handleToast(errorMessage, 'error');
    } finally {
      setIsProcessingLibrary(false);
    }
  };

  useEffect(() => {
    if (!hasRequestedInitial.current && !suggestedTrack && !isProcessingLibrary) {
      hasRequestedInitial.current = true;
      handleRequestSuggestion();
    }
  }, [suggestedTrack, isProcessingLibrary]);

  const handleSkipSuggestion = async () => {
    if (!suggestedTrack || isProcessingLibrary) return;

    try {
      setIsProcessingLibrary(true);
      
      setCurrentSuggestionOutcome(session.Outcome.skipped);
      
      await ProvideSuggestionFeedback(
        session.Outcome.skipped,
        suggestedTrack.name,
        suggestedTrack.artist,
        suggestedTrack.album,
      );

      handleToast("Skipped suggestion", 'warning');

      await handleRequestSuggestion();
    } catch (error: any) {
      console.error("Error skipping suggestion:", error);
      let errorMessage = "Failed to skip track";
      if (error?.error) {
        if (typeof error.error === 'string') {
          errorMessage = error.error;
        } else if (error.error?.message) {
          errorMessage = error.error.message;
        }
      } else if (error?.message) {
        errorMessage = error.message;
      }
      setCurrentSuggestionOutcome(session.Outcome.pending);
      setSuggestionError(errorMessage);
      handleToast(errorMessage, 'error');
    } finally {
      setIsProcessingLibrary(false);
    }
  };

  const handleSuggestionFeedback = async (feedbackType: "like" | "dislike") => {
    if (!suggestedTrack || isProcessingLibrary) return;

    try {
      setIsProcessingLibrary(true);
      const outcome = feedbackType === "like" ? session.Outcome.liked : session.Outcome.disliked;

      await ProvideSuggestionFeedback(
        outcome,
        suggestedTrack.name,
        suggestedTrack.artist,
        suggestedTrack.album
      );

      enqueueSnackbar(
        feedbackType === "like"
          ? "Thanks for the feedback! We'll use this to improve your suggestions."
          : "Got it - we'll avoid similar songs in the future.",
        { 
          variant: feedbackType === "like" ? "success" : "error",
          autoHideDuration: 3000
        }
      );

      if (feedbackType === "like") {
        setHasLikedCurrentSuggestion(true);
      }
      setCurrentSuggestionOutcome(outcome);
      
      // Request a new suggestion after feedback
      handleRequestSuggestion();
    } catch (error) {
      console.error("Error providing suggestion feedback:", error);
      enqueueSnackbar("Failed to save your feedback", { variant: "error" });
    } finally {
      setIsProcessingLibrary(false);
    }
  };

  const handleAddToLibrary = async () => {
    if (!suggestedTrack || isProcessingLibrary) return;

    try {
      setIsProcessingLibrary(true);
      
      setCurrentSuggestionOutcome(session.Outcome.added);
      setHasLikedCurrentSuggestion(true);
      
      await ProvideSuggestionFeedback(
        session.Outcome.added,
        suggestedTrack.name,
        suggestedTrack.artist,
        suggestedTrack.album,
      );

      handleToast("Added to library", 'success');
    } catch (error: any) {
      console.error("Error adding to library:", error);
      let errorMessage = "Failed to add to library";
      if (error?.error) {
        if (typeof error.error === 'string') {
          errorMessage = error.error;
        } else if (error.error?.message) {
          errorMessage = error.error.message;
        }
      } else if (error?.message) {
        errorMessage = error.message;
      }
      setCurrentSuggestionOutcome(session.Outcome.pending);
      setHasLikedCurrentSuggestion(false);
      setSuggestionError(errorMessage);
      handleToast(errorMessage, 'error');
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
    isProcessingLibrary,
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

import { createContext, useContext, useState, ReactNode, useEffect, useRef } from "react";
import { spotify } from "../../wailsjs/go/models";
import { session } from "../../wailsjs/go/models";
import {
  ProvideSuggestionFeedback,
  RequestNewSuggestion,
} from "../../wailsjs/go/bindings/Music";
import { useToast } from "@/hooks/useToast";

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
  const { showToast } = useToast();
  const [suggestedTrack, setSuggestedTrack] =
    useState<spotify.SuggestedTrackInfo | null>(null);
  const [suggestionError, setSuggestionError] = useState<string | null>(null);
  const [suggestionContext, setSuggestionContext] = useState<string | null>(null);
  const [currentSuggestionOutcome, setCurrentSuggestionOutcome] =
    useState<session.Outcome>(session.Outcome.pending);
  const [hasLikedCurrentSuggestion, setHasLikedCurrentSuggestion] =
    useState(false);
  const [isProcessingLibrary, setIsProcessingLibrary] = useState(false);
  const hasRequestedInitial = useRef(false);

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
      // Handle nested error structures
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
      showToast({ message: errorMessage, type: "error" });
    } finally {
      setIsProcessingLibrary(false);
    }
  };

  // Load initial suggestion only once
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
      
      // Set the outcome before making the API call
      setCurrentSuggestionOutcome(session.Outcome.skipped);
      
      await ProvideSuggestionFeedback(
        session.Outcome.skipped,
        suggestedTrack.name,
        suggestedTrack.artist,
        suggestedTrack.album,
      );

      showToast({ message: "Skipped suggestion", type: "skip" });

      // Only request new suggestion after successful skip
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
      // Revert the state on error
      setCurrentSuggestionOutcome(session.Outcome.pending);
      setSuggestionError(errorMessage);
      showToast({ message: errorMessage, type: "error" });
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

      // Set the outcome before making the API call
      setCurrentSuggestionOutcome(outcome);
      if (feedbackType === "like") {
        setHasLikedCurrentSuggestion(true);
      }

      await ProvideSuggestionFeedback(
        outcome,
        suggestedTrack.name,
        suggestedTrack.artist,
        suggestedTrack.album,
      );

      showToast({
        message: feedbackType === "like" ? "Liked suggestion" : "Disliked suggestion",
        type: feedbackType === "like" ? "success" : "dislike"
      });
      
      // Only request new suggestion on dislike after successful feedback
      if (feedbackType === "dislike") {
        await handleRequestSuggestion();
      }
    } catch (error: any) {
      console.error("Error providing feedback:", error);
      let errorMessage = "Failed to save feedback";
      if (error?.error) {
        if (typeof error.error === 'string') {
          errorMessage = error.error;
        } else if (error.error?.message) {
          errorMessage = error.error.message;
        }
      } else if (error?.message) {
        errorMessage = error.message;
      }
      // Revert the state changes on error
      setCurrentSuggestionOutcome(session.Outcome.pending);
      if (feedbackType === "like") {
        setHasLikedCurrentSuggestion(false);
      }
      setSuggestionError(errorMessage);
      showToast({ message: errorMessage, type: "error" });
    } finally {
      setIsProcessingLibrary(false);
    }
  };

  const handleAddToLibrary = async () => {
    if (!suggestedTrack || isProcessingLibrary) return;

    try {
      setIsProcessingLibrary(true);
      
      // Set the outcome before making the API call
      setCurrentSuggestionOutcome(session.Outcome.added);
      setHasLikedCurrentSuggestion(true);
      
      await ProvideSuggestionFeedback(
        session.Outcome.added,
        suggestedTrack.name,
        suggestedTrack.artist,
        suggestedTrack.album,
      );

      showToast({ message: "Added to library", type: "success" });
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
      // Revert the state on error
      setCurrentSuggestionOutcome(session.Outcome.pending);
      setHasLikedCurrentSuggestion(false);
      setSuggestionError(errorMessage);
      showToast({ message: errorMessage, type: "error" });
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

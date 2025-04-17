import {
  FaPause,
  FaPlay,
  FaPlus,
  FaStepForward,
  FaThumbsDown,
  FaThumbsUp,
  FaRobot,
} from "react-icons/fa";
import { useSuggestion } from "@/components/music/suggestions/SuggestionContext";
import { usePlayer } from "@/components/music/player/PlayerContext";
import {
  Box,
  Button,
  IconButton,
  styled,
  Typography,
  CircularProgress,
} from "@mui/material";
import { session } from "@wailsjs/go/models";
import { ReasonCard } from "@/components/common/ReasonCard";
import { useEffect } from "react";

const StyledButton = styled(Button)(({ theme }) => ({
  padding: "10px 20px",
  color: "white",
  border: "none",
  borderRadius: "20px",
  cursor: "pointer",
  fontWeight: 500,
  fontFamily: "var(--body-font)",
  transition: "all 0.2s",
  textTransform: "none",
  display: "flex",
  alignItems: "center",
  gap: "8px",
  height: "40px",
  "&.feedback-button": {
    backgroundColor: "rgba(0, 0, 0, 0.7)",
    border: "1px solid rgba(255, 255, 255, 0.3)",
    "&:hover:not(:disabled)": {
      backgroundColor: "rgba(0, 0, 0, 0.85)",
      border: "1px solid rgba(255, 255, 255, 0.4)",
    },
    "&:disabled": {
      backgroundColor: "rgba(0, 0, 0, 0.3)",
      border: "1px solid rgba(255, 255, 255, 0.1)",
      color: "rgba(255, 255, 255, 0.3)",
      cursor: "not-allowed",
    },
  },
  "&.action-button": {
    backgroundColor: "rgba(255, 255, 255, 0.15)",
    "&:hover:not(:disabled)": {
      backgroundColor: "rgba(255, 255, 255, 0.25)",
    },
    "&:disabled": {
      backgroundColor: "rgba(255, 255, 255, 0.05)",
      color: "rgba(255, 255, 255, 0.3)",
      cursor: "not-allowed",
    },
  },
}));

const PlayButton = styled(IconButton)(({ theme }) => ({
  backgroundColor: "var(--primary-color)",
  color: "white",
  padding: 0,
  border: "none",
  borderRadius: "50%",
  cursor: "pointer",
  transition: "all 0.2s",
  width: "40px",
  height: "40px",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  "& svg": {
    width: "20px",
    height: "20px",
  },
  "&:hover:not(:disabled)": {
    backgroundColor: "var(--primary-hover)",
  },
  "&.playing": {
    backgroundColor: "var(--primary-hover)",
  },
  "&:disabled": {
    backgroundColor: "rgba(123, 104, 238, 0.5)",
    color: "rgba(255, 255, 255, 0.3)",
    cursor: "not-allowed",
  },
}));

export const SuggestionDisplay: React.FC = () => {
  console.log('[SuggestionDisplay] Component rendering');
  
  const suggestionContext = useSuggestion();
  console.log('[SuggestionDisplay] SuggestionContext:', {
    hasSuggestedTrack: !!suggestionContext.suggestedTrack,
    hasContext: !!suggestionContext.suggestionContext,
    isLoading: suggestionContext.isFetchingSuggestion,
    hasError: !!suggestionContext.suggestionError
  });
  
  const {
    suggestedTrack,
    suggestionContext: trackReason,
    isProcessingLibrary,
    suggestionError,
    isFetchingSuggestion,
    handleRequestSuggestion,
    handleSkipSuggestion,
    handleSuggestionFeedback,
    handleAddToLibrary,
  } = suggestionContext;

  const { nowPlayingTrack, isPlaybackPaused, handlePlay, handlePlayPause } = usePlayer();

  useEffect(() => {
    console.log('[SuggestionDisplay] Current track state:', {
      suggestedTrack: suggestedTrack ? JSON.stringify(suggestedTrack) : null,
      suggestionContext,
      isLoading: isFetchingSuggestion,
      hasError: !!suggestionError,
      isProcessing: isProcessingLibrary
    });
  }, [suggestedTrack, suggestionContext, isFetchingSuggestion, suggestionError, isProcessingLibrary]);

  // Log when the component will return nothing
  useEffect(() => {
    if (!suggestedTrack && !isFetchingSuggestion && !suggestionError) {
      console.log('[SuggestionDisplay] No track, not loading, no error - will render empty state');
    }
  }, [suggestedTrack, isFetchingSuggestion, suggestionError]);

  if (isFetchingSuggestion) {
    return (
      <Box
        display="flex"
        justifyContent="center"
        alignItems="center"
        minHeight="200px"
      >
        <CircularProgress sx={{ color: "rgba(123, 104, 238, 0.7)" }} />
      </Box>
    );
  }

  if (suggestionError) {
    // Truncate very long error messages
    const truncatedError = suggestionError.length > 500 
      ? suggestionError.substring(0, 500) + "..." 
      : suggestionError;
      
    return (
      <Box className="suggestion-error-state">
        <Typography className="error-message" sx={{ 
          color: "var(--purple-red)",
          fontWeight: 500,
          fontFamily: "var(--body-font)",
          padding: "12px 16px",
          backgroundColor: "rgba(194, 59, 133, 0.1)",
          borderRadius: "8px",
          border: "1px solid rgba(194, 59, 133, 0.3)"
        }}>
          {truncatedError}
        </Typography>
        <StyledButton
          onClick={handleRequestSuggestion}
          className="retry-button"
          disabled={isProcessingLibrary}
        >
          Try Again
        </StyledButton>
      </Box>
    );
  }

  if (!suggestedTrack) {
    return (
      <Box className="empty-suggestion-state" sx={{
        display: "flex", 
        justifyContent: "center", 
        alignItems: "center", 
        minHeight: "200px"
      }}>
        <StyledButton
          onClick={handleRequestSuggestion}
          className="request-suggestion-button"
          disabled={isProcessingLibrary}
        >
          Get a Suggestion
        </StyledButton>
      </Box>
    );
  }

  return (
    <Box className="suggested-track-display">
      <Box className="suggestion-art-and-info">
        {suggestedTrack.albumArtUrl && (
          <Box
            component="img"
            src={suggestedTrack.albumArtUrl}
            alt="Suggested album art"
            className="suggested-album-art"
            sx={{
              opacity: isProcessingLibrary ? 0.5 : 1,
              border: "2px solid rgba(123, 104, 238, 0.3)",
              transition: "all 0.2s ease-in-out",
              borderColor: "rgba(123, 104, 238, 0.5)",
              borderWidth: "2px",
            }}
          />
        )}

        <Box className="suggestion-info">
          <Typography 
            variant="h4" 
            component="h4" 
            sx={{ 
              fontFamily: "var(--heading-font)", 
              fontWeight: 600 
            }}
          >
            {suggestedTrack.name}
          </Typography>
          <Typography 
            component="p" 
            sx={{ 
              fontFamily: "var(--body-font)" 
            }}
          >
            {suggestedTrack.artist}
          </Typography>
          {trackReason && (
            <Box
              sx={{
                maxWidth: "55%",
                mx: "auto",
                minWidth: "45%",
                mt: 2,
              }}
            >
              <ReasonCard reason={trackReason} />
            </Box>
          )}
        </Box>

        <Box
          className="suggestion-controls"
          sx={{
            display: "flex",
            alignItems: "center",
            gap: "10px",
            opacity: isProcessingLibrary ? 0.5 : 1,
            pointerEvents: isProcessingLibrary ? "none" : "auto",
            mt: 4,
          }}
        >
          <PlayButton
            className={`play-button ${!isPlaybackPaused && nowPlayingTrack?.id === suggestedTrack.id ? "playing" : ""}`}
            onClick={() => {
              if (!isPlaybackPaused && nowPlayingTrack?.id === suggestedTrack.id) {
                handlePlayPause();
              } else {
                handlePlay(suggestedTrack);
              }
            }}
            disabled={isProcessingLibrary}
          >
            {!isPlaybackPaused && nowPlayingTrack?.id === suggestedTrack.id ? (
              <FaPause />
            ) : (
              <FaPlay />
            )}
          </PlayButton>

          <StyledButton
            className="feedback-button like-button"
            onClick={() => handleSuggestionFeedback("like")}
            disabled={isProcessingLibrary}
          >
            <FaThumbsUp /> Like
          </StyledButton>

          <StyledButton
            className="feedback-button dislike-button"
            onClick={() => handleSuggestionFeedback("dislike")}
            disabled={isProcessingLibrary}
          >
            <FaThumbsDown /> Dislike
          </StyledButton>

          <StyledButton
            className="action-button add-button"
            onClick={handleAddToLibrary}
            disabled={isProcessingLibrary}
          >
            <FaPlus /> Add to Library
          </StyledButton>

          <StyledButton
            className="action-button next-button"
            onClick={() => {
              if (suggestedTrack) {
                handleSkipSuggestion();
              }
            }}
            disabled={isProcessingLibrary}
            aria-label={suggestionContext.hasLikedCurrentSuggestion ? "Get next suggestion" : "Skip this suggestion"}
          >
            {suggestionContext.hasLikedCurrentSuggestion ? "Next" : "Skip"} <FaStepForward />
          </StyledButton>
        </Box>
      </Box>
    </Box>
  );
};

import {
  FaPause,
  FaPlay,
  FaPlus,
  FaStepForward,
  FaThumbsDown,
  FaThumbsUp,
} from "react-icons/fa";
import { useSuggestion } from "@/components/music/suggestions/SuggestionContext";
import { usePlayer } from "@/components/music/player/PlayerContext";
import { Box, Button, IconButton, styled, Typography, CircularProgress } from "@mui/material";

const StyledButton = styled(Button)(({ theme }) => ({
  padding: "10px 20px",
  color: "white",
  border: "none",
  borderRadius: "20px",
  cursor: "pointer",
  fontWeight: 500,
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
  backgroundColor: "#4caf50",
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
    backgroundColor: "#388e3c",
  },
  "&.playing": {
    backgroundColor: "#388e3c",
  },
  "&:disabled": {
    backgroundColor: "#1b5e20",
    color: "rgba(255, 255, 255, 0.3)",
    cursor: "not-allowed",
  },
}));

export function SuggestionDisplay() {
  const {
    suggestedTrack,
    suggestionContext,
    isProcessingLibrary,
    suggestionError,
    handleSkipSuggestion,
    handleSuggestionFeedback,
    handleAddToLibrary,
    handleRequestSuggestion,
    isFetchingSuggestion,
  } = useSuggestion();

  const { nowPlayingTrack, isPlaybackPaused, handlePlay } = usePlayer();

  const LoadingDisplay = () => (
    <Box
      className="loading-indicator"
      sx={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 2,
        minHeight: "300px",
      }}
    >
      <Box className="loading-spinner"></Box>
      <Typography variant="h6" sx={{ textAlign: "center" }}>
        Finding your next song recommendation...
      </Typography>
    </Box>
  );

  if (isProcessingLibrary && suggestedTrack) {
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
                opacity: 0.3,
                filter: "grayscale(50%)",
                transition: "all 0.3s",
              }}
            />
          )}

          <Box className="suggestion-info" sx={{ opacity: 0.3 }}>
            <Typography variant="h4" component="h4">
              {suggestedTrack.name}
            </Typography>
            <Typography component="p">{suggestedTrack.artist}</Typography>
          </Box>

          <Box
            sx={{
              position: "absolute",
              top: "50%",
              left: "50%",
              transform: "translate(-50%, -50%)",
              textAlign: "center",
              zIndex: 1,
            }}
          >
            <Box
              className="loading-spinner"
              style={{ marginBottom: "16px" }}
            ></Box>
            <Typography variant="h6">Loading a new suggestion...</Typography>
          </Box>

          <Box
            className="suggestion-controls"
            sx={{
              display: "flex",
              alignItems: "center",
              gap: "10px",
              opacity: 0.3,
            }}
          >
            <PlayButton disabled>
              <FaPlay />
            </PlayButton>

            <StyledButton className="feedback-button like-button" disabled>
              <FaThumbsUp /> Like
            </StyledButton>

            <StyledButton className="feedback-button dislike-button" disabled>
              <FaThumbsDown /> Dislike
            </StyledButton>

            <StyledButton className="action-button add-button" disabled>
              <FaPlus /> Add to Library
            </StyledButton>

            <StyledButton className="action-button next-button" disabled>
              Next Suggestion <FaStepForward />
            </StyledButton>
          </Box>
        </Box>
      </Box>
    );
  }

  if (isProcessingLibrary) {
    return <LoadingDisplay />;
  }

  if (suggestionError) {
    console.log("Displaying suggestion error:", suggestionError);
    return (
      <Box className="suggestion-error-state">
        <Typography className="error-message" sx={{ color: "error.main" }}>{suggestionError}</Typography>
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

  if (isFetchingSuggestion) {
    return (
      <Box className="loading-state" sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', p: 4 }}>
        <CircularProgress size={32} sx={{ mb: 2 }} />
        <Typography variant="body1" color="text.secondary">
          Finding your next favorite song...
        </Typography>
      </Box>
    );
  }

  if (!suggestedTrack) {
    return (
      <Box className="empty-suggestion-state">
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
            sx={{ opacity: isProcessingLibrary ? 0.5 : 1 }}
          />
        )}

        <Box className="suggestion-info">
          <Typography variant="h4" component="h4">
            {suggestedTrack.name}
          </Typography>
          <Typography component="p">{suggestedTrack.artist}</Typography>
          {suggestionContext &&
            suggestionContext !==
              `${suggestedTrack.name} by ${suggestedTrack.artist}` && (
              <Typography
                variant="body1"
                color="text.secondary"
                sx={{
                  maxWidth: "800px",
                  mx: "auto",
                  textAlign: "center",
                  mb: 2,
                }}
              >
                Based on AI suggestion: "{suggestionContext}"
              </Typography>
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
          }}
        >
          <PlayButton
            className={`play-button ${!isPlaybackPaused && nowPlayingTrack?.id === suggestedTrack.id ? "playing" : ""}`}
            onClick={() => handlePlay(suggestedTrack)}
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
            onClick={handleSkipSuggestion}
            disabled={isProcessingLibrary}
          >
            Next Suggestion <FaStepForward />
          </StyledButton>
        </Box>
      </Box>
    </Box>
  );
}

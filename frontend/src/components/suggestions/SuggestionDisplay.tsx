import {
  FaPause,
  FaPlay,
  FaPlus,
  FaStepForward,
  FaThumbsDown,
  FaThumbsUp,
} from "react-icons/fa";
import { useSuggestion } from "@/contexts/SuggestionContext";
import { usePlayer } from "@/contexts/PlayerContext";
import { SaveTrack } from "../../../wailsjs/go/bindings/Music";
import { Box, Button, CircularProgress, Typography, Stack, IconButton, styled } from '@mui/material';

const StyledButton = styled(Button)(({ theme }) => ({
  padding: '10px 20px',
  color: 'white',
  border: 'none',
  borderRadius: '20px',
  cursor: 'pointer',
  fontWeight: 500,
  transition: 'background-color 0.2s',
  textTransform: 'none',
  display: 'flex',
  alignItems: 'center',
  gap: '8px',
  height: '40px',
  '&.feedback-button': {
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    border: '1px solid rgba(255, 255, 255, 0.3)',
    '&:hover': {
      backgroundColor: 'rgba(0, 0, 0, 0.85)',
      border: '1px solid rgba(255, 255, 255, 0.4)',
    }
  },
  '&.action-button': {
    backgroundColor: 'rgba(255, 255, 255, 0.15)',
    '&:hover': {
      backgroundColor: 'rgba(255, 255, 255, 0.25)',
    }
  }
}));

const PlayButton = styled(IconButton)(({ theme }) => ({
  backgroundColor: '#4caf50',
  color: 'white',
  padding: 0,
  border: 'none',
  borderRadius: '50%',
  cursor: 'pointer',
  transition: 'background-color 0.2s',
  width: '40px',
  height: '40px',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  '& svg': {
    width: '20px',
    height: '20px',
  },
  '&:hover': {
    backgroundColor: '#388e3c',
  },
  '&.playing': {
    backgroundColor: '#388e3c',
  }
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
  } = useSuggestion();

  const { nowPlayingTrack, isPlaybackPaused, handlePlay } = usePlayer();

  if (isProcessingLibrary) {
    return (
      <Box className="loading-indicator">
        <div className="loading-spinner"></div>
        <Typography>Finding your next song recommendation...</Typography>
      </Box>
    );
  }

  if (suggestionError) {
    return (
      <Box className="suggestion-error-state">
        <Typography className="error-message">{suggestionError}</Typography>
        <StyledButton onClick={handleRequestSuggestion} className="retry-button">
          Try getting a suggestion
        </StyledButton>
      </Box>
    );
  }

  if (!suggestedTrack) {
    return (
      <Box className="empty-suggestion-state">
        <StyledButton
          onClick={handleRequestSuggestion}
          className="request-suggestion-button"
        >
          Get a song suggestion
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
          />
        )}
        
        <Box className="suggestion-info">
          <Typography variant="h4" component="h4">{suggestedTrack.name}</Typography>
          <Typography component="p">{suggestedTrack.artist}</Typography>
          {suggestionContext &&
            suggestionContext !==
              `${suggestedTrack.name} by ${suggestedTrack.artist}` && (
              <Typography component="p" className="suggestion-context">
                Based on AI suggestion: "{suggestionContext}"
              </Typography>
            )}
        </Box>

        <Box className="suggestion-controls" sx={{ 
          display: 'flex', 
          alignItems: 'center',
          gap: '10px'
        }}>
          <PlayButton
            className={`play-button ${!isPlaybackPaused && nowPlayingTrack?.id === suggestedTrack.id ? "playing" : ""}`}
            onClick={() => handlePlay(suggestedTrack)}
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
          >
            <FaThumbsUp /> Like
          </StyledButton>
          
          <StyledButton
            className="feedback-button dislike-button"
            onClick={() => handleSuggestionFeedback("dislike")}
          >
            <FaThumbsDown /> Dislike
          </StyledButton>
          
          <StyledButton
            className="action-button add-button"
            onClick={handleAddToLibrary}
          >
            <FaPlus /> Add to Library
          </StyledButton>
          
          <StyledButton
            className="action-button next-button"
            onClick={handleSkipSuggestion}
          >
            Next Suggestion <FaStepForward />
          </StyledButton>
        </Box>
      </Box>
    </Box>
  );
}

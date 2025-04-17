import {
  FaThumbsDown,
  FaThumbsUp,
  FaStepForward,
  FaPlus,
} from "react-icons/fa";
import {
  Box,
  Button,
  styled,
  Typography,
  CircularProgress,
  Card,
  CardMedia,
} from "@mui/material";
import { PlaylistAdd, Favorite } from "@mui/icons-material";
import { ReasonCard } from "@/components/common/ReasonCard";

const StyledButton = styled(Button)(({ theme }) => ({
  padding: "8px 16px",
  color: "white",
  border: "none",
  borderRadius: "20px",
  cursor: "pointer",
  fontWeight: 500,
  transition: "all 0.2s",
  textTransform: "none",
  display: "flex",
  alignItems: "center",
  gap: "6px",
  height: "36px",
  fontSize: "0.875rem",
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

export interface MediaSuggestionItem {
  id: number | string;
  title: string;
  artist?: string;
  description?: string;
  imageUrl?: string;
  playUrl?: string;
  uri?: string;
  releaseDate?: string;
  rating?: number;
  voteCount?: number;
}

interface MediaSuggestionDisplayProps {
  mediaType: 'movie' | 'book' | 'podcast' | 'other'; // Keep original media types
  suggestedItem: MediaSuggestionItem | null;
  suggestionReason: string | null;
  isLoading: boolean;
  error: string | null;
  isProcessing: boolean;
  hasBeenLiked?: boolean; // Add prop to track if item has been liked
  onRequestSuggestion: () => void;
  onLike: () => void;
  onDislike: () => void;
  onSkip: () => void;
  onAddToLibrary?: () => void;
  onAddToWatchlist?: () => void;
  renderImage?: (item: MediaSuggestionItem) => React.ReactNode;
}

export const MediaSuggestionDisplay: React.FC<MediaSuggestionDisplayProps> = ({
  mediaType,
  suggestedItem,
  suggestionReason,
  isLoading,
  error,
  isProcessing,
  hasBeenLiked = false, // Default to false (not liked)
  onRequestSuggestion,
  onLike,
  onDislike,
  onSkip,
  onAddToLibrary,
  onAddToWatchlist,
  renderImage,
}) => {
  if (isLoading) {
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

  if (error) {
    // Truncate very long error messages
    const truncatedError = error.length > 500 
      ? error.substring(0, 500) + "..." 
      : error;
      
    return (
      <Box className="suggestion-error-state">
        <Typography className="error-message" sx={{ 
          color: "var(--purple-red)",
          fontWeight: 500,
          padding: "12px 16px",
          backgroundColor: "rgba(194, 59, 133, 0.1)",
          borderRadius: "8px",
          border: "1px solid rgba(194, 59, 133, 0.3)"
        }}>
          {truncatedError}
        </Typography>
        <StyledButton
          onClick={onRequestSuggestion}
          className="retry-button"
          disabled={isProcessing}
        >
          Try Again
        </StyledButton>
      </Box>
    );
  }

  if (!suggestedItem) {
    return (
      <Box className="empty-suggestion-state" sx={{
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        minHeight: "200px"
      }}>
        <StyledButton
          onClick={onRequestSuggestion}
          className="request-suggestion-button"
          disabled={isProcessing}
        >
          Get a Suggestion
        </StyledButton>
      </Box>
    );
  }

  const renderDefaultImage = () => {
    if (!suggestedItem.imageUrl) return null;
    
    return (
      <Card sx={{ height: "100%", maxWidth: "300px" }}>
        <CardMedia
          component="img"
          src={suggestedItem.imageUrl}
          alt={`${suggestedItem.title} image`}
          sx={{ 
            height: "450px", 
            objectFit: "cover",
            opacity: isProcessing ? 0.5 : 1,
            border: "2px solid rgba(123, 104, 238, 0.3)",
            transition: "all 0.2s ease-in-out",
            borderColor: "rgba(123, 104, 238, 0.5)",
            borderWidth: "2px", 
          }}
        />
      </Card>
    );
  };

  const getAddToLibraryButtonText = () => {
    switch (mediaType) {
      case 'movie':
        return 'Favorite';
      case 'book':
        return 'Reading List';
      case 'podcast':
        return 'Listen Later';
      default:
        return 'Library';
    }
  };

  return (
    <Box className="suggested-item-display">
      <Box 
        className="suggestion-container"
        sx={{
          display: "flex",
          flexDirection: { xs: "column", md: "row" },
          alignItems: { xs: "center", md: "flex-start" },
          gap: 3,
          backgroundColor: "var(--surface-color)",
          borderRadius: "var(--border-radius)",
          p: 3,
          position: "relative",
        }}
      >
        <Box 
          className="media-image-container"
          sx={{
            flexShrink: 0,
            width: { xs: "100%", md: "300px" },
            display: "flex",
            justifyContent: "center",
            position: { md: "relative" },
          }}
        >
          {renderImage ? renderImage(suggestedItem) : renderDefaultImage()}
        </Box>

        <Box className="suggestion-info" sx={{ 
          flex: 1,
          display: "flex",
          flexDirection: "column",
          minHeight: { md: "450px" },
          position: { md: "relative" },
        }}>
          <Box className="content" sx={{ flex: 1 }}>
            <Typography variant="h4" component="h4">
              {suggestedItem.title}
            </Typography>
            
            {mediaType === 'movie' && (
              <Typography variant="subtitle1" color="text.secondary" gutterBottom>
                {suggestedItem.releaseDate?.substring(0, 4) && `${suggestedItem.releaseDate.substring(0, 4)} • `}
                {suggestedItem.rating && `Rating: ${suggestedItem.rating}/10`}
                {suggestedItem.voteCount && ` (${suggestedItem.voteCount} votes)`}
              </Typography>
            )}
            
            {suggestedItem.artist && (
              <Typography variant="subtitle1" component="p">
                {suggestedItem.artist}
              </Typography>
            )}
            
            {suggestedItem.description && (
              <Typography variant="body1" sx={{ 
                mt: 2,
                maxHeight: { md: "200px" },
                overflow: "auto",
              }}>
                {suggestedItem.description}
              </Typography>
            )}

            {suggestionReason && (
              <Box sx={{ mt: 2 }}>
                <ReasonCard reason={suggestionReason} />
              </Box>
            )}
          </Box>

          <Box
            className="suggestion-controls"
            sx={{
              display: "flex",
              flexWrap: "wrap",
              alignItems: "center",
              justifyContent: "center",
              gap: { xs: "8px", md: "10px" },
              opacity: isProcessing ? 0.5 : 1,
              pointerEvents: isProcessing ? "none" : "auto",
              mt: { xs: 4, md: "auto" },
              position: { md: "absolute" },
              bottom: { md: 0 },
              left: { md: 0 },
              right: { md: 0 },
            }}
          >
            <StyledButton
              className="feedback-button like-button"
              onClick={onLike}
              disabled={isProcessing}
            >
              <FaThumbsUp /> Like
            </StyledButton>

            <StyledButton
              className="feedback-button dislike-button"
              onClick={onDislike}
              disabled={isProcessing}
            >
              <FaThumbsDown /> Dislike
            </StyledButton>

            {(onAddToWatchlist && mediaType === 'movie') && (
              <StyledButton
                className="action-button watchlist-button"
                onClick={onAddToWatchlist}
                disabled={isProcessing}
                sx={{
                  backgroundColor: "rgba(100, 181, 246, 0.8)",
                  color: "white",
                  "&:hover": {
                    backgroundColor: "rgba(100, 181, 246, 1)",
                  },
                }}
              >
                <PlaylistAdd sx={{ fontSize: "1.125rem" }} /> Watchlist
              </StyledButton>
            )}

            {(onAddToLibrary && (mediaType === 'movie' || mediaType === 'book' || mediaType === 'podcast')) && (
              <StyledButton
                className="action-button add-button"
                onClick={onAddToLibrary}
                disabled={isProcessing}
                sx={{
                  backgroundColor: "var(--primary-color)",
                  color: "white",
                  "&:hover": {
                    backgroundColor: "var(--primary-hover)",
                  },
                }}
              >
                <Favorite sx={{ fontSize: "1.125rem" }} /> {getAddToLibraryButtonText()}
              </StyledButton>
            )}

            <StyledButton
              className="action-button next-button"
              onClick={onSkip}
              disabled={isProcessing}
              aria-label={hasBeenLiked ? "Get next suggestion" : "Skip this suggestion"}
            >
              {hasBeenLiked ? "Next" : "Skip"} <FaStepForward />
            </StyledButton>
          </Box>
        </Box>
      </Box>
    </Box>
  );
}; 
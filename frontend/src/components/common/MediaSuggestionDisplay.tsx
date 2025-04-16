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
import { ReasonCard } from "@/components/common/ReasonCard";

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

export interface MediaSuggestionItem {
  id: number | string;
  title: string;
  artist?: string;
  description?: string;
  imageUrl?: string;
}

interface MediaSuggestionDisplayProps {
  mediaType: 'movie' | 'book' | 'podcast' | 'other'; // add more types as needed
  suggestedItem: MediaSuggestionItem | null;
  suggestionReason: string | null;
  isLoading: boolean;
  error: string | null;
  isProcessing: boolean;
  onRequestSuggestion: () => void;
  onLike: () => void;
  onDislike: () => void;
  onSkip: () => void;
  onAddToLibrary?: () => void;
  renderImage?: (item: MediaSuggestionItem) => React.ReactNode;
}

export const MediaSuggestionDisplay: React.FC<MediaSuggestionDisplayProps> = ({
  mediaType,
  suggestedItem,
  suggestionReason,
  isLoading,
  error,
  isProcessing,
  onRequestSuggestion,
  onLike,
  onDislike,
  onSkip,
  onAddToLibrary,
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
    return (
      <Box className="suggestion-error-state">
        <Typography className="error-message" sx={{ color: "error.main" }}>
          {error}
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
      <Box className="empty-suggestion-state" sx={{ textAlign: "center", py: 4 }}>
        <StyledButton
          onClick={onRequestSuggestion}
          className="request-suggestion-button"
          disabled={isProcessing}
          variant="contained"
          sx={{
            bgcolor: "var(--primary-color)",
            "&:hover": {
              bgcolor: "var(--primary-hover)",
            },
          }}
        >
          Get a Suggestion
        </StyledButton>
      </Box>
    );
  }

  // Default image rendering if custom renderer not provided
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

  // Set button text based on media type
  const getAddToLibraryButtonText = () => {
    switch (mediaType) {
      case 'movie':
        return 'Add to Favorites';
      case 'book':
        return 'Add to Reading List';
      case 'podcast':
        return 'Add to Listen Later';
      default:
        return 'Add to Library';
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
        }}
      >
        <Box 
          className="media-image-container"
          sx={{
            flexShrink: 0,
            width: { xs: "100%", md: "300px" },
            display: "flex",
            justifyContent: "center",
          }}
        >
          {renderImage ? renderImage(suggestedItem) : renderDefaultImage()}
        </Box>

        <Box className="suggestion-info" sx={{ flex: 1 }}>
          <Typography variant="h4" component="h4">
            {suggestedItem.title}
          </Typography>
          
          {suggestedItem.artist && (
            <Typography variant="subtitle1" component="p">
              {suggestedItem.artist}
            </Typography>
          )}
          
          {suggestedItem.description && (
            <Typography variant="body1" sx={{ mt: 2 }}>
              {suggestedItem.description}
            </Typography>
          )}

          {suggestionReason && (
            <Box sx={{ mt: 2, mb: 3 }}>
              <ReasonCard reason={suggestionReason} />
            </Box>
          )}

          <Box
            className="suggestion-controls"
            sx={{
              display: "flex",
              flexWrap: "wrap",
              alignItems: "center",
              justifyContent: "center",
              gap: "10px",
              opacity: isProcessing ? 0.5 : 1,
              pointerEvents: isProcessing ? "none" : "auto",
              mt: 4,
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

            {/* Always show Add to Library button for movies */}
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
                <FaPlus /> {getAddToLibraryButtonText()}
              </StyledButton>
            )}

            <StyledButton
              className="action-button next-button"
              onClick={onSkip}
              disabled={isProcessing}
            >
              Next Suggestion <FaStepForward />
            </StyledButton>
          </Box>
        </Box>
      </Box>
    </Box>
  );
}; 
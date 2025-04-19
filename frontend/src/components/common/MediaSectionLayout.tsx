import React from "react";
import { Box, Typography, Button, CircularProgress } from "@mui/material";
import {
  MediaSuggestionDisplay,
  MediaSuggestionItem,
} from "./MediaSuggestionDisplay";
import { MediaItemBase } from "../../hooks/useMediaSection";

interface MediaSectionLayoutProps<T extends MediaItemBase> {
  // Basic metadata
  type: "movie" | "tv" | "game";
  typeName: string; // Human-readable name ("Movie", "TV Show", "Game")

  // Refs
  searchResultsRef: React.RefObject<HTMLDivElement>;

  // State
  credentialsError: boolean;
  isLoadingSuggestion: boolean;
  suggestionError: string | null;
  isProcessingFeedback: boolean;
  searchResults: T[];
  showSearchResults: boolean;
  watchlistItems: T[];
  savedItems: T[];
  showWatchlist: boolean;
  showLibrary: boolean;

  // Suggestion item data
  suggestedItem: T | null;
  suggestionReason: string | null;

  // Event handlers
  onRefreshCredentials: () => void;
  onRequestSuggestion: () => void;
  onLikeSuggestion: () => void;
  onDislikeSuggestion: () => void;
  onSkipSuggestion: () => void;
  onAddToLibrary: () => void;
  onAddSuggestionToWatchlist: (() => void) | undefined;
  onToggleWatchlist: () => void;
  onToggleLibrary: () => void;

  // Render functions
  renderSearchResults: () => React.ReactNode;
  renderWatchlistItems: () => React.ReactNode;
  renderSavedItems: () => React.ReactNode;
  renderSuggestionPoster?: (item: MediaSuggestionItem) => React.ReactNode;

  // Optional additional content
  headerContent?: React.ReactNode;
  footerContent?: React.ReactNode;

  // Mapping function to convert media item to suggestion item
  mapToSuggestionItem: (item: T) => MediaSuggestionItem;
  queueName?: string;
}

export function MediaSectionLayout<T extends MediaItemBase>({
  type,
  typeName,
  searchResultsRef,
  credentialsError,
  isLoadingSuggestion,
  suggestionError,
  isProcessingFeedback,
  searchResults,
  showSearchResults,
  watchlistItems,
  savedItems,
  showWatchlist,
  showLibrary,
  suggestedItem,
  suggestionReason,
  onRefreshCredentials,
  onRequestSuggestion,
  onLikeSuggestion,
  onDislikeSuggestion,
  onSkipSuggestion,
  onAddToLibrary,
  onAddSuggestionToWatchlist,
  onToggleWatchlist,
  onToggleLibrary,
  renderSearchResults,
  renderWatchlistItems,
  renderSavedItems,
  renderSuggestionPoster,
  headerContent,
  footerContent,
  mapToSuggestionItem,
  queueName = "Watchlist",
}: MediaSectionLayoutProps<T>) {
  return (
    <Box sx={{ width: "100%" }}>
      {/* Optional header content */}
      {headerContent}

      {/* API credentials error message */}
      {credentialsError && !isLoadingSuggestion && (
        <Box
          sx={{
            mb: 4,
            p: 3,
            backgroundColor: "rgba(0, 145, 234, 0.1)",
            borderRadius: 2,
            border: "1px solid rgba(0, 145, 234, 0.3)",
          }}
        >
          <Typography variant="h6" sx={{ color: "#0091EA" }} gutterBottom>
            Missing API Credentials
          </Typography>
          <Typography variant="body1">
            {type === "game"
              ? "The RAWG API credentials are not configured. Please set up your RAWG API key in the Settings to use game recommendations."
              : "The Movie Database API credentials are not configured. Please set up your TMDB API key in the Settings to use recommendations."}
          </Typography>
        </Box>
      )}

      {/* Suggestion Section */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h5" sx={{ mb: 2 }}>
          Suggested for You
        </Typography>

        <MediaSuggestionDisplay
          mediaType="movie"
          suggestedItem={
            suggestedItem ? mapToSuggestionItem(suggestedItem) : null
          }
          suggestionReason={suggestionReason}
          isLoading={isLoadingSuggestion}
          error={suggestionError}
          isProcessing={isProcessingFeedback}
          hasBeenLiked={suggestedItem?.isSaved}
          onRequestSuggestion={onRequestSuggestion}
          onLike={onLikeSuggestion}
          onDislike={onDislikeSuggestion}
          onSkip={onSkipSuggestion}
          onAddToLibrary={onAddToLibrary}
          onAddToWatchlist={onAddSuggestionToWatchlist}
          renderImage={renderSuggestionPoster}
          queueName={queueName}
        />
      </Box>

      {/* Search Results Section */}
      {searchResults.length > 0 && showSearchResults && (
        <Box sx={{ mb: 4 }} ref={searchResultsRef}>
          <Typography variant="h5" sx={{ mb: 2 }}>
            Search Results
          </Typography>
          {renderSearchResults()}
        </Box>
      )}

      {/* Watchlist Section */}
      <Box sx={{ mb: 4 }}>
        <Box
          sx={{
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
            mb: 2,
            cursor: "pointer",
          }}
          onClick={onToggleWatchlist}
        >
          <Typography variant="h6" sx={{ color: "text.primary" }}>
            Your {queueName}
          </Typography>
          <Typography variant="body2" sx={{ color: "text.secondary", ml: 2 }}>
            {showWatchlist ? "Hide" : "Show"} ({watchlistItems.length})
          </Typography>
        </Box>

        {showWatchlist &&
          (watchlistItems.length === 0 ? (
            <Box
              sx={{
                textAlign: "center",
                py: 4,
                color: "var(--text-secondary)",
              }}
            >
              <Typography variant="body1">
                Your watchlist is empty. Add {typeName.toLowerCase()}s to watch
                later by clicking the "Add to Watchlist" icon.
              </Typography>
            </Box>
          ) : (
            renderWatchlistItems()
          ))}
      </Box>

      {/* Library/Saved Items Section */}
      <Box sx={{ mb: 4 }}>
        <Box
          sx={{
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
            mb: 2,
            cursor: "pointer",
          }}
          onClick={onToggleLibrary}
        >
          <Typography variant="h6" sx={{ color: "text.primary" }}>
            Your Library
          </Typography>
          <Typography variant="body2" sx={{ color: "text.secondary", ml: 2 }}>
            {showLibrary ? "Hide" : "Show"} ({savedItems.length})
          </Typography>
        </Box>

        {showLibrary &&
          (savedItems.length === 0 ? (
            <Box
              sx={{
                textAlign: "center",
                py: 4,
                color: "var(--text-secondary)",
              }}
            >
              <Typography variant="body1">
                You haven't saved any {typeName.toLowerCase()}s yet. Search for{" "}
                {typeName.toLowerCase()}s and click the heart icon to add them
                to your favorites.
              </Typography>
            </Box>
          ) : (
            renderSavedItems()
          ))}
      </Box>

      {/* Optional footer content */}
      {footerContent}
    </Box>
  );
}

// Reusable grid layout for media items
export function MediaGrid({ children }: { children: React.ReactNode }) {
  return (
    <Box
      sx={{
        display: "grid",
        gridTemplateColumns: {
          xs: "repeat(1, 1fr)",
          sm: "repeat(2, 1fr)",
          md: "repeat(3, 1fr)",
          lg: "repeat(4, 1fr)",
          xl: "repeat(5, 1fr)",
        },
        gap: 3,
        "& > div": {
          height: "100%",
        },
      }}
    >
      {children}
    </Box>
  );
}

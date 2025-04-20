import React, {
  useRef,
  forwardRef,
  useImperativeHandle,
  useCallback,
  useEffect,
} from "react";
import { Box, Typography, Card, CardMedia } from "@mui/material";
import { MovieCard } from "./MovieCard";
import {
  SearchMovies,
  SetFavoriteMovies,
  GetFavoriteMovies,
  HasValidCredentials,
  RefreshCredentials,
  GetMovieSuggestion,
  GetMovieDetails,
  ProvideSuggestionFeedback,
  AddToWatchlist,
  GetWatchlist,
  RemoveFromWatchlist,
} from "@wailsjs/go/bindings/Movies";
import { MovieWithSavedStatus } from "@wailsjs/go/models";
import { session } from "@wailsjs/go/models";
import { MediaSuggestionItem } from "@/components/common/MediaSuggestionDisplay";
import { useMediaSection, MediaItemBase } from "@/hooks/useMediaSection";
import {
  MediaSectionLayout,
  MediaGrid,
} from "@/components/common/MediaSectionLayout";
import { MediaItemWrapper } from "@/components/common/MediaItemWrapper";
import { EnhancedMediaSuggestionItem, createEnhancedCachingEffect, getBestImageUrl } from "@/utils/enhancedMediaCache";
import { SuggestionCache } from "@/utils/suggestionCache";

// Define the exported types
export interface MovieSectionHandle {
  handleClearSearch: () => void;
  handleSearch: (query: string) => Promise<void>;
}

// Define our own type that combines both interfaces
interface MovieItem
  extends Omit<MovieWithSavedStatus, "isSaved">,
    Omit<MediaItemBase, "title" | "name"> {
  title: string;
  poster_path: string;
  isSaved?: boolean;
}

export const MovieSection = forwardRef<MovieSectionHandle, {}>((props, ref) => {
  // Use our common media section hook
  const mediaSection = useMediaSection<MovieItem>({
    type: "movie",

    // API functions
    checkCredentials: async () => {
      const hasCredentials = await HasValidCredentials();
      return hasCredentials;
    },
    getSuggestion: async () => {
      const suggestion = await GetMovieSuggestion();
      if (!suggestion) {
        throw new Error("Failed to get movie suggestion");
      }
      return {
        media: {
          ...suggestion.movie,
          poster_path: suggestion.movie.poster_path || "",
        } as MovieItem,
        reason: suggestion.reason,
      };
    },
    provideFeedback: ProvideSuggestionFeedback,
    loadSavedItems: async () => {
      const favoriteMovies = (await GetFavoriteMovies()) || [];
      // Ensure all items have the required properties
      return favoriteMovies.map((movie) => ({
        ...movie,
        poster_path: movie.poster_path || "",
      })) as MovieItem[];
    },
    loadWatchlistItems: async () => {
      const watchlist = (await GetWatchlist()) || [];
      // Ensure all items have the required properties
      return watchlist.map((movie) => ({
        ...movie,
        poster_path: movie.poster_path || "",
      })) as MovieItem[];
    },
    searchItems: async (query: string) => {
      const results = await SearchMovies(query);
      // Ensure all items have the required properties
      return results.map((movie) => ({
        ...movie,
        poster_path: movie.poster_path || "",
      })) as MovieItem[];
    },
    saveItem: async (item: MovieItem) => {
      const favoriteMovies = (await GetFavoriteMovies()) || [];

      if (item.isSaved) {
        // Remove from saved movies
        const updatedFavorites = favoriteMovies.filter(
          (fav) => fav.title !== item.title,
        );
        await SetFavoriteMovies(updatedFavorites);
      } else {
        // Add to saved movies
        const newFavorite: session.Movie = {
          title: item.title,
          director: item.director || "",
          writer: item.writer || "",
          poster_path: item.poster_path || "",
        };
        await SetFavoriteMovies([...favoriteMovies, newFavorite]);
      }
    },
    removeItem: async (item: MovieItem) => {
      const favoriteMovies = (await GetFavoriteMovies()) || [];
      const updatedFavorites = favoriteMovies.filter(
        (fav) => fav.title !== item.title,
      );
      await SetFavoriteMovies(updatedFavorites);
    },
    addToWatchlist: async (item: MovieItem) => {
      // Create a session.Movie to add to watchlist
      const movie: session.Movie = {
        title: item.title,
        director: item.director || "",
        writer: item.writer || "",
        poster_path: item.poster_path || "",
      };
      await AddToWatchlist(movie);
    },
    removeFromWatchlist: async (item: MovieItem) => {
      await RemoveFromWatchlist(item.title);
    },
    getItemDetails: async (id: number) => {
      const details = await GetMovieDetails(id);
      return {
        ...details,
        poster_path: details.poster_path || "",
      } as MovieItem;
    },

    // Local storage keys
    cachedSuggestionKey: "cached_movie_suggestion",
    cachedReasonKey: "cached_movie_reason",
  });

  // Expose functions via ref
  useImperativeHandle(ref, () => ({
    handleClearSearch: mediaSection.handleClearSearch,
    handleSearch: mediaSection.handleSearch,
  }));

  // Convert movie to MediaSuggestionItem
  const mapMovieToSuggestionItem = useCallback(
    (movie: MovieItem): MediaSuggestionItem => {
    return {
      id: movie.id,
      title: movie.title,
      description: movie.overview,
      imageUrl: movie.poster_path
        ? `https://image.tmdb.org/t/p/w500${movie.poster_path}`
        : undefined,
      releaseDate: movie.release_date,
      rating: movie.vote_average,
        voteCount: movie.vote_count,
    };
    },
    [],
  );

  // Custom renderer for movie poster
  const renderMoviePoster = useCallback(
    (item: MediaSuggestionItem) => {
      // Try to get the best image URL using our enhanced function
      const imageUrl = getBestImageUrl(item, "movie");
      if (!imageUrl) return null;

      // For TMDB images, add the base URL if it's not already there
      const fullImageUrl = imageUrl.startsWith('http') 
        ? imageUrl 
        : `https://image.tmdb.org/t/p/w500${imageUrl}`;

      return (
        <Card sx={{ height: "100%" }}>
          <CardMedia
            component="img"
            image={fullImageUrl}
            alt={item.title}
            sx={{
              height: "450px",
              objectFit: "cover",
              opacity: mediaSection.isProcessingFeedback ? 0.5 : 1,
              transition: "all 0.2s ease-in-out",
            }}
          />
        </Card>
      );
    },
    [mediaSection.isProcessingFeedback],
  );

  // Render functions for the sections
  const renderSearchResults = useCallback(
    () => (
      <MediaGrid>
        {mediaSection.searchResults.map((movie) => (
          <Box key={`search-${movie.id}`} sx={{ cursor: "pointer" }}>
            <MovieCard
              movie={movie as MovieWithSavedStatus}
              isSaved={!!movie.isSaved}
              isInWatchlist={mediaSection.watchlistItems.some(
                (m) => m.title === movie.title,
              )}
              view="default"
              onSave={() => mediaSection.handleSave(movie)}
              onAddToWatchlist={() => mediaSection.handleAddToWatchlist(movie)}
            />
          </Box>
        ))}
      </MediaGrid>
    ),
    [
      mediaSection.searchResults,
      mediaSection.watchlistItems,
      mediaSection.handleSave,
      mediaSection.handleAddToWatchlist,
    ],
  );

  const renderWatchlistItems = useCallback(
    () => (
      <MediaGrid>
        {mediaSection.watchlistItems.map((movie) => (
          <MediaItemWrapper
            key={`watchlist-${movie.id || movie.title}`}
            item={movie}
            view="watchlist"
            onRemoveFromWatchlist={() =>
              mediaSection.handleRemoveFromWatchlist(movie)
            }
          >
            <MovieCard
              movie={movie as MovieWithSavedStatus}
              isSaved={!!movie.isSaved}
              view="watchlist"
              onSave={() => mediaSection.handleWatchlistToFavorites(movie)}
              onRemoveFromWatchlist={undefined}
              onLike={() => mediaSection.handleWatchlistFeedback(movie, "like")}
              onDislike={() => {
                mediaSection.handleWatchlistFeedback(movie, "dislike");
                mediaSection.handleRemoveFromWatchlist(movie);
              }}
            />
          </MediaItemWrapper>
        ))}
      </MediaGrid>
    ),
    [
      mediaSection.watchlistItems,
      mediaSection.handleWatchlistToFavorites,
      mediaSection.handleRemoveFromWatchlist,
      mediaSection.handleWatchlistFeedback,
    ],
  );

  const renderSavedItems = useCallback(
    () => (
      <MediaGrid>
        {mediaSection.savedItems.map((movie, index) => (
          <Box key={`saved-${movie.id || index}`} sx={{ cursor: "pointer" }}>
            <MovieCard
              movie={{...movie, isSaved: true} as MovieWithSavedStatus}
              isSaved={true}
              isInWatchlist={mediaSection.watchlistItems.some(
                (m) => m.title === movie.title,
              )}
              view="default"
              onSave={() => mediaSection.handleSave({...movie, isSaved: true})}
              onAddToWatchlist={() => mediaSection.handleAddToWatchlist(movie)}
            />
          </Box>
        ))}
      </MediaGrid>
    ),
    [
      mediaSection.savedItems,
      mediaSection.watchlistItems,
      mediaSection.handleSave,
      mediaSection.handleAddToWatchlist,
    ],
  );

  // Refresh credentials handler
  const handleRefreshCredentials = useCallback(async () => {
    try {
      await RefreshCredentials();
      await mediaSection.checkCredentials();
    } catch (error) {
      console.error("Failed to refresh TMDB credentials:", error);
    }
  }, [mediaSection.checkCredentials]);

  // Ensure the suggested item is properly enhanced when switching tabs
  useEffect(
    createEnhancedCachingEffect("movie", mediaSection.suggestedItem, mediaSection.suggestionReason),
    [mediaSection.suggestedItem, mediaSection.suggestionReason]
  );

  return (
    <MediaSectionLayout
      type="movie"
      typeName="Movie"
      searchResultsRef={mediaSection.searchResultsRef}
      credentialsError={mediaSection.credentialsError}
      isLoadingSuggestion={mediaSection.isLoadingSuggestion}
      suggestionError={mediaSection.suggestionError}
      suggestionErrorDetails={mediaSection.suggestionErrorDetails}
      isProcessingFeedback={mediaSection.isProcessingFeedback}
      searchResults={mediaSection.searchResults}
      showSearchResults={mediaSection.showSearchResults}
      watchlistItems={mediaSection.watchlistItems}
      savedItems={mediaSection.savedItems}
      showWatchlist={mediaSection.showWatchlist}
      showLibrary={mediaSection.showLibrary}
      suggestedItem={mediaSection.suggestedItem}
      suggestionReason={mediaSection.suggestionReason}
      onRefreshCredentials={handleRefreshCredentials}
      onRequestSuggestion={mediaSection.handleGetSuggestion}
      onLikeSuggestion={() => {
        mediaSection.handleFeedback(session.Outcome.liked);
        // Don't add to favorites, just mark as liked
      }}
      onDislikeSuggestion={() =>
        mediaSection.handleFeedback(session.Outcome.disliked)
      }
      onSkipSuggestion={() => {
        mediaSection.handleSkip();
      }}
      onAddToLibrary={mediaSection.handleAddToFavorites}
      onAddSuggestionToWatchlist={
        mediaSection.suggestedItem
          ? () => mediaSection.handleAddToWatchlist(mediaSection.suggestedItem!)
          : undefined
      }
      onToggleWatchlist={() =>
        mediaSection.setShowWatchlist(!mediaSection.showWatchlist)
      }
      onToggleLibrary={() =>
        mediaSection.setShowLibrary(!mediaSection.showLibrary)
      }
      renderSearchResults={renderSearchResults}
      renderWatchlistItems={renderWatchlistItems}
      renderSavedItems={renderSavedItems}
      renderSuggestionPoster={renderMoviePoster}
      mapToSuggestionItem={mapMovieToSuggestionItem}
    />
  );
});

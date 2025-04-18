import React, { forwardRef, useImperativeHandle, useCallback } from "react";
import { Box, Card, CardMedia } from "@mui/material";
import { TVShowCard } from "./TVShowCard";
import {
  SearchTVShows,
  SetFavoriteTVShows,
  GetFavoriteTVShows,
  HasValidCredentials,
  RefreshCredentials,
  GetTVShowSuggestion,
  GetTVShowDetails,
  ProvideSuggestionFeedback,
  AddToWatchlist,
  GetWatchlist,
  RemoveFromWatchlist,
} from "@wailsjs/go/bindings/TVShows";
import { bindings } from "@wailsjs/go/models";
import { session } from "@wailsjs/go/models";
import { MediaSuggestionItem } from "@/components/common/MediaSuggestionDisplay";
import { useMediaSection, MediaItemBase } from "@/hooks/useMediaSection";
import {
  MediaSectionLayout,
  MediaGrid,
} from "@/components/common/MediaSectionLayout";

// Define the exported types
export interface TVShowSectionHandle {
  handleClearSearch: () => void;
  handleSearch: (query: string) => Promise<void>;
}

// Define our own type that combines both interfaces
interface TVShowItem
  extends Omit<bindings.TVShowWithSavedStatus, "isSaved">,
    Omit<MediaItemBase, "title" | "name"> {
  name: string;
  poster_path: string;
  isSaved?: boolean;
}

export const TVShowSection = forwardRef<TVShowSectionHandle, {}>(
  (props, ref) => {
    // Use our common media section hook
    const mediaSection = useMediaSection<TVShowItem>({
      type: "tv",

      // API functions
      checkCredentials: async () => {
        const hasCredentials = await HasValidCredentials();
        return hasCredentials;
      },
      getSuggestion: async () => {
        const suggestion = await GetTVShowSuggestion();
        if (!suggestion) {
          throw new Error("Failed to get TV show suggestion");
        }
        return {
          media: {
            ...suggestion.show,
            poster_path: suggestion.show.poster_path || "",
          } as TVShowItem,
          reason: suggestion.reason,
        };
      },
      provideFeedback: ProvideSuggestionFeedback,
      loadSavedItems: async () => {
        const favoriteShows = (await GetFavoriteTVShows()) || [];
        // Ensure all items have the required properties
        return favoriteShows.map((show) => ({
          ...show,
          name: show.title || "", // Map title to name for TV shows
          id: 0, // Default id since TVShow might not have it
          overview: "",
          first_air_date: "",
          vote_average: 0,
          vote_count: 0,
          genres: [],
          poster_path: show.poster_path || "",
        })) as unknown as TVShowItem[];
      },
      loadWatchlistItems: async () => {
        const watchlist = (await GetWatchlist()) || [];
        // Ensure all items have the required properties
        return watchlist.map((show) => ({
          ...show,
          name: show.title || "", // Map title to name for TV shows
          id: 0, // Default id since TVShow might not have it
          overview: "",
          first_air_date: "",
          vote_average: 0,
          vote_count: 0,
          genres: [],
          poster_path: show.poster_path || "",
        })) as unknown as TVShowItem[];
      },
      searchItems: async (query: string) => {
        const results = await SearchTVShows(query);
        // Ensure all items have the required properties
        return results.map((show) => ({
          ...show,
          poster_path: show.poster_path || "",
        })) as unknown as TVShowItem[];
      },
      saveItem: async (item: TVShowItem) => {
        const favoriteShows = (await GetFavoriteTVShows()) || [];

        if (item.isSaved) {
          // Remove from saved shows
          const updatedFavorites = favoriteShows.filter(
            (fav) => fav.title.toLowerCase() !== item.name.toLowerCase(),
          );
          await SetFavoriteTVShows(updatedFavorites);
        } else {
          // Add to saved shows
          const newFavorite: session.TVShow = {
            title: item.name,
            director: item.director || "",
            writer: item.writer || "",
            poster_path: item.poster_path || "",
          };
          await SetFavoriteTVShows([...favoriteShows, newFavorite]);
        }
      },
      removeItem: async (item: TVShowItem) => {
        const favoriteShows = (await GetFavoriteTVShows()) || [];
        const updatedFavorites = favoriteShows.filter(
          (fav) => fav.title.toLowerCase() !== item.name.toLowerCase(),
        );
        await SetFavoriteTVShows(updatedFavorites);
      },
      addToWatchlist: async (item: TVShowItem) => {
        // Create a session.TVShow to add to watchlist
        const show: session.TVShow = {
          title: item.name,
          director: item.director || "",
          writer: item.writer || "",
          poster_path: item.poster_path || "",
        };
        await AddToWatchlist(show);
      },
      removeFromWatchlist: async (item: TVShowItem) => {
        await RemoveFromWatchlist(item.name);
      },
      getItemDetails: async (id: number) => {
        const details = await GetTVShowDetails(id);
        return {
          ...details,
          poster_path: details.poster_path || "",
        } as unknown as TVShowItem;
      },

      // Local storage keys
      cachedSuggestionKey: "cached_tv_suggestion",
      cachedReasonKey: "cached_tv_reason",
    });

    // Expose functions via ref
    useImperativeHandle(ref, () => ({
      handleClearSearch: mediaSection.handleClearSearch,
      handleSearch: mediaSection.handleSearch,
    }));

    // Convert show to MediaSuggestionItem
    const mapShowToSuggestionItem = useCallback(
      (show: TVShowItem): MediaSuggestionItem => {
        return {
          id: show.id,
          title: show.name,
          description: show.overview,
          imageUrl: show.poster_path
            ? `https://image.tmdb.org/t/p/w500${show.poster_path}`
            : undefined,
          releaseDate: show.first_air_date,
          rating: show.vote_average,
          voteCount: show.vote_count,
        };
      },
      [],
    );

    // Custom renderer for show poster
    const renderShowPoster = useCallback(
      (item: MediaSuggestionItem) => {
        if (!item.imageUrl) return null;

        return (
          <Card sx={{ height: "100%" }}>
            <CardMedia
              component="img"
              image={item.imageUrl}
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
          {mediaSection.searchResults.map((show) => (
            <Box
              key={`search-${show.id || "unknown"}`}
              sx={{ cursor: "pointer" }}
            >
              <TVShowCard
                show={show as unknown as bindings.TVShowWithSavedStatus}
                isSaved={!!show.isSaved}
                isInWatchlist={mediaSection.watchlistItems.some(
                  (m) => m.name === show.name,
                )}
                view="default"
                onSave={() => mediaSection.handleSave(show)}
                onAddToWatchlist={() => mediaSection.handleAddToWatchlist(show)}
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
          {mediaSection.watchlistItems.map((show) => (
            <Box
              key={`watchlist-${show.id || show.name}`}
              sx={{ cursor: "pointer" }}
            >
              <TVShowCard
                show={show as unknown as bindings.TVShowWithSavedStatus}
                isSaved={!!show.isSaved}
                view="watchlist"
                onSave={() => mediaSection.handleSave(show)}
                onRemoveFromWatchlist={() =>
                  mediaSection.handleRemoveFromWatchlist(show)
                }
                onLike={() =>
                  mediaSection.handleWatchlistFeedback(show, "like")
                }
                onDislike={() =>
                  mediaSection.handleWatchlistFeedback(show, "dislike")
                }
              />
            </Box>
          ))}
        </MediaGrid>
      ),
      [
        mediaSection.watchlistItems,
        mediaSection.handleSave,
        mediaSection.handleRemoveFromWatchlist,
        mediaSection.handleWatchlistFeedback,
      ],
    );

    const renderSavedItems = useCallback(
      () => (
        <MediaGrid>
          {mediaSection.savedItems.map((show, index) => (
            <Box key={`saved-${show.id || index}`} sx={{ cursor: "pointer" }}>
              <TVShowCard
                show={show as unknown as bindings.TVShowWithSavedStatus}
                isSaved={true}
                isInWatchlist={mediaSection.watchlistItems.some(
                  (m) => m.name === show.name,
                )}
                view="default"
                onSave={() => mediaSection.handleSave(show)}
                onAddToWatchlist={() => mediaSection.handleAddToWatchlist(show)}
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

    return (
      <MediaSectionLayout
        type="tv"
        typeName="TV Show"
        searchResultsRef={mediaSection.searchResultsRef}
        credentialsError={mediaSection.credentialsError}
        isLoadingSuggestion={mediaSection.isLoadingSuggestion}
        suggestionError={mediaSection.suggestionError}
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
          // Update the library state directly
          if (mediaSection.suggestedItem) {
            const updatedShow = {
              ...mediaSection.suggestedItem,
              isSaved: true,
            };
            // Add to savedItems if not already there
            if (!mediaSection.savedItems.some((m) => m.id === updatedShow.id)) {
              mediaSection.setSavedItems([
                ...mediaSection.savedItems,
                updatedShow,
              ]);
            }
          }
        }}
        onDislikeSuggestion={() =>
          mediaSection.handleFeedback(session.Outcome.disliked)
        }
        onSkipSuggestion={() => {
          if (
            mediaSection.suggestedItem &&
            mediaSection.suggestedItem.isSaved
          ) {
            // Get a new suggestion
            mediaSection.handleGetSuggestion();
          } else {
            mediaSection.handleFeedback(session.Outcome.skipped);
          }
        }}
        onAddToLibrary={mediaSection.handleAddToFavorites}
        onAddSuggestionToWatchlist={
          mediaSection.suggestedItem
            ? () =>
                mediaSection.handleAddToWatchlist(mediaSection.suggestedItem!)
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
        renderSuggestionPoster={renderShowPoster}
        mapToSuggestionItem={mapShowToSuggestionItem}
      />
    );
  },
);

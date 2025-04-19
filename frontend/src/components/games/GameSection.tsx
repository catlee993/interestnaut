import React, { forwardRef, useImperativeHandle, useCallback } from "react";
import { Box, Card, CardMedia } from "@mui/material";
import GameCard from "./GameCard";
import {
  SearchGames,
  SaveGame,
  UnsaveGame,
  GetSavedGames,
  HasValidCredentials,
  GetGameSuggestion,
  GetGameDetails,
  ProvideSuggestionFeedback,
  AddGameToWatchlist,
  GetWatchlistGames,
  RemoveGameFromWatchlist,
} from "@wailsjs/go/bindings/Games";
import { bindings, rawg, session } from "@wailsjs/go/models";
import { MediaSuggestionItem } from "@/components/common/MediaSuggestionDisplay";
import { useMediaSection, MediaItemBase } from "@/hooks/useMediaSection";
import {
  MediaSectionLayout,
  MediaGrid,
} from "@/components/common/MediaSectionLayout";
import { MediaItemWrapper } from "@/components/common/MediaItemWrapper";
import { useSnackbar } from "notistack";

// Define the exported types
export interface GameSectionHandle {
  handleClearSearch: () => void;
  handleSearch: (query: string) => Promise<void>;
}

// Define our own type that combines both interfaces
interface GameItem extends Omit<rawg.Game, "convertValues">, MediaItemBase {
  id: number;
  name: string;
  background_image?: string;
  isSaved?: boolean;
  isInWatchlist?: boolean;
  // Implement any methods required
  convertValues?: (a: any, classs: any, asMap?: boolean) => any;
}

export const GameSection = forwardRef<GameSectionHandle, {}>((props, ref) => {
  // Use our common media section hook
  const mediaSection = useMediaSection<GameItem>({
    type: "game",

    // API functions
    checkCredentials: async () => {
      const hasCredentials = await HasValidCredentials();
      return hasCredentials;
    },
    getSuggestion: async () => {
      const suggestion = await GetGameSuggestion();
      if (!suggestion) {
        throw new Error("Failed to get game suggestion");
      }
      return {
        media: {
          ...suggestion.game,
          background_image: suggestion.game.background_image || "",
          id: suggestion.game.id || 0,
          name: suggestion.game.name || "",
          isSaved: suggestion.game.isSaved,
          isInWatchlist: suggestion.game.isInWatchlist,
        } as unknown as GameItem,
        reason: suggestion.reason,
      };
    },
    provideFeedback: ProvideSuggestionFeedback,
    loadSavedItems: async () => {
      const savedGames = (await GetSavedGames()) || [];
      // Ensure all items have the required properties
      return savedGames.map((game) => ({
        ...game,
        background_image: game.background_image || "",
        isSaved: true,
      })) as unknown as GameItem[];
    },
    loadWatchlistItems: async () => {
      const watchlist = (await GetWatchlistGames()) || [];
      // Ensure all items have the required properties
      return watchlist.map((game) => ({
        ...game,
        background_image: game.background_image || "",
        isInWatchlist: true,
      })) as unknown as GameItem[];
    },
    searchItems: async (query: string) => {
      const results = await SearchGames(query, 1, 20);
      // Ensure all items have the required properties
      return (results?.results || []).map((game) => ({
        ...game,
        background_image: game.background_image || "",
      })) as unknown as GameItem[];
    },
    saveItem: async (item: GameItem) => {
      if (item.isSaved) {
        // Remove from saved games
        await UnsaveGame(item.id);
      } else {
        // Add to saved games
        await SaveGame(item.id);
      }
    },
    removeItem: async (item: GameItem) => {
      await UnsaveGame(item.id);
    },
    addToWatchlist: async (item: GameItem) => {
      await AddGameToWatchlist(item.id);
    },
    removeFromWatchlist: async (item: GameItem) => {
      await RemoveGameFromWatchlist(item.id);
    },
    getItemDetails: async (id: number) => {
      const details = await GetGameDetails(id);
      return {
        ...details,
        background_image: details.background_image || "",
      } as unknown as GameItem;
    },

    // Local storage keys
    cachedSuggestionKey: "cached_game_suggestion",
    cachedReasonKey: "cached_game_reason",
  });

  // Expose functions via ref
  useImperativeHandle(ref, () => ({
    handleClearSearch: mediaSection.handleClearSearch,
    handleSearch: mediaSection.handleSearch,
  }));

  // Convert game to MediaSuggestionItem
  const mapGameToSuggestionItem = useCallback(
    (game: GameItem): MediaSuggestionItem => {
      return {
        id: game.id,
        title: game.name,
        description: game.description || "",
        imageUrl: game.background_image || undefined,
        releaseDate: game.released,
        rating: game.rating ? game.rating * 2 : 0, // RAWG ratings are out of 5, convert to 10 for consistency
        voteCount: game.ratings_count,
      };
    },
    [],
  );

  // Custom renderer for game poster
  const renderGamePoster = useCallback(
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
        {mediaSection.searchResults.map((game) => (
          <Box key={`search-${game.id}`} sx={{ cursor: "pointer" }}>
            <GameCard
              game={game}
              onSelect={() => {}}
              onSave={() => mediaSection.handleSave(game)}
              onAddToWatchlist={() => mediaSection.handleAddToWatchlist(game)}
              isSaved={!!game.isSaved}
              isInWatchlist={!!game.isInWatchlist}
            />
          </Box>
        ))}
      </MediaGrid>
    ),
    [
      mediaSection.searchResults,
      mediaSection.handleSave,
      mediaSection.handleAddToWatchlist,
    ],
  );

  const { enqueueSnackbar } = useSnackbar();

  const renderWatchlistItems = useCallback(
    () => (
      <MediaGrid>
        {mediaSection.watchlistItems.map((game) => (
          <MediaItemWrapper
            key={`watchlist-${game.id || game.name}`}
            item={game}
            view="watchlist"
            onRemoveFromWatchlist={() => mediaSection.handleRemoveFromWatchlist(game)}
          >
            <GameCard
              game={game}
              onSelect={() => {}}
              onSave={() => {
                // Instead of using handleWatchlistToFavorites, which removes from watchlist,
                // we'll just add to favorites if not already favorited
                if (!game.isSaved) {
                  mediaSection.handleSave({ ...game, isSaved: false });
                }
                
                // Show success message
                enqueueSnackbar(`"${game.name}" is in your library`, {
                  variant: "success",
                });
              }}
              onRemoveFromWatchlist={undefined}
              isSaved={!!game.isSaved}
              isInWatchlist={true}
              view="watchlist"
              onLike={() => {
                try {
                  // If not saved, add to library
                  if (!game.isSaved) {
                    mediaSection.handleSave({ ...game, isSaved: false });
                  }
                  
                  // Send feedback (but don't use handleWatchlistFeedback to avoid removal)
                  // Wrap in try-catch to prevent errors from affecting UI
                  ProvideSuggestionFeedback(session.Outcome.liked, game.id)
                    .catch(err => console.error("Failed to record feedback:", err));
                  
                  // Show success message
                  enqueueSnackbar(`You liked "${game.name}"`, {
                    variant: "success",
                  });
                } catch (error) {
                  console.error("Error in onLike handler:", error);
                  enqueueSnackbar("An error occurred while processing your feedback", {
                    variant: "error",
                  });
                }
              }}
              onDislike={() => mediaSection.handleWatchlistFeedback(game, "dislike")}
            />
          </MediaItemWrapper>
        ))}
      </MediaGrid>
    ),
    [
      mediaSection.watchlistItems,
      mediaSection.handleSave,
      mediaSection.handleRemoveFromWatchlist,
      mediaSection.handleWatchlistFeedback,
      enqueueSnackbar,
    ],
  );

  const renderSavedItems = useCallback(
    () => (
      <MediaGrid>
        {mediaSection.savedItems.map((game, index) => (
          <Box key={`saved-${game.id || index}`} sx={{ cursor: "pointer" }}>
            <GameCard
              game={{...game, isSaved: true}}
              onSelect={() => {}}
              onSave={() => mediaSection.handleSave({...game, isSaved: true})}
              onAddToWatchlist={() => mediaSection.handleAddToWatchlist(game)}
              isSaved={true}
              isInWatchlist={!!game.isInWatchlist}
            />
          </Box>
        ))}
      </MediaGrid>
    ),
    [
      mediaSection.savedItems,
      mediaSection.handleSave,
      mediaSection.handleAddToWatchlist,
    ],
  );

  // Refresh credentials handler - redirect to settings
  const handleRefreshCredentials = useCallback(() => {
    window.location.href = "#/settings";
  }, []);

  return (
    <MediaSectionLayout
      type="game"
      typeName="Game"
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
          const updatedGame = { ...mediaSection.suggestedItem, isSaved: true };
          // Add to savedItems if not already there
          if (!mediaSection.savedItems.some((g) => g.id === updatedGame.id)) {
            mediaSection.setSavedItems([
              ...mediaSection.savedItems,
              updatedGame,
            ]);
          }
        }
      }}
      onDislikeSuggestion={() =>
        mediaSection.handleFeedback(session.Outcome.disliked)
      }
      onSkipSuggestion={() => {
        if (mediaSection.suggestedItem && mediaSection.suggestedItem.isSaved) {
          // Get a new suggestion
          mediaSection.handleGetSuggestion();
        } else {
          mediaSection.handleFeedback(session.Outcome.skipped);
        }
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
      renderSuggestionPoster={renderGamePoster}
      mapToSuggestionItem={mapGameToSuggestionItem}
    />
  );
});

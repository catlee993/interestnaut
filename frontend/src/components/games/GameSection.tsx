import React, {
  useRef,
  forwardRef,
  useImperativeHandle,
  useCallback,
} from "react";
import { Box, Card, CardMedia } from "@mui/material";
import { GameCard, ExtendedGame } from "./GameCard";
import {
  SearchGames,
  SetFavoriteGames,
  GetFavoriteGames,
  HasValidCredentials,
  RefreshCredentials,
  GetGameSuggestion,
  GetGameDetails,
  ProvideSuggestionFeedback,
  AddToWatchlist,
  GetWatchlist,
  RemoveFromWatchlist,
} from "@wailsjs/go/bindings/Games";
import { bindings, session } from "@wailsjs/go/models";
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
interface GameItem extends Omit<ExtendedGame, "convertValues">, MediaItemBase {
  id: number;
  name: string;
  background_image?: string;
  isSaved?: boolean;
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
        } as unknown as GameItem,
        reason: suggestion.reason,
      };
    },
    provideFeedback: ProvideSuggestionFeedback,
    loadSavedItems: async () => {
      const favoriteGames = (await GetFavoriteGames()) || [];
      // Ensure all items have the required properties
      return favoriteGames.map((game) => ({
        id: 0, // We may not have an ID
        name: game.title,
        background_image: game.cover_path || "",
        isSaved: true,
      })) as unknown as GameItem[];
    },
    loadWatchlistItems: async () => {
      const watchlist = (await GetWatchlist()) || [];
      // Ensure all items have the required properties, similar to how MovieSection does it
      return watchlist.map((game: any) => ({
        id: game.id || 0,
        name: game.title || "", // Use title as primary key like movies do
        background_image: game.cover_path || "",
        isSaved: false, // Start with false, will be updated if in saved items
      })) as unknown as GameItem[];
    },
    searchItems: async (query: string) => {
      const results = await SearchGames(query);
      // Ensure all items have the required properties
      return results.map((game) => ({
        ...game,
        background_image: game.background_image || "",
      })) as unknown as GameItem[];
    },
    saveItem: async (item: GameItem) => {
      const favoriteGames = (await GetFavoriteGames()) || [];

      if (item.isSaved) {
        // Remove from saved games
        const updatedFavorites = favoriteGames.filter(
          (fav) => fav.title !== item.name,
        );
        await SetFavoriteGames(updatedFavorites);
      } else {
        // Add to saved games - we need to use a minimal object that meets the requirements
        // without specifying optional fields that might cause type errors
        const newFavorite = {
          title: item.name,
          developer: "",
          publisher: "",
          cover_path: item.background_image || "",
        };
        await SetFavoriteGames([
          ...favoriteGames,
          newFavorite as session.VideoGame,
        ]);
      }
    },
    removeItem: async (item: GameItem) => {
      const favoriteGames = (await GetFavoriteGames()) || [];
      const updatedFavorites = favoriteGames.filter(
        (fav) => fav.title !== item.name,
      );
      await SetFavoriteGames(updatedFavorites);
    },
    addToWatchlist: async (item: GameItem) => {
      // Create a VideoGame object to pass to the API
      const game: session.VideoGame = {
        title: item.name,
        developer: "",
        publisher: "",
        cover_path: item.background_image || "",
        platforms: [], // Include required platforms property
      };
      await AddToWatchlist(game);
    },
    removeFromWatchlist: async (item: GameItem) => {
      // The API expects a string (title)
      await RemoveFromWatchlist(item.name);
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

    // Use "Playlist" instead of "Watchlist" for games
    queueListName: "Playlist",
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
      if (!item) return null;
      
      // Just show the image, descriptions are handled by MediaSuggestionDisplay
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
              game={game as unknown as ExtendedGame}
              isSaved={!!game.isSaved}
              isInWatchlist={mediaSection.watchlistItems.some(
                (g) => g.name === game.name,
              )}
              view="default"
              onSave={() => mediaSection.handleSave(game)}
              onAddToWatchlist={() => mediaSection.handleAddToWatchlist(game)}
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
        {mediaSection.watchlistItems.map((game) => (
          <MediaItemWrapper
            key={`watchlist-${game.id || game.name}`}
            item={game}
            view="watchlist"
            onRemoveFromWatchlist={() =>
              mediaSection.handleRemoveFromWatchlist(game)
            }
          >
            <GameCard
              game={game as unknown as ExtendedGame}
              isSaved={!!game.isSaved}
              view="watchlist"
              onSave={() => mediaSection.handleWatchlistToFavorites(game)}
              onRemoveFromWatchlist={undefined}
              onLike={() => mediaSection.handleWatchlistFeedback(game, "like")}
              onDislike={() => {
                mediaSection.handleWatchlistFeedback(game, "dislike");
                mediaSection.handleRemoveFromWatchlist(game);
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
        {mediaSection.savedItems.map((game, index) => (
          <Box key={`saved-${game.id || index}`} sx={{ cursor: "pointer" }}>
            <GameCard
              game={{ ...game, isSaved: true } as unknown as ExtendedGame}
              isSaved={true}
              isInWatchlist={mediaSection.watchlistItems.some(
                (g) => g.name === game.name,
              )}
              view="default"
              onSave={() => mediaSection.handleSave({ ...game, isSaved: true })}
              onAddToWatchlist={() => mediaSection.handleAddToWatchlist(game)}
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
      console.error("Failed to refresh RAWG credentials:", error);
    }
  }, [mediaSection.checkCredentials]);

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
      queueName="Playlist"
    />
  );
});

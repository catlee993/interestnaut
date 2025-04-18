import React, { useState, useEffect, useCallback, forwardRef } from "react";
import {
  Box,
  Typography,
  CircularProgress,
  TextField,
  InputAdornment,
  IconButton,
  Divider,
  Button,
  Paper,
  Snackbar,
  Alert,
  Grid,
  Pagination,
  Stack,
  Card,
  CardMedia,
  Dialog,
  DialogTitle,
  DialogContent,
} from "@mui/material";
import { useSnackbar } from "notistack";
import SearchIcon from "@mui/icons-material/Search";
import ClearIcon from "@mui/icons-material/Clear";
import {
  GetGameDetails,
  GetGames,
  SearchGames,
  SaveGame,
  UnsaveGame,
  GetSavedGames,
  AddGameToWatchlist,
  RemoveGameFromWatchlist,
  GetWatchlistGames,
  HasValidCredentials,
  GetGameSuggestion,
  ProvideSuggestionFeedback,
} from "../../../wailsjs/go/bindings/Games";
import { bindings, rawg, session } from "../../../wailsjs/go/models";
import { MediaCard } from "../common/MediaCard";
import { useMediaCollection } from "../../hooks/useMediaCollection";
import {
  MediaSuggestionDisplay,
  MediaSuggestionItem,
} from "../common/MediaSuggestionDisplay";
import { Grid as MuiGrid } from "@mui/material";
import CloseIcon from "@mui/icons-material/Close";

// Define a ref handle for external control
export interface GameSectionHandle {
  handleClearSearch: () => void;
  handleSearch: (query: string) => Promise<void>;
}

// Define a wrapper interface that extends the rawg.Game type
interface ExtendedGame extends Omit<rawg.Game, "convertValues"> {
  isSaved?: boolean;
  isInWatchlist?: boolean;
  // Implement any methods required
  convertValues?: (a: any, classs: any, asMap?: boolean) => any;
}

// Interface for game suggestion data (similar to TVShowSuggestionData)
interface GameSuggestionData {
  game: bindings.GameWithSavedStatus;
  reason: string;
}

// Define the GameDetailDialog component
interface GameDetailDialogProps {
  open: boolean;
  game: rawg.Game;
  platforms?: { platform: { id: number; name: string } }[]; // Use a simple type compatible with both
  onClose: () => void;
  onSave: () => void;
  onAddToWatchlist?: () => void;
  onRemoveFromWatchlist?: () => void;
  isSaved: boolean;
  isInWatchlist: boolean;
}

const GameDetailDialog = ({
  open,
  game,
  platforms,
  onClose,
  onSave,
  onAddToWatchlist,
  onRemoveFromWatchlist,
  isSaved,
  isInWatchlist,
}: GameDetailDialogProps) => {
  if (!game) return null;
  
  const formattedReleaseDate = game.released
    ? new Date(game.released).toLocaleDateString()
    : 'Unknown';
    
  const platformNames = platforms?.map(p => p.platform.name).join(', ') || '';
  const genreNames = game.genres?.map(g => g.name).join(', ') || '';
  
  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="md"
      fullWidth
    >
      <DialogTitle>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Typography variant="h6">{game.name}</Typography>
          <IconButton onClick={onClose}>
            <CloseIcon />
          </IconButton>
        </Box>
      </DialogTitle>
      <DialogContent dividers>
        <Box sx={{ display: 'flex', flexDirection: { xs: 'column', md: 'row' }, gap: 3 }}>
          {/* Game poster */}
          <Box sx={{ width: { xs: '100%', md: '40%' } }}>
            {game.background_image && (
              <CardMedia
                component="img"
                image={game.background_image}
                alt={game.name}
                sx={{ height: '400px', objectFit: 'cover', borderRadius: 1 }}
              />
            )}
            <Box sx={{ mt: 2, display: 'flex', justifyContent: 'center', gap: 2 }}>
              <Button 
                variant={isSaved ? "contained" : "outlined"}
                color="primary"
                onClick={onSave}
              >
                {isSaved ? "Saved" : "Add to Library"}
              </Button>
              
              {isInWatchlist && onRemoveFromWatchlist ? (
                <Button 
                  variant="outlined" 
                  color="secondary"
                  onClick={onRemoveFromWatchlist}
                >
                  Remove from Watchlist
                </Button>
              ) : onAddToWatchlist ? (
                <Button 
                  variant="outlined"
                  color="secondary"
                  onClick={onAddToWatchlist}
                >
                  Add to Watchlist
                </Button>
              ) : null}
            </Box>
          </Box>
          
          {/* Game details */}
          <Box sx={{ width: { xs: '100%', md: '60%' } }}>
            <Typography variant="body1" paragraph>
              {game.description || "No description available"}
            </Typography>
            
            <Typography variant="subtitle1" color="text.secondary">
              Released: {formattedReleaseDate}
            </Typography>
            
            {game.rating > 0 && (
              <Typography variant="subtitle1" color="text.secondary">
                Rating: {game.rating.toFixed(1)}/5 ({game.ratings_count} votes)
              </Typography>
            )}
            
            {platformNames && (
              <Typography variant="subtitle1" color="text.secondary">
                Platforms: {platformNames}
              </Typography>
            )}
            
            {genreNames && (
              <Typography variant="subtitle1" color="text.secondary">
                Genres: {genreNames}
              </Typography>
            )}
          </Box>
        </Box>
      </DialogContent>
    </Dialog>
  );
};

export const GameSection = forwardRef<GameSectionHandle, {}>((props, ref) => {
  const { enqueueSnackbar } = useSnackbar();

  // State for games
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [searchResults, setSearchResults] = useState<ExtendedGame[]>([]);
  const [popularGames, setPopularGames] = useState<ExtendedGame[]>([]);
  const [savedGames, setSavedGames] = useState<ExtendedGame[]>([]);
  const [watchlistGames, setWatchlistGames] = useState<ExtendedGame[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [selectedGame, setSelectedGame] = useState<ExtendedGame | null>(null);
  const [currentPage, setCurrentPage] = useState<number>(1);
  const [totalPages, setTotalPages] = useState<number>(1);
  const [showGameDetails, setShowGameDetails] = useState<boolean>(false);
  const [showSearchResults, setShowSearchResults] = useState<boolean>(false);

  // State for error handling
  const [error, setError] = useState<string | null>(null);
  const [showError, setShowError] = useState<boolean>(false);

  // State for game suggestions
  const [suggestedGame, setSuggestedGame] =
    useState<bindings.GameWithSavedStatus | null>(null);
  const [suggestionReason, setSuggestionReason] = useState<string | null>(null);
  const [isLoadingSuggestion, setIsLoadingSuggestion] =
    useState<boolean>(false);
  const [suggestionError, setSuggestionError] = useState<string | null>(null);
  const [isProcessingFeedback, setIsProcessingFeedback] =
    useState<boolean>(false);
  const [credentialsError, setCredentialsError] = useState<boolean>(false);

  // Local storage keys for caching
  const CACHED_GAME_SUGGESTION_KEY = "cached_game_suggestion";
  const CACHED_GAME_REASON_KEY = "cached_game_reason";

  // Add state for collapsible sections
  const [showWatchlist, setShowWatchlist] = useState<boolean>(true);
  const [showLibrary, setShowLibrary] = useState<boolean>(true);

  // Expose functions via ref
  React.useImperativeHandle(ref, () => ({
    handleClearSearch: () => {
      setSearchQuery("");
      setShowSearchResults(false);
    },
    handleSearch: async (query: string) => {
      setSearchQuery(query);
      if (query.trim()) {
        await handleSearch();
      }
    },
  }));

  // Initial load
  useEffect(() => {
    const loadInitialData = async () => {
      await checkCredentials();
      await fetchPopularGames();
      await fetchSavedGames();
      await fetchWatchlistGames();

      // Try to load cached suggestion first
      const cachedGame = localStorage.getItem(CACHED_GAME_SUGGESTION_KEY);
      const cachedReason = localStorage.getItem(CACHED_GAME_REASON_KEY);

      if (cachedGame && cachedReason) {
        try {
          const parsedGame = JSON.parse(cachedGame);
          setSuggestedGame(parsedGame);
          setSuggestionReason(cachedReason);

          // Verify the cached suggestion is still valid by checking game details
          // This helps ensure we're not showing a suggestion that's no longer in the server's session
          if (parsedGame && parsedGame.id) {
            try {
              await GetGameDetails(parsedGame.id);
              console.log("Cached game suggestion is valid");
            } catch (error) {
              console.log(
                "Cached suggestion is no longer valid, getting a new one",
              );
              // Clear localStorage
              localStorage.removeItem(CACHED_GAME_SUGGESTION_KEY);
              localStorage.removeItem(CACHED_GAME_REASON_KEY);
              // Get a new suggestion
              handleGetSuggestion();
            }
          }
        } catch (e) {
          console.error("Failed to parse cached game suggestion:", e);
          // If parsing fails, get a new suggestion
          localStorage.removeItem(CACHED_GAME_SUGGESTION_KEY);
          localStorage.removeItem(CACHED_GAME_REASON_KEY);
          handleGetSuggestion();
        }
      } else {
        // No cached suggestion, get a new one
        handleGetSuggestion();
      }
    };

    loadInitialData();

    // Save suggestion to localStorage when component unmounts or when suggestion changes
    return () => {
      if (suggestedGame) {
        localStorage.setItem(
          CACHED_GAME_SUGGESTION_KEY,
          JSON.stringify(suggestedGame),
        );
      }
      if (suggestionReason) {
        localStorage.setItem(CACHED_GAME_REASON_KEY, suggestionReason);
      }
    };
  }, []);

  // Update cached suggestion whenever it changes
  useEffect(() => {
    if (suggestedGame) {
      localStorage.setItem(
        CACHED_GAME_SUGGESTION_KEY,
        JSON.stringify(suggestedGame),
      );
    }
    if (suggestionReason) {
      localStorage.setItem(CACHED_GAME_REASON_KEY, suggestionReason);
    }
  }, [suggestedGame, suggestionReason]);

  // Helper to check if a game is saved
  const isGameSaved = useCallback(
    (gameId: number) => {
      return savedGames.some((g) => g.id === gameId);
    },
    [savedGames],
  );

  // Helper to check if a game is in watchlist
  const isGameInWatchlist = useCallback(
    (gameId: number) => {
      return watchlistGames.some((g) => g.id === gameId);
    },
    [watchlistGames],
  );

  // Update game saved and watchlist status across all lists
  const updateGameStatuses = useCallback(
    (games: rawg.Game[]): ExtendedGame[] => {
      return games.map((game) => ({
        ...game,
        isSaved: isGameSaved(game.id),
        isInWatchlist: isGameInWatchlist(game.id),
      }));
    },
    [isGameSaved, isGameInWatchlist],
  );

  // Update game saved status in all lists
  const updateGameSavedStatus = useCallback(
    (gameId: number, isSaved: boolean) => {
      // Update in popular games
      setPopularGames((prevGames) =>
        prevGames.map((game) =>
          game.id === gameId ? { ...game, isSaved } : game,
        ),
      );

      // Update in search results
      setSearchResults((prevResults) =>
        prevResults.map((game) =>
          game.id === gameId ? { ...game, isSaved } : game,
        ),
      );

      // If this is our suggested game, update its status too
      if (suggestedGame && suggestedGame.id === gameId) {
        // Use type assertion to fix TypeScript issue
        setSuggestedGame({
          ...suggestedGame,
          isSaved,
        } as bindings.GameWithSavedStatus);
      }
    },
    [suggestedGame],
  );

  // Update game watchlist status in all lists
  const updateGameWatchlistStatus = useCallback(
    (gameId: number, isInWatchlist: boolean) => {
      // Update in popular games
      setPopularGames((prevGames) =>
        prevGames.map((game) =>
          game.id === gameId ? { ...game, isInWatchlist } : game,
        ),
      );

      // Update in search results
      setSearchResults((prevResults) =>
        prevResults.map((game) =>
          game.id === gameId ? { ...game, isInWatchlist } : game,
        ),
      );

      // If this is our suggested game, update its status too
      if (suggestedGame && suggestedGame.id === gameId) {
        // Use type assertion to fix TypeScript issue
        setSuggestedGame({
          ...suggestedGame,
          isInWatchlist,
        } as bindings.GameWithSavedStatus);
      }
    },
    [suggestedGame],
  );

  // Check if API credentials are valid
  const checkCredentials = async () => {
    try {
      const hasCredentials = await HasValidCredentials();
      setCredentialsError(!hasCredentials);
    } catch (error) {
      console.error("Failed to check credentials:", error);
      setCredentialsError(true);
    }
  };

  // Fetch popular games
  const fetchPopularGames = useCallback(
    async (page: number = 1) => {
      try {
        setLoading(true);
        const response = await GetGames(page, 20);
        if (response) {
          const gamesWithStatus = updateGameStatuses(response.results || []);
          setPopularGames(gamesWithStatus);
          setTotalPages(Math.ceil((response.count || 0) / 20));
        }
      } catch (err) {
        console.error("Error fetching popular games:", err);
        setError("Failed to fetch popular games. Please try again later.");
        setShowError(true);
      } finally {
        setLoading(false);
      }
    },
    [updateGameStatuses],
  );

  // Update popular games when page changes
  useEffect(() => {
    // Only fetch popular games once on initial load
    if (!popularGames.length) {
      fetchPopularGames();
    }
  }, [fetchPopularGames, popularGames.length]);

  // Update search results when page changes
  useEffect(() => {
    if (showSearchResults && searchQuery && currentPage > 1) {
      searchGamesPage(searchQuery, currentPage);
    }
  }, [currentPage, searchQuery, showSearchResults]);

  // Fetch saved games
  const fetchSavedGames = useCallback(async () => {
    try {
      const response = await GetSavedGames();
      if (response) {
        // Process the games with detailed error handling
        const gamesWithDetails: ExtendedGame[] = [];

        // Track games by title to prevent duplicates
        const processedTitles = new Set<string>();

        let apiCallCount = 0;
        const MAX_API_CALLS = 5;

        for (const game of response) {
          // Skip if we've already processed a game with this title
          if (processedTitles.has(game.name?.toLowerCase() || "")) {
            continue;
          }

          // Add to processed set to prevent duplicates
          processedTitles.add(game.name?.toLowerCase() || "");

          // We already have background_image stored for saved games
          if (game.background_image) {
            // Create a game object with the stored image
            gamesWithDetails.push({
              ...game,
              isSaved: true,
              isInWatchlist: game.isInWatchlist || false,
            });
          } else {
            try {
              // If we've hit our API call limit, create a basic entry
              if (apiCallCount >= MAX_API_CALLS) {
                gamesWithDetails.push({
                  ...game,
                  isSaved: true,
                  isInWatchlist: game.isInWatchlist || false,
                });
                continue;
              }

              // Get more details for the game
              const gameDetails = await GetGameDetails(game.id);
              apiCallCount++;

              // Add it to our array with detailed info
              gamesWithDetails.push({
                ...gameDetails,
                isSaved: true,
                isInWatchlist:
                  gameDetails.isInWatchlist || game.isInWatchlist || false,
              });
            } catch (error) {
              console.error(
                `Failed to fetch details for game "${game.name}":`,
                error,
              );
              // Add a basic entry for this game
              gamesWithDetails.push({
                ...game,
                isSaved: true,
                isInWatchlist: game.isInWatchlist || false,
              });
            }
          }
        }

        setSavedGames(gamesWithDetails);

        // If we hit the API call limit, show a message to the user
        if (apiCallCount >= MAX_API_CALLS && response.length > MAX_API_CALLS) {
          enqueueSnackbar(
            `Loaded ${MAX_API_CALLS} game details, ${response.length - MAX_API_CALLS} games shown with limited details`,
            {
              variant: "info",
            },
          );
        }
      }
    } catch (err) {
      console.error("Error fetching saved games:", err);
      setError("Failed to fetch your saved games. Please try again later.");
      setShowError(false); // Don't show error notification for this
    }
  }, [enqueueSnackbar]);

  // Fetch watchlist games
  const fetchWatchlistGames = useCallback(async () => {
    try {
      const response = await GetWatchlistGames();

      // If watchlist is empty, just set empty array
      if (!response || response.length === 0) {
        setWatchlistGames([]);
        return;
      }

      const gamesWithDetails: ExtendedGame[] = [];

      // Track games by title to prevent duplicates
      const processedTitles = new Set<string>();

      let apiCallCount = 0;
      const MAX_API_CALLS = 5;

      // Get the current savedGames from state to use for comparison
      const currentSavedGames = savedGames;

      for (const game of response) {
        // Skip if we've already processed a game with this title
        if (processedTitles.has(game.name?.toLowerCase() || "")) {
          continue;
        }

        // Add to processed set to prevent duplicates
        processedTitles.add(game.name?.toLowerCase() || "");

        // Check if this game is in favorites by comparing names (case insensitive)
        const isSaved = currentSavedGames.some(
          (saved) =>
            saved.name.toLowerCase() === (game.name?.toLowerCase() || ""),
        );

        // We already have background_image stored for watchlist games
        if (game.background_image) {
          // Create a game object with the stored image
          gamesWithDetails.push({
            ...game,
            isSaved: isSaved, // Using the saved status check
            isInWatchlist: true,
          });
        } else {
          try {
            // If we've hit our API call limit, create a basic entry
            if (apiCallCount >= MAX_API_CALLS) {
              gamesWithDetails.push({
                ...game,
                isSaved: isSaved,
                isInWatchlist: true,
              });
              continue;
            }

            // Get more details for the game
            const gameDetails = await GetGameDetails(game.id);
            apiCallCount++;

            // Check if this game is also in favorites (comparing case insensitive)
            const isSavedWithDetails = currentSavedGames.some(
              (saved) =>
                saved.name.toLowerCase() === gameDetails.name.toLowerCase(),
            );

            // Add it to our array with detailed info
            gamesWithDetails.push({
              ...gameDetails,
              isSaved: isSavedWithDetails || isSaved,
              isInWatchlist: true,
            });
          } catch (error) {
            console.error(
              `Failed to fetch details for game "${game.name}":`,
              error,
            );
            // Add a basic entry for this game
            gamesWithDetails.push({
              ...game,
              isSaved: isSaved,
              isInWatchlist: true,
            });
          }
        }
      }

      setWatchlistGames(gamesWithDetails);

      // If we hit the API call limit, show a message to the user
      if (apiCallCount >= MAX_API_CALLS && response.length > MAX_API_CALLS) {
        enqueueSnackbar(
          `Loaded ${MAX_API_CALLS} watchlist game details, ${response.length - MAX_API_CALLS} games shown with limited details`,
          {
            variant: "info",
          },
        );
      }
    } catch (err) {
      console.error("Error fetching watchlist games:", err);
      setError("Failed to fetch your watchlist. Please try again later.");
      setShowError(true);
    }
  }, [savedGames, enqueueSnackbar]);

  // Search for games
  const handleSearch = useCallback(async () => {
    if (!searchQuery.trim()) {
      return;
    }

    try {
      setLoading(true);
      await searchGamesPage(searchQuery, 1);
    } catch (err) {
      console.error("Error searching games:", err);
      setError("Failed to search for games. Please try again later.");
      setShowError(true);
    } finally {
      setLoading(false);
    }
  }, [searchQuery]);

  // Search games with pagination
  const searchGamesPage = async (query: string, page: number) => {
    try {
      const response = await SearchGames(query, page, 20);
      if (response) {
        const resultsWithStatus = updateGameStatuses(response.results || []);
        setSearchResults(resultsWithStatus);
        setTotalPages(Math.ceil((response.count || 0) / 20));
        setCurrentPage(page);
        setShowSearchResults(true);
      }
    } catch (err) {
      console.error("Error searching games:", err);
      throw err;
    }
  };

  // Handle page change
  const handlePageChange = (
    event: React.ChangeEvent<unknown>,
    value: number,
  ) => {
    setCurrentPage(value);
    // Only reload search results when page changes
    if (showSearchResults && searchQuery) {
      searchGamesPage(searchQuery, value);
    }
  };

  // Clear search
  const handleClearSearch = () => {
    setSearchQuery("");
    setSearchResults([]);
    setShowSearchResults(false);
  };

  // Close game details
  const handleCloseDetails = () => {
    setShowGameDetails(false);
  };

  // Handle suggestion feedback
  const handleFeedback = async (outcome: session.Outcome) => {
    if (!suggestedGame) return;

    try {
      setIsProcessingFeedback(true);

      // Call the Go binding to provide feedback
      await ProvideSuggestionFeedback(outcome, suggestedGame.id);

      const message =
        outcome === session.Outcome.liked
          ? `You liked "${suggestedGame.name}"`
          : outcome === session.Outcome.disliked
            ? `You disliked "${suggestedGame.name}"`
            : `Skipped "${suggestedGame.name}"`;

      const variant =
        outcome === session.Outcome.liked
          ? "success"
          : outcome === session.Outcome.disliked
            ? "error"
            : "info";

      enqueueSnackbar(message, { variant: variant as any });

      // Only clear the current suggestion and get a new one if disliked or skipped
      // For "liked", just leave the suggestion in place
      if (outcome !== session.Outcome.liked) {
        setSuggestedGame(null);
        setSuggestionReason(null);

        // Clear localStorage cache
        localStorage.removeItem(CACHED_GAME_SUGGESTION_KEY);
        localStorage.removeItem(CACHED_GAME_REASON_KEY);

        // Short delay for UI feedback
        setTimeout(() => {
          handleGetSuggestion();
        }, 500);
      } else {
        // If liked, just release the processing state without changing anything
        setIsProcessingFeedback(false);
      }
    } catch (error) {
      console.error("Failed to provide feedback:", error);
      enqueueSnackbar("Failed to record your feedback", { variant: "error" });

      // Clear localStorage cache on error to prevent future issues
      localStorage.removeItem(CACHED_GAME_SUGGESTION_KEY);
      localStorage.removeItem(CACHED_GAME_REASON_KEY);

      // Get a new suggestion after a short delay
      setTimeout(() => {
        setSuggestedGame(null);
        setSuggestionReason(null);
        handleGetSuggestion();
      }, 1000);
    } finally {
      // Only set processing to false for non-liked outcomes
      // For liked outcome, we already set it in the success block
      if (outcome !== session.Outcome.liked) {
        setIsProcessingFeedback(false);
      }
    }
  };

  // Get a game suggestion
  const handleGetSuggestion = async () => {
    // Reset any previous error
    setSuggestionError(null);

    // Check if credentials are valid
    if (credentialsError) {
      enqueueSnackbar("Please set up your RAWG credentials in Settings first", {
        variant: "warning",
      });
      return;
    }

    setIsLoadingSuggestion(true);

    try {
      // Call the Go binding to get a game suggestion
      const result = await GetGameSuggestion();

      if (result && result.game) {
        setSuggestedGame(result.game);
        setSuggestionReason(result.reason || null);

        // Cache the suggestion
        localStorage.setItem(
          CACHED_GAME_SUGGESTION_KEY,
          JSON.stringify(result.game),
        );
        localStorage.setItem(CACHED_GAME_REASON_KEY, result.reason || "");
      } else {
        // Handle case where no suggestion is available
        setSuggestionError("No game suggestions available at the moment.");
      }
    } catch (error) {
      console.error("Failed to get game suggestion:", error);
      let errorMessage = "Failed to get game recommendation. Please try again.";

      if (error instanceof Error) {
        // Check for specific error types
        if (error.message.includes("credentials not available")) {
          errorMessage =
            "Game recommendations require RAWG API credentials to be configured.";
          setCredentialsError(true);
        } else if (error.message.includes("rate limit")) {
          errorMessage =
            "OpenAI rate limit reached. Please try again in a few minutes.";
        } else {
          errorMessage = error.message;
        }
      }

      setSuggestionError(errorMessage);
      enqueueSnackbar(errorMessage, { variant: "error" });
    } finally {
      setIsLoadingSuggestion(false);
    }
  };

  // Map game to MediaSuggestionItem
  const mapGameToSuggestionItem = (
    game: bindings.GameWithSavedStatus,
  ): MediaSuggestionItem => {
    return {
      id: game.id,
      title: game.name,
      description: game.description,
      imageUrl: game.background_image || undefined,
      releaseDate: game.released,
      rating: game.rating * 2, // RAWG ratings are out of 5, convert to 10 for consistency
      voteCount: game.ratings_count,
    };
  };

  // Render game poster for suggestion
  const renderGamePoster = (item: MediaSuggestionItem) => {
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
            opacity: isProcessingFeedback ? 0.5 : 1,
            transition: "all 0.2s ease-in-out",
          }}
        />
      </Card>
    );
  };

  // Add the suggested game to favorites
  const handleAddToFavorites = async () => {
    if (!suggestedGame) return;

    try {
      setIsProcessingFeedback(true);

      // Save the game
      await SaveGame(suggestedGame.id);

      // Update local state to reflect the game is now saved
      updateGameSavedStatus(suggestedGame.id, true);

      // Also record this as a "liked" outcome for improving future suggestions
      await ProvideSuggestionFeedback(session.Outcome.liked, suggestedGame.id);

      // Show a success message
      enqueueSnackbar(`Added "${suggestedGame.name}" to favorites`, {
        variant: "success",
      });
    } catch (error) {
      console.error("Failed to add game to favorites:", error);
      enqueueSnackbar("Failed to add game to favorites", { variant: "error" });

      // Clear localStorage cache on error
      localStorage.removeItem(CACHED_GAME_SUGGESTION_KEY);
      localStorage.removeItem(CACHED_GAME_REASON_KEY);

      // Get a new suggestion
      setTimeout(() => {
        setSuggestedGame(null);
        setSuggestionReason(null);
        handleGetSuggestion();
      }, 1000);
    } finally {
      setIsProcessingFeedback(false);
    }
  };

  // Handle game selection
  const handleGameSelect = useCallback(
    async (gameId: number) => {
      try {
        setLoading(true);
        const game = await GetGameDetails(gameId);

        // Add saved status to the selected game
        const gameWithStatus: ExtendedGame = {
          ...game,
          isSaved: isGameSaved(game.id),
          isInWatchlist: isGameInWatchlist(game.id),
        } as ExtendedGame; // Type assertion to fix compatibility

        setSelectedGame(gameWithStatus);
        setShowGameDetails(true);
      } catch (err) {
        console.error("Error fetching game details:", err);
        setError("Failed to fetch game details. Please try again later.");
        setShowError(true);
      } finally {
        setLoading(false);
      }
    },
    [isGameSaved, isGameInWatchlist],
  );

  // Save a game
  const handleSave = useCallback(
    async (game: ExtendedGame) => {
      try {
        const isAlreadySaved = isGameSaved(game.id);

        if (isAlreadySaved) {
          // Remove game from library
          await UnsaveGame(game.id);
          setSavedGames((prev) => prev.filter((g) => g.id !== game.id));
          enqueueSnackbar(`Removed "${game.name}" from your favorites`, {
            variant: "info",
          });
        } else {
          // Add game to library
          await SaveGame(game.id);
          const savedGame = { ...game, isSaved: true };
          setSavedGames((prev) => [...prev, savedGame]);
          enqueueSnackbar(`Added "${game.name}" to your favorites`, {
            variant: "success",
          });
        }

        // Update status in all lists
        updateGameSavedStatus(game.id, !isAlreadySaved);

        // If we have a selected game, update its status too
        if (selectedGame && selectedGame.id === game.id) {
          setSelectedGame({
            ...selectedGame,
            isSaved: !isAlreadySaved,
          });
        }
      } catch (err) {
        console.error("Error saving game:", err);
        enqueueSnackbar(
          "Failed to update your favorites. Please try again later.",
          {
            variant: "error",
          },
        );
      }
    },
    [isGameSaved, enqueueSnackbar, selectedGame, updateGameSavedStatus],
  );

  // Add to watchlist
  const handleAddToWatchlist = useCallback(
    async (game: ExtendedGame) => {
      try {
        // Check if game is already in watchlist
        if (isGameInWatchlist(game.id)) {
          enqueueSnackbar(`"${game.name}" is already in your watchlist`, {
            variant: "info",
          });
          return;
        }

        // Add to watchlist
        await AddGameToWatchlist(game.id);
        const watchlistGame = { ...game, isInWatchlist: true };
        setWatchlistGames((prev) => [...prev, watchlistGame]);

        // Update status in all lists
        updateGameWatchlistStatus(game.id, true);

        // If we have a selected game, update its status too
        if (selectedGame && selectedGame.id === game.id) {
          setSelectedGame({
            ...selectedGame,
            isInWatchlist: true,
          });
        }

        // If this is the current suggestion, get a new suggestion
        if (suggestedGame && suggestedGame.id === game.id) {
          // Also record this as a positive outcome
          await ProvideSuggestionFeedback(session.Outcome.liked, game.id);

          enqueueSnackbar(`Added "${game.name}" to your watchlist`, {
            variant: "success",
          });

          // Clear the current suggestion
          setSuggestedGame(null);
          setSuggestionReason(null);

          // Clear localStorage cache
          localStorage.removeItem(CACHED_GAME_SUGGESTION_KEY);
          localStorage.removeItem(CACHED_GAME_REASON_KEY);

          // Get a new suggestion
          setTimeout(() => {
            handleGetSuggestion();
          }, 500);
        } else {
          enqueueSnackbar(`Added "${game.name}" to your watchlist`, {
            variant: "success",
          });
        }
      } catch (err) {
        console.error("Error adding game to watchlist:", err);
        enqueueSnackbar(
          "Failed to update your watchlist. Please try again later.",
          {
            variant: "error",
          },
        );
      }
    },
    [
      isGameInWatchlist,
      enqueueSnackbar,
      selectedGame,
      suggestedGame,
      updateGameWatchlistStatus,
    ],
  );

  // Remove from watchlist
  const handleRemoveFromWatchlist = useCallback(
    async (gameId: number) => {
      try {
        // Find the game in watchlist
        const game = watchlistGames.find((g) => g.id === gameId);
        if (!game) {
          console.error(`Game with ID ${gameId} not found in watchlist`);
          return;
        }

        // Remove from watchlist
        await RemoveGameFromWatchlist(gameId);

        // Update local state
        setWatchlistGames((prev) => prev.filter((g) => g.id !== gameId));

        // Update status in all lists
        updateGameWatchlistStatus(gameId, false);

        // If we have a selected game, update its status too
        if (selectedGame && selectedGame.id === gameId) {
          setSelectedGame({
            ...selectedGame,
            isInWatchlist: false,
          });
        }

        enqueueSnackbar(`Removed "${game.name}" from your watchlist`, {
          variant: "success",
        });
      } catch (err) {
        console.error("Error removing game from watchlist:", err);
        enqueueSnackbar(
          "Failed to update your watchlist. Please try again later.",
          {
            variant: "error",
          },
        );
      }
    },
    [watchlistGames, enqueueSnackbar, selectedGame, updateGameWatchlistStatus],
  );

  // Like game from watchlist
  const handleLike = useCallback(
    (game: ExtendedGame) => {
      // Add to favorites if not already there
      if (!isGameSaved(game.id)) {
        handleSave(game);
      }

      // Remove from watchlist
      handleRemoveFromWatchlist(game.id);

      // Provide feedback
      ProvideSuggestionFeedback(session.Outcome.liked, game.id)
        .then(() => {
          enqueueSnackbar(
            `You liked "${game.name}" and it was added to your favorites`,
            {
              variant: "success",
            },
          );
        })
        .catch((error) => {
          console.error("Failed to record like feedback:", error);
          // Still show success for the watchlist action even if feedback fails
          enqueueSnackbar(
            `"${game.name}" was moved from watchlist to favorites`,
            {
              variant: "success",
            },
          );
        });
    },
    [isGameSaved, handleSave, handleRemoveFromWatchlist, enqueueSnackbar],
  );

  // Dislike game
  const handleDislike = useCallback(
    (game: ExtendedGame) => {
      // Remove from watchlist
      if (isGameInWatchlist(game.id)) {
        handleRemoveFromWatchlist(game.id);
      }

      // Provide feedback
      ProvideSuggestionFeedback(session.Outcome.disliked, game.id)
        .then(() => {
          enqueueSnackbar(
            `You disliked "${game.name}" and it was removed from your watchlist`,
            {
              variant: "info",
            },
          );
        })
        .catch((error) => {
          console.error("Failed to record dislike feedback:", error);
          // Still show success for the watchlist action even if feedback fails
          enqueueSnackbar(`"${game.name}" was removed from your watchlist`, {
            variant: "info",
          });
        });
    },
    [isGameInWatchlist, handleRemoveFromWatchlist, enqueueSnackbar],
  );

  // Convert platforms for GameDetails component
  const convertPlatforms = useCallback(
    (
      platforms?: rawg.Platform[],
    ): { platform: { id: number; name: string } }[] => {
      if (!platforms) return [];

      return platforms.map((p) => ({
        platform: {
          id: p.platform?.id || 0,
          name: p.platform?.name || "",
        },
      }));
    },
    [],
  );

  return (
    <Box
      sx={{
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
      }}
    >
      {/* API credentials error message */}
      {credentialsError && !isLoadingSuggestion && (
        <Box
          sx={{
            mb: 4,
            p: 3,
            backgroundColor: "rgba(255, 193, 7, 0.1)",
            borderRadius: 2,
            border: "1px solid rgba(255, 193, 7, 0.3)",
          }}
        >
          <Typography variant="h6" color="warning.main" gutterBottom>
            Missing RAWG Credentials
          </Typography>
          <Typography variant="body1">
            The RAWG API credentials are not configured. Please set up your RAWG
            API key in the Settings to use game recommendations.
          </Typography>
          <Button
            variant="outlined"
            color="warning"
            sx={{ mt: 2 }}
            onClick={() => (window.location.href = "#/settings")}
          >
            Go to Settings
          </Button>
        </Box>
      )}

      {/* Search Bar */}
      <Paper sx={{ p: 2, mb: 2 }}>
        <TextField
          fullWidth
          placeholder="Search for games..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          onKeyPress={(e) => e.key === "Enter" && handleSearch()}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchIcon />
              </InputAdornment>
            ),
            endAdornment: searchQuery && (
              <InputAdornment position="end">
                <IconButton onClick={handleClearSearch} edge="end">
                  <ClearIcon />
                </IconButton>
              </InputAdornment>
            ),
          }}
        />
        <Stack direction="row" spacing={2} sx={{ mt: 2 }}>
          <Button
            variant="contained"
            color="primary"
            onClick={handleSearch}
            disabled={!searchQuery.trim()}
          >
            Search
          </Button>
          {showSearchResults && (
            <Button variant="outlined" onClick={handleClearSearch}>
              Clear Results
            </Button>
          )}
        </Stack>
      </Paper>

      {/* Game Suggestion Section */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h5" sx={{ mb: 2 }}>
          Suggested for You
        </Typography>

        <MediaSuggestionDisplay
          mediaType="movie" // Use movie type for consistent styling
          suggestedItem={
            suggestedGame ? mapGameToSuggestionItem(suggestedGame) : null
          }
          suggestionReason={suggestionReason}
          isLoading={isLoadingSuggestion}
          error={suggestionError}
          isProcessing={isProcessingFeedback}
          hasBeenLiked={suggestedGame?.isSaved}
          onRequestSuggestion={handleGetSuggestion}
          onLike={() => {
            // Call the feedback handler
            handleFeedback(session.Outcome.liked);
            // Also update the suggestedGame to show it's now liked
            if (suggestedGame) {
              updateGameSavedStatus(suggestedGame.id, true);
            }
          }}
          onDislike={() => handleFeedback(session.Outcome.disliked)}
          onSkip={() => {
            if (suggestedGame && suggestedGame.isSaved) {
              setSuggestedGame(null);
              setSuggestionReason(null);

              localStorage.removeItem(CACHED_GAME_SUGGESTION_KEY);
              localStorage.removeItem(CACHED_GAME_REASON_KEY);

              handleGetSuggestion();
            } else {
              handleFeedback(session.Outcome.skipped);
            }
          }}
          onAddToLibrary={handleAddToFavorites}
          onAddToWatchlist={
            suggestedGame
              ? () => handleAddToWatchlist(suggestedGame)
              : undefined
          }
          renderImage={renderGamePoster}
        />
      </Box>

      {/* Search Results Section (when visible) */}
      {searchResults.length > 0 && showSearchResults && (
        <Box sx={{ mb: 4 }}>
          <Typography variant="h5" sx={{ mb: 2 }}>
            Search Results
          </Typography>
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
              p: 2,
              "& > div": {
                height: "100%",
              },
            }}
          >
            {searchResults.map((game) => (
              <Box 
                key={`search-${game.id}`}
                onClick={() => handleGameSelect(game.id)}
                sx={{ cursor: 'pointer' }}
              >
                <MediaCard
                  item={{
                    id: game.id,
                    title: game.name,
                    overview: game.description || "",
                    poster_path: game.background_image || "",
                    vote_average: game.rating || 0,
                    vote_count: game.ratings_count || 0,
                    date: game.released || "",
                    mediaType: "movie"  // Use 'movie' since 'game' isn't a valid option
                  }}
                  onSave={() => handleSave(game)}
                  onAddToWatchlist={
                    !game.isInWatchlist
                      ? () => handleAddToWatchlist(game)
                      : undefined
                  }
                  onRemoveFromWatchlist={
                    game.isInWatchlist
                      ? () => handleRemoveFromWatchlist(game.id)
                      : undefined
                  }
                  isSaved={!!game.isSaved}
                  isInWatchlist={!!game.isInWatchlist}
                  view="default"
                />
              </Box>
            ))}
          </Box>

          {totalPages > 1 && (
            <Box sx={{ display: "flex", justifyContent: "center", p: 2 }}>
              <Pagination
                count={totalPages}
                page={currentPage}
                onChange={handlePageChange}
                color="primary"
                size="large"
              />
            </Box>
          )}
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
          onClick={() => setShowWatchlist(!showWatchlist)}
        >
          <Typography variant="h6" sx={{ color: "text.primary" }}>
            Your Watchlist
          </Typography>
          <Typography variant="body2" sx={{ color: "text.secondary", ml: 2 }}>
            {showWatchlist ? "Hide" : "Show"} ({watchlistGames.length})
          </Typography>
        </Box>

        {showWatchlist &&
          (watchlistGames.length === 0 ? (
            <Box
              sx={{
                textAlign: "center",
                py: 4,
                color: "var(--text-secondary)",
              }}
            >
              <Typography variant="body1">
                Your watchlist is empty. Add games to play later by clicking the
                "Add to Watchlist" icon.
              </Typography>
            </Box>
          ) : (
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
                p: 2,
                "& > div": {
                  height: "100%",
                },
              }}
            >
              {watchlistGames.map((game) => (
                <Box 
                  key={`watchlist-${game.id}`}
                  onClick={() => handleGameSelect(game.id)}
                  sx={{ cursor: 'pointer' }}
                >
                  <MediaCard
                    item={{
                      id: game.id,
                      title: game.name,
                      overview: game.description || "",
                      poster_path: game.background_image || "",
                      vote_average: game.rating || 0,
                      vote_count: game.ratings_count || 0, 
                      date: game.released || "",
                      mediaType: "movie"
                    }}
                    onSave={() => handleSave(game)}
                    onRemoveFromWatchlist={() =>
                      handleRemoveFromWatchlist(game.id)
                    }
                    onLike={() => handleLike(game)}
                    onDislike={() => handleDislike(game)}
                    isSaved={!!game.isSaved}
                    isInWatchlist={true}
                    view="watchlist"
                  />
                </Box>
              ))}
            </Box>
          ))}
      </Box>

      {/* Favorites/Library Section */}
      <Box sx={{ mb: 4 }}>
        <Box
          sx={{
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
            mb: 2,
            cursor: "pointer",
          }}
          onClick={() => setShowLibrary(!showLibrary)}
        >
          <Typography variant="h6" sx={{ color: "text.primary" }}>
            Your Library
          </Typography>
          <Typography variant="body2" sx={{ color: "text.secondary", ml: 2 }}>
            {showLibrary ? "Hide" : "Show"} ({savedGames.length})
          </Typography>
        </Box>

        {showLibrary &&
          (savedGames.length === 0 ? (
            <Box
              sx={{
                textAlign: "center",
                py: 4,
                color: "var(--text-secondary)",
              }}
            >
              <Typography variant="body1">
                You haven't saved any games yet. Search for games and click the
                heart icon to add them to your favorites.
              </Typography>
            </Box>
          ) : (
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
                p: 2,
                "& > div": {
                  height: "100%",
                },
              }}
            >
              {savedGames.map((game) => (
                <Box 
                  key={`saved-${game.id}`}
                  onClick={() => handleGameSelect(game.id)}
                  sx={{ cursor: 'pointer' }}
                >
                  <MediaCard
                    item={{
                      id: game.id,
                      title: game.name,
                      overview: game.description || "",
                      poster_path: game.background_image || "",
                      vote_average: game.rating || 0,
                      vote_count: game.ratings_count || 0,
                      date: game.released || "",
                      mediaType: "movie"
                    }}
                    onSave={() => handleSave(game)}
                    onAddToWatchlist={
                      !game.isInWatchlist
                        ? () => handleAddToWatchlist(game)
                        : undefined
                    }
                    isSaved={true}
                    isInWatchlist={!!game.isInWatchlist}
                    view="default"
                  />
                </Box>
              ))}
            </Box>
          ))}
      </Box>

      {/* Popular Games Section */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h6" sx={{ mb: 2 }}>
          Popular Games
        </Typography>

        {loading ? (
          <Box sx={{ display: "flex", justifyContent: "center", p: 3 }}>
            <CircularProgress />
          </Box>
        ) : popularGames.length === 0 ? (
          <Box
            sx={{ textAlign: "center", py: 4, color: "var(--text-secondary)" }}
          >
            <Typography variant="body1">
              No popular games found. Please check your internet connection.
            </Typography>
          </Box>
        ) : (
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
            {popularGames.slice(0, 10).map((game) => (
              <Box 
                key={`popular-${game.id}`}
                onClick={() => handleGameSelect(game.id)}
                sx={{ cursor: 'pointer' }}
              >
                <MediaCard
                  item={{
                    id: game.id,
                    title: game.name,
                    overview: game.description || "",
                    poster_path: game.background_image || "",
                    vote_average: game.rating || 0,
                    vote_count: game.ratings_count || 0,
                    date: game.released || "",
                    mediaType: "movie"
                  }}
                  onSave={() => handleSave(game)}
                  onAddToWatchlist={
                    !game.isInWatchlist
                      ? () => handleAddToWatchlist(game)
                      : undefined
                  }
                  isSaved={!!game.isSaved}
                  isInWatchlist={!!game.isInWatchlist}
                  view="default"
                />
              </Box>
            ))}
          </Box>
        )}
      </Box>

      {/* Error snackbar */}
      <Snackbar
        open={showError}
        autoHideDuration={6000}
        onClose={() => setShowError(false)}
      >
        <Alert onClose={() => setShowError(false)} severity="error">
          {error}
        </Alert>
      </Snackbar>

      {/* Game details dialog */}
      {showGameDetails && selectedGame && (
        <GameDetailDialog
          open={showGameDetails}
          game={selectedGame as any}
          platforms={convertPlatforms(selectedGame.platforms)}
          onClose={handleCloseDetails}
          onSave={() => handleSave(selectedGame)}
          onAddToWatchlist={
            !selectedGame.isInWatchlist
              ? () => handleAddToWatchlist(selectedGame)
              : undefined
          }
          onRemoveFromWatchlist={
            selectedGame.isInWatchlist
              ? () => handleRemoveFromWatchlist(selectedGame.id)
              : undefined
          }
          isSaved={!!selectedGame.isSaved}
          isInWatchlist={!!selectedGame.isInWatchlist}
        />
      )}
    </Box>
  );
});

export default GameSection;

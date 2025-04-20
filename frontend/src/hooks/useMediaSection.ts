import { useState, useEffect, useRef, useCallback } from "react";
import { session } from "@wailsjs/go/models";
import { useSnackbar } from "notistack";
import { SuggestionCache } from "@/utils/suggestionCache";
import { MediaSuggestionItem } from "@/components/common/MediaSuggestionDisplay";

// Generic interface for media items with common properties
export interface MediaItemBase {
  id: number;
  title?: string;
  name?: string; // TV shows use name instead of title
  isSaved?: boolean;
  isInWatchlist?: boolean;
  poster_path?: string;
  background_image?: string; // Games use this instead of poster_path
}

// Options for the hook
export interface UseMediaSectionOptions<T extends MediaItemBase> {
  type: "movie" | "tv" | "game" | "book";
  // Core API functions
  checkCredentials: () => Promise<boolean>;
  getSuggestion: () => Promise<{ media: T; reason: string }>;
  provideFeedback: (outcome: session.Outcome, id: number) => Promise<void>;
  loadSavedItems: () => Promise<T[]>;
  loadWatchlistItems: () => Promise<T[]>;
  searchItems: (query: string) => Promise<T[]>;
  saveItem: (item: T) => Promise<void>;
  removeItem: (item: T) => Promise<void>;
  addToWatchlist: (item: T) => Promise<void>;
  removeFromWatchlist: (item: T) => Promise<void>;

  // Local storage keys
  cachedSuggestionKey: string;
  cachedReasonKey: string;

  // Optional functions for specific media types
  getItemDetails?: (id: number) => Promise<T>;

  queueListName?: string;
}

export function useMediaSection<T extends MediaItemBase>(
  options: UseMediaSectionOptions<T>,
) {
  const {
    type,
    checkCredentials,
    getSuggestion,
    provideFeedback,
    loadSavedItems,
    loadWatchlistItems,
    searchItems,
    saveItem,
    removeItem,
    addToWatchlist,
    removeFromWatchlist,
    cachedSuggestionKey,
    cachedReasonKey,
    getItemDetails,
    queueListName = "Watchlist", // Default if not provided
  } = options;

  // Convert MediaItemBase to MediaSuggestionItem for SuggestionCache
  const toMediaSuggestionItem = (item: T): MediaSuggestionItem => {
    let enhancedItem: any = {
      id: item.id,
      title: item.title || item.name || 'Unknown Title',
      imageUrl: item.poster_path || item.background_image,
      description: '',  // Provide defaults for required MediaSuggestionItem properties
      artist: '',
    };

    // For all media types, store type-specific data in customFields
    const customFields: Record<string, any> = {
      isSaved: item.isSaved,
      isInWatchlist: item.isInWatchlist,
    };

    // Handle book-specific properties
    if (type === "book") {
      // Book items have special properties like author and cover_path
      const bookItem = item as any;
      
      // Use proper book fields for standard fields
      enhancedItem.imageUrl = bookItem.cover_path;
      enhancedItem.artist = bookItem.author ? `by ${bookItem.author}` : '';
      enhancedItem.description = bookItem.description || '';
      
      // Add book-specific fields to customFields
      customFields.author = bookItem.author;
      customFields.key = bookItem.key;
      customFields.cover_path = bookItem.cover_path;
      customFields.year = bookItem.year;
      customFields.subjects = bookItem.subjects;
    } 
    // Handle movie-specific properties
    else if (type === "movie") {
      const movieItem = item as any;
      
      // Use proper movie fields for standard fields
      enhancedItem.imageUrl = movieItem.poster_path;
      enhancedItem.description = movieItem.overview || '';
      
      // Add movie-specific fields to customFields
      customFields.poster_path = movieItem.poster_path;
      customFields.backdrop_path = movieItem.backdrop_path;
      customFields.overview = movieItem.overview;
      customFields.release_date = movieItem.release_date;
      customFields.vote_average = movieItem.vote_average;
      customFields.vote_count = movieItem.vote_count;
      customFields.genres = movieItem.genres;
    }
    // Handle TV-specific properties
    else if (type === "tv") {
      const tvItem = item as any;
      
      // Use TV show name as title if available
      enhancedItem.title = tvItem.name || tvItem.title || 'Unknown TV Show';
      enhancedItem.imageUrl = tvItem.poster_path;
      enhancedItem.description = tvItem.overview || '';
      
      // Add TV-specific fields to customFields
      customFields.name = tvItem.name;
      customFields.poster_path = tvItem.poster_path;
      customFields.backdrop_path = tvItem.backdrop_path;
      customFields.overview = tvItem.overview;
      customFields.first_air_date = tvItem.first_air_date;
      customFields.vote_average = tvItem.vote_average;
      customFields.vote_count = tvItem.vote_count;
      customFields.genres = tvItem.genres;
      customFields.number_of_seasons = tvItem.number_of_seasons;
    }
    // Handle game-specific properties
    else if (type === "game") {
      const gameItem = item as any;
      
      enhancedItem.imageUrl = gameItem.background_image;
      enhancedItem.description = gameItem.description_raw || gameItem.description || '';
      
      // Add game-specific fields to customFields
      customFields.name = gameItem.name;
      customFields.background_image = gameItem.background_image;
      customFields.description_raw = gameItem.description_raw;
      customFields.released = gameItem.released;
      customFields.rating = gameItem.rating;
      customFields.ratings_count = gameItem.ratings_count;
      customFields.genres = gameItem.genres;
      customFields.platforms = gameItem.platforms;
      customFields.developers = gameItem.developers;
      customFields.publishers = gameItem.publishers;
    }

    // Add the customFields to the enhanced item
    enhancedItem.customFields = customFields;

    return enhancedItem as MediaSuggestionItem;
  };

  const { enqueueSnackbar } = useSnackbar();

  // Common state
  const [searchResults, setSearchResults] = useState<T[]>([]);
  const [showSearchResults, setShowSearchResults] = useState(false);
  const [savedItems, setSavedItems] = useState<T[]>([]);
  const [watchlistItems, setWatchlistItems] = useState<T[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingSuggestion, setIsLoadingSuggestion] = useState(false);
  const [suggestedItem, setSuggestedItem] = useState<T | null>(null);
  const [suggestionReason, setSuggestionReason] = useState<string | null>(null);
  const [credentialsError, setCredentialsError] = useState(false);
  const [suggestionError, setSuggestionError] = useState<string | null>(null);
  const [isProcessingFeedback, setIsProcessingFeedback] = useState(false);
  const [showWatchlist, setShowWatchlist] = useState(true);
  const [showLibrary, setShowLibrary] = useState(true);

  const searchResultsRef = useRef<HTMLDivElement>(null);

  // Initial load
  useEffect(() => {
    const loadInitialData = async () => {
      try {
        const hasCredentials = await checkCredentials();
        setCredentialsError(!hasCredentials);

        await loadLibraryItems();
        await loadWatchlistFromAPI();

        // Try to load cached suggestion using SuggestionCache
        const { item: cachedItem, reason: cachedReason } = SuggestionCache.getItem(type);

        if (cachedItem && cachedReason) {
          try {
            // Check if this is an enhanced item with customFields
            let parsedItem: T;
            if ((cachedItem as any).customFields) {
              const enhancedFields = (cachedItem as any).customFields;
              
              // Handle different media types
              if (type === "book") {
                // Create a book item with all the necessary fields
                parsedItem = {
                  id: typeof cachedItem.id === 'number' ? cachedItem.id : parseInt(cachedItem.id as string, 10),
                  title: cachedItem.title,
                  description: cachedItem.description,
                  // Book-specific fields
                  author: enhancedFields.author || (cachedItem.artist ? cachedItem.artist.replace('by ', '') : ''),
                  cover_path: enhancedFields.cover_path || cachedItem.imageUrl,
                  key: enhancedFields.key || `book-${cachedItem.id}`,
                  year: enhancedFields.year,
                  subjects: enhancedFields.subjects || [],
                  isSaved: enhancedFields.isSaved || false,
                  isInWatchlist: enhancedFields.isInWatchlist || false
                } as any as T;
                
                console.log("Restored enhanced book item from cache:", parsedItem);
              } 
              else if (type === "movie") {
                parsedItem = {
                  id: typeof cachedItem.id === 'number' ? cachedItem.id : parseInt(cachedItem.id as string, 10),
                  title: cachedItem.title,
                  // Movie-specific fields
                  poster_path: enhancedFields.poster_path || cachedItem.imageUrl,
                  backdrop_path: enhancedFields.backdrop_path,
                  overview: enhancedFields.overview || cachedItem.description,
                  release_date: enhancedFields.release_date,
                  vote_average: enhancedFields.vote_average,
                  vote_count: enhancedFields.vote_count,
                  genres: enhancedFields.genres,
                  isSaved: enhancedFields.isSaved || false,
                  isInWatchlist: enhancedFields.isInWatchlist || false
                } as any as T;
                
                console.log("Restored enhanced movie item from cache:", parsedItem);
              }
              else if (type === "tv") {
                parsedItem = {
                  id: typeof cachedItem.id === 'number' ? cachedItem.id : parseInt(cachedItem.id as string, 10),
                  title: cachedItem.title,
                  name: enhancedFields.name || cachedItem.title,
                  // TV-specific fields
                  poster_path: enhancedFields.poster_path || cachedItem.imageUrl,
                  backdrop_path: enhancedFields.backdrop_path,
                  overview: enhancedFields.overview || cachedItem.description,
                  first_air_date: enhancedFields.first_air_date,
                  vote_average: enhancedFields.vote_average,
                  vote_count: enhancedFields.vote_count,
                  genres: enhancedFields.genres,
                  number_of_seasons: enhancedFields.number_of_seasons,
                  isSaved: enhancedFields.isSaved || false,
                  isInWatchlist: enhancedFields.isInWatchlist || false
                } as any as T;
                
                console.log("Restored enhanced TV item from cache:", parsedItem);
              }
              else if (type === "game") {
                parsedItem = {
                  id: typeof cachedItem.id === 'number' ? cachedItem.id : parseInt(cachedItem.id as string, 10),
                  title: cachedItem.title,
                  name: enhancedFields.name || cachedItem.title,
                  // Game-specific fields
                  background_image: enhancedFields.background_image || cachedItem.imageUrl,
                  description: enhancedFields.description_raw || cachedItem.description,
                  description_raw: enhancedFields.description_raw,
                  released: enhancedFields.released,
                  rating: enhancedFields.rating,
                  ratings_count: enhancedFields.ratings_count,
                  genres: enhancedFields.genres,
                  platforms: enhancedFields.platforms,
                  developers: enhancedFields.developers,
                  publishers: enhancedFields.publishers,
                  isSaved: enhancedFields.isSaved || false,
                  isInWatchlist: enhancedFields.isInWatchlist || false
                } as any as T;
                
                console.log("Restored enhanced game item from cache:", parsedItem);
              }
              else {
                // For other media types or without specific handling
                parsedItem = {
                  ...cachedItem,
                  ...enhancedFields,
                  id: typeof cachedItem.id === 'number' ? cachedItem.id : parseInt(cachedItem.id as string, 10)
                } as T;
              }
            } else {
              // For items without customFields (backwards compatibility)
              parsedItem = cachedItem as T;
            }
            
            setSuggestedItem(parsedItem);
            setSuggestionReason(cachedReason);

            // Validate the cached suggestion if we have a getItemDetails function
            if (getItemDetails && parsedItem.id) {
              try {
                await getItemDetails(parsedItem.id);
                console.log(`Cached ${type} suggestion is valid`);
              } catch (error) {
                console.log(
                  `Cached ${type} suggestion is no longer valid, getting a new one`,
                );
                // Clear cache using SuggestionCache
                SuggestionCache.clearItem(type);
                // Get a new suggestion
                handleGetSuggestion();
              }
            }
          } catch (e) {
            console.error(`Failed to parse cached ${type} suggestion:`, e);
            // If parsing fails, get a new suggestion
            SuggestionCache.clearItem(type);
            handleGetSuggestion();
          }
        } else {
          // No cached suggestion, get a new one
          handleGetSuggestion();
        }
      } catch (error) {
        console.error("Error loading initial data:", error);
        setCredentialsError(true);
      }
    };

    loadInitialData();

    // Save suggestion using SuggestionCache when component unmounts
    return () => {
      if (suggestedItem && suggestionReason) {
        SuggestionCache.saveItem(type, toMediaSuggestionItem(suggestedItem), suggestionReason);
      }
    };
  }, []);

  // Update cached suggestion whenever it changes
  useEffect(() => {
    if (suggestedItem && suggestionReason) {
      SuggestionCache.saveItem(type, toMediaSuggestionItem(suggestedItem), suggestionReason);
    }
  }, [suggestedItem, suggestionReason]);

  // Effect to add click outside listener for search results
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        searchResultsRef.current &&
        !searchResultsRef.current.contains(event.target as Node)
      ) {
        // Check if the click is on the NowPlayingBar
        const nowPlayingBar = document.querySelector(".now-playing-bar");
        if (nowPlayingBar && nowPlayingBar.contains(event.target as Node)) {
          // Don't close search results when clicking on the now playing bar
          return;
        }

        setShowSearchResults(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);

    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, []);

  // Update showSearchResults when search results change
  useEffect(() => {
    if (searchResults && searchResults.length > 0) {
      setShowSearchResults(true);
    } else {
      setShowSearchResults(false);
    }
  }, [searchResults]);

  // Load library items
  const loadLibraryItems = async () => {
    try {
      const items = await loadSavedItems();
      setSavedItems(items || []);
      return items || [];
    } catch (error) {
      console.error(`Failed to load saved ${type} items:`, error);
      enqueueSnackbar(`Failed to load your ${type} library`, {
        variant: "error",
      });
      return [];
    }
  };

  // Load watchlist items
  const loadWatchlistFromAPI = async () => {
    try {
      const items = await loadWatchlistItems();
      setWatchlistItems(items || []);
      return items || [];
    } catch (error) {
      console.error(
        `Failed to load ${type} ${queueListName.toLowerCase()}:`,
        error,
      );
      enqueueSnackbar(
        `Failed to load your ${type} ${queueListName.toLowerCase()}`,
        {
          variant: "error",
        },
      );
      return [];
    }
  };

  // Search for items
  const handleSearch = async (query: string): Promise<void> => {
    if (!query.trim()) {
      setSearchResults([]);
      setShowSearchResults(false);
      return;
    }

    setIsLoading(true);
    try {
      const results = await searchItems(query);

      // Mark items that are already saved
      const resultsWithSavedStatus = results.map((item) => {
        const itemTitle = item.title || item.name || "";
        const isSaved = savedItems.some((saved) => {
          const savedTitle = saved.title || saved.name || "";
          return savedTitle.toLowerCase() === itemTitle.toLowerCase();
        });

        const isInWatchlist = watchlistItems.some((watchlist) => {
          const watchlistTitle = watchlist.title || watchlist.name || "";
          return watchlistTitle.toLowerCase() === itemTitle.toLowerCase();
        });

        return { ...item, isSaved, isInWatchlist };
      });

      setSearchResults(resultsWithSavedStatus);
      setShowSearchResults(true);
      setCredentialsError(false);

      // Scroll to search results
      setTimeout(() => {
        searchResultsRef.current?.scrollIntoView({ behavior: "smooth" });
      }, 100);
    } catch (error) {
      console.error(`Search ${type} error:`, error);

      // Check if this is a credentials error
      if (
        error instanceof Error &&
        error.message.includes("credentials not available")
      ) {
        setCredentialsError(true);
        enqueueSnackbar("API credentials are not configured", {
          variant: "warning",
        });
      } else {
        enqueueSnackbar(`Failed to search ${type}. Please try again.`, {
          variant: "error",
        });
      }
    } finally {
      setIsLoading(false);
    }
  };

  // Handle saving/unsaving items
  const handleSave = async (item: T) => {
    if (!item) return;

    try {
      setIsLoading(true);

      if (item.isSaved) {
        // Remove from saved items
        await removeItem(item);

        // Update local state
        setSavedItems((prev) => {
          return prev.filter((saved) => {
            // Match by ID if available, otherwise by title/name
            if (item.id && saved.id) {
              return saved.id !== item.id;
            } else {
              const savedTitle = saved.title || saved.name || "";
              const itemTitle = item.title || item.name || "";
              return savedTitle.toLowerCase() !== itemTitle.toLowerCase();
            }
          });
        });

        enqueueSnackbar(
          `Removed "${item.title || item.name}" from your library`,
          {
            variant: "success",
          },
        );
      } else {
        // Add to saved items
        await saveItem(item);

        // Check if item already exists in library to prevent duplicates
        const exists = savedItems.some((saved) => {
          // Match by ID if available, otherwise by title/name
          if (item.id && saved.id) {
            return saved.id === item.id;
          } else {
            const savedTitle = saved.title || saved.name || "";
            const itemTitle = item.title || item.name || "";
            return savedTitle.toLowerCase() === itemTitle.toLowerCase();
          }
        });

        if (!exists) {
          setSavedItems((prev) => [...prev, { ...item, isSaved: true }]);
        }

        enqueueSnackbar(`Added "${item.title || item.name}" to your library`, {
          variant: "success",
        });
      }

      // Update the search results to reflect the new saved status
      setSearchResults((prev) =>
        prev.map((i) => {
          const isMatch =
            i.id && item.id
              ? i.id === item.id
              : (i.title || i.name || "").toLowerCase() ===
                (item.title || item.name || "").toLowerCase();

          return isMatch ? { ...i, isSaved: !item.isSaved } : i;
        }),
      );

      // Update watchlist items to reflect the new saved status
      setWatchlistItems((prev) =>
        prev.map((i) => {
          const isMatch =
            i.id && item.id
              ? i.id === item.id
              : (i.title || i.name || "").toLowerCase() ===
                (item.title || item.name || "").toLowerCase();

          return isMatch ? { ...i, isSaved: !item.isSaved } : i;
        }),
      );

      // If this is our suggested item, update its status too
      if (suggestedItem) {
        const isMatch =
          suggestedItem.id && item.id
            ? suggestedItem.id === item.id
            : (
                suggestedItem.title ||
                suggestedItem.name ||
                ""
              ).toLowerCase() === (item.title || item.name || "").toLowerCase();

        if (isMatch) {
          setSuggestedItem({
            ...suggestedItem,
            isSaved: !item.isSaved,
          } as T);
        }
      }
    } catch (error) {
      console.error("Failed to update item:", error);
      enqueueSnackbar("Failed to update library status", { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  // Handle feedback for suggestions
  const handleFeedback = async (outcome: session.Outcome) => {
    if (!suggestedItem) return;

    try {
      setIsProcessingFeedback(true);

      // Call the API to provide feedback
      await provideFeedback(outcome, suggestedItem.id);

      const message =
        outcome === session.Outcome.liked
          ? `You liked "${suggestedItem.title || suggestedItem.name}"`
          : outcome === session.Outcome.disliked
            ? `You disliked "${suggestedItem.title || suggestedItem.name}"`
            : `Skipped "${suggestedItem.title || suggestedItem.name}"`;

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
        setSuggestedItem(null);
        setSuggestionReason(null);

        // Clear cache using SuggestionCache
        SuggestionCache.clearItem(type);

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

      // Clear cache using SuggestionCache
      SuggestionCache.clearItem(type);

      // Get a new suggestion after a short delay
      setTimeout(() => {
        setSuggestedItem(null);
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

  // Get a suggestion
  const handleGetSuggestion = async () => {
    // Reset any previous error
    setSuggestionError(null);

    // Check if credentials are valid
    if (credentialsError) {
      enqueueSnackbar("Please set up your API credentials in Settings first", {
        variant: "warning",
      });
      return;
    }

    setIsLoadingSuggestion(true);

    try {
      // Call the API to get a suggestion
      const result = await getSuggestion();

      if (result && result.media) {
        setSuggestedItem(result.media);
        setSuggestionReason(result.reason || null);

        // Cache the suggestion using SuggestionCache
        SuggestionCache.saveItem(type, toMediaSuggestionItem(result.media), result.reason || "");
      } else {
        // Handle case where no suggestion is available
        setSuggestionError(`No ${type} suggestions available at the moment.`);
      }
    } catch (error) {
      console.error(`Failed to get ${type} suggestion:`, error);
      let errorMessage = `Failed to get ${type} recommendation. Please try again.`;

      if (error instanceof Error) {
        // Check for specific error types
        if (error.message.includes("credentials not available")) {
          errorMessage = `${type} recommendations require API credentials to be configured.`;
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

  // Add to watchlist
  const handleAddToWatchlist = async (item: T) => {
    try {
      setIsLoading(true);

      // Check if item is already in watchlist
      const itemTitle = item.title || item.name || "";
      const isInWatchlist = watchlistItems.some((watchlist) => {
        const watchlistTitle = watchlist.title || watchlist.name || "";
        return watchlistTitle.toLowerCase() === itemTitle.toLowerCase();
      });

      if (isInWatchlist) {
        enqueueSnackbar(
          `"${itemTitle}" is already in your ${queueListName.toLowerCase()}`,
          {
            variant: "info",
          },
        );
        return;
      }

      // Add to watchlist
      await addToWatchlist(item);

      // Update local state
      setWatchlistItems((prev) => [...prev, { ...item, isInWatchlist: true }]);

      // Show success message
      enqueueSnackbar(
        `Added "${itemTitle}" to your ${queueListName.toLowerCase()}`,
        {
          variant: "success",
        },
      );

      // Check if this item is the current suggestion
      const isCurrentSuggestion =
        suggestedItem &&
        (suggestedItem.id === item.id ||
          suggestedItem.title === item.title ||
          suggestedItem.name === item.name);

      // If this is the current suggestion, get a new suggestion
      if (isCurrentSuggestion) {
        // Clear the current suggestion
        setSuggestedItem(null);
        setSuggestionReason(null);

        // Clear cache using SuggestionCache
        SuggestionCache.clearItem(type);

        // Get a new suggestion after a short delay for better UX
        setTimeout(() => {
          handleGetSuggestion();
        }, 500);

        // Also record this as a positive outcome
        if (item.id > 0) {
          await provideFeedback(session.Outcome.liked, item.id);
        }
      }
    } catch (error) {
      console.error(
        `Failed to add ${type} to ${queueListName.toLowerCase()}:`,
        error,
      );
      enqueueSnackbar(`Failed to update your ${queueListName.toLowerCase()}`, {
        variant: "error",
      });
    } finally {
      setIsLoading(false);
    }
  };

  // Remove from watchlist
  const handleRemoveFromWatchlist = async (item: T) => {
    try {
      setIsLoading(true);

      // Remove from watchlist
      await removeFromWatchlist(item);

      // Get the item identifiers for filtering
      const itemTitle = item.title || item.name || "";
      console.log(
        `Removing from ${queueListName.toLowerCase()}: '${itemTitle}'`,
      );

      // Update local state with more precise filtering
      setWatchlistItems((prev) => {
        // Log current items to debug
        console.log(
          "Current watchlist items:",
          prev.map((i) => i.title || i.name),
        );

        return prev.filter((watchlist) => {
          // First check if both items have IDs
          if (item.id && watchlist.id) {
            if (watchlist.id === item.id) {
              // If IDs match, remove the item
              return false;
            } else {
              // If IDs don't match, keep the item
              return true;
            }
          }

          // Otherwise compare by title/name
          const watchlistTitle = watchlist.title || watchlist.name || "";
          const itemTitle = item.title || item.name || "";
          return watchlistTitle.toLowerCase() !== itemTitle.toLowerCase();
        });
      });

      // Show success message
      enqueueSnackbar(
        `Removed "${itemTitle}" from your ${queueListName.toLowerCase()}`,
        {
          variant: "success",
        },
      );
    } catch (error) {
      console.error(
        `Failed to remove ${type} from ${queueListName.toLowerCase()}:`,
        error,
      );
      enqueueSnackbar(`Failed to update your ${queueListName.toLowerCase()}`, {
        variant: "error",
      });
    } finally {
      setIsLoading(false);
    }
  };

  // Handle moving an item from watchlist to favorites
  const handleWatchlistToFavorites = async (item: T) => {
    try {
      setIsLoading(true);

      // Check if the item is already in favorites by comparing title/name or ID
      const alreadyInFavorites = savedItems.some((savedItem) => {
        if (item.id && savedItem.id) {
          return savedItem.id === item.id;
        } else {
          const savedTitle = savedItem.title || savedItem.name || "";
          const itemTitle = item.title || item.name || "";
          return savedTitle.toLowerCase() === itemTitle.toLowerCase();
        }
      });

      if (!alreadyInFavorites) {
        // Only add to favorites if not already there
        await saveItem(item);

        // Update local state
        setSavedItems((prev) => [...prev, { ...item, isSaved: true }]);

        // Record positive feedback
        await provideFeedback(session.Outcome.liked, item.id);

        // Show success message for adding to favorites
        enqueueSnackbar(`Moved "${item.title || item.name}" to your library`, {
          variant: "success",
        });
      } else {
        // Item already exists in favorites, just remove from watchlist
        enqueueSnackbar(
          `Removed "${item.title || item.name}" from your ${queueListName.toLowerCase()}`,
          {
            variant: "success",
          },
        );
      }

      // Remove from watchlist
      await removeFromWatchlist(item);

      // Update local state with the same correct filtering logic as handleRemoveFromWatchlist
      setWatchlistItems((prev) => {
        return prev.filter((watchlist) => {
          // First check if both items have IDs
          if (item.id && watchlist.id) {
            if (watchlist.id === item.id) {
              // If IDs match, remove the item
              return false;
            } else {
              // If IDs don't match, keep the item
              return true;
            }
          }
          
          // Otherwise compare by title/name
          const watchlistTitle = watchlist.title || watchlist.name || "";
          const itemTitle = item.title || item.name || "";
          return watchlistTitle.toLowerCase() !== itemTitle.toLowerCase();
        });
      });
    } catch (error) {
      console.error(
        `Failed to move ${type} from ${queueListName.toLowerCase()} to favorites:`,
        error,
      );
      enqueueSnackbar("Failed to update your media", { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  // Handle add to favorites from suggestion
  const handleAddToFavorites = async () => {
    if (!suggestedItem) return;

    try {
      setIsProcessingFeedback(true);

      // Save the item
      await handleSave({ ...suggestedItem, isSaved: false } as T);

      // Also record this as a "liked" outcome for improving future suggestions
      await provideFeedback(session.Outcome.liked, suggestedItem.id);

      // Show a success message
      enqueueSnackbar(
        `Added "${suggestedItem.title || suggestedItem.name}" to favorites`,
        {
          variant: "success",
        },
      );
    } catch (error) {
      console.error(`Failed to add ${type} to favorites:`, error);
      enqueueSnackbar(`Failed to add ${type} to favorites`, {
        variant: "error",
      });

      // Clear cache using SuggestionCache
      SuggestionCache.clearItem(type);

      // Get a new suggestion
      setTimeout(() => {
        setSuggestedItem(null);
        setSuggestionReason(null);
        handleGetSuggestion();
      }, 1000);
    } finally {
      setIsProcessingFeedback(false);
    }
  };

  // Handle watchlist feedback (like/dislike)
  const handleWatchlistFeedback = async (
    item: T,
    action: "like" | "dislike",
  ) => {
    try {
      setIsLoading(true);

      // Record feedback
      await provideFeedback(
        action === "like" ? session.Outcome.liked : session.Outcome.disliked,
        item.id,
      );

      // If liked, add to library if not already there
      if (action === "like" && !item.isSaved) {
        await handleSave({ ...item, isSaved: false } as T);
      }

      // Remove from watchlist
      await handleRemoveFromWatchlist(item);

      // Show success message
      const message =
        action === "like"
          ? `You liked "${item.title || item.name}"`
          : `You disliked "${item.title || item.name}"`;

      enqueueSnackbar(message, {
        variant: action === "like" ? "success" : "error",
      });
    } catch (error) {
      console.error(`Failed to record ${action} for ${type}:`, error);
      enqueueSnackbar(`Failed to record your ${action}`, { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  // Clear search
  const handleClearSearch = () => {
    setSearchResults([]);
    setShowSearchResults(false);
  };

  return {
    // State
    searchResults,
    showSearchResults,
    savedItems,
    watchlistItems,
    isLoading,
    isLoadingSuggestion,
    suggestedItem,
    suggestionReason,
    credentialsError,
    suggestionError,
    isProcessingFeedback,
    showWatchlist,
    showLibrary,
    searchResultsRef,

    // Actions
    setSavedItems,
    setWatchlistItems,
    setShowWatchlist,
    setShowLibrary,
    checkCredentials,
    handleSearch,
    handleClearSearch,
    handleSave,
    handleFeedback,
    handleGetSuggestion,
    handleAddToWatchlist,
    handleRemoveFromWatchlist,
    handleAddToFavorites,
    handleWatchlistFeedback,
    handleWatchlistToFavorites,
  };
}

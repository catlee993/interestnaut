import React, {
  useState,
  useEffect,
  useRef,
  forwardRef,
  useImperativeHandle,
} from "react";
import {
  Box,
  Typography,
  Divider,
  Grid,
  Button,
  CircularProgress,
  Card,
  CardMedia,
  styled,
} from "@mui/material";
import { TVShowCard } from "@/components/tv/TVShowCard";
import { TVShowSuggestion } from "@/components/tv/TVShowSuggestion";
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
import { useSnackbar } from "notistack";
import { session } from "@wailsjs/go/models";
import {
  MediaSuggestionDisplay,
  MediaSuggestionItem,
} from "@/components/common/MediaSuggestionDisplay";

// Extended interface to include isSaved property
interface ExtendedTVShowWithSavedStatus extends bindings.TVShowWithSavedStatus {
  isSaved?: boolean;
}

// Define the TV show suggestion type
interface TVShowSuggestionData {
  show: bindings.TVShowWithSavedStatus;
  reason: string;
}

export interface TVShowSectionHandle {
  handleClearSearch: () => void;
  handleSearch: (query: string) => Promise<void>;
}

export const TVShowSection = forwardRef<TVShowSectionHandle, {}>((props, ref) => {
  const { enqueueSnackbar } = useSnackbar();
  const [searchResults, setSearchResults] = useState<ExtendedTVShowWithSavedStatus[]>(
    [],
  );
  const [showSearchResults, setShowSearchResults] = useState(true);
  const [savedShows, setSavedShows] = useState<ExtendedTVShowWithSavedStatus[]>(
    [],
  );
  const [watchlistShows, setWatchlistShows] = useState<ExtendedTVShowWithSavedStatus[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingSuggestion, setIsLoadingSuggestion] = useState(false);
  const [suggestedShow, setSuggestedShow] =
    useState<ExtendedTVShowWithSavedStatus | null>(null);
  const [suggestionReason, setSuggestionReason] = useState<string | null>(null);
  const [credentialsError, setCredentialsError] = useState(false);
  const [suggestionError, setSuggestionError] = useState<string | null>(null);
  const [isProcessingFeedback, setIsProcessingFeedback] = useState(false);
  const [showWatchlist, setShowWatchlist] = useState(true);
  const [showLibrary, setShowLibrary] = useState(true);

  const searchResultsRef = useRef<HTMLDivElement>(null);

  // Local storage keys
  const CACHED_SHOW_SUGGESTION_KEY = "cached_tv_suggestion";
  const CACHED_SHOW_REASON_KEY = "cached_tv_reason";

  // Expose methods to parent component
  useImperativeHandle(ref, () => ({
    handleClearSearch: () => {
      setShowSearchResults(false);
    },
    handleSearch,
  }));

  // Load saved shows and request a suggestion on component mount
  useEffect(() => {
    checkCredentials();
    loadSavedShows();
    loadWatchlistShows();

    // Try to load cached suggestion first
    const cachedShow = localStorage.getItem(CACHED_SHOW_SUGGESTION_KEY);
    const cachedReason = localStorage.getItem(CACHED_SHOW_REASON_KEY);

    if (cachedShow && cachedReason) {
      try {
        const parsedShow = JSON.parse(cachedShow);
        setSuggestedShow(parsedShow);
        setSuggestionReason(cachedReason);
        
        // Verify the cached suggestion is still valid by checking show details
        // This helps ensure we're not showing a suggestion that's no longer in the server's session
        if (parsedShow && parsedShow.id) {
          GetTVShowDetails(parsedShow.id)
            .catch(error => {
              console.log("Cached suggestion is no longer valid, getting a new one");
              // Clear localStorage
              localStorage.removeItem(CACHED_SHOW_SUGGESTION_KEY);
              localStorage.removeItem(CACHED_SHOW_REASON_KEY);
              // Get a new suggestion
              handleGetSuggestion();
            });
        }
      } catch (e) {
        console.error("Failed to parse cached TV show suggestion:", e);
        // If parsing fails, get a new suggestion
        localStorage.removeItem(CACHED_SHOW_SUGGESTION_KEY);
        localStorage.removeItem(CACHED_SHOW_REASON_KEY);
        handleGetSuggestion();
      }
    } else {
      // No cached suggestion, get a new one
      handleGetSuggestion();
    }

    // Save suggestion to localStorage when component unmounts or when suggestion changes
    return () => {
      if (suggestedShow) {
        localStorage.setItem(
          CACHED_SHOW_SUGGESTION_KEY,
          JSON.stringify(suggestedShow),
        );
      }
      if (suggestionReason) {
        localStorage.setItem(CACHED_SHOW_REASON_KEY, suggestionReason);
      }
    };
  }, []);

  // Update cached suggestion whenever it changes
  useEffect(() => {
    if (suggestedShow) {
      localStorage.setItem(
        CACHED_SHOW_SUGGESTION_KEY,
        JSON.stringify(suggestedShow),
      );
    }
    if (suggestionReason) {
      localStorage.setItem(CACHED_SHOW_REASON_KEY, suggestionReason);
    }
  }, [suggestedShow, suggestionReason]);

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

  const checkCredentials = async () => {
    try {
      const hasCredentials = await HasValidCredentials();
      setCredentialsError(!hasCredentials);
    } catch (error) {
      console.error("Failed to check credentials:", error);
      setCredentialsError(true);
    }
  };

  const handleRefreshCredentials = async () => {
    try {
      const success = await RefreshCredentials();
      setCredentialsError(!success);
      if (success) {
        enqueueSnackbar("TMDB credentials refreshed successfully", {
          variant: "success",
        });
      } else {
        enqueueSnackbar(
          "Failed to refresh TMDB credentials. Please check settings.",
          { variant: "error" },
        );
      }
    } catch (error) {
      console.error("Failed to refresh credentials:", error);
      enqueueSnackbar("Error refreshing TMDB credentials", {
        variant: "error",
      });
    }
  };

  const handleSearch = async (query: string): Promise<void> => {
    if (!query.trim()) {
      setSearchResults([]);
      setShowSearchResults(false);
      return;
    }

    setIsLoading(true);
    try {
      const results = await SearchTVShows(query);
      
      // Mark shows that are already saved
      const resultsWithSavedStatus = results.map((show) => {
        const isSaved = savedShows.some((saved) => saved.name === show.name);
        return { ...show, isSaved };
      });
      
      setSearchResults(resultsWithSavedStatus);
      setShowSearchResults(true);
      
      // Scroll to search results
      setTimeout(() => {
        searchResultsRef.current?.scrollIntoView({ behavior: "smooth" });
      }, 100);
    } catch (error) {
      console.error("Search error:", error);
      
      // Check if this is a credentials error
      if (
        error instanceof Error &&
        error.message.includes("credentials not available")
      ) {
        setCredentialsError(true);
        enqueueSnackbar("TMDB API credentials are not configured", {
          variant: "warning",
        });
      } else {
        enqueueSnackbar("Failed to search TV shows. Please try again.", {
          variant: "error",
        });
      }
    } finally {
      setIsLoading(false);
    }
  };

  const loadSavedShows = async () => {
    try {
      const favoriteShows = await GetFavoriteTVShows();
      
      // If favoriteShows is null or undefined, treat it as an empty array
      const shows = favoriteShows || [];
      
      const showsWithDetails: ExtendedTVShowWithSavedStatus[] = [];

      let apiCallCount = 0;
      const MAX_API_CALLS = 5;

      for (const show of shows) {
        // Check if we have the poster path stored
        if (show.poster_path) {
          // Create a show object with the stored poster
          showsWithDetails.push({
            id: 0,
            name: show.title || "",
            overview: "",
            poster_path: show.poster_path,
            first_air_date: "",
            vote_average: 0,
            vote_count: 0,
            genres: [],
            isSaved: true,
            director: show.director || "",
            writer: show.writer || ""
          });
        }
          try {
            // If we've hit our API call limit, create a basic entry
            if (apiCallCount >= MAX_API_CALLS) {
              showsWithDetails.push({
                id: 0,
                name: show.title || "",
                overview: "",
                poster_path: "",
                first_air_date: "",
                vote_average: 0,
                vote_count: 0,
                genres: [],
                isSaved: true,
                director: show.director || "",
                writer: show.writer || ""
              });
              continue;
            }

            // Search for the show by title to get its TMDB ID
            const searchResults = await SearchTVShows(show.title || "");
            apiCallCount++;

            // If we found a matching show in search results
            if (searchResults && searchResults.length > 0) {
              // Use the first search result as our match
              const matchedShow = searchResults[0];

              // Add it to our array with isSaved flag
              showsWithDetails.push({
                ...matchedShow,
                isSaved: true,
                director: show.director || matchedShow.director || "", 
                writer: show.writer || matchedShow.writer || ""
              });
            } else {
              // If no match found, create a basic entry without poster
              showsWithDetails.push({
                id: 0,
                name: show.title || "",
                overview: "",
                poster_path: "",
                first_air_date: "",
                vote_average: 0,
                vote_count: 0,
                genres: [],
                isSaved: true,
                director: show.director || "",
                writer: show.writer || ""
              });
            }
          } catch (error) {
            console.error("Error loading show details:", error);
            // In case of error, create a basic entry
            showsWithDetails.push({
              id: 0,
              name: show.title || "",
              overview: "",
              poster_path: "",
              first_air_date: "",
              vote_average: 0,
              vote_count: 0,
              genres: [],
              isSaved: true,
              director: show.director || "",
              writer: show.writer || ""
            });
          }
      }
      
      setSavedShows(showsWithDetails);
      return showsWithDetails; // Return the saved shows for use in loadWatchlistShows
    } catch (error) {
      console.error("Failed to load saved shows:", error);
      enqueueSnackbar("Failed to load your TV show library", {
        variant: "error",
      });
      return [];
    }
  };

  const loadWatchlistShows = async () => {
    try {
      const watchlist = await GetWatchlist();
      
      // If watchlist is empty, just set empty array
      if (!watchlist || watchlist.length === 0) {
        setWatchlistShows([]);
        return;
      }
      
      const showsWithDetails: ExtendedTVShowWithSavedStatus[] = [];
      
      let apiCallCount = 0;
      const MAX_API_CALLS = 5;

      // Get the current savedShows from state to use for comparison
      const currentSavedShows = savedShows;

      for (const show of watchlist) {
        // Check if we have the poster path stored
        if (show.poster_path) {
          // Check if this show is in favorites by comparing names
          const isSaved = currentSavedShows.some(saved => saved.name === (show.title || ""));
          
          // Create a show object with the stored poster
          showsWithDetails.push({
            id: 0,
            name: show.title || "",
            overview: "",
            poster_path: show.poster_path,
            first_air_date: "",
            vote_average: 0,
            vote_count: 0,
            genres: [],
            isSaved: isSaved, // Using the saved status check
            director: show.director || "",
            writer: show.writer || ""
          });
        }
          try {
            // If we've hit our API call limit, create a basic entry
            if (apiCallCount >= MAX_API_CALLS) {
              // Check if this show is in favorites by comparing names
              const isSaved = currentSavedShows.some(saved => saved.name === (show.title || ""));
              
              showsWithDetails.push({
                id: 0,
                name: show.title || "",
                overview: "",
                poster_path: "",
                first_air_date: "",
                vote_average: 0,
                vote_count: 0,
                genres: [],
                isSaved: isSaved,
                director: show.director || "",
                writer: show.writer || ""
              });
              continue;
            }

            // Search for the show by title to get its TMDB ID
            const searchResults = await SearchTVShows(show.title || "");
            apiCallCount++;

            // If we found a matching show in search results
            if (searchResults && searchResults.length > 0) {
              // Use the first search result as our match
              const matchedShow = searchResults[0];
              
              // Check if this show is also in favorites
              const isSaved = currentSavedShows.some(saved => saved.name === matchedShow.name);

              // Add it to our array with appropriate flags
              showsWithDetails.push({
                ...matchedShow,
                isSaved: isSaved,
                director: show.director || matchedShow.director || "",
                writer: show.writer || matchedShow.writer || ""
              });
            } else {
              // If no match found, create a basic entry without poster
              // Check if this show is in favorites by comparing names
              const isSaved = currentSavedShows.some(saved => saved.name === (show.title || ""));
              
              showsWithDetails.push({
                id: 0,
                name: show.title || "",
                overview: "",
                poster_path: "",
                first_air_date: "",
                vote_average: 0,
                vote_count: 0,
                genres: [],
                isSaved: isSaved,
                director: show.director || "",
                writer: show.writer || ""
              });
            }
          } catch (error) {
            console.error("Error loading show details:", error);
            // In case of error, create a basic entry
            // Check if this show is in favorites by comparing names
            const isSaved = currentSavedShows.some(saved => saved.name === (show.title || ""));
            
            showsWithDetails.push({
              id: 0,
              name: show.title || "",
              overview: "",
              poster_path: "",
              first_air_date: "",
              vote_average: 0,
              vote_count: 0,
              genres: [],
              isSaved: isSaved,
              director: show.director || "",
              writer: show.writer || ""
            });
          }
      }
      
      setWatchlistShows(showsWithDetails);
    } catch (error) {
      console.error("Failed to load watchlist shows:", error);
      enqueueSnackbar("Failed to load your TV show watchlist", {
        variant: "error",
      });
    }
  };

  // Handle save/remove from library
  const handleSave = async (show: ExtendedTVShowWithSavedStatus) => {
    try {
      setIsLoading(true);
      
      const favoriteShows = await GetFavoriteTVShows();
      
      // If favoriteShows is null or undefined, treat it as an empty array
      const shows = favoriteShows || [];

      if (show.isSaved) {
        // Remove from saved shows by filtering out the show with the matching title
        const updatedFavorites = shows.filter(
          (fav) => fav.title !== show.name
        );

        // Update the backend with the modified list
        await SetFavoriteTVShows(updatedFavorites);

        // Update local state
        setSavedShows((prev) => prev.filter((s) => s.name !== show.name));
        enqueueSnackbar(`Removed "${show.name}" from your library`, {
          variant: "success",
        });
      } else {
        // Check if show already exists in favorites to prevent duplicates
        const exists = shows.some(s => s.title === show.name);
        if (exists) {
          enqueueSnackbar(`"${show.name}" is already in your library`, {
            variant: "info",
          });
          
          // Update local state to reflect the correct status
          setSearchResults((prev) =>
            prev.map((s) =>
              s.id === show.id ? { ...s, isSaved: true } : s,
            ),
          );
          setIsLoading(false);
          return;
        }
        
        // Get director info from TMDB if show has an ID and we don't have director info
        let directorName = show.director || "";
        if (show.id > 0 && !directorName) {
          try {
            const details = await GetTVShowDetails(show.id);
            if (details && details.director) {
              directorName = details.director;
            }
          } catch (error) {
            console.error(`Failed to fetch director info for "${show.name}":`, error);
          }
        }
        
        // Add to saved shows with poster path and director
        const newFavorite: session.TVShow = {
          title: show.name,
          director: directorName,
          writer: show.writer || "", // We might not have this info from TMDB
          poster_path: show.poster_path || ""
        };
        
        // Add to the existing favorites
        const updatedFavorites = [...shows, newFavorite];

        // Update the backend with the modified list
        await SetFavoriteTVShows(updatedFavorites);

        // Update local state
        setSavedShows((prev) => [...prev, { ...show, isSaved: true, director: directorName }]);
        enqueueSnackbar(`Added "${show.name}" to your library`, {
          variant: "success",
        });
      }

      // Update the search results to reflect the new saved status
      setSearchResults((prev) =>
        prev.map((s) =>
          s.id === show.id ? { ...s, isSaved: !show.isSaved } : s,
        ),
      );
    } catch (error) {
      console.error("Failed to update show:", error);
      enqueueSnackbar("Failed to update library status", { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  // Handle suggestion feedback
  const handleFeedback = async (outcome: session.Outcome) => {
    if (!suggestedShow) return;
    
    try {
      setIsProcessingFeedback(true);

      // Call the Go binding to provide feedback
      await ProvideSuggestionFeedback(outcome, suggestedShow.id);

      const message =
        outcome === session.Outcome.liked
          ? `You liked "${suggestedShow.name}"`
          : outcome === session.Outcome.disliked
            ? `You disliked "${suggestedShow.name}"`
            : `Skipped "${suggestedShow.name}"`;

      const variant =
        outcome === session.Outcome.liked
          ? "success"
          : outcome === session.Outcome.disliked
            ? "error"
            : "skip";

      enqueueSnackbar(message, { variant: variant as any });

      // Only clear the current suggestion and get a new one if disliked or skipped
      // For "liked", just leave the suggestion in place
      if (outcome !== session.Outcome.liked) {
        setSuggestedShow(null);
        setSuggestionReason(null);
        
        // Clear localStorage cache
        localStorage.removeItem(CACHED_SHOW_SUGGESTION_KEY);
        localStorage.removeItem(CACHED_SHOW_REASON_KEY);
        
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
      localStorage.removeItem(CACHED_SHOW_SUGGESTION_KEY);
      localStorage.removeItem(CACHED_SHOW_REASON_KEY);
      
      // Get a new suggestion after a short delay
      setTimeout(() => {
        setSuggestedShow(null);
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

  // Add to watchlist
  const handleAddToWatchlist = async (show: ExtendedTVShowWithSavedStatus) => {
    try {
      setIsLoading(true);
      
      // Check if show is already in watchlist
      const isInWatchlist = watchlistShows.some(s => s.name === show.name);
      if (isInWatchlist) {
        enqueueSnackbar(`"${show.name}" is already in your watchlist`, {
          variant: "info",
        });
        return;
      }
      
      // Create a session.TVShow to add to watchlist
      const tvShow: session.TVShow = {
        title: show.name,
        director: show.director || "",
        writer: show.writer || "",
        poster_path: show.poster_path || "",
      };
      
      // Add to watchlist
      await AddToWatchlist(tvShow);
      
      // Update local state - add the show to watchlist
      setWatchlistShows(prev => [...prev, { ...show, isSaved: show.isSaved }]);
      
      // Show success message
      enqueueSnackbar(`Added "${show.name}" to your watchlist`, {
        variant: "success",
      });
      
      // Check if this show is the current suggestion
      const isCurrentSuggestion = suggestedShow && suggestedShow.name === show.name;
      
      // If this is the current suggestion, get a new suggestion
      if (isCurrentSuggestion) {
        // Clear the current suggestion
        setSuggestedShow(null);
        setSuggestionReason(null);
        
        // Clear localStorage cache
        localStorage.removeItem(CACHED_SHOW_SUGGESTION_KEY);
        localStorage.removeItem(CACHED_SHOW_REASON_KEY);
        
        // Get a new suggestion after a short delay for better UX
        setTimeout(() => {
          handleGetSuggestion();
        }, 500);
        
        // Also record this as a positive outcome
        if (show.id > 0) {
          await ProvideSuggestionFeedback(session.Outcome.liked, show.id);
        }
      }
    } catch (error) {
      console.error("Failed to add show to watchlist:", error);
      enqueueSnackbar("Failed to add to watchlist", { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  // Remove from watchlist
  const handleRemoveFromWatchlist = async (show: ExtendedTVShowWithSavedStatus) => {
    try {
      setIsLoading(true);
      
      // Remove from watchlist via backend
      await RemoveFromWatchlist(show.name);
      
      // Update local state - remove the show from watchlist
      setWatchlistShows(prev => prev.filter(s => s.name !== show.name));
      
      // Show success message
      enqueueSnackbar(`Removed "${show.name}" from your watchlist`, {
        variant: "success",
      });
    } catch (error) {
      console.error("Failed to remove show from watchlist:", error);
      enqueueSnackbar("Failed to remove from watchlist", { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  // Handle watchlist feedback
  const handleWatchlistFeedback = async (show: ExtendedTVShowWithSavedStatus, action: "like" | "dislike") => {
    try {
      setIsLoading(true);
      
      // For shows without an ID (ID = 0), try to find the show by title in search results first
      let showForFeedback = show;
      if (show.id === 0) {
        console.log(`Looking up show "${show.name}" in search results or saved shows for proper ID`);
        
        // Check if the show exists in search results with a valid ID
        const showInSearchResults = searchResults.find(s => s.name === show.name);
        if (showInSearchResults && showInSearchResults.id > 0) {
          console.log(`Found show "${show.name}" in search results with ID ${showInSearchResults.id}`);
          showForFeedback = { 
            ...showInSearchResults,
            director: show.director || showInSearchResults.director || "",
            writer: show.writer || showInSearchResults.writer || ""
          };
        } else {
          // If not in search results, search for it to get the ID
          console.log(`Searching for show "${show.name}" to get proper ID`);
          try {
            const results = await SearchTVShows(show.name);
            if (results && results.length > 0) {
              console.log(`Found show "${show.name}" in TMDB with ID ${results[0].id}`);
              showForFeedback = { 
                ...results[0],
                director: show.director || results[0].director || "",
                writer: show.writer || results[0].writer || ""
              };
            }
          } catch (error) {
            console.error(`Failed to search for show "${show.name}":`, error);
            // Continue with original show if search fails
          }
        }
      }
      
      // If show has an ID but is missing director/writer info, try to get it
      if (showForFeedback.id > 0 && (!showForFeedback.director || !showForFeedback.writer)) {
        try {
          const details = await GetTVShowDetails(showForFeedback.id);
          if (details) {
            showForFeedback = {
              ...showForFeedback,
              director: showForFeedback.director || details.director || "",
              writer: showForFeedback.writer || details.writer || ""
            };
          }
        } catch (error) {
          console.error(`Failed to get details for show ID ${showForFeedback.id}:`, error);
          // Continue with what we have if details fetch fails
        }
      }
      
      // Record feedback with the show ID and all available metadata
      console.log(`Recording ${action} feedback for show "${showForFeedback.name}" with ID ${showForFeedback.id}, director: "${showForFeedback.director}", writer: "${showForFeedback.writer}"`);
      
      await ProvideSuggestionFeedback(
        action === "like" ? session.Outcome.liked : session.Outcome.disliked,
        showForFeedback.id
      );
      
      // If liked, add to library
      if (action === "like") {
        // Create a session.TVShow to add to favorites
        const tvShow: session.TVShow = {
          title: showForFeedback.name,
          director: showForFeedback.director || "",
          writer: showForFeedback.writer || "",
          poster_path: showForFeedback.poster_path || "",
        };
        
        // Check if already in library
        const exists = savedShows.some(s => s.name === showForFeedback.name);
        if (!exists) {
          // Add to savedShows in UI with proper ID and details
          await handleSave(showForFeedback);
        }
      }
      
      // Remove from watchlist
      await handleRemoveFromWatchlist(show);
      
      // Show success message
      const message = action === "like" 
        ? `You liked "${show.name}"`
        : `You disliked "${show.name}"`;
      
      enqueueSnackbar(message, {
        variant: action === "like" ? "success" : "error",
      });
    } catch (error) {
      console.error(`Failed to record ${action} for show:`, error);
      enqueueSnackbar(`Failed to record your ${action}`, { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  // Get new suggestion
  const handleGetSuggestion = async () => {
    // Don't show credentials error when loading a suggestion
    setSuggestionError(null);

    // Check if credentials are valid
    if (credentialsError) {
      enqueueSnackbar("Please set up your TMDB credentials in Settings first", {
        variant: "warning",
      });
      return;
    }
    
    setIsLoadingSuggestion(true);
    
    try {
      // Call the Go binding to get a TV show suggestion
      const result = await GetTVShowSuggestion();
      
      if (result && result.show) {
        setSuggestedShow(result.show);
        setSuggestionReason(result.reason || null);
        
        // Cache the suggestion
        localStorage.setItem(CACHED_SHOW_SUGGESTION_KEY, JSON.stringify(result.show));
        localStorage.setItem(CACHED_SHOW_REASON_KEY, result.reason || "");
      } else {
        // Handle case where no suggestion is available
        setSuggestionError("No TV show suggestions available at the moment.");
      }
    } catch (error) {
      console.error("Failed to get TV show suggestion:", error);
      
      // Format a user-friendly error message
      let errorMessage = "Failed to get TV show recommendation. Please try again.";
      
      // Check if this is a string error or an object
      if (typeof error === "string") {
        errorMessage = error;
      } else if (error instanceof Error) {
        // Check for specific error types
        if (error.message.includes("credentials not available")) {
          errorMessage = "TV show recommendations require TMDB API credentials to be configured.";
          setCredentialsError(true);
        } else if (error.message.includes("rate limit")) {
          errorMessage = "OpenAI rate limit reached. Please try again in a few minutes.";
        } else {
          errorMessage = error.message;
        }
      } else if (error && typeof error === "object") {
        // Try to extract error message from error object
        if ("message" in error && typeof error.message === "string") {
          errorMessage = error.message;
        } else if ("error" in error) {
          if (typeof error.error === "string") {
            errorMessage = error.error;
          } else if (error.error && typeof error.error === "object" && "message" in error.error) {
            errorMessage = String(error.error.message);
          }
        }
        
        // Check for rate limit error specifically
        if (errorMessage.includes("rate limit")) {
          errorMessage = "OpenAI rate limit reached. Please try again in a few minutes.";
        }
      }
      
      setSuggestionError(errorMessage);
      
      // Show a toast notification for the error
      enqueueSnackbar(errorMessage, { variant: "error" });
    } finally {
      setIsLoadingSuggestion(false);
    }
  };

  // Convert TVShowWithSavedStatus to MediaSuggestionItem
  const mapShowToSuggestionItem = (
    show: ExtendedTVShowWithSavedStatus,
  ): MediaSuggestionItem => {
    return {
      id: show.id,
      title: show.name,
      description: show.overview,
      imageUrl: show.poster_path
        ? `https://image.tmdb.org/t/p/w500${show.poster_path}`
        : undefined,
      releaseDate: show.first_air_date,
      rating: show.vote_average,
      voteCount: show.vote_count
    };
  };

  // Custom renderer for TV show poster
  const renderShowPoster = (item: MediaSuggestionItem) => {
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

  // Handle adding the suggested TV show to favorites
  const handleAddToFavorites = async () => {
    if (!suggestedShow) return;

    try {
      setIsProcessingFeedback(true);

      // Add to saved shows
      await handleSave({ ...suggestedShow, isSaved: false });

      // Update the suggested show's status
      const updatedShow = { ...suggestedShow, isSaved: true };
      setSuggestedShow(updatedShow);

      // Also record this as a "liked" outcome for improving future suggestions
      await ProvideSuggestionFeedback(session.Outcome.liked, suggestedShow.id);

      // Show a success message
      enqueueSnackbar(`Added "${suggestedShow.name}" to favorites`, {
        variant: "success",
      });

      // Don't clear the suggestion, just set processing to false
      setIsProcessingFeedback(false);
    } catch (error) {
      console.error("Failed to add TV show to favorites:", error);
      enqueueSnackbar("Failed to add TV show to favorites", { variant: "error" });
      
      // Clear localStorage cache on error
      localStorage.removeItem(CACHED_SHOW_SUGGESTION_KEY);
      localStorage.removeItem(CACHED_SHOW_REASON_KEY);
      
      // Get a new suggestion
      setTimeout(() => {
        setSuggestedShow(null);
        setSuggestionReason(null);
        handleGetSuggestion();
      }, 1000);
      
      setIsProcessingFeedback(false);
    }
  };

  return (
    <Box sx={{ width: "100%" }}>
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
            Missing TMDB Credentials
          </Typography>
          <Typography variant="body1">
            The Movie Database API credentials are not configured. Please set up
            your TMDB API key in the Settings to use TV show recommendations.
          </Typography>
          <Button
            variant="outlined"
            color="warning"
            sx={{ mt: 2 }}
            onClick={handleRefreshCredentials}
          >
            Refresh Credentials
          </Button>
        </Box>
      )}

      {/* Search Results Section */}
      {searchResults.length > 0 && showSearchResults && (
        <Box sx={{ mb: 4 }} ref={searchResultsRef}>
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
              "& > div": {
                height: "100%",
              },
            }}
          >
            {searchResults.map((show) => (
              <Box key={`search-${show.id}`}>
                <TVShowCard
                  show={show}
                  isSaved={show.isSaved || false}
                  isInWatchlist={watchlistShows.some(m => m.name === show.name)}
                  view="default"
                  onSave={() => handleSave(show)}
                  onAddToWatchlist={() => handleAddToWatchlist(show)}
                />
              </Box>
            ))}
          </Box>
        </Box>
      )}

      {/* TV Show Suggestion Section */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h5" sx={{ mb: 2 }}>
          Suggested for You
        </Typography>

        <MediaSuggestionDisplay
          mediaType="movie"
          suggestedItem={
            suggestedShow ? mapShowToSuggestionItem(suggestedShow) : null
          }
          suggestionReason={suggestionReason}
          isLoading={isLoadingSuggestion}
          error={suggestionError}
          isProcessing={isProcessingFeedback}
          hasBeenLiked={suggestedShow?.isSaved}
          onRequestSuggestion={handleGetSuggestion}
          onLike={() => {
            // Call the feedback handler
            handleFeedback(session.Outcome.liked);
            // Also update the suggestedShow to show it's now liked
            if (suggestedShow) {
              const updatedShow = { ...suggestedShow, isSaved: true };
              setSuggestedShow(updatedShow);
            }
          }}
          onDislike={() => handleFeedback(session.Outcome.disliked)}
          onSkip={() => {
            if (suggestedShow && suggestedShow.isSaved) {
              setSuggestedShow(null);
              setSuggestionReason(null);
              
              localStorage.removeItem(CACHED_SHOW_SUGGESTION_KEY);
              localStorage.removeItem(CACHED_SHOW_REASON_KEY);
              
              handleGetSuggestion();
            } else {
              handleFeedback(session.Outcome.skipped);
            }
          }}
          onAddToLibrary={handleAddToFavorites}
          onAddToWatchlist={suggestedShow ? () => handleAddToWatchlist(suggestedShow) : undefined}
          renderImage={renderShowPoster}
        />
      </Box>

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
            {showWatchlist ? "Hide" : "Show"} ({watchlistShows.length})
          </Typography>
        </Box>

        {showWatchlist && (
          watchlistShows.length === 0 ? (
            <Box
              sx={{ textAlign: "center", py: 4, color: "var(--text-secondary)" }}
            >
              <Typography variant="body1">
                Your watchlist is empty. Add TV shows to watch later by clicking the "Add to Watchlist" icon.
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
              {watchlistShows.map((show) => (
                <Box key={`watchlist-${show.id || show.name}`}>
                  <TVShowCard
                    show={show}
                    isSaved={show.isSaved || false}
                    view="watchlist"
                    onSave={() => handleSave(show)}
                    onRemoveFromWatchlist={() => handleRemoveFromWatchlist(show)}
                    onLike={() => handleWatchlistFeedback(show, "like")}
                    onDislike={() => handleWatchlistFeedback(show, "dislike")}
                  />
                </Box>
              ))}
            </Box>
          )
        )}
      </Box>

      {/* Saved TV Shows Section */}
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
            {showLibrary ? "Hide" : "Show"} ({savedShows.length})
          </Typography>
        </Box>

        {showLibrary && (
          savedShows.length === 0 ? (
            <Box
              sx={{ textAlign: "center", py: 4, color: "var(--text-secondary)" }}
            >
              <Typography variant="body1">
                You haven't saved any TV shows yet. Search for shows and click the
                heart icon to add them to your library.
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
              {savedShows.map((show, index) => (
                <Box key={`saved-${show.id || index}`}>
                  <TVShowCard
                    show={show}
                    isSaved={true}
                    isInWatchlist={watchlistShows.some(m => m.name === show.name)}
                    view="default"
                    onSave={() => handleSave(show)}
                    onAddToWatchlist={() => handleAddToWatchlist(show)}
                  />
                </Box>
              ))}
            </Box>
          )
        )}
      </Box>
    </Box>
  );
}); 
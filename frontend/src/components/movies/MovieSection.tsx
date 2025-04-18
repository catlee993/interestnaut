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
import { MovieCard } from "@/components/movies/MovieCard";
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
import { useSnackbar } from "notistack";
import { session } from "@wailsjs/go/models";
import {
  MediaSuggestionDisplay,
  MediaSuggestionItem,
} from "@/components/common/MediaSuggestionDisplay";

// Define the movie suggestion type
interface MovieSuggestionData {
  movie: MovieWithSavedStatus;
  reason: string;
}

export interface MovieSectionHandle {
  handleClearSearch: () => void;
  handleSearch: (query: string) => Promise<void>;
}

export const MovieSection = forwardRef<MovieSectionHandle, {}>((props, ref) => {
  const { enqueueSnackbar } = useSnackbar();
  const [searchResults, setSearchResults] = useState<MovieWithSavedStatus[]>(
    [],
  );
  const [showSearchResults, setShowSearchResults] = useState(true);
  const [savedMovies, setSavedMovies] = useState<MovieWithSavedStatus[]>([]);
  const [watchlistMovies, setWatchlistMovies] = useState<MovieWithSavedStatus[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingSuggestion, setIsLoadingSuggestion] = useState(false);
  const [suggestedMovie, setSuggestedMovie] =
    useState<MovieWithSavedStatus | null>(null);
  const [suggestionReason, setSuggestionReason] = useState<string | null>(null);
  const [credentialsError, setCredentialsError] = useState(false);
  const [suggestionError, setSuggestionError] = useState<string | null>(null);
  const [isProcessingFeedback, setIsProcessingFeedback] = useState(false);
  const [showWatchlist, setShowWatchlist] = useState(true);
  const [showLibrary, setShowLibrary] = useState(true);

  const searchResultsRef = useRef<HTMLDivElement>(null);

  // Local storage keys
  const CACHED_MOVIE_SUGGESTION_KEY = "cached_movie_suggestion";
  const CACHED_MOVIE_REASON_KEY = "cached_movie_reason";

  // Expose methods to parent component
  useImperativeHandle(ref, () => ({
    handleClearSearch: () => {
      setShowSearchResults(false);
    },
    handleSearch,
  }));

  // Load saved movies and request a suggestion on component mount
  useEffect(() => {
    checkCredentials();
    loadSavedMovies();
    loadWatchlistMovies();

    // Try to load cached suggestion first
    const cachedMovie = localStorage.getItem(CACHED_MOVIE_SUGGESTION_KEY);
    const cachedReason = localStorage.getItem(CACHED_MOVIE_REASON_KEY);

    if (cachedMovie && cachedReason) {
      try {
        const parsedMovie = JSON.parse(cachedMovie);
        setSuggestedMovie(parsedMovie);
        setSuggestionReason(cachedReason);
        
        // Verify the cached suggestion is still valid by checking movie details
        // This helps ensure we're not showing a suggestion that's no longer in the server's session
        if (parsedMovie && parsedMovie.id) {
          GetMovieDetails(parsedMovie.id)
            .catch(error => {
              console.log("Cached suggestion is no longer valid, getting a new one");
              // Clear localStorage
              localStorage.removeItem(CACHED_MOVIE_SUGGESTION_KEY);
              localStorage.removeItem(CACHED_MOVIE_REASON_KEY);
              // Get a new suggestion
              handleGetSuggestion();
            });
        }
      } catch (e) {
        console.error("Failed to parse cached suggestion:", e);
        // If parsing fails, get a new suggestion
        localStorage.removeItem(CACHED_MOVIE_SUGGESTION_KEY);
        localStorage.removeItem(CACHED_MOVIE_REASON_KEY);
        handleGetSuggestion();
      }
    } else {
      // No cached suggestion, get a new one
      handleGetSuggestion();
    }

    // Save suggestion to localStorage when component unmounts or when suggestion changes
    return () => {
      if (suggestedMovie) {
        localStorage.setItem(
          CACHED_MOVIE_SUGGESTION_KEY,
          JSON.stringify(suggestedMovie),
        );
      }
      if (suggestionReason) {
        localStorage.setItem(CACHED_MOVIE_REASON_KEY, suggestionReason);
      }
    };
  }, []);

  // Update cached suggestion whenever it changes
  useEffect(() => {
    if (suggestedMovie) {
      localStorage.setItem(
        CACHED_MOVIE_SUGGESTION_KEY,
        JSON.stringify(suggestedMovie),
      );
    }
    if (suggestionReason) {
      localStorage.setItem(CACHED_MOVIE_REASON_KEY, suggestionReason);
    }
  }, [suggestedMovie, suggestionReason]);

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

  const loadSavedMovies = async () => {
    try {
      const favoriteMovies = await GetFavoriteMovies();
      
      // If favoriteMovies is null or undefined, treat it as an empty array
      const movies = favoriteMovies || [];
      
      const moviesWithDetails: MovieWithSavedStatus[] = [];

      let apiCallCount = 0;
      const MAX_API_CALLS = 5;

      for (const movie of movies) {
        // Check if we have the poster path stored
        if (movie.poster_path) {
          // Create a movie object with the stored poster
          moviesWithDetails.push({
            id: 0,
            title: movie.title || "",
            overview: "",
            poster_path: movie.poster_path,
            release_date: "",
            vote_average: 0,
            vote_count: 0,
            genres: [],
            isSaved: true,
            director: movie.director || "",
            writer: movie.writer || ""
          });
        } else {
          try {
            // If we've hit our API call limit, create a basic entry
            if (apiCallCount >= MAX_API_CALLS) {
              moviesWithDetails.push({
                id: 0,
                title: movie.title || "",
                overview: "",
                poster_path: "",
                release_date: "",
                vote_average: 0,
                vote_count: 0,
                genres: [],
                isSaved: true,
                director: movie.director || "",
                writer: movie.writer || ""
              });
              continue;
            }

            // Search for the movie by title to get its TMDB ID
            const searchResults = await SearchMovies(movie.title || "");
            apiCallCount++;

            // If we found a matching movie in search results
            if (searchResults && searchResults.length > 0) {
              // Use the first search result as our match
              const matchedMovie = searchResults[0];

              // Add it to our array with isSaved flag
              moviesWithDetails.push({
                ...matchedMovie,
                isSaved: true,
                director: movie.director || matchedMovie.director || "", 
                writer: movie.writer || matchedMovie.writer || ""
              });
            } else {
              // If no match found, create a basic entry without poster
              moviesWithDetails.push({
                id: 0,
                title: movie.title || "",
                overview: "",
                poster_path: "",
                release_date: "",
                vote_average: 0,
                vote_count: 0,
                genres: [],
                isSaved: true,
                director: movie.director || "",
                writer: movie.writer || ""
              });
            }
          } catch (error) {
            console.error(
              `Failed to fetch details for movie "${movie.title}":`,
              error,
            );
            // Add a basic entry for this movie
            moviesWithDetails.push({
              id: 0,
              title: movie.title || "",
              overview: "",
              poster_path: "",
              release_date: "",
              vote_average: 0,
              vote_count: 0,
              genres: [],
              isSaved: true,
              director: movie.director || "",
              writer: movie.writer || ""
            });
          }
        }
      }

      setSavedMovies(moviesWithDetails);

      // If we hit the API call limit, show a message to the user
      if (apiCallCount >= MAX_API_CALLS && movies.length > MAX_API_CALLS) {
        enqueueSnackbar(
          `Loaded ${MAX_API_CALLS} movie details, ${movies.length - MAX_API_CALLS} movies shown with limited details`,
          {
            variant: "info",
          },
        );
      }
    } catch (error) {
      console.error("Failed to load saved movies:", error);
      enqueueSnackbar("Failed to load your favorite movies", {
        variant: "error",
      });
    }
  };

  const loadWatchlistMovies = async () => {
    try {
      const watchlist = await GetWatchlist();
      
      // If watchlist is empty, just set empty array
      if (!watchlist || watchlist.length === 0) {
        setWatchlistMovies([]);
        return;
      }
      
      const moviesWithDetails: MovieWithSavedStatus[] = [];
      
      let apiCallCount = 0;
      const MAX_API_CALLS = 5;

      for (const movie of watchlist) {
        // Check if we have the poster path stored
        if (movie.poster_path) {
          // Create a movie object with the stored poster
          moviesWithDetails.push({
            id: 0,
            title: movie.title || "",
            overview: "",
            poster_path: movie.poster_path,
            release_date: "",
            vote_average: 0,
            vote_count: 0,
            genres: [],
            isSaved: false, // Not in favorites
            director: movie.director || "",
            writer: movie.writer || ""
          });
        } else {
          try {
            // If we've hit our API call limit, create a basic entry
            if (apiCallCount >= MAX_API_CALLS) {
              moviesWithDetails.push({
                id: 0,
                title: movie.title || "",
                overview: "",
                poster_path: "",
                release_date: "",
                vote_average: 0,
                vote_count: 0,
                genres: [],
                isSaved: false,
                director: movie.director || "",
                writer: movie.writer || ""
              });
              continue;
            }

            // Search for the movie by title to get its TMDB ID
            const searchResults = await SearchMovies(movie.title || "");
            apiCallCount++;

            // If we found a matching movie in search results
            if (searchResults && searchResults.length > 0) {
              // Use the first search result as our match
              const matchedMovie = searchResults[0];
              
              // Check if this movie is also in favorites
              const isSaved = savedMovies.some(saved => saved.title === matchedMovie.title);

              // Add it to our array with appropriate flags
              moviesWithDetails.push({
                ...matchedMovie,
                isSaved: isSaved,
                director: movie.director || matchedMovie.director || "",
                writer: movie.writer || matchedMovie.writer || ""
              });
            } else {
              // If no match found, create a basic entry without poster
              moviesWithDetails.push({
                id: 0,
                title: movie.title || "",
                overview: "",
                poster_path: "",
                release_date: "",
                vote_average: 0,
                vote_count: 0,
                genres: [],
                isSaved: false,
                director: movie.director || "",
                writer: movie.writer || ""
              });
            }
          } catch (error) {
            console.error(
              `Failed to fetch details for movie "${movie.title}":`,
              error,
            );
            // Add a basic entry for this movie
            moviesWithDetails.push({
              id: 0,
              title: movie.title || "",
              overview: "",
              poster_path: "",
              release_date: "",
              vote_average: 0,
              vote_count: 0,
              genres: [],
              isSaved: false,
              director: movie.director || "",
              writer: movie.writer || ""
            });
          }
        }
      }

      setWatchlistMovies(moviesWithDetails);
    } catch (error) {
      console.error("Failed to load watchlist:", error);
      enqueueSnackbar("Failed to load your watchlist", { variant: "error" });
    }
  };

  const handleSearch = async (query: string) => {
    console.log(`[MovieSection] Searching for movies with query: "${query}"`);
    if (!query.trim()) {
      setSearchResults([]);
      return;
    }

    try {
      setIsLoading(true);
      const response = await SearchMovies(query);

      // Mark movies that are already saved - use title comparison instead of ID
      const updatedResults = response.map((movie) => ({
        ...movie,
        isSaved: savedMovies.some((saved) => saved.title === movie.title),
      }));

      setSearchResults(updatedResults);
      setCredentialsError(false);
      setShowSearchResults(true);
      console.log(
        `[MovieSection] Search complete, found ${updatedResults.length} movies`,
      );
    } catch (error) {
      console.error("Failed to search movies:", error);

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
        enqueueSnackbar("Failed to search movies", { variant: "error" });
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleSave = async (movie: MovieWithSavedStatus) => {
    try {
      setIsLoading(true);
      
      const favoriteMovies = await GetFavoriteMovies();
      
      // If favoriteMovies is null or undefined, treat it as an empty array
      const movies = favoriteMovies || [];

      if (movie.isSaved) {
        // Remove from saved movies by filtering out the movie with the matching title
        const updatedFavorites = movies.filter(
          (fav) => fav.title !== movie.title
        );

        // Update the backend with the modified list
        await SetFavoriteMovies(updatedFavorites);

        // Update local state
        setSavedMovies((prev) => prev.filter((m) => m.title !== movie.title));
        enqueueSnackbar(`Removed "${movie.title}" from your library`, {
          variant: "success",
        });
      } else {
        // Check if movie already exists in favorites to prevent duplicates
        const exists = movies.some(m => m.title === movie.title);
        if (exists) {
          enqueueSnackbar(`"${movie.title}" is already in your library`, {
            variant: "info",
          });
          
          // Update local state to reflect the correct status
          setSearchResults((prev) =>
            prev.map((m) =>
              m.id === movie.id ? { ...m, isSaved: true } : m,
            ),
          );
          return;
        }
        
        // Get director info from TMDB if movie has an ID and we don't have director info
        let directorName = movie.director || "";
        if (movie.id > 0 && !directorName) {
          try {
            const details = await GetMovieDetails(movie.id);
            if (details && details.director) {
              directorName = details.director;
            }
          } catch (error) {
            console.error(`Failed to fetch director info for "${movie.title}":`, error);
          }
        }
        
        // Add to saved movies with poster path and director
        const newFavorite: session.Movie = {
          title: movie.title,
          director: directorName,
          writer: movie.writer || "", // We might not have this info from TMDB
          poster_path: movie.poster_path || ""
        };
        
        // Add to the existing favorites
        const updatedFavorites = [...movies, newFavorite];

        // Update the backend with the modified list
        await SetFavoriteMovies(updatedFavorites);

        // Update local state
        setSavedMovies((prev) => [...prev, { ...movie, isSaved: true, director: directorName }]);
        enqueueSnackbar(`Added "${movie.title}" to your library`, {
          variant: "success",
        });
      }

      // Update the search results to reflect the new saved status
      setSearchResults((prev) =>
        prev.map((m) =>
          m.id === movie.id ? { ...m, isSaved: !movie.isSaved } : m,
        ),
      );
    } catch (error) {
      console.error("Failed to update movie:", error);
      enqueueSnackbar("Failed to update library status", { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  const handleGetSuggestion = async () => {
    // Don't show credentials error when loading a suggestion
    setSuggestionError(null);

    // Check if credentials are valid
    try {
      setIsLoadingSuggestion(true);

      // Call the Go binding to get a movie suggestion
      const suggestion = await GetMovieSuggestion();

      if (suggestion) {
        setSuggestedMovie(suggestion.movie);
        setSuggestionReason(suggestion.reason);
      } else {
        // Handle case where no suggestion is available
        setSuggestionError("No movie suggestions available at the moment.");
      }
    } catch (error) {
      console.error("Failed to get movie suggestion:", error);
      
      // Format a user-friendly error message
      let errorMessage = "Failed to get movie recommendation. Please try again.";
      
      // Check if this is a string error or an object
      if (typeof error === "string") {
        errorMessage = error;
      } else if (error instanceof Error) {
        // Check for specific error types
        if (error.message.includes("credentials not available")) {
          errorMessage = "Movie recommendations require TMDB API credentials to be configured.";
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

  const handleFeedback = async (outcome: session.Outcome) => {
    if (!suggestedMovie) return;

    try {
      setIsProcessingFeedback(true);

      // Call the Go binding to provide feedback
      await ProvideSuggestionFeedback(outcome, suggestedMovie.id);

      const message =
        outcome === session.Outcome.liked
          ? `You liked "${suggestedMovie.title}"`
          : outcome === session.Outcome.disliked
            ? `You disliked "${suggestedMovie.title}"`
            : `Skipped "${suggestedMovie.title}"`;

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
        setSuggestedMovie(null);
        setSuggestionReason(null);
        
        // Clear localStorage cache
        localStorage.removeItem(CACHED_MOVIE_SUGGESTION_KEY);
        localStorage.removeItem(CACHED_MOVIE_REASON_KEY);
        
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
      localStorage.removeItem(CACHED_MOVIE_SUGGESTION_KEY);
      localStorage.removeItem(CACHED_MOVIE_REASON_KEY);
      
      // Get a new suggestion after a short delay
      setTimeout(() => {
        setSuggestedMovie(null);
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

  // Check if TMDB credentials are valid
  const checkCredentials = async () => {
    try {
      const hasCredentials = await HasValidCredentials();
      const newCredentialsError = !hasCredentials;

      // Update the credential error state
      if (credentialsError !== newCredentialsError) {
        console.log(
          `[MovieSection] TMDB credentials status: ${hasCredentials ? "available" : "not available"}`,
        );
        setCredentialsError(newCredentialsError);

        // If credentials were just fixed (e.g., the user added them in settings),
        // reload the page content
        if (!newCredentialsError && credentialsError) {
          console.log(
            "[MovieSection] TMDB credentials available, loading content",
          );
          loadSavedMovies();
          handleGetSuggestion();
        }
      }
    } catch (error) {
      console.error("[MovieSection] Failed to check credentials:", error);
      setCredentialsError(true);
    }
  };

  // Convert MovieWithSavedStatus to MediaSuggestionItem
  const mapMovieToSuggestionItem = (
    movie: MovieWithSavedStatus,
  ): MediaSuggestionItem => {
    return {
      id: movie.id,
      title: movie.title,
      description: movie.overview,
      imageUrl: movie.poster_path
        ? `https://image.tmdb.org/t/p/w500${movie.poster_path}`
        : undefined,
      releaseDate: movie.release_date,
      rating: movie.vote_average,
      voteCount: movie.vote_count
    };
  };

  // Custom renderer for movie poster
  const renderMoviePoster = (item: MediaSuggestionItem) => {
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

  // Handle adding the suggested movie to favorites
  const handleAddToFavorites = async () => {
    if (!suggestedMovie) return;

    try {
      setIsProcessingFeedback(true);

      // Add to saved movies
      await handleSave({ ...suggestedMovie, isSaved: false });

      // Update the suggested movie's status
      const updatedMovie = { ...suggestedMovie, isSaved: true };
      setSuggestedMovie(updatedMovie);

      // Also record this as a "liked" outcome for improving future suggestions
      await ProvideSuggestionFeedback(session.Outcome.liked, suggestedMovie.id);

      // Show a success message
      enqueueSnackbar(`Added "${suggestedMovie.title}" to favorites`, {
        variant: "success",
      });

      // Don't clear the suggestion, just set processing to false
      setIsProcessingFeedback(false);
    } catch (error) {
      console.error("Failed to add movie to favorites:", error);
      enqueueSnackbar("Failed to add movie to favorites", { variant: "error" });
      
      // Clear localStorage cache on error
      localStorage.removeItem(CACHED_MOVIE_SUGGESTION_KEY);
      localStorage.removeItem(CACHED_MOVIE_REASON_KEY);
      
      // Get a new suggestion
      setTimeout(() => {
        setSuggestedMovie(null);
        setSuggestionReason(null);
        handleGetSuggestion();
      }, 1000);
      
      setIsProcessingFeedback(false);
    }
  };

  const handleAddToWatchlist = async (movie: MovieWithSavedStatus) => {
    try {
      setIsLoading(true);
      
      // Check if movie is already in watchlist
      const isInWatchlist = watchlistMovies.some(m => m.title === movie.title);
      if (isInWatchlist) {
        enqueueSnackbar(`"${movie.title}" is already in your watchlist`, {
          variant: "info",
        });
        return;
      }
      
      // Get director info from TMDB if movie has an ID and we don't have director info
      let directorName = movie.director || "";
      if (movie.id > 0 && !directorName) {
        try {
          const details = await GetMovieDetails(movie.id);
          if (details && details.director) {
            directorName = details.director;
          }
        } catch (error) {
          console.error(`Failed to fetch director info for "${movie.title}":`, error);
        }
      }
      
      // Create a movie object to add to the watchlist
      const watchlistMovie: session.Movie = {
        title: movie.title,
        director: directorName,
        writer: movie.writer || "", // We might not have this info from TMDB
        poster_path: movie.poster_path || ""
      };
      
      // Add to the watchlist
      await AddToWatchlist(watchlistMovie);
      
      // Update local state - add the movie to watchlist
      setWatchlistMovies(prev => [...prev, { ...movie, isSaved: movie.isSaved, director: directorName }]);
      
      // Show success message
      enqueueSnackbar(`Added "${movie.title}" to your watchlist`, {
        variant: "success",
      });
      
      // Update search results to reflect the new watchlist status
      setSearchResults(prev =>
        prev.map(m =>
          m.id === movie.id ? { ...m } : m
        )
      );
      
      // Check if this movie is the current suggestion
      const isCurrentSuggestion = suggestedMovie && suggestedMovie.title === movie.title;
      
      // If this is the current suggestion, get a new suggestion
      if (isCurrentSuggestion) {
        // Clear the current suggestion
        setSuggestedMovie(null);
        setSuggestionReason(null);
        
        // Clear localStorage cache
        localStorage.removeItem(CACHED_MOVIE_SUGGESTION_KEY);
        localStorage.removeItem(CACHED_MOVIE_REASON_KEY);
        
        // Get a new suggestion after a short delay for better UX
        setTimeout(() => {
          handleGetSuggestion();
        }, 500);
        
        // Also record this as a positive outcome
        if (movie.id > 0) {
          await ProvideSuggestionFeedback(session.Outcome.liked, movie.id);
        }
      }
    } catch (error) {
      console.error("Failed to add movie to watchlist:", error);
      enqueueSnackbar("Failed to add to watchlist", { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  const handleRemoveFromWatchlist = async (movie: MovieWithSavedStatus) => {
    try {
      setIsLoading(true);
      
      // Remove from watchlist via backend
      await RemoveFromWatchlist(movie.title);
      
      // Update local state - remove the movie from watchlist
      setWatchlistMovies(prev => prev.filter(m => m.title !== movie.title));
      
      // Show success message
      enqueueSnackbar(`Removed "${movie.title}" from your watchlist`, {
        variant: "success",
      });
    } catch (error) {
      console.error("Failed to remove movie from watchlist:", error);
      enqueueSnackbar("Failed to remove from watchlist", { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  const handleWatchlistFeedback = async (movie: MovieWithSavedStatus, action: "like" | "dislike") => {
    try {
      setIsLoading(true);
      
      // For movies without an ID (ID = 0), try to find the movie by title in search results first
      let movieForFeedback = movie;
      if (movie.id === 0) {
        console.log(`Looking up movie "${movie.title}" in search results or saved movies for proper ID`);
        
        // Check if the movie exists in search results with a valid ID
        const movieInSearchResults = searchResults.find(m => m.title === movie.title);
        if (movieInSearchResults && movieInSearchResults.id > 0) {
          console.log(`Found movie "${movie.title}" in search results with ID ${movieInSearchResults.id}`);
          movieForFeedback = { 
            ...movieInSearchResults,
            director: movie.director || movieInSearchResults.director || "",
            writer: movie.writer || movieInSearchResults.writer || ""
          };
        } else {
          // If not in search results, search for it to get the ID
          console.log(`Searching for movie "${movie.title}" to get proper ID`);
          try {
            const results = await SearchMovies(movie.title);
            if (results && results.length > 0) {
              console.log(`Found movie "${movie.title}" in TMDB with ID ${results[0].id}`);
              movieForFeedback = { 
                ...results[0],
                director: movie.director || results[0].director || "",
                writer: movie.writer || results[0].writer || ""
              };
            }
          } catch (error) {
            console.error(`Failed to search for movie "${movie.title}":`, error);
            // Continue with original movie if search fails
          }
        }
      }
      
      // If movie has an ID but is missing director/writer info, try to get it
      if (movieForFeedback.id > 0 && (!movieForFeedback.director || !movieForFeedback.writer)) {
        try {
          const details = await GetMovieDetails(movieForFeedback.id);
          if (details) {
            movieForFeedback = {
              ...movieForFeedback,
              director: movieForFeedback.director || details.director || "",
              writer: movieForFeedback.writer || details.writer || ""
            };
          }
        } catch (error) {
          console.error(`Failed to get details for movie ID ${movieForFeedback.id}:`, error);
          // Continue with what we have if details fetch fails
        }
      }
      
      // Record feedback with the movie ID and all available metadata
      console.log(`Recording ${action} feedback for movie "${movieForFeedback.title}" with ID ${movieForFeedback.id}, director: "${movieForFeedback.director}", writer: "${movieForFeedback.writer}"`);
      
      await ProvideSuggestionFeedback(
        action === "like" ? session.Outcome.liked : session.Outcome.disliked,
        movieForFeedback.id
      );
      
      // Remove from watchlist
      await handleRemoveFromWatchlist(movie);
      
      // Show success message
      const message = action === "like" 
        ? `You liked "${movie.title}"`
        : `You disliked "${movie.title}"`;
      
      enqueueSnackbar(message, {
        variant: action === "like" ? "success" : "error",
      });
    } catch (error) {
      console.error(`Failed to record ${action} for movie:`, error);
      enqueueSnackbar(`Failed to record your ${action}`, { variant: "error" });
    } finally {
      setIsLoading(false);
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
            your TMDB API key in the Settings to use movie recommendations.
          </Typography>
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
            {searchResults.map((movie) => (
              <Box key={`search-${movie.id}`}>
                <MovieCard
                  movie={movie}
                  isSaved={movie.isSaved}
                  isInWatchlist={watchlistMovies.some(m => m.title === movie.title)}
                  view="default"
                  onSave={() => handleSave(movie)}
                  onAddToWatchlist={() => handleAddToWatchlist(movie)}
                />
              </Box>
            ))}
          </Box>
        </Box>
      )}

      {/* Movie Suggestion Section */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h5" sx={{ mb: 2 }}>
          Suggested for You
        </Typography>

        <MediaSuggestionDisplay
          mediaType="movie"
          suggestedItem={
            suggestedMovie ? mapMovieToSuggestionItem(suggestedMovie) : null
          }
          suggestionReason={suggestionReason}
          isLoading={isLoadingSuggestion}
          error={suggestionError}
          isProcessing={isProcessingFeedback}
          hasBeenLiked={suggestedMovie?.isSaved}
          onRequestSuggestion={handleGetSuggestion}
          onLike={() => {
            // Call the feedback handler
            handleFeedback(session.Outcome.liked);
            // Also update the suggestedMovie to show it's now liked
            if (suggestedMovie) {
              const updatedMovie = { ...suggestedMovie, isSaved: true };
              setSuggestedMovie(updatedMovie);
            }
          }}
          onDislike={() => handleFeedback(session.Outcome.disliked)}
          onSkip={() => {
            if (suggestedMovie && suggestedMovie.isSaved) {
              setSuggestedMovie(null);
              setSuggestionReason(null);
              
              localStorage.removeItem(CACHED_MOVIE_SUGGESTION_KEY);
              localStorage.removeItem(CACHED_MOVIE_REASON_KEY);
              
              handleGetSuggestion();
            } else {
              handleFeedback(session.Outcome.skipped);
            }
          }}
          onAddToLibrary={handleAddToFavorites}
          onAddToWatchlist={suggestedMovie ? () => handleAddToWatchlist(suggestedMovie) : undefined}
          renderImage={renderMoviePoster}
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
            {showWatchlist ? "Hide" : "Show"} ({watchlistMovies.length})
          </Typography>
        </Box>

        {showWatchlist && (
          watchlistMovies.length === 0 ? (
            <Box
              sx={{ textAlign: "center", py: 4, color: "var(--text-secondary)" }}
            >
              <Typography variant="body1">
                Your watchlist is empty. Add movies to watch later by clicking the "Add to Watchlist" icon.
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
              {watchlistMovies.map((movie) => (
                <Box key={`watchlist-${movie.id || movie.title}`}>
                  <MovieCard
                    movie={movie}
                    isSaved={movie.isSaved}
                    view="watchlist"
                    onSave={() => handleSave(movie)}
                    onRemoveFromWatchlist={() => handleRemoveFromWatchlist(movie)}
                    onLike={() => handleWatchlistFeedback(movie, "like")}
                    onDislike={() => handleWatchlistFeedback(movie, "dislike")}
                  />
                </Box>
              ))}
            </Box>
          )
        )}
      </Box>

      {/* Saved Movies Section */}
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
            {showLibrary ? "Hide" : "Show"} ({savedMovies.length})
          </Typography>
        </Box>

        {showLibrary && (
          savedMovies.length === 0 ? (
            <Box
              sx={{ textAlign: "center", py: 4, color: "var(--text-secondary)" }}
            >
              <Typography variant="body1">
                You haven't saved any movies yet. Search for movies and click the
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
                "& > div": {
                  height: "100%",
                },
              }}
            >
              {savedMovies.map((movie, index) => (
                <Box key={`saved-${movie.id || index}`}>
                  <MovieCard
                    movie={movie}
                    isSaved={true}
                    isInWatchlist={watchlistMovies.some(m => m.title === movie.title)}
                    view="default"
                    onSave={() => handleSave(movie)}
                    onAddToWatchlist={() => handleAddToWatchlist(movie)}
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

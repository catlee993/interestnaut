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
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingSuggestion, setIsLoadingSuggestion] = useState(false);
  const [suggestedMovie, setSuggestedMovie] =
    useState<MovieWithSavedStatus | null>(null);
  const [suggestionReason, setSuggestionReason] = useState<string | null>(null);
  const [credentialsError, setCredentialsError] = useState(false);
  const [suggestionError, setSuggestionError] = useState<string | null>(null);
  const [isProcessingFeedback, setIsProcessingFeedback] = useState(false);

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

  // Periodically check credentials status when component is visible
  useEffect(() => {
    const checkInterval = setInterval(() => {
      checkCredentials();
    }, 60000); // Check every minute

    return () => {
      clearInterval(checkInterval);
    };
  }, []);

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
      // Get the current list of saved movies
      const favoriteMovies = await GetFavoriteMovies();

      // If favoriteMovies is null or undefined, treat it as an empty array
      const movies = favoriteMovies || [];
      
      // Create an array to store loaded movie data
      const moviesWithDetails: MovieWithSavedStatus[] = [];

      // Keep track of API calls to avoid too many requests
      let apiCallCount = 0;
      const MAX_API_CALLS = 5; // Limit to 5 API calls per load

      // For each saved movie, check if we already have poster path
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

  const handleSearch = async (query: string) => {
    console.log(`[MovieSection] Searching for movies with query: "${query}"`);
    if (!query.trim()) {
      setSearchResults([]);
      return;
    }

    try {
      setIsLoading(true);
      const response = await SearchMovies(query);

      // Mark movies that are already saved
      const updatedResults = response.map((movie) => ({
        ...movie,
        isSaved: savedMovies.some((saved) => saved.id === movie.id),
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
      // Get the current list of saved movies
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
        enqueueSnackbar(`Removed "${movie.title}" from favorites`, {
          variant: "success",
        });
      } else {
        // Add to saved movies with poster path
        const newFavorite: session.Movie = {
          title: movie.title,
          director: "", // We don't have this info from TMDB
          writer: "", // We don't have this info from TMDB
          poster_path: movie.poster_path || ""
        };
        
        // Add to the existing favorites
        const updatedFavorites = [...movies, newFavorite];

        // Update the backend with the modified list
        await SetFavoriteMovies(updatedFavorites);

        // Update local state
        setSavedMovies((prev) => [...prev, { ...movie, isSaved: true }]);
        enqueueSnackbar(`Added "${movie.title}" to favorites`, {
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
      enqueueSnackbar("Failed to update favorite status", { variant: "error" });
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

      // Check if this is a credentials error
      if (
        error instanceof Error &&
        error.message.includes("credentials not available")
      ) {
        setSuggestionError(
          "Movie recommendations require TMDB API credentials to be configured.",
        );
        setCredentialsError(true);
      } else {
        setSuggestionError(
          "Failed to get movie recommendation. Please try again.",
        );
      }
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
          ? `Added "${suggestedMovie.title}" to favorites`
          : outcome === session.Outcome.disliked
            ? `You disliked "${suggestedMovie.title}"`
            : `Skipped "${suggestedMovie.title}"`;

      const variant =
        outcome === session.Outcome.liked
          ? "success"
          : outcome === session.Outcome.disliked
            ? "error"
            : "info";

      enqueueSnackbar(message, { variant });

      if (outcome === session.Outcome.liked) {
        // Add to saved movies if liked
        handleSave({ ...suggestedMovie, isSaved: false });

        // Clear current suggestion
        setSuggestedMovie(null);
        setSuggestionReason(null);
        
        // Clear localStorage cache
        localStorage.removeItem(CACHED_MOVIE_SUGGESTION_KEY);
        localStorage.removeItem(CACHED_MOVIE_REASON_KEY);
      } else {
        // Get next suggestion immediately for dislike/skip
        setSuggestedMovie(null);
        setSuggestionReason(null);
        
        // Clear localStorage cache
        localStorage.removeItem(CACHED_MOVIE_SUGGESTION_KEY);
        localStorage.removeItem(CACHED_MOVIE_REASON_KEY);
        
        // Short delay for UI feedback
        setTimeout(() => {
          handleGetSuggestion();
        }, 500);
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
      setIsProcessingFeedback(false);
    }
  };

  // Check if TMDB credentials are valid
  const checkCredentials = async () => {
    try {
      const hasCredentials = await HasValidCredentials();
      const newCredentialsError = !hasCredentials;

      // Only update state if it's changed
      if (credentialsError !== newCredentialsError) {
        console.log(
          `[MovieSection] TMDB credentials status changed: ${hasCredentials ? "available" : "not available"}`,
        );
        setCredentialsError(newCredentialsError);

        // If credentials were just fixed, reload the page content
        if (!newCredentialsError && credentialsError) {
          console.log(
            "[MovieSection] TMDB credentials restored, reloading content",
          );
          loadSavedMovies();
          handleGetSuggestion();
        }
      }

      // If we don't have credentials, try to refresh
      if (newCredentialsError) {
        console.log("[MovieSection] Attempting to refresh TMDB credentials");
        const refreshed = await RefreshCredentials();
        if (refreshed) {
          console.log("[MovieSection] TMDB credentials successfully refreshed");
          setCredentialsError(false);
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

      // After a delay, get a new suggestion
      setTimeout(() => {
        setSuggestedMovie(null);
        setSuggestionReason(null);
        
        // Clear localStorage cache
        localStorage.removeItem(CACHED_MOVIE_SUGGESTION_KEY);
        localStorage.removeItem(CACHED_MOVIE_REASON_KEY);
        
        handleGetSuggestion();
      }, 1500);
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
    } finally {
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
                  onSave={() => handleSave(movie)}
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
          onRequestSuggestion={handleGetSuggestion}
          onLike={() => handleFeedback(session.Outcome.liked)}
          onDislike={() => handleFeedback(session.Outcome.disliked)}
          onSkip={() => handleFeedback(session.Outcome.skipped)}
          onAddToLibrary={handleAddToFavorites}
          renderImage={renderMoviePoster}
        />
      </Box>

      {/* Saved Movies Section */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h6" sx={{ mb: 2, color: "text.primary" }}>
          Your Library
        </Typography>

        {savedMovies.length === 0 ? (
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
            {savedMovies.map((movie) => (
              <Box key={`saved-${movie.id}`}>
                <MovieCard
                  movie={movie}
                  isSaved={true}
                  onSave={() => handleSave(movie)}
                />
              </Box>
            ))}
          </Box>
        )}
      </Box>
    </Box>
  );
});

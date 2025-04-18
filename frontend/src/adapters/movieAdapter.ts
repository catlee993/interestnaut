import { MediaItem } from "@/components/common/MediaCard";
import { MovieWithSavedStatus } from "@wailsjs/go/models";
import { session } from "@wailsjs/go/models";

// Convert from API MovieWithSavedStatus to our generic MediaItem
export function movieToMediaItem(
  movie: MovieWithSavedStatus,
  isSaved: boolean
): MediaItem {
  return {
    id: movie.id,
    title: movie.title,
    overview: movie.overview,
    poster_path: movie.poster_path,
    vote_average: movie.vote_average,
    vote_count: movie.vote_count,
    date: movie.release_date,
    isSaved: isSaved || movie.isSaved,
    director: movie.director || "",
    writer: movie.writer || "",
    mediaType: "movie",
  };
}

// Convert from our generic MediaItem to session.Movie for API
export function mediaItemToSessionMovie(item: MediaItem): session.Movie {
  return {
    title: item.title,
    director: item.director || "",
    writer: item.writer || "",
    poster_path: item.poster_path || "",
  };
}

// Extract basic info from a session.Movie
export function sessionMovieToPartialMediaItem(
  movie: session.Movie
): Partial<MediaItem> {
  return {
    title: movie.title || "",
    director: movie.director || "",
    writer: movie.writer || "",
    poster_path: movie.poster_path || "",
  };
}

// Check if two media items represent the same movie
export function isMovieEqual(item1: MediaItem, item2: MediaItem): boolean {
  // Primary check by title
  return item1.title === item2.title;
}

// Movie adapter object for use with useMediaCollection
export const movieAdapter = {
  toMediaItem: movieToMediaItem,
  fromMediaItem: mediaItemToSessionMovie,
  fromApiItem: sessionMovieToPartialMediaItem,
  isItemEqual: isMovieEqual,
}; 
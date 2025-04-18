import { MediaItem } from "@/components/common/MediaCard";
import { bindings } from "@wailsjs/go/models";
import { session } from "@wailsjs/go/models";

// Extended interface from TVShowSection
interface ExtendedTVShowWithSavedStatus extends bindings.TVShowWithSavedStatus {
  isSaved?: boolean;
}

// Convert from API TVShowWithSavedStatus to our generic MediaItem
export function tvShowToMediaItem(
  show: bindings.TVShowWithSavedStatus | ExtendedTVShowWithSavedStatus,
  isSaved: boolean
): MediaItem {
  return {
    id: show.id,
    title: show.name,
    overview: show.overview,
    poster_path: show.poster_path,
    vote_average: show.vote_average,
    vote_count: show.vote_count,
    date: show.first_air_date,
    isSaved: isSaved || (show as ExtendedTVShowWithSavedStatus).isSaved,
    director: show.director || "",
    writer: show.writer || "",
    mediaType: "tv",
  };
}

// Convert from our generic MediaItem to session.TVShow for API
export function mediaItemToSessionTVShow(item: MediaItem): session.TVShow {
  return {
    title: item.title,
    director: item.director || "",
    writer: item.writer || "",
    poster_path: item.poster_path || "",
  };
}

// Extract basic info from a session.TVShow
export function sessionTVShowToPartialMediaItem(
  show: session.TVShow
): Partial<MediaItem> {
  return {
    title: show.title || "",
    director: show.director || "",
    writer: show.writer || "",
    poster_path: show.poster_path || "",
  };
}

// Check if two media items represent the same TV show
export function isTVShowEqual(item1: MediaItem, item2: MediaItem): boolean {
  // Use case-insensitive title comparison for more reliable matching
  return item1.title.toLowerCase() === item2.title.toLowerCase();
}

// TVShow adapter object for use with useMediaCollection
export const tvShowAdapter = {
  toMediaItem: tvShowToMediaItem,
  fromMediaItem: mediaItemToSessionTVShow,
  fromApiItem: sessionTVShowToPartialMediaItem,
  isItemEqual: isTVShowEqual,
}; 
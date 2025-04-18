import {
  SearchTVShows,
  SetFavoriteTVShows,
  GetFavoriteTVShows,
  GetTVShowDetails,
  AddToWatchlist,
  GetWatchlist,
  RemoveFromWatchlist,
} from "@wailsjs/go/bindings/TVShows";
import { bindings } from "@wailsjs/go/models";
import { session } from "@wailsjs/go/models";

export const tvShowAPI = {
  getFavorites: async () => {
    return GetFavoriteTVShows();
  },
  setFavorites: async (shows: session.TVShow[]) => {
    return SetFavoriteTVShows(shows);
  },
  search: async (query: string) => {
    return SearchTVShows(query);
  },
  getDetails: async (id: number) => {
    return GetTVShowDetails(id);
  },
  getWatchlist: async () => {
    return GetWatchlist();
  },
  addToWatchlist: async (show: session.TVShow) => {
    return AddToWatchlist(show);
  },
  removeFromWatchlist: async (title: string) => {
    return RemoveFromWatchlist(title);
  },
}; 
import {
  SearchMovies,
  SetFavoriteMovies,
  GetFavoriteMovies,
  GetMovieDetails,
  AddToWatchlist,
  GetWatchlist,
  RemoveFromWatchlist,
} from "@wailsjs/go/bindings/Movies";
import { MovieWithSavedStatus } from "@wailsjs/go/models";
import { session } from "@wailsjs/go/models";

export const movieAPI = {
  getFavorites: async () => {
    return GetFavoriteMovies();
  },
  setFavorites: async (movies: session.Movie[]) => {
    return SetFavoriteMovies(movies);
  },
  search: async (query: string) => {
    return SearchMovies(query);
  },
  getDetails: async (id: number) => {
    return GetMovieDetails(id);
  },
  getWatchlist: async () => {
    return GetWatchlist();
  },
  addToWatchlist: async (movie: session.Movie) => {
    return AddToWatchlist(movie);
  },
  removeFromWatchlist: async (title: string) => {
    return RemoveFromWatchlist(title);
  },
};
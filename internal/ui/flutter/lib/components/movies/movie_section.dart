import 'package:flutter/material.dart';
import 'movie_card.dart';
import '../common/media_grid.dart';
import '../common/media_section_layout.dart';
import '../common/media_suggestion_display.dart';
import '../../models.dart';

class MovieSection extends StatefulWidget {
  const MovieSection({Key? key}) : super(key: key);

  @override
  State<MovieSection> createState() => _MovieSectionState();
}

class _MovieSectionState extends State<MovieSection> {
  List<MovieWithSavedStatus> movies = [];
  List<MovieWithSavedStatus> watchlist = [];
  List<MovieWithSavedStatus> favorites = [];
  int currentPage = 1;
  int itemsPerPage = 12;
  int totalMovies = 0;
  String searchQuery = '';
  bool isLoadingSuggestion = false;
  String? suggestionError;
  String? suggestionErrorDetails;
  bool isProcessingFeedback = false;
  MovieWithSavedStatus? suggestedMovie;
  String? suggestionReason;
  bool showSearchResults = false;
  bool showWatchlist = false;
  bool showLibrary = false;

  @override
  void initState() {
    super.initState();
    // TODO: Load initial movies, favorites, and watchlist from backend
  }

  void onSearch(String query) {
    setState(() {
      searchQuery = query;
      showSearchResults = query.isNotEmpty;
      // TODO: Search movies from backend
    });
  }

  void onSave(int id) {
    setState(() {
      // TODO: Save or unsave movie in backend
    });
  }

  void onAddToWatchlist(int id) {
    setState(() {
      // TODO: Add movie to watchlist in backend
    });
  }

  void onRemoveFromWatchlist(int id) {
    setState(() {
      // TODO: Remove movie from watchlist in backend
    });
  }

  void onLike(int id) {
    // TODO: Provide like feedback to backend
  }

  void onDislike(int id) {
    // TODO: Provide dislike feedback to backend
  }

  void onNextPage() {
    setState(() {
      currentPage++;
      // TODO: Load next page from backend
    });
  }

  void onPrevPage() {
    setState(() {
      if (currentPage > 1) currentPage--;
      // TODO: Load previous page from backend
    });
  }

  void onRequestSuggestion() {
    setState(() {
      isLoadingSuggestion = true;
      suggestionError = null;
      suggestionErrorDetails = null;
    });
    // TODO: Request movie suggestion from backend
  }

  void onLikeSuggestion() {
    setState(() {
      isProcessingFeedback = true;
    });
    // TODO: Send like feedback for suggestion to backend
  }

  void onDislikeSuggestion() {
    setState(() {
      isProcessingFeedback = true;
    });
    // TODO: Send dislike feedback for suggestion to backend
  }

  void onSkipSuggestion() {
    setState(() {
      suggestedMovie = null;
      suggestionReason = null;
    });
  }

  void onAddSuggestionToWatchlist() {
    if (suggestedMovie != null) {
      onAddToWatchlist(suggestedMovie!.id);
    }
  }

  void onToggleWatchlist() {
    setState(() {
      showWatchlist = !showWatchlist;
    });
  }

  void onToggleLibrary() {
    setState(() {
      showLibrary = !showLibrary;
    });
  }

  MediaSuggestionItem _mapMovieToSuggestionItem(MovieWithSavedStatus movie) {
    return MediaSuggestionItem(
      id: movie.id,
      title: movie.title,
      description: movie.overview,
      imageUrl: movie.posterPath != null ? 'https://image.tmdb.org/t/p/w500${movie.posterPath}' : null,
      releaseDate: movie.releaseDate,
      rating: movie.voteAverage,
      voteCount: movie.voteCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaSectionLayout<MovieWithSavedStatus>(
      type: 'movie',
      typeName: 'Movie',
      searchResultsKey: GlobalKey(),
      credentialsError: false,
      isLoadingSuggestion: isLoadingSuggestion,
      suggestionError: suggestionError,
      suggestionErrorDetails: suggestionErrorDetails,
      isProcessingFeedback: isProcessingFeedback,
      searchResults: movies,
      showSearchResults: showSearchResults,
      watchlistItems: watchlist,
      savedItems: favorites,
      showWatchlist: showWatchlist,
      showLibrary: showLibrary,
      suggestedItem: suggestedMovie,
      suggestionReason: suggestionReason,
      onRefreshCredentials: () {
        // TODO: Refresh API credentials
      },
      onRequestSuggestion: onRequestSuggestion,
      onLikeSuggestion: onLikeSuggestion,
      onDislikeSuggestion: onDislikeSuggestion,
      onSkipSuggestion: onSkipSuggestion,
      onAddToLibrary: onAddSuggestionToWatchlist,
      onAddSuggestionToWatchlist: onAddSuggestionToWatchlist,
      onToggleWatchlist: onToggleWatchlist,
      onToggleLibrary: onToggleLibrary,
      onHideSearchResults: () {
        setState(() {
          showSearchResults = false;
          searchQuery = '';
        });
      },
      renderSearchResults: () => MediaGrid(
        children: movies
            .map((movie) => MovieCard(
                  movie: movie,
                  isSaved: favorites.any((fav) => fav.id == movie.id),
                  isInWatchlist: watchlist.any((wl) => wl.id == movie.id),
                  onSave: onSave,
                  onAddToWatchlist: onAddToWatchlist,
                  onRemoveFromWatchlist: onRemoveFromWatchlist,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      renderWatchlistItems: () => MediaGrid(
        children: watchlist
            .map((movie) => MovieCard(
                  movie: movie,
                  isSaved: favorites.any((fav) => fav.id == movie.id),
                  isInWatchlist: true,
                  view: 'watchlist',
                  onSave: onSave,
                  onAddToWatchlist: onAddToWatchlist,
                  onRemoveFromWatchlist: onRemoveFromWatchlist,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      renderSavedItems: () => MediaGrid(
        children: favorites
            .map((movie) => MovieCard(
                  movie: movie,
                  isSaved: true,
                  isInWatchlist: watchlist.any((wl) => wl.id == movie.id),
                  view: 'saved',
                  onSave: onSave,
                  onAddToWatchlist: onAddToWatchlist,
                  onRemoveFromWatchlist: onRemoveFromWatchlist,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      mapToSuggestionItem: _mapMovieToSuggestionItem,
      queueName: 'Watchlist',
    );
  }
} 
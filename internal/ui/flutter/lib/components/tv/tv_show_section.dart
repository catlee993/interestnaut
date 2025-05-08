import 'package:flutter/material.dart';
import 'tv_show_card.dart';
import '../common/media_grid.dart';
import '../common/media_section_layout.dart';
import '../common/media_suggestion_display.dart';
import '../../models.dart';

class TVShowSection extends StatefulWidget {
  const TVShowSection({Key? key}) : super(key: key);

  @override
  State<TVShowSection> createState() => _TVShowSectionState();
}

class _TVShowSectionState extends State<TVShowSection> {
  List<TVShowWithSavedStatus> shows = [];
  List<TVShowWithSavedStatus> watchlist = [];
  List<TVShowWithSavedStatus> favorites = [];
  int currentPage = 1;
  int itemsPerPage = 12;
  int totalShows = 0;
  String searchQuery = '';
  bool isLoadingSuggestion = false;
  String? suggestionError;
  String? suggestionErrorDetails;
  bool isProcessingFeedback = false;
  TVShowWithSavedStatus? suggestedShow;
  String? suggestionReason;
  bool showSearchResults = false;
  bool showWatchlist = false;
  bool showLibrary = false;

  @override
  void initState() {
    super.initState();
    // TODO: Load initial shows, favorites, and watchlist from backend
  }

  void onSearch(String query) {
    setState(() {
      searchQuery = query;
      showSearchResults = query.isNotEmpty;
      // TODO: Search TV shows from backend
    });
  }

  void onSave(int id) {
    setState(() {
      // TODO: Save or unsave TV show in backend
    });
  }

  void onAddToWatchlist(int id) {
    setState(() {
      // TODO: Add TV show to watchlist in backend
    });
  }

  void onRemoveFromWatchlist(int id) {
    setState(() {
      // TODO: Remove TV show from watchlist in backend
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
    // TODO: Request TV show suggestion from backend
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
      suggestedShow = null;
      suggestionReason = null;
    });
  }

  void onAddSuggestionToWatchlist() {
    if (suggestedShow != null) {
      onAddToWatchlist(suggestedShow!.id);
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

  MediaSuggestionItem _mapShowToSuggestionItem(TVShowWithSavedStatus show) {
    return MediaSuggestionItem(
      id: show.id,
      title: show.name,
      description: show.overview,
      imageUrl: show.posterPath != null ? 'https://image.tmdb.org/t/p/w500${show.posterPath}' : null,
      releaseDate: show.firstAirDate,
      rating: show.voteAverage,
      voteCount: show.voteCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaSectionLayout<TVShowWithSavedStatus>(
      type: 'tv',
      typeName: 'TV Show',
      searchResultsKey: GlobalKey(),
      credentialsError: false,
      isLoadingSuggestion: isLoadingSuggestion,
      suggestionError: suggestionError,
      suggestionErrorDetails: suggestionErrorDetails,
      isProcessingFeedback: isProcessingFeedback,
      searchResults: shows,
      showSearchResults: showSearchResults,
      watchlistItems: watchlist,
      savedItems: favorites,
      showWatchlist: showWatchlist,
      showLibrary: showLibrary,
      suggestedItem: suggestedShow,
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
        children: shows
            .map((show) => TVShowCard(
                  show: show,
                  isSaved: favorites.any((fav) => fav.id == show.id),
                  isInWatchlist: watchlist.any((wl) => wl.id == show.id),
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
            .map((show) => TVShowCard(
                  show: show,
                  isSaved: favorites.any((fav) => fav.id == show.id),
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
            .map((show) => TVShowCard(
                  show: show,
                  isSaved: true,
                  isInWatchlist: watchlist.any((wl) => wl.id == show.id),
                  view: 'saved',
                  onSave: onSave,
                  onAddToWatchlist: onAddToWatchlist,
                  onRemoveFromWatchlist: onRemoveFromWatchlist,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      mapToSuggestionItem: _mapShowToSuggestionItem,
      queueName: 'Watchlist',
    );
  }
} 
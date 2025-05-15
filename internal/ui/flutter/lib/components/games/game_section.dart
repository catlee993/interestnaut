import 'package:flutter/material.dart';
import 'game_card.dart';
import '../common/media_grid.dart';
import '../common/media_section_layout.dart';
import '../../models.dart';

class GameSection extends StatefulWidget {
  const GameSection({Key? key}) : super(key: key);

  @override
  State<GameSection> createState() => _GameSectionState();
}

class _GameSectionState extends State<GameSection> {
  List<GameWithSavedStatus> games = [];
  List<GameWithSavedStatus> library = [];
  List<GameWithSavedStatus> favorites = [];
  int currentPage = 1;
  int itemsPerPage = 12;
  int totalGames = 0;
  String searchQuery = '';
  bool isLoadingSuggestion = false;
  String? suggestionError;
  String? suggestionErrorDetails;
  bool isProcessingFeedback = false;
  GameWithSavedStatus? suggestedGame;
  String? suggestionReason;
  bool showSearchResults = false;
  bool showLibrary = false;

  @override
  void initState() {
    super.initState();
    // TODO: Load initial games, favorites, and library from backend
  }

  void onSearch(String query) {
    setState(() {
      searchQuery = query;
      showSearchResults = query.isNotEmpty;
      // TODO: Search games from backend
    });
  }

  void onSave(int id) {
    setState(() {
      // TODO: Save or unsave game in backend
    });
  }

  void onAddToLibrary(int id) {
    setState(() {
      // TODO: Add game to library in backend
    });
  }

  void onRemoveFromLibrary(int id) {
    setState(() {
      // TODO: Remove game from library in backend
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
    // TODO: Request game suggestion from backend
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
      suggestedGame = null;
      suggestionReason = null;
    });
  }

  void onAddSuggestionToLibrary() {
    if (suggestedGame != null) {
      onAddToLibrary(suggestedGame!.id);
    }
  }

  void onToggleLibrary() {
    setState(() {
      showLibrary = !showLibrary;
    });
  }

  MediaSuggestionItem _mapGameToSuggestionItem(GameWithSavedStatus game) {
    return MediaSuggestionItem(
      id: game.id,
      title: game.name,
      description: game.description,
      imageUrl: game.coverUrl,
      releaseDate: game.releaseDate,
      rating: game.rating,
      voteCount: game.ratingsCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaSectionLayout<GameWithSavedStatus>(
      type: 'game',
      typeName: 'Game',
      searchResultsKey: GlobalKey(),
      credentialsError: false,
      isLoadingSuggestion: isLoadingSuggestion,
      suggestionError: suggestionError,
      suggestionErrorDetails: suggestionErrorDetails,
      isProcessingFeedback: isProcessingFeedback,
      searchResults: games,
      showSearchResults: showSearchResults,
      watchlistItems: library,
      savedItems: favorites,
      showWatchlist: false,
      showLibrary: showLibrary,
      suggestedItem: suggestedGame,
      suggestionReason: suggestionReason,
      onRefreshCredentials: () {
        // TODO: Refresh API credentials
      },
      onRequestSuggestion: onRequestSuggestion,
      onLikeSuggestion: onLikeSuggestion,
      onDislikeSuggestion: onDislikeSuggestion,
      onSkipSuggestion: onSkipSuggestion,
      onAddToLibrary: onAddSuggestionToLibrary,
      onAddSuggestionToWatchlist: onAddSuggestionToLibrary,
      onToggleWatchlist: () {}, // Not used for games
      onToggleLibrary: onToggleLibrary,
      onHideSearchResults: () {
        setState(() {
          showSearchResults = false;
          searchQuery = '';
        });
      },
      renderSearchResults: () => MediaGrid(
        children: games
            .map((game) => GameCard(
                  game: game,
                  isSaved: favorites.any((fav) => fav.id == game.id),
                  isInLibrary: library.any((lib) => lib.id == game.id),
                  onSave: onSave,
                  onAddToLibrary: onAddToLibrary,
                  onRemoveFromLibrary: onRemoveFromLibrary,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      renderWatchlistItems: () => MediaGrid(
        children: library
            .map((game) => GameCard(
                  game: game,
                  isSaved: favorites.any((fav) => fav.id == game.id),
                  isInLibrary: true,
                  view: 'library',
                  onSave: onSave,
                  onAddToLibrary: onAddToLibrary,
                  onRemoveFromLibrary: onRemoveFromLibrary,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      renderSavedItems: () => MediaGrid(
        children: favorites
            .map((game) => GameCard(
                  game: game,
                  isSaved: true,
                  isInLibrary: library.any((lib) => lib.id == game.id),
                  view: 'saved',
                  onSave: onSave,
                  onAddToLibrary: onAddToLibrary,
                  onRemoveFromLibrary: onRemoveFromLibrary,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      mapToSuggestionItem: _mapGameToSuggestionItem,
      queueName: 'Library',
    );
  }
} 
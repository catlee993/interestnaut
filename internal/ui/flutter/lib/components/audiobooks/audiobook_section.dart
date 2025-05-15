import 'package:flutter/material.dart';
import 'audiobook_card.dart';
import '../common/media_grid.dart';
import '../common/media_section_layout.dart';
import '../../models.dart';

class AudiobookSection extends StatefulWidget {
  const AudiobookSection({Key? key}) : super(key: key);

  @override
  State<AudiobookSection> createState() => _AudiobookSectionState();
}

class _AudiobookSectionState extends State<AudiobookSection> {
  List<AudiobookWithSavedStatus> audiobooks = [];
  List<AudiobookWithSavedStatus> listenList = [];
  List<AudiobookWithSavedStatus> favorites = [];
  int currentPage = 1;
  int itemsPerPage = 12;
  int totalAudiobooks = 0;
  String searchQuery = '';
  bool isLoadingSuggestion = false;
  String? suggestionError;
  String? suggestionErrorDetails;
  bool isProcessingFeedback = false;
  AudiobookWithSavedStatus? suggestedAudiobook;
  String? suggestionReason;
  bool showSearchResults = false;
  bool showListenList = false;
  bool showLibrary = false;

  @override
  void initState() {
    super.initState();
    // TODO: Load initial audiobooks, favorites, and listen list from backend
  }

  void onSearch(String query) {
    setState(() {
      searchQuery = query;
      showSearchResults = query.isNotEmpty;
      // TODO: Search audiobooks from backend
    });
  }

  void onSave(String title, String author) {
    setState(() {
      // TODO: Save or unsave audiobook in backend
    });
  }

  void onAddToListenList(String title, String author) {
    setState(() {
      // TODO: Add audiobook to listen list in backend
    });
  }

  void onRemoveFromListenList(String title, String author) {
    setState(() {
      // TODO: Remove audiobook from listen list in backend
    });
  }

  void onLike(String title, String author) {
    // TODO: Provide like feedback to backend
  }

  void onDislike(String title, String author) {
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
    // TODO: Request audiobook suggestion from backend
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
      suggestedAudiobook = null;
      suggestionReason = null;
    });
  }

  void onAddSuggestionToListenList() {
    if (suggestedAudiobook != null) {
      onAddToListenList(suggestedAudiobook!.title, suggestedAudiobook!.author);
    }
  }

  void onToggleListenList() {
    setState(() {
      showListenList = !showListenList;
    });
  }

  void onToggleLibrary() {
    setState(() {
      showLibrary = !showLibrary;
    });
  }

  MediaSuggestionItem _mapAudiobookToSuggestionItem(AudiobookWithSavedStatus audiobook) {
    return MediaSuggestionItem(
      id: audiobook.key,
      title: audiobook.title,
      artist: audiobook.author,
      description: audiobook.description,
      imageUrl: audiobook.coverPath,
      releaseDate: audiobook.year?.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaSectionLayout<AudiobookWithSavedStatus>(
      type: 'audiobook',
      typeName: 'Audiobook',
      searchResultsKey: GlobalKey(),
      credentialsError: false,
      isLoadingSuggestion: isLoadingSuggestion,
      suggestionError: suggestionError,
      suggestionErrorDetails: suggestionErrorDetails,
      isProcessingFeedback: isProcessingFeedback,
      searchResults: audiobooks,
      showSearchResults: showSearchResults,
      watchlistItems: listenList,
      savedItems: favorites,
      showWatchlist: showListenList,
      showLibrary: showLibrary,
      suggestedItem: suggestedAudiobook,
      suggestionReason: suggestionReason,
      onRefreshCredentials: () {
        // TODO: Refresh API credentials
      },
      onRequestSuggestion: onRequestSuggestion,
      onLikeSuggestion: onLikeSuggestion,
      onDislikeSuggestion: onDislikeSuggestion,
      onSkipSuggestion: onSkipSuggestion,
      onAddToLibrary: onAddSuggestionToListenList,
      onAddSuggestionToWatchlist: onAddSuggestionToListenList,
      onToggleWatchlist: onToggleListenList,
      onToggleLibrary: onToggleLibrary,
      onHideSearchResults: () {
        setState(() {
          showSearchResults = false;
          searchQuery = '';
        });
      },
      renderSearchResults: () => MediaGrid(
        children: audiobooks
            .map((audiobook) => AudiobookCard(
                  audiobook: audiobook,
                  isSaved: favorites.any((fav) => fav.key == audiobook.key),
                  isInListenList: listenList.any((ll) => ll.key == audiobook.key),
                  onSave: onSave,
                  onAddToListenList: onAddToListenList,
                  onRemoveFromListenList: onRemoveFromListenList,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      renderWatchlistItems: () => MediaGrid(
        children: listenList
            .map((audiobook) => AudiobookCard(
                  audiobook: audiobook,
                  isSaved: favorites.any((fav) => fav.key == audiobook.key),
                  isInListenList: true,
                  view: 'listenlist',
                  onSave: onSave,
                  onAddToListenList: onAddToListenList,
                  onRemoveFromListenList: onRemoveFromListenList,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      renderSavedItems: () => MediaGrid(
        children: favorites
            .map((audiobook) => AudiobookCard(
                  audiobook: audiobook,
                  isSaved: true,
                  isInListenList: listenList.any((ll) => ll.key == audiobook.key),
                  view: 'saved',
                  onSave: onSave,
                  onAddToListenList: onAddToListenList,
                  onRemoveFromListenList: onRemoveFromListenList,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      mapToSuggestionItem: _mapAudiobookToSuggestionItem,
      queueName: 'Listen List',
    );
  }
} 
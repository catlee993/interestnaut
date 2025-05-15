import 'package:flutter/material.dart';
import 'book_card.dart';
import '../common/media_grid.dart';
import '../common/media_section_layout.dart';
import '../../models.dart';

class BookSection extends StatefulWidget {
  const BookSection({Key? key}) : super(key: key);

  @override
  State<BookSection> createState() => _BookSectionState();
}

class _BookSectionState extends State<BookSection> {
  List<BookWithSavedStatus> books = [];
  List<BookWithSavedStatus> readList = [];
  List<BookWithSavedStatus> favorites = [];
  int currentPage = 1;
  int itemsPerPage = 12;
  int totalBooks = 0;
  String searchQuery = '';
  bool isLoadingSuggestion = false;
  String? suggestionError;
  String? suggestionErrorDetails;
  bool isProcessingFeedback = false;
  BookWithSavedStatus? suggestedBook;
  String? suggestionReason;
  bool showSearchResults = false;
  bool showReadList = false;
  bool showLibrary = false;

  @override
  void initState() {
    super.initState();
    // TODO: Load initial books, favorites, and read list from backend
  }

  void onSearch(String query) {
    setState(() {
      searchQuery = query;
      showSearchResults = query.isNotEmpty;
      // TODO: Search books from backend
    });
  }

  void onSave(String title, String author) {
    setState(() {
      // TODO: Save or unsave book in backend
    });
  }

  void onAddToReadList(String title, String author) {
    setState(() {
      // TODO: Add book to read list in backend
    });
  }

  void onRemoveFromReadList(String title, String author) {
    setState(() {
      // TODO: Remove book from read list in backend
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
    // TODO: Request book suggestion from backend
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
      suggestedBook = null;
      suggestionReason = null;
    });
  }

  void onAddSuggestionToReadList() {
    if (suggestedBook != null) {
      onAddToReadList(suggestedBook!.title, suggestedBook!.author);
    }
  }

  void onToggleReadList() {
    setState(() {
      showReadList = !showReadList;
    });
  }

  void onToggleLibrary() {
    setState(() {
      showLibrary = !showLibrary;
    });
  }

  MediaSuggestionItem _mapBookToSuggestionItem(BookWithSavedStatus book) {
    return MediaSuggestionItem(
      id: book.key,
      title: book.title,
      artist: book.author,
      description: book.description,
      imageUrl: book.coverPath,
      releaseDate: book.year?.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaSectionLayout<BookWithSavedStatus>(
      type: 'book',
      typeName: 'Book',
      searchResultsKey: GlobalKey(),
      credentialsError: false,
      isLoadingSuggestion: isLoadingSuggestion,
      suggestionError: suggestionError,
      suggestionErrorDetails: suggestionErrorDetails,
      isProcessingFeedback: isProcessingFeedback,
      searchResults: books,
      showSearchResults: showSearchResults,
      watchlistItems: readList,
      savedItems: favorites,
      showWatchlist: showReadList,
      showLibrary: showLibrary,
      suggestedItem: suggestedBook,
      suggestionReason: suggestionReason,
      onRefreshCredentials: () {
        // TODO: Refresh API credentials
      },
      onRequestSuggestion: onRequestSuggestion,
      onLikeSuggestion: onLikeSuggestion,
      onDislikeSuggestion: onDislikeSuggestion,
      onSkipSuggestion: onSkipSuggestion,
      onAddToLibrary: onAddSuggestionToReadList,
      onAddSuggestionToWatchlist: onAddSuggestionToReadList,
      onToggleWatchlist: onToggleReadList,
      onToggleLibrary: onToggleLibrary,
      onHideSearchResults: () {
        setState(() {
          showSearchResults = false;
          searchQuery = '';
        });
      },
      renderSearchResults: () => MediaGrid(
        children: books
            .map((book) => BookCard(
                  book: book,
                  isSaved: favorites.any((fav) => fav.key == book.key),
                  isInReadList: readList.any((rl) => rl.key == book.key),
                  onSave: onSave,
                  onAddToReadList: onAddToReadList,
                  onRemoveFromReadList: onRemoveFromReadList,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      renderWatchlistItems: () => MediaGrid(
        children: readList
            .map((book) => BookCard(
                  book: book,
                  isSaved: favorites.any((fav) => fav.key == book.key),
                  isInReadList: true,
                  view: 'readlist',
                  onSave: onSave,
                  onAddToReadList: onAddToReadList,
                  onRemoveFromReadList: onRemoveFromReadList,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      renderSavedItems: () => MediaGrid(
        children: favorites
            .map((book) => BookCard(
                  book: book,
                  isSaved: true,
                  isInReadList: readList.any((rl) => rl.key == book.key),
                  view: 'saved',
                  onSave: onSave,
                  onAddToReadList: onAddToReadList,
                  onRemoveFromReadList: onRemoveFromReadList,
                  onLike: onLike,
                  onDislike: onDislike,
                ))
            .toList(),
      ),
      mapToSuggestionItem: _mapBookToSuggestionItem,
      queueName: 'Read List',
    );
  }
} 
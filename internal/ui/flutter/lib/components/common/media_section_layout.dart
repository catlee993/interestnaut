import 'package:flutter/material.dart';
import '../../models.dart';
import 'media_suggestion_display.dart';

class MediaSectionLayout<T> extends StatelessWidget {
  final String type;
  final String typeName;
  final GlobalKey searchResultsKey;
  final bool credentialsError;
  final bool isLoadingSuggestion;
  final String? suggestionError;
  final String? suggestionErrorDetails;
  final bool isProcessingFeedback;
  final List<T> searchResults;
  final bool showSearchResults;
  final List<T> watchlistItems;
  final List<T> savedItems;
  final bool showWatchlist;
  final bool showLibrary;
  final T? suggestedItem;
  final String? suggestionReason;
  final VoidCallback onRefreshCredentials;
  final VoidCallback onRequestSuggestion;
  final VoidCallback onLikeSuggestion;
  final VoidCallback onDislikeSuggestion;
  final VoidCallback onSkipSuggestion;
  final VoidCallback onAddToLibrary;
  final VoidCallback? onAddSuggestionToWatchlist;
  final VoidCallback onToggleWatchlist;
  final VoidCallback onToggleLibrary;
  final VoidCallback? onHideSearchResults;
  final Widget Function() renderSearchResults;
  final Widget Function() renderWatchlistItems;
  final Widget Function() renderSavedItems;
  final Widget Function(MediaSuggestionItem)? renderSuggestionPoster;
  final Widget? headerContent;
  final Widget? footerContent;
  final MediaSuggestionItem Function(T) mapToSuggestionItem;
  final String queueName;

  const MediaSectionLayout({
    Key? key,
    required this.type,
    required this.typeName,
    required this.searchResultsKey,
    required this.credentialsError,
    required this.isLoadingSuggestion,
    required this.suggestionError,
    this.suggestionErrorDetails,
    required this.isProcessingFeedback,
    required this.searchResults,
    required this.showSearchResults,
    required this.watchlistItems,
    required this.savedItems,
    required this.showWatchlist,
    required this.showLibrary,
    required this.suggestedItem,
    required this.suggestionReason,
    required this.onRefreshCredentials,
    required this.onRequestSuggestion,
    required this.onLikeSuggestion,
    required this.onDislikeSuggestion,
    required this.onSkipSuggestion,
    required this.onAddToLibrary,
    this.onAddSuggestionToWatchlist,
    required this.onToggleWatchlist,
    required this.onToggleLibrary,
    this.onHideSearchResults,
    required this.renderSearchResults,
    required this.renderWatchlistItems,
    required this.renderSavedItems,
    this.renderSuggestionPoster,
    this.headerContent,
    this.footerContent,
    required this.mapToSuggestionItem,
    this.queueName = 'Watchlist',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (headerContent != null) headerContent!,
        if (credentialsError && !isLoadingSuggestion)
          Container(
            margin: const EdgeInsets.only(bottom: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color.fromRGBO(0, 145, 234, 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color.fromRGBO(0, 145, 234, 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Missing API Credentials', style: TextStyle(color: Color(0xFF0091EA), fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  type == 'game'
                      ? 'The RAWG API credentials are not configured. Please set up your RAWG API key in the Settings to use game recommendations.'
                      : 'The Movie Database API credentials are not configured. Please set up your TMDB API key in the Settings to use recommendations.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        if (searchResults.isNotEmpty && showSearchResults && renderSearchResults != null)
          Container(
            margin: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Search Results', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                renderSearchResults(),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Suggested for You', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              if (suggestedItem != null)
                MediaSuggestionDisplay(
                  mediaType: type,
                  suggestedItem: mapToSuggestionItem(suggestedItem!),
                  suggestionReason: suggestionReason,
                  isLoading: isLoadingSuggestion,
                  error: suggestionError,
                  errorDetails: suggestionErrorDetails,
                  isProcessing: isProcessingFeedback,
                  hasBeenLiked: false,
                  onRequestSuggestion: onRequestSuggestion,
                  onLike: onLikeSuggestion,
                  onDislike: onDislikeSuggestion,
                  onSkip: onSkipSuggestion,
                  onAddToLibrary: onAddToLibrary,
                  onAddToWatchlist: onAddSuggestionToWatchlist,
                  renderImage: renderSuggestionPoster,
                  queueName: queueName,
                )
              else
                Center(
                  child: ElevatedButton(
                    onPressed: isLoadingSuggestion ? null : onRequestSuggestion,
                    child: Text('Get a Suggestion'),
                  ),
                ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onToggleWatchlist,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Your $queueName', style: TextStyle(fontSize: 18, color: Colors.white)),
                    const SizedBox(width: 12),
                    Text(
                      showWatchlist ? 'Hide (${watchlistItems.length})' : 'Show (${watchlistItems.length})',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (showWatchlist)
                (watchlistItems.isEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text('Your watchlist is empty. Add ${typeName.toLowerCase()}s to watch later by clicking the "Add to Watchlist" icon.', style: TextStyle(color: Colors.white54)),
                        ),
                      )
                    : renderWatchlistItems(),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onToggleLibrary,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Your Library', style: TextStyle(fontSize: 18, color: Colors.white)),
                    const SizedBox(width: 12),
                    Text(
                      showLibrary ? 'Hide (${savedItems.length})' : 'Show (${savedItems.length})',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (showLibrary)
                (savedItems.isEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text("You haven't saved any ${typeName.toLowerCase()}s yet. Search for ${typeName.toLowerCase()}s and click the heart icon to add them to your favorites.", style: TextStyle(color: Colors.white54)),
                        ),
                      )
                    : renderSavedItems(),
            ],
          ),
        ),
        if (footerContent != null) footerContent!,
      ],
    );
  }
} 
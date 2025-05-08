import 'package:flutter/material.dart';
import '../../models.dart';

class MediaSuggestionDisplay extends StatelessWidget {
  final String mediaType;
  final MediaSuggestionItem? suggestedItem;
  final String? suggestionReason;
  final bool isLoading;
  final String? error;
  final String? errorDetails;
  final bool isProcessing;
  final bool hasBeenLiked;
  final VoidCallback onRequestSuggestion;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onSkip;
  final VoidCallback? onAddToLibrary;
  final VoidCallback? onAddToWatchlist;
  final Widget Function(MediaSuggestionItem)? renderImage;
  final String queueName;

  const MediaSuggestionDisplay({
    Key? key,
    required this.mediaType,
    required this.suggestedItem,
    required this.suggestionReason,
    required this.isLoading,
    required this.error,
    this.errorDetails,
    required this.isProcessing,
    this.hasBeenLiked = false,
    required this.onRequestSuggestion,
    required this.onLike,
    required this.onDislike,
    required this.onSkip,
    this.onAddToLibrary,
    this.onAddToWatchlist,
    this.renderImage,
    this.queueName = 'Watchlist',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: SizedBox(
          height: 48,
          width: 48,
          child: CircularProgressIndicator(
            color: Color.fromRGBO(123, 104, 238, 0.7),
          ),
        ),
      );
    }

    if (error != null && error!.isNotEmpty) {
      final truncatedError = error!.length > 500 ? error!.substring(0, 500) + '...' : error!;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Color.fromRGBO(194, 59, 133, 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color.fromRGBO(194, 59, 133, 0.3)),
            ),
            child: Text(
              truncatedError,
              style: TextStyle(
                color: Color(0xFFC23B85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (errorDetails != null && errorDetails!.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 16),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color.fromRGBO(0, 0, 0, 0.1)),
              ),
              child: Text(
                errorDetails!,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ElevatedButton(
              onPressed: isProcessing ? null : onRequestSuggestion,
              child: Text('Try Again'),
            ),
          ),
        ],
      );
    }

    if (suggestedItem == null) {
      return Center(
        child: ElevatedButton(
          onPressed: isProcessing ? null : onRequestSuggestion,
          child: Text('Get a Suggestion'),
        ),
      );
    }

    Widget defaultImage(MediaSuggestionItem item) {
      if (item.imageUrl == null || item.imageUrl!.isEmpty) return SizedBox.shrink();
      return Card(
        child: Image.network(
          item.imageUrl!,
          height: 450,
          width: 300,
          fit: BoxFit.cover,
          color: isProcessing ? Colors.black.withOpacity(0.5) : null,
          colorBlendMode: isProcessing ? BlendMode.darken : null,
        ),
      );
    }

    String getAddToLibraryButtonText() {
      switch (mediaType) {
        case 'movie':
          return 'Favorite';
        case 'book':
          return 'Reading List';
        case 'podcast':
          return 'Listen Later';
        default:
          return 'Library';
      }
    }

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 300,
            height: 450,
            child: suggestedItem != null
                ? (renderImage != null ? renderImage!(suggestedItem!) : defaultImage(suggestedItem!))
                : const SizedBox.shrink(),
          ),
          SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestedItem?.title ?? '',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (mediaType == 'movie')
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${suggestedItem?.releaseDate?.substring(0, 4) ?? ''}${suggestedItem?.rating != null ? ' • Rating: ${suggestedItem?.rating}/10' : ''}${suggestedItem?.voteCount != null ? ' (${suggestedItem?.voteCount} votes)' : ''}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black54),
                    ),
                  ),
                if (suggestedItem?.artist != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      suggestedItem?.artist ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                if (suggestedItem?.description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      suggestedItem?.description ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                if (suggestionReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      suggestionReason!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Spacer(),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: isProcessing ? null : onLike,
                      icon: Icon(Icons.thumb_up),
                      label: Text('Like'),
                    ),
                    ElevatedButton.icon(
                      onPressed: isProcessing ? null : onDislike,
                      icon: Icon(Icons.thumb_down),
                      label: Text('Dislike'),
                    ),
                    if (onAddToWatchlist != null && mediaType == 'movie')
                      ElevatedButton.icon(
                        onPressed: isProcessing ? null : onAddToWatchlist,
                        icon: Icon(Icons.playlist_add),
                        label: Text(queueName),
                      ),
                    if (onAddToLibrary != null && (mediaType == 'movie' || mediaType == 'book' || mediaType == 'podcast'))
                      ElevatedButton.icon(
                        onPressed: isProcessing ? null : onAddToLibrary,
                        icon: Icon(Icons.favorite),
                        label: Text(getAddToLibraryButtonText()),
                      ),
                    ElevatedButton.icon(
                      onPressed: isProcessing ? null : onSkip,
                      icon: Icon(Icons.skip_next),
                      label: Text(hasBeenLiked ? 'Next' : 'Skip'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 
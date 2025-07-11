import 'package:flutter/material.dart';
import '../../models.dart';
import '../../theme.dart';

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
      return const Center(
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
      final truncatedError = error!.length > 500 ? '${error!.substring(0, 500)}...' : error!;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(194, 59, 133, 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color.fromRGBO(194, 59, 133, 0.3)),
            ),
            child: Text(
              truncatedError,
              style: const TextStyle(
                color: Color(0xFFC23B85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (errorDetails != null && errorDetails!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(0, 0, 0, 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.1)),
              ),
              child: Text(
                errorDetails!,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ElevatedButton(
              onPressed: isProcessing ? null : onRequestSuggestion,
              child: const Text('Try Again'),
            ),
          ),
        ],
      );
    }

    if (suggestedItem == null) {
      return Center(
        child: ElevatedButton(
          onPressed: isProcessing ? null : onRequestSuggestion,
          child: const Text('Get a Suggestion'),
        ),
      );
    }

    Widget defaultImage(MediaSuggestionItem item) {
      if (item.imageUrl == null || item.imageUrl!.isEmpty) return const SizedBox.shrink();
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 300,
            height: 450,
            child: suggestedItem != null
                ? (renderImage != null ? renderImage!(suggestedItem!) : defaultImage(suggestedItem!))
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  () {
                    final displayInfo = MediaDisplayHelper.resolveDisplayInfo(
                      title: suggestedItem?.title,
                      artist: suggestedItem?.artist,
                      fallbackTitle: '',
                    );
                    return displayInfo.displayTitle;
                  }(),
                  style: AppTheme.mediaTitleStyle.copyWith(fontSize: 24),
                ),
                if (mediaType == 'movie')
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${suggestedItem?.releaseDate?.substring(0, 4) ?? ''}${suggestedItem?.rating != null ? ' • Rating: ${suggestedItem?.rating}/10' : ''}${suggestedItem?.voteCount != null ? ' (${suggestedItem?.voteCount} votes)' : ''}',
                      style: AppTheme.mediaDescriptionStyle,
                    ),
                  ),
                () {
                  final displayInfo = MediaDisplayHelper.resolveDisplayInfo(
                    title: suggestedItem?.title,
                    artist: suggestedItem?.artist,
                    fallbackTitle: '',
                  );
                  if (displayInfo.hasSubtitle) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        displayInfo.displaySubtitle!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }(),
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
                const Spacer(),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: isProcessing ? null : onLike,
                      icon: const Icon(Icons.thumb_up),
                      label: const Text('Like'),
                    ),
                    ElevatedButton.icon(
                      onPressed: isProcessing ? null : onDislike,
                      icon: const Icon(Icons.thumb_down),
                      label: const Text('Dislike'),
                    ),
                    if (onAddToWatchlist != null && mediaType == 'movie')
                      ElevatedButton.icon(
                        onPressed: isProcessing ? null : onAddToWatchlist,
                        icon: const Icon(Icons.playlist_add),
                        label: Text(queueName),
                      ),
                    if (onAddToLibrary != null && (mediaType == 'movie' || mediaType == 'book' || mediaType == 'podcast'))
                      ElevatedButton.icon(
                        onPressed: isProcessing ? null : onAddToLibrary,
                        icon: const Icon(Icons.favorite),
                        label: Text(getAddToLibraryButtonText()),
                      ),
                    ElevatedButton.icon(
                      onPressed: isProcessing ? null : onSkip,
                      icon: const Icon(Icons.skip_next),
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
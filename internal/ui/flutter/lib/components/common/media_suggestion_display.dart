import 'package:flutter/material.dart';
import '../../models.dart';
import '../../theme.dart';
import 'media_preview_buttons.dart';

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
                      fallbackTitle: 'Pending Suggestion',
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
                    fallbackTitle: 'Pending Suggestion',
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
                // Detected Themes section
                if (suggestedItem?.themes != null && suggestedItem!.themes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Detected Themes: ',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: suggestedItem!.themes!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                // Detected Genres section
                if (suggestedItem?.genres != null && suggestedItem!.genres!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Detected Genres: ',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: suggestedItem!.genres!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                // Preview buttons for music (or YouTube for other media)
                if (suggestedItem != null && (suggestedItem!.youtubeId != null || suggestedItem!.spotifyId != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: MediaPreviewButtons(
                      title: suggestedItem!.title ?? '',
                      artist: suggestedItem!.artist,
                      mediaType: mediaType,
                      spotifyId: suggestedItem!.spotifyId,
                      youtubeId: suggestedItem!.youtubeId,
                      youtubeUrl: suggestedItem!.youtubeUrl,
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

  /// Extract Spotify ID from mediaId if it's a Spotify URL or ID
  String? _extractSpotifyId(String? mediaId) {
    if (mediaId == null || mediaType != 'music') return null;
    
    // Handle Spotify URI format: spotify:track:4iV5W9uYEdYUVa79Axb7Rh
    if (mediaId.startsWith('spotify:track:')) {
      return mediaId.substring('spotify:track:'.length);
    }
    
    // Handle Spotify URL format: https://open.spotify.com/track/4iV5W9uYEdYUVa79Axb7Rh
    if (mediaId.contains('spotify.com/track/')) {
      final match = RegExp(r'track/([a-zA-Z0-9]+)').firstMatch(mediaId);
      return match?.group(1);
    }
    
    // Handle direct Spotify ID (22 character alphanumeric string)
    if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(mediaId)) {
      return mediaId;
    }
    
    return null;
  }
} 
import 'package:flutter/material.dart';
import 'consistent_layout_wrapper.dart';

/// Generic action buttons for media suggestions
/// Provides consistent styling and behavior across all media types
class SuggestionActionButtons extends StatelessWidget {
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onFavorite;
  final VoidCallback? onAddToWatchlist;
  final VoidCallback? onSkip;
  final bool hasLikedCurrentSuggestion;
  final bool isInWatchlist;
  final String mediaType;
  final bool isProcessing;

  const SuggestionActionButtons({
    Key? key,
    this.onLike,
    this.onDislike,
    this.onFavorite,
    this.onAddToWatchlist,
    this.onSkip,
    this.hasLikedCurrentSuggestion = false,
    this.isInWatchlist = false,
    required this.mediaType,
    this.isProcessing = false,
  }) : super(key: key);

  String _getWatchlistTerminology() {
    switch (mediaType) {
      case 'music':
        return 'Playlist';
      case 'book':
        return 'Reading List';
      case 'movie':
      case 'tv':
      case 'tv_show':
        return 'Watchlist';
      case 'game':
      case 'video_game':
        return 'Wishlist';
      default:
        return 'List';
    }
  }

  String _getWatchlistTerminologyAction() {
    switch (mediaType) {
      case 'music':
        return 'playlist';
      case 'book':
        return 'reading list';
      case 'movie':
      case 'tv':
      case 'tv_show':
        return 'watchlist';
      case 'game':
      case 'video_game':
        return 'wishlist';
      default:
        return 'list';
    }
  }

  ButtonStyle _getButtonStyle({
    required bool isActive,
    Color? activeColor,
    bool isDisabled = false,
  }) {
    if (isDisabled) {
      return ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.withOpacity(0.3),
        foregroundColor: Colors.grey,
        elevation: 0,
        side: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(0, 44),
      );
    }

    if (isActive && activeColor != null) {
      return ElevatedButton.styleFrom(
        backgroundColor: activeColor.withOpacity(0.3),
        foregroundColor: activeColor,
        elevation: 0,
        side: BorderSide(color: activeColor.withOpacity(0.5), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(0, 44),
      );
    }

    return ElevatedButton.styleFrom(
      backgroundColor: Colors.black.withOpacity(0.7),
      foregroundColor: Colors.white,
      elevation: 0,
      side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: const Size(0, 44),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ActionButtonsWrapper(
      children: [
        // Like button
        if (onLike != null)
          ElevatedButton.icon(
            onPressed: (isProcessing || hasLikedCurrentSuggestion) ? null : onLike,
            icon: Icon(
              hasLikedCurrentSuggestion ? Icons.thumb_up : Icons.thumb_up_outlined,
              size: 16
            ),
            label: Text(
              hasLikedCurrentSuggestion ? 'Liked' : 'Like',
              style: const TextStyle(fontSize: 13)
            ),
            style: _getButtonStyle(
              isActive: hasLikedCurrentSuggestion,
              activeColor: Colors.green,
              isDisabled: isProcessing || hasLikedCurrentSuggestion,
            ),
          ),

        // Dislike button
        if (onDislike != null)
          ElevatedButton.icon(
            onPressed: isProcessing ? null : onDislike,
            icon: const Icon(Icons.thumb_down, size: 16),
            label: const Text('Dislike', style: TextStyle(fontSize: 13)),
            style: _getButtonStyle(
              isActive: false,
              isDisabled: isProcessing,
            ),
          ),

        // Favorite button
        if (onFavorite != null)
          ElevatedButton.icon(
            onPressed: (isProcessing || hasLikedCurrentSuggestion) ? null : onFavorite,
            icon: Icon(
              hasLikedCurrentSuggestion ? Icons.favorite : Icons.favorite_border,
              size: 16
            ),
            label: Text(
              hasLikedCurrentSuggestion ? 'Favorited' : 'Favorite',
              style: const TextStyle(fontSize: 13)
            ),
            style: _getButtonStyle(
              isActive: hasLikedCurrentSuggestion,
              activeColor: Colors.red,
              isDisabled: isProcessing || hasLikedCurrentSuggestion,
            ),
          ),

        // Watchlist button
        if (onAddToWatchlist != null)
          ElevatedButton.icon(
            onPressed: isProcessing ? null : onAddToWatchlist,
            icon: Icon(
              isInWatchlist ? Icons.bookmark_added : Icons.bookmark_add,
              size: 16
            ),
            label: Text(
              isInWatchlist ? 'In ${_getWatchlistTerminology()}' : _getWatchlistTerminology(),
              style: const TextStyle(fontSize: 13)
            ),
            style: _getButtonStyle(
              isActive: isInWatchlist,
              activeColor: Colors.blue,
              isDisabled: isProcessing,
            ),
          ),

        // Skip/Next button
        if (onSkip != null)
          ElevatedButton.icon(
            onPressed: isProcessing ? null : onSkip,
            icon: Icon(
              hasLikedCurrentSuggestion ? Icons.arrow_forward : Icons.skip_next,
              size: 16
            ),
            label: Text(
              hasLikedCurrentSuggestion ? 'Next' : 'Skip',
              style: const TextStyle(fontSize: 13)
            ),
            style: _getButtonStyle(
              isActive: hasLikedCurrentSuggestion,
              activeColor: const Color(0xFF7B68EE),
              isDisabled: isProcessing,
            ),
          ),
      ],
    );
  }
} 
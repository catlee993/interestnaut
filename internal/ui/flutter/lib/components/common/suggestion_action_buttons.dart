import 'package:flutter/material.dart';
import 'consistent_layout_wrapper.dart';

/// Generic action buttons for media suggestions
/// Provides consistent styling and behavior across all media types
class SuggestionActionButtons extends StatelessWidget {
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onFavorite;
  final VoidCallback? onUnfavorite;
  final VoidCallback? onAddToWatchlist;
  final VoidCallback? onSkip;
  final bool hasLikedCurrentSuggestion;
  final bool hasFavoritedCurrentSuggestion;
  final bool isInWatchlist;
  final String mediaType;
  final bool isProcessing;

  const SuggestionActionButtons({
    Key? key,
    this.onLike,
    this.onDislike,
    this.onFavorite,
    this.onUnfavorite,
    this.onAddToWatchlist,
    this.onSkip,
    this.hasLikedCurrentSuggestion = false,
    this.hasFavoritedCurrentSuggestion = false,
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
    bool isFavoriteButton = false, // Add parameter to identify favorite button
  }) {
    // Special case: Favorite button when active should be solid purple (but more subtle)
    // Check this FIRST, before disabled check, so active favorited buttons show purple
    if (isActive && activeColor != null && isFavoriteButton) {
      return ElevatedButton.styleFrom(
        backgroundColor: activeColor.withOpacity(0.25), // Same opacity as watchlist button
        foregroundColor: activeColor, // Use the color itself for text, not white
        elevation: 0,
        side: BorderSide(color: activeColor, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(100, 44), // Minimum size with consistent padding
      );
    }

    // All other active buttons (watchlist, like) use semi-transparent background
    // Check this SECOND, before disabled check, so active buttons show their colors
    if (isActive && activeColor != null) {
      return ElevatedButton.styleFrom(
        backgroundColor: activeColor.withOpacity(0.25), // More subtle semi-transparent
        foregroundColor: activeColor,
        elevation: 0,
        side: BorderSide(color: activeColor.withOpacity(0.5), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(100, 44), // Minimum size with consistent padding
      );
    }

    // If button is disabled but NOT active, show gray
    // Only show gray if the button is disabled AND not in an active state
    if (isDisabled && !isActive) {
      return ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.withOpacity(0.3),
        foregroundColor: Colors.grey,
        elevation: 0,
        side: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(100, 44), // Minimum size with consistent padding
      );
    }

    // Default style for normal buttons (not active, not disabled, or disabled but active)
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.black.withOpacity(0.7),
      foregroundColor: Colors.white,
      elevation: 0,
      side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: const Size(100, 44), // Minimum size with consistent padding
    );
  }

  @override
  Widget build(BuildContext context) {
    return ActionButtonsWrapper(
      children: [
        // Like button
        if (onLike != null)
          ElevatedButton.icon(
            onPressed: (isProcessing || hasLikedCurrentSuggestion || hasFavoritedCurrentSuggestion) ? null : onLike,
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
              isDisabled: isProcessing || hasLikedCurrentSuggestion || hasFavoritedCurrentSuggestion,
            ),
          ),

        // Dislike button
        if (onDislike != null)
          ElevatedButton.icon(
            onPressed: isProcessing ? () {
              debugPrint('🔘 Dislike button pressed but disabled due to isProcessing: $isProcessing');
            } : () {
              debugPrint('🔘 Dislike button pressed - isProcessing: $isProcessing');
              onDislike?.call();
            },
            icon: const Icon(Icons.thumb_down, size: 16),
            label: const Text('Dislike', style: TextStyle(fontSize: 13)),
            style: _getButtonStyle(
              isActive: false,
              isDisabled: isProcessing,
            ),
          ),

        // Favorite button - works like watchlist button (can unfavorite when favorited)
        if (onFavorite != null || onUnfavorite != null)
          ElevatedButton.icon(
            onPressed: isProcessing ? () {
              debugPrint('🔘 Favorite button pressed but disabled due to isProcessing: $isProcessing');
            } : () {
              debugPrint('🔘 Favorite button pressed - isProcessing: $isProcessing, hasFavorited: $hasFavoritedCurrentSuggestion');
              if (hasFavoritedCurrentSuggestion) {
                debugPrint('🔘 Calling onUnfavorite');
                onUnfavorite?.call();
              } else {
                debugPrint('🔘 Calling onFavorite');
                onFavorite?.call();
              }
            },
            icon: Icon(
              hasFavoritedCurrentSuggestion ? Icons.favorite : Icons.favorite_border,
              size: 16
            ),
            label: Text(
              hasFavoritedCurrentSuggestion ? 'Favorited' : 'Favorite',
              style: const TextStyle(fontSize: 13)
            ),
            style: _getButtonStyle(
              isActive: hasFavoritedCurrentSuggestion,
              activeColor: const Color(0xFF7B68EE),
              isDisabled: isProcessing,
              isFavoriteButton: true,
            ),
          ),

        // Watchlist button
        if (onAddToWatchlist != null)
          ElevatedButton.icon(
            onPressed: isProcessing ? () {
              debugPrint('🔘 Watchlist button pressed but disabled due to isProcessing: $isProcessing');
            } : () {
              debugPrint('🔘 Watchlist button pressed - isProcessing: $isProcessing, isInWatchlist: $isInWatchlist');
              onAddToWatchlist?.call();
            },
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
            onPressed: isProcessing ? () {
              debugPrint('🔘 Skip button pressed but disabled due to isProcessing: $isProcessing');
            } : () {
              debugPrint('🔘 Skip button pressed - isProcessing: $isProcessing, hasLiked: $hasLikedCurrentSuggestion, hasFavorited: $hasFavoritedCurrentSuggestion');
              onSkip?.call();
            },
            icon: Icon(
              (hasLikedCurrentSuggestion || hasFavoritedCurrentSuggestion) ? Icons.arrow_forward : Icons.skip_next,
              size: 16
            ),
            label: Text(
              (hasLikedCurrentSuggestion || hasFavoritedCurrentSuggestion) ? 'Next' : 'Skip',
              style: const TextStyle(fontSize: 13)
            ),
            style: _getButtonStyle(
              isActive: false, // Never make the skip/next button purple
              isDisabled: isProcessing,
            ),
          ),
      ],
    );
  }
} 
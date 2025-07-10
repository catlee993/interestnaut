import 'package:flutter/material.dart';
import 'consistent_layout_wrapper.dart';
import '../../theme.dart';
import 'media_action_icons.dart';

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
    return AppTheme.getMediaListName(mediaType);
  }

  String _getWatchlistTerminologyAction() {
    return AppTheme.getMediaListActionName(mediaType);
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
        // Like button - toggleable, disabled when favorited (since favorite > like)
        if (onLike != null)
          ElevatedButton.icon(
            onPressed: (isProcessing || hasFavoritedCurrentSuggestion) ? () {
              if (hasFavoritedCurrentSuggestion) {
                debugPrint('🔘 Like button pressed but disabled because item is favorited');
              } else {
                debugPrint('🔘 Like button pressed but disabled due to isProcessing: $isProcessing');
              }
            } : () {
              debugPrint('🔘 Like button pressed - isProcessing: $isProcessing, hasLiked: $hasLikedCurrentSuggestion');
              onLike?.call();
            },
            icon: Icon(
              // Show as liked only if liked AND not favorited (favorite takes priority)
              MediaActionIcons.getLikeIcon(hasLikedCurrentSuggestion && !hasFavoritedCurrentSuggestion),
              size: 16
            ),
            label: Text(
              (hasLikedCurrentSuggestion && !hasFavoritedCurrentSuggestion) ? 'Liked' : 'Like',
              style: const TextStyle(fontSize: 13)
            ),
            style: _getButtonStyle(
              // Show as active only if liked AND not favorited (favorite takes priority)
              isActive: hasLikedCurrentSuggestion && !hasFavoritedCurrentSuggestion,
              activeColor: AppTheme.likeColor,
              isDisabled: isProcessing || hasFavoritedCurrentSuggestion,
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
            icon: Icon(MediaActionIcons.getDislikeIcon(), size: 16),
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
              MediaActionIcons.getFavoriteIcon(hasFavoritedCurrentSuggestion),
              size: 16
            ),
            label: Text(
              hasFavoritedCurrentSuggestion ? 'Favorited' : 'Favorite',
              style: const TextStyle(fontSize: 13)
            ),
            style: _getButtonStyle(
              isActive: hasFavoritedCurrentSuggestion,
              activeColor: AppTheme.favoriteColor,
              isDisabled: isProcessing,
              isFavoriteButton: true,
            ),
          ),

        // Watchlist button - shows as active whenever in watchlist (can coexist with favorite and like)
        if (onAddToWatchlist != null)
          ElevatedButton.icon(
            onPressed: isProcessing ? () {
              debugPrint('🔘 Watchlist button pressed but disabled due to isProcessing: $isProcessing');
            } : () {
              debugPrint('🔘 Watchlist button pressed - isProcessing: $isProcessing, isInWatchlist: $isInWatchlist');
              onAddToWatchlist?.call();
            },
            icon: Icon(
              // Show as added whenever in watchlist (regardless of other states)
              MediaActionIcons.getWatchlistIcon(isInWatchlist),
              size: 16
            ),
            label: Text(
              isInWatchlist ? 'In ${_getWatchlistTerminology()}' : _getWatchlistTerminology(),
              style: const TextStyle(fontSize: 13)
            ),
            style: _getButtonStyle(
              // Show as active whenever in watchlist (regardless of other states)
              isActive: isInWatchlist,
              activeColor: AppTheme.watchlistColor,
              isDisabled: isProcessing,
            ),
          ),

        // Skip/Next button
        if (onSkip != null)
          ElevatedButton.icon(
            onPressed: isProcessing ? () {
              debugPrint('🔘 Skip button pressed but disabled due to isProcessing: $isProcessing');
            } : () {
              debugPrint('🔘 Skip button pressed - isProcessing: $isProcessing, hasLiked: $hasLikedCurrentSuggestion, hasFavorited: $hasFavoritedCurrentSuggestion, isInWatchlist: $isInWatchlist');
              onSkip?.call();
            },
            icon: Icon(
              (hasLikedCurrentSuggestion || hasFavoritedCurrentSuggestion || isInWatchlist) ? Icons.arrow_forward : Icons.skip_next,
              size: 16
            ),
            label: Text(
              (hasLikedCurrentSuggestion || hasFavoritedCurrentSuggestion || isInWatchlist) ? 'Next' : 'Skip',
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
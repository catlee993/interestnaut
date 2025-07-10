import 'package:flutter/material.dart';
import '../../theme.dart';

/// Centralized service for media action icons and colors
/// Handles all icon and color logic for media actions across the app
class MediaActionIcons {
  MediaActionIcons._();

  /// Get icon for like action based on state
  static IconData getLikeIcon(bool isLiked) {
    return isLiked ? Icons.thumb_up : Icons.thumb_up_outlined;
  }

  /// Get icon for dislike action based on state
  static IconData getDislikeIcon([bool isDisliked = false]) {
    return isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined;
  }

  /// Get icon for favorite action based on state
  static IconData getFavoriteIcon(bool isFavorited) {
    return isFavorited ? Icons.favorite : Icons.favorite_border;
  }

  /// Get icon for watchlist action based on state
  static IconData getWatchlistIcon(bool isInWatchlist) {
    return isInWatchlist ? Icons.bookmark_added : Icons.bookmark_border;
  }

  /// Get color for like action based on state
  static Color getLikeColor(bool isLiked) {
    return isLiked ? AppTheme.likeColor : AppTheme.textSecondary;
  }

  /// Get color for dislike action based on state
  static Color getDislikeColor(bool isDisliked) {
    return isDisliked ? AppTheme.dislikeColor : AppTheme.textSecondary;
  }

  /// Get color for favorite action based on state
  static Color getFavoriteColor(bool isFavorited) {
    return isFavorited ? AppTheme.favoriteColor : AppTheme.textSecondary;
  }

  /// Get color for watchlist action based on state
  static Color getWatchlistColor(bool isInWatchlist) {
    return isInWatchlist ? AppTheme.watchlistColor : AppTheme.textSecondary;
  }

  /// Get icon for action type (used in history screens, etc.)
  static IconData getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'liked':
        return Icons.thumb_up;
      case 'disliked':
        return Icons.thumb_down;
      case 'favorited':
        return Icons.favorite;
      case 'watchlisted':
        return Icons.bookmark;
      default:
        return Icons.help_outline;
    }
  }

  /// Get color for action type (used in history screens, etc.)
  static Color getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'liked':
        return AppTheme.likeColor;
      case 'disliked':
        return AppTheme.dislikeColor;
      case 'favorited':
        return AppTheme.favoriteColor;
      case 'watchlisted':
        return AppTheme.watchlistColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  /// Get complete icon data for a media action
  static MediaActionIconData getIconData({
    required MediaActionType type,
    required bool isActive,
  }) {
    switch (type) {
      case MediaActionType.like:
        return MediaActionIconData(
          icon: getLikeIcon(isActive),
          color: getLikeColor(isActive),
          activeColor: AppTheme.likeColor,
          inactiveColor: AppTheme.textSecondary,
        );
      case MediaActionType.dislike:
        return MediaActionIconData(
          icon: getDislikeIcon(isActive),
          color: getDislikeColor(isActive),
          activeColor: AppTheme.dislikeColor,
          inactiveColor: AppTheme.textSecondary,
        );
      case MediaActionType.favorite:
        return MediaActionIconData(
          icon: getFavoriteIcon(isActive),
          color: getFavoriteColor(isActive),
          activeColor: AppTheme.favoriteColor,
          inactiveColor: AppTheme.textSecondary,
        );
      case MediaActionType.watchlist:
        return MediaActionIconData(
          icon: getWatchlistIcon(isActive),
          color: getWatchlistColor(isActive),
          activeColor: AppTheme.watchlistColor,
          inactiveColor: AppTheme.textSecondary,
        );
    }
  }
}

/// Enum for media action types
enum MediaActionType {
  like,
  dislike,
  favorite,
  watchlist,
}

/// Data class for complete icon information
class MediaActionIconData {
  final IconData icon;
  final Color color;
  final Color activeColor;
  final Color inactiveColor;

  const MediaActionIconData({
    required this.icon,
    required this.color,
    required this.activeColor,
    required this.inactiveColor,
  });
}

/// Widget for consistent media action buttons
class MediaActionButton extends StatelessWidget {
  final MediaActionType type;
  final bool isActive;
  final VoidCallback onPressed;
  final double iconSize;
  final bool isLoading;

  const MediaActionButton({
    Key? key,
    required this.type,
    required this.isActive,
    required this.onPressed,
    this.iconSize = 18.0,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconData = MediaActionIcons.getIconData(
      type: type,
      isActive: isActive,
    );

    return IconButton(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: iconData.activeColor,
              ),
            )
          : Icon(
              iconData.icon,
              color: iconData.color,
              size: iconSize,
            ),
      constraints: BoxConstraints(
        minWidth: iconSize + 8,
        minHeight: iconSize + 8,
      ),
      padding: const EdgeInsets.all(4),
    );
  }
} 
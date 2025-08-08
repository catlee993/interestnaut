import 'package:flutter/material.dart';
import 'consistent_layout_wrapper.dart';
import '../theme/theme.dart';
import 'media_action_icons.dart';
import 'interestnaut_button.dart';

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


  @override
  Widget build(BuildContext context) {
    return ActionButtonsWrapper(
      children: [
        // Like button - toggleable, disabled when favorited (since favorite > like)
        if (onLike != null)
          InterestNautButton(
            text: (hasLikedCurrentSuggestion && !hasFavoritedCurrentSuggestion) ? 'Liked' : 'Like',
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
            color: AppTheme.likeColor,
            backgroundColor: AppTheme.likeColor,
            isActive: hasLikedCurrentSuggestion && !hasFavoritedCurrentSuggestion,
            isDisabled: isProcessing || hasFavoritedCurrentSuggestion,
            icon: Icon(MediaActionIcons.getLikeIcon(hasLikedCurrentSuggestion && !hasFavoritedCurrentSuggestion)),
          ),

        // Dislike button
        if (onDislike != null)
          InterestNautButton(
            text: 'Dislike',
            onPressed: isProcessing ? () {
              debugPrint('🔘 Dislike button pressed but disabled due to isProcessing: $isProcessing');
            } : () {
              debugPrint('🔘 Dislike button pressed - isProcessing: $isProcessing');
              onDislike?.call();
            },
            isDisabled: isProcessing,
            icon: Icon(MediaActionIcons.getDislikeIcon()),
          ),

        // Favorite button - works like watchlist button (can unfavorite when favorited)
        if (onFavorite != null || onUnfavorite != null)
          InterestNautButton(
            text: hasFavoritedCurrentSuggestion ? 'Favorited' : 'Favorite',
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
            color: AppTheme.favoriteColor,
            backgroundColor: AppTheme.favoriteColor,
            isActive: hasFavoritedCurrentSuggestion,
            isDisabled: isProcessing,
            icon: Icon(MediaActionIcons.getFavoriteIcon(hasFavoritedCurrentSuggestion)),
          ),

        // Watchlist button - shows as active whenever in watchlist (can coexist with favorite and like)
        if (onAddToWatchlist != null)
          InterestNautButton(
            text: isInWatchlist ? 'In ${_getWatchlistTerminology()}' : _getWatchlistTerminology(),
            onPressed: isProcessing ? () {
              debugPrint('🔘 Watchlist button pressed but disabled due to isProcessing: $isProcessing');
            } : () {
              debugPrint('🔘 Watchlist button pressed - isProcessing: $isProcessing, isInWatchlist: $isInWatchlist');
              onAddToWatchlist?.call();
            },
            color: AppTheme.watchlistColor,
            backgroundColor: AppTheme.watchlistColor,
            isActive: isInWatchlist,
            isDisabled: isProcessing,
            icon: Icon(MediaActionIcons.getWatchlistIcon(isInWatchlist)),
          ),

        // Skip/Next button
        if (onSkip != null)
          InterestNautButton(
            text: (hasLikedCurrentSuggestion || hasFavoritedCurrentSuggestion || isInWatchlist) ? 'Next' : 'Skip',
            onPressed: isProcessing ? () {
              debugPrint('🔘 Skip button pressed but disabled due to isProcessing: $isProcessing');
            } : () {
              debugPrint('🔘 Skip button pressed - isProcessing: $isProcessing, hasLiked: $hasLikedCurrentSuggestion, hasFavorited: $hasFavoritedCurrentSuggestion, isInWatchlist: $isInWatchlist');
              onSkip?.call();
            },
            isDisabled: isProcessing,
            icon: Icon((hasLikedCurrentSuggestion || hasFavoritedCurrentSuggestion || isInWatchlist) ? Icons.arrow_forward : Icons.skip_next),
          ),
      ],
    );
  }
} 
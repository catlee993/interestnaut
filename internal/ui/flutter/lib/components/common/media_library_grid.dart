import 'package:flutter/material.dart';
import '../../services/recommendation_service.dart';
import 'media_library_card.dart';

/// Card format options for different media types
enum CardFormat {
  square,  // For music albums - 1:1 ratio
  poster,  // For movies, TV shows, books - 2:3 ratio (taller)
  cover,   // For game covers - slightly taller than square
}

/// A reusable grid component for displaying media library/watchlist items
/// Provides consistent 3-column layout with proper spacing
class MediaLibraryGrid extends StatelessWidget {
  final List<MediaSuggestion> suggestions;
  final String mediaType;
  final bool isWatchlist;
  final Function(MediaSuggestion)? onRemove;
  final Function(MediaSuggestion)? onLike;
  final Function(MediaSuggestion)? onDislike;
  final Function(MediaSuggestion)? onAddToWatchlist;
  final Function(MediaSuggestion)? onRemoveFromWatchlist;
  final Function(MediaSuggestion)? onFavorite;
  final Function(MediaSuggestion)? onUnfavorite;
  final List<MediaSuggestion> watchlistItems;
  final CardFormat? cardFormat; // Optional override for card format

  const MediaLibraryGrid({
    Key? key,
    required this.suggestions,
    required this.mediaType,
    required this.isWatchlist,
    this.onRemove,
    this.onLike,
    this.onDislike,
    this.onAddToWatchlist,
    this.onRemoveFromWatchlist,
    this.onFavorite,
    this.onUnfavorite,
    this.watchlistItems = const [],
    this.cardFormat, // Allow manual override
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // Keep 3 columns as requested
        childAspectRatio: _getAspectRatio(), // Dynamic aspect ratio based on media type
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
      final suggestion = suggestions[index];
      final isInWatchlist = watchlistItems.any((item) => item.id == suggestion.id);
      
      return MediaLibraryCard(
        suggestion: suggestion,
        isWatchlist: isWatchlist,
        mediaType: mediaType,
        isInWatchlist: isInWatchlist,
        cardFormat: cardFormat ?? _getCardFormat(), // Use override or auto-detect
        onRemove: onRemove != null ? () => onRemove!(suggestion) : null,
        onLike: onLike != null ? () => onLike!(suggestion) : null,
        onDislike: onDislike != null ? () => onDislike!(suggestion) : null,
        onAddToWatchlist: onAddToWatchlist != null ? () => onAddToWatchlist!(suggestion) : null,
        onRemoveFromWatchlist: onRemoveFromWatchlist != null ? () => onRemoveFromWatchlist!(suggestion) : null,
        onFavorite: onFavorite != null ? () => onFavorite!(suggestion) : null,
        onUnfavorite: onUnfavorite != null ? () => onUnfavorite!(suggestion) : null,
      );
    },
    );
  }

  /// Get the card format based on media type
  CardFormat _getCardFormat() {
    switch (mediaType) {
      case 'music':
        return CardFormat.square; // Albums are square
      case 'movie':
      case 'tv_show':
      case 'tv':
      case 'book':
        return CardFormat.poster; // Movies, TV, books use poster format
      case 'video_game':
      case 'game':
        return CardFormat.cover; // Games use cover format
      default:
        return CardFormat.poster; // Default to poster
    }
  }

  /// Get the appropriate aspect ratio for the card format
  double _getAspectRatio() {
    final format = cardFormat ?? _getCardFormat();
    
    switch (format) {
      case CardFormat.square:
        return 1.0; // Perfect square (1:1)
      case CardFormat.poster:
        return 0.7; // Poster format (2:3 ratio - taller)
      case CardFormat.cover:
        return 0.8; // Game cover format (4:5 ratio - slightly taller)
    }
  }

  /// Helper method to get aspect ratio for a specific media type (static utility)
  static double getAspectRatioForMediaType(String mediaType) {
    switch (mediaType) {
      case 'music':
        return 1.0; // Square for albums
      case 'movie':
      case 'tv_show':
      case 'tv':
      case 'book':
        return 0.7; // Poster format
      case 'video_game':
      case 'game':
        return 0.8; // Game cover format
      default:
        return 0.7; // Default to poster
    }
  }

  /// Helper method to get card format for a specific media type (static utility)
  static CardFormat getCardFormatForMediaType(String mediaType) {
    switch (mediaType) {
      case 'music':
        return CardFormat.square;
      case 'movie':
      case 'tv_show':
      case 'tv':
      case 'book':
        return CardFormat.poster;
      case 'video_game':
      case 'game':
        return CardFormat.cover;
      default:
        return CardFormat.poster;
    }
  }
} 
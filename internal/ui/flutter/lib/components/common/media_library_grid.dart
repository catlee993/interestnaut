import 'package:flutter/material.dart';
import '../../services/recommendation_service.dart';
import 'media_library_card.dart';
import '../../utils/text_utils.dart';

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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // Keep 3 columns as requested
        childAspectRatio: 1.2, // Keep the same aspect ratio
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
} 
import '../services/recommendation_service.dart';

/// Centralized utility for handling media titles with intelligent fallbacks
/// Provides consistent title display logic across the entire app
class MediaTitleHandler {
  MediaTitleHandler._();

  /// Get the best available display title for any media item
  /// Follows media-type-specific fallback hierarchies
  static String getBestTitle(
    String? title,
    String? primaryCreator, // artist/author/director/developer
    String? secondaryInfo,  // album/publisher/studio/network
    String mediaType,
  ) {
    // Primary: Use title if available and not generic
    if (title != null && title.isNotEmpty && !_isGenericTitle(title)) {
      return title;
    }

    // Secondary: Use appropriate creator based on media type
    if (primaryCreator != null && primaryCreator.isNotEmpty && !_isGenericCreator(primaryCreator)) {
      return primaryCreator;
    }

    // Tertiary: Use secondary info (album, publisher, etc.)
    if (secondaryInfo != null && secondaryInfo.isNotEmpty && !_isGenericInfo(secondaryInfo)) {
      return secondaryInfo;
    }

    // Fallback: Return the original title even if generic, or media type default
    if (title != null && title.isNotEmpty) {
      return title;
    }

    // Last resort: Media type specific unknown
    return _getUnknownFallback(mediaType);
  }

  /// Get best title from MediaSuggestion
  static String getBestTitleFromSuggestion(MediaSuggestion suggestion) {
    return getBestTitle(
      suggestion.title,
      suggestion.artist,
      suggestion.album,
      suggestion.mediaType,
    );
  }

  /// Get best title with media type context for different data structures
  static String getBestTitleFromMap(Map<String, dynamic> item, String mediaType) {
    final title = item['title'] as String?;
    final primaryCreator = _getPrimaryCreatorFromMap(item, mediaType);
    final secondaryInfo = _getSecondaryInfoFromMap(item, mediaType);

    return getBestTitle(title, primaryCreator, secondaryInfo, mediaType);
  }

  /// Get contextual field name for primary creator based on media type
  static String getPrimaryCreatorLabel(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'music':
        return 'Artist';
      case 'movie':
        return 'Director';
      case 'book':
        return 'Author';
      case 'tv_show':
      case 'tv':
        return 'Creator';
      case 'video_game':
      case 'game':
        return 'Developer';
      default:
        return 'Creator';
    }
  }

  /// Get contextual field name for secondary info based on media type
  static String getSecondaryInfoLabel(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'music':
        return 'Album';
      case 'movie':
        return 'Studio';
      case 'book':
        return 'Publisher';
      case 'tv_show':
      case 'tv':
        return 'Network';
      case 'video_game':
      case 'game':
        return 'Publisher';
      default:
        return 'Publisher';
    }
  }

  /// Check if a title looks generic or placeholder
  static bool _isGenericTitle(String title) {
    final lowerTitle = title.toLowerCase().trim();
    
    // Common generic titles
    final genericTitles = {
      'unknown', 'unknown title', 'untitled', 'no title',
      'title', 'name', 'item', 'media', 'content',
      'track', 'song', 'movie', 'book', 'game', 'show'
    };

    return genericTitles.contains(lowerTitle) || 
           lowerTitle.isEmpty || 
           lowerTitle.length < 2;
  }

  /// Check if creator info looks generic or placeholder
  static bool _isGenericCreator(String creator) {
    final lowerCreator = creator.toLowerCase().trim();
    
    final genericCreators = {
      'unknown', 'unknown artist', 'unknown author', 'unknown director',
      'unknown developer', 'unknown creator', 'artist', 'author', 
      'director', 'developer', 'creator', 'various', 'various artists'
    };

    return genericCreators.contains(lowerCreator) || 
           lowerCreator.isEmpty || 
           lowerCreator.length < 2;
  }

  /// Check if secondary info looks generic
  static bool _isGenericInfo(String info) {
    final lowerInfo = info.toLowerCase().trim();
    
    final genericInfo = {
      'unknown', 'unknown album', 'unknown publisher', 'unknown studio',
      'album', 'publisher', 'studio', 'network', 'various'
    };

    return genericInfo.contains(lowerInfo) || 
           lowerInfo.isEmpty || 
           lowerInfo.length < 2;
  }

  /// Get appropriate unknown fallback for media type
  static String _getUnknownFallback(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'music':
        return 'Unknown Song';
      case 'movie':
        return 'Unknown Movie';
      case 'book':
        return 'Unknown Book';
      case 'tv_show':
      case 'tv':
        return 'Unknown Show';
      case 'video_game':
      case 'game':
        return 'Unknown Game';
      default:
        return 'Unknown Media';
    }
  }

  /// Extract primary creator from generic map based on media type
  static String? _getPrimaryCreatorFromMap(Map<String, dynamic> item, String mediaType) {
    // Try common field names in order of preference
    return item['artist'] as String? ?? 
           item['author'] as String? ??
           item['director'] as String? ??
           item['developer'] as String? ??
           item['creator'] as String? ??
           item['primary_creator'] as String?;
  }

  /// Extract secondary info from generic map based on media type
  static String? _getSecondaryInfoFromMap(Map<String, dynamic> item, String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'music':
        return item['album'] as String?;
      case 'movie':
        return item['studio'] as String? ?? item['production_company'] as String?;
      case 'book':
        return item['publisher'] as String?;
      case 'tv_show':
      case 'tv':
        return item['network'] as String? ?? item['studio'] as String?;
      case 'video_game':
      case 'game':
        return item['publisher'] as String?;
      default:
        return item['publisher'] as String? ?? 
               item['studio'] as String? ?? 
               item['album'] as String?;
    }
  }

  /// Get display string with creator context (e.g., "Song by Artist", "Book by Author")
  static String getDisplayWithCreator(
    String? title,
    String? creator,
    String? secondaryInfo,
    String mediaType,
  ) {
    final bestTitle = getBestTitle(title, creator, secondaryInfo, mediaType);
    
    // If we used the creator as the title, don't add "by Creator"
    if (creator != null && creator.isNotEmpty && bestTitle == creator) {
      return bestTitle;
    }

    // If we have a proper title and creator, combine them
    if (title != null && title.isNotEmpty && !_isGenericTitle(title) &&
        creator != null && creator.isNotEmpty && !_isGenericCreator(creator)) {
      final creatorLabel = getPrimaryCreatorLabel(mediaType).toLowerCase();
      return '$bestTitle by $creator';
    }

    return bestTitle;
  }

  /// Get compact display for lists (title only, with fallbacks)
  static String getCompactTitle(
    String? title,
    String? creator,
    String? secondaryInfo,
    String mediaType,
  ) {
    return getBestTitle(title, creator, secondaryInfo, mediaType);
  }

  /// Get detailed display for cards/expanded views
  static Map<String, String?> getDetailedDisplay(
    String? title,
    String? creator,
    String? secondaryInfo,
    String mediaType,
  ) {
    final bestTitle = getBestTitle(title, creator, secondaryInfo, mediaType);
    
    // Determine what to show as subtitle
    String? subtitle;
    String? tertiaryInfo;

    if (title != null && title.isNotEmpty && !_isGenericTitle(title)) {
      // We have a real title, show creator as subtitle
      if (creator != null && creator.isNotEmpty && !_isGenericCreator(creator)) {
        subtitle = creator;
        if (secondaryInfo != null && secondaryInfo.isNotEmpty && !_isGenericInfo(secondaryInfo)) {
          tertiaryInfo = secondaryInfo;
        }
      } else if (secondaryInfo != null && secondaryInfo.isNotEmpty && !_isGenericInfo(secondaryInfo)) {
        subtitle = secondaryInfo;
      }
    } else if (creator != null && creator.isNotEmpty && !_isGenericCreator(creator)) {
      // Using creator as title, show secondary info as subtitle
      if (secondaryInfo != null && secondaryInfo.isNotEmpty && !_isGenericInfo(secondaryInfo)) {
        subtitle = secondaryInfo;
      }
    }

    return {
      'title': bestTitle,
      'subtitle': subtitle,
      'tertiary': tertiaryInfo,
    };
  }
} 
import 'package:flutter/material.dart';

/// Comprehensive media type enum with all necessary mappings and configurations
enum MediaType {
  music,
  movie,
  tvShow,
  book,
  videoGame;

  /// Database representation (what's stored in SQLite)
  String get databaseName {
    switch (this) {
      case MediaType.music:
        return 'music';
      case MediaType.movie:
        return 'movie';
      case MediaType.tvShow:
        return 'tv_show';
      case MediaType.book:
        return 'book';
      case MediaType.videoGame:
        return 'video_game';
    }
  }

  /// Header/UI display name (singular)
  String get displayName {
    switch (this) {
      case MediaType.music:
        return 'Music';
      case MediaType.movie:
        return 'Movie';
      case MediaType.tvShow:
        return 'TV Show';
      case MediaType.book:
        return 'Book';
      case MediaType.videoGame:
        return 'Video Game';
    }
  }

  /// Header/UI display name (plural)
  String get pluralDisplayName {
    switch (this) {
      case MediaType.music:
        return 'Music';
      case MediaType.movie:
        return 'Movies';
      case MediaType.tvShow:
        return 'TV Shows';
      case MediaType.book:
        return 'Books';
      case MediaType.videoGame:
        return 'Video Games';
    }
  }

  /// Header display name (uppercase, for nav headers)
  String get headerDisplayName {
    switch (this) {
      case MediaType.music:
        return 'MUSIC';
      case MediaType.movie:
        return 'MOVIES';
      case MediaType.tvShow:
        return 'SHOWS';
      case MediaType.book:
        return 'BOOKS';
      case MediaType.videoGame:
        return 'GAMES';
    }
  }

  /// Icon for the media type
  IconData get icon {
    switch (this) {
      case MediaType.music:
        return Icons.music_note;
      case MediaType.movie:
        return Icons.movie;
      case MediaType.tvShow:
        return Icons.tv;
      case MediaType.book:
        return Icons.book;
      case MediaType.videoGame:
        return Icons.videogame_asset;
    }
  }

  /// Fallback icon for the media type
  IconData get fallbackIcon {
    switch (this) {
      case MediaType.music:
        return Icons.music_note;
      case MediaType.movie:
        return Icons.movie;
      case MediaType.tvShow:
        return Icons.tv;
      case MediaType.book:
        return Icons.menu_book;
      case MediaType.videoGame:
        return Icons.sports_esports;
    }
  }

  /// List name (e.g., "Watchlist", "Playlist")
  String get listName {
    switch (this) {
      case MediaType.music:
        return 'Playlist';
      case MediaType.movie:
        return 'Watchlist';
      case MediaType.tvShow:
        return 'Watchlist';
      case MediaType.book:
        return 'Reading List';
      case MediaType.videoGame:
        return 'Playlist';
    }
  }

  /// Action name for the list (e.g., "watchlist", "playlist")
  String get listActionName {
    switch (this) {
      case MediaType.music:
        return 'playlist';
      case MediaType.movie:
        return 'watchlist';
      case MediaType.tvShow:
        return 'watchlist';
      case MediaType.book:
        return 'reading list';
      case MediaType.videoGame:
        return 'playlist';
    }
  }

  /// Search placeholder text
  String get searchPlaceholder {
    switch (this) {
      case MediaType.music:
        return 'Search tracks...';
      case MediaType.movie:
        return 'Search movies...';
      case MediaType.tvShow:
        return 'Search TV shows...';
      case MediaType.book:
        return 'Search books...';
      case MediaType.videoGame:
        return 'Search games...';
    }
  }

  /// Estimated database size for display
  String get estimatedDbSize {
    switch (this) {
      case MediaType.music:
        return '928 MB';
      case MediaType.movie:
        return '440 MB';
      case MediaType.tvShow:
        return '238 MB';
      case MediaType.book:
        return '191 MB';
      case MediaType.videoGame:
        return '84 MB';
    }
  }

  /// Parse from database name
  static MediaType fromDatabaseName(String databaseName) {
    switch (databaseName.toLowerCase()) {
      case 'music':
        return MediaType.music;
      case 'movie':
        return MediaType.movie;
      case 'tv_show':
        return MediaType.tvShow;
      case 'book':
        return MediaType.book;
      case 'video_game':
        return MediaType.videoGame;
      default:
        throw ArgumentError('Unknown database media type: $databaseName');
    }
  }

  /// Parse from header display name (handles various formats)
  static MediaType fromHeaderName(String headerName) {
    switch (headerName.toLowerCase()) {
      case 'music':
        return MediaType.music;
      case 'movie':
      case 'movies':
        return MediaType.movie;
      case 'tv':
      case 'show':
      case 'shows':
      case 'tv show':
      case 'tv shows':
      case 'tv_show':  // Database name support
        return MediaType.tvShow;
      case 'book':
      case 'books':
        return MediaType.book;
      case 'game':
      case 'games':
      case 'video game':
      case 'video games':
      case 'videogame':
      case 'videogames':
      case 'video_game':  // Database name support
        return MediaType.videoGame;
      default:
        throw ArgumentError('Unknown header media type: $headerName');
    }
  }

  /// Parse from any string representation (attempts all formats)
  static MediaType? fromString(String input) {
    try {
      return fromHeaderName(input);
    } catch (e) {
      try {
        return fromDatabaseName(input);
      } catch (e) {
        return null;
      }
    }
  }

  /// Get all media types as a list
  static List<MediaType> get allTypes => MediaType.values;

  /// Get media type configuration as a map (for backward compatibility)
  Map<String, dynamic> get config => {
    'displayName': displayName,
    'pluralDisplayName': pluralDisplayName,
    'icon': icon,
    'fallbackIcon': fallbackIcon,
    'listName': listName,
    'listActionName': listActionName,
    'searchPlaceholder': searchPlaceholder,
    'estimatedDbSize': estimatedDbSize,
    'headerDisplayName': headerDisplayName,
    'databaseName': databaseName,
  };
}

/// Extension methods for MediaType
extension MediaTypeExtensions on MediaType {
  /// Check if this media type uses watchlist (vs playlist)
  bool get usesWatchlist => this == MediaType.movie || this == MediaType.tvShow;

  /// Check if this media type is audio-based
  bool get isAudio => this == MediaType.music;

  /// Check if this media type is video-based
  bool get isVideo => this == MediaType.movie || this == MediaType.tvShow;

  /// Check if this media type is text-based
  bool get isText => this == MediaType.book;

  /// Check if this media type is interactive
  bool get isInteractive => this == MediaType.videoGame;
}

/// Helper class for media type utilities
class MediaTypeUtils {
  /// Convert legacy string-based media types to enum
  static MediaType? convertLegacyString(String mediaType) {
    return MediaType.fromString(mediaType);
  }

  /// Get all database names
  static List<String> get allDatabaseNames => 
    MediaType.allTypes.map((type) => type.databaseName).toList();

  /// Get all header names
  static List<String> get allHeaderNames => 
    MediaType.allTypes.map((type) => type.headerDisplayName).toList();

  /// Create a map of database names to MediaType (for quick lookup)
  static Map<String, MediaType> get databaseNameMap => {
    for (final type in MediaType.allTypes) type.databaseName: type
  };

  /// Create a map of header names to MediaType (for quick lookup)
  static Map<String, MediaType> get headerNameMap => {
    for (final type in MediaType.allTypes) type.headerDisplayName.toLowerCase(): type
  };
} 
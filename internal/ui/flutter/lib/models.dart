class SimpleTrack {
  final String id;
  final String name;
  final String artist;
  final String album;
  final String albumArtUrl;
  final String? previewUrl;
  final String uri;

  SimpleTrack({
    required this.id,
    required this.name,
    required this.artist,
    required this.album,
    required this.albumArtUrl,
    this.previewUrl,
    required this.uri,
  });

  factory SimpleTrack.fromJson(Map<String, dynamic> json) {
    final track = json['track'] as Map<String, dynamic>;
    final album = track['album'] as Map<String, dynamic>;
    final images = album['images'] as List<dynamic>;
    final artists = track['artists'] as List<dynamic>;

    String imageUrl = '';
    if (images.isNotEmpty) {
      imageUrl = images[0]['url'] as String? ?? '';
    }

    final artistNames = artists
        .map((a) => a['name'] as String)
        .join(', ');

    return SimpleTrack(
      id: track['id'] as String,
      name: track['name'] as String,
      artist: artistNames,
      album: album['name'] as String,
      albumArtUrl: imageUrl,
      uri: track['uri'] as String,
      previewUrl: track['preview_url'] as String?,
    );
  }
}

class Track {
  final String id;
  final String name;
  final List<Artist> artists;
  final Album album;
  final String previewUrl;
  final String uri;

  Track({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.previewUrl,
    required this.uri,
  });

  String get artist => artists.map((a) => a.name).join(', ');

  String get albumArtUrl => album.images.isNotEmpty ? album.images.first.url : '';
}

class Artist {
  final String name;

  Artist({
    required this.name,
  });
}

class Album {
  final String name;
  final List<ImageData> images;

  Album({
    required this.name,
    required this.images,
  });
}

class ImageData {
  final String url;
  final int height;
  final int width;

  ImageData({
    required this.url,
    required this.height,
    required this.width,
  });
}

/// MediaItem represents a generic media item (music, movie, book, etc.)
class MediaItem {
  final dynamic id;
  final String title;
  final String overview;
  final String posterPath;
  final String mediaType;
  final String reason;
  final String? director;
  final String? author;
  final String? uri;
  final String? previewUrl;
  final double? voteAverage;
  final String? date;
  final List<String>? subjects;
  final double? rating;
  final int? voteCount;
  final String? releaseDate;

  MediaItem({
    required this.id,
    required this.title,
    required this.mediaType,
    this.overview = '',
    this.posterPath = '',
    this.reason = '',
    this.director,
    this.author,
    this.uri,
    this.previewUrl,
    this.voteAverage,
    this.date,
    this.subjects,
    this.rating,
    this.voteCount,
    this.releaseDate,
  });

  /// Create a MediaItem from a Map, useful for JSON parsing
  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'],
      title: map['title'] ?? map['name'] ?? 'Unknown',
      overview: map['overview'] ?? map['artist'] ?? map['description'] ?? '',
      posterPath: map['poster_path'] ?? map['album_art_url'] ?? map['image_url'] ?? '',
      mediaType: map['media_type'] ?? 'unknown',
      reason: map['reason'] ?? '',
      director: map['director'],
      author: map['author'],
      uri: map['uri'],
      previewUrl: map['preview_url'],
      voteAverage: map['vote_average'] != null ? (map['vote_average'] is int ? (map['vote_average'] as int).toDouble() : map['vote_average'] as double) : 0.0,
      date: map['date'] ?? map['release_date'] ?? map['published_date'],
      subjects: map['subjects'] != null ? List<String>.from(map['subjects']) : null,
      rating: map['rating'] != null ? (map['rating'] is int ? (map['rating'] as int).toDouble() : map['rating'] as double) : null,
      voteCount: map['vote_count'],
      releaseDate: map['release_date'],
    );
  }

  /// Create a MediaItem from a JSON string
  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem.fromMap(json);
  }

  /// Convert to a Map, useful for JSON serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_path': posterPath,
      'media_type': mediaType,
      'reason': reason,
      if (director != null) 'director': director,
      if (author != null) 'author': author,
      if (uri != null) 'uri': uri,
      if (previewUrl != null) 'preview_url': previewUrl,
      if (voteAverage != null) 'vote_average': voteAverage,
      if (date != null) 'date': date,
      if (subjects != null) 'subjects': subjects,
      if (rating != null) 'rating': rating,
      if (voteCount != null) 'vote_count': voteCount,
      if (releaseDate != null) 'release_date': releaseDate,
    };
  }

  /// Create a copy with some fields replaced
  MediaItem copyWith({
    dynamic id,
    String? title,
    String? overview,
    String? posterPath,
    String? mediaType,
    String? reason,
    String? director,
    String? author,
    String? uri,
    String? previewUrl,
    double? voteAverage,
    String? date,
    List<String>? subjects,
    double? rating,
    int? voteCount,
    String? releaseDate,
    Map<String, dynamic>? extras,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      mediaType: mediaType ?? this.mediaType,
      reason: reason ?? this.reason,
      director: director ?? this.director,
      author: author ?? this.author,
      uri: uri ?? this.uri,
      previewUrl: previewUrl ?? this.previewUrl,
      voteAverage: voteAverage ?? this.voteAverage,
      date: date ?? this.date,
      subjects: subjects ?? this.subjects,
      rating: rating ?? this.rating,
      voteCount: voteCount ?? this.voteCount,
      releaseDate: releaseDate ?? this.releaseDate,
    );
  }
}

class MediaSuggestionItem {
  final dynamic id;
  final String title;
  final String? artist;
  final String? description;
  final String? imageUrl;
  final String? playUrl;
  final String? uri;
  final String? releaseDate;
  final double? rating;
  final int? voteCount;
  final String? mediaId; // Vector database ID
  final String? youtubeUrl; // Direct YouTube URL if available
  final String? youtubeId; // YouTube video ID
  final String? spotifyId; // Spotify track ID
  final String? themes; // Detected themes
  final String? genres; // Detected genres

  MediaSuggestionItem({
    required this.id,
    required this.title,
    this.artist,
    this.description,
    this.imageUrl,
    this.playUrl,
    this.uri,
    this.releaseDate,
    this.rating,
    this.voteCount,
    this.mediaId,
    this.youtubeUrl,
    this.youtubeId,
    this.spotifyId,
    this.themes,
    this.genres,
  });
}

/// Utility class to handle smart title/artist resolution
class MediaDisplayHelper {
  /// Intelligently determine what to show as title and subtitle
  /// If title is generic/unknown but artist exists, use artist as title
  /// If both exist and title is meaningful, use normally
  /// If both are null/empty, use fallback
  static MediaDisplayInfo resolveDisplayInfo({
    String? title,
    String? artist,
    String fallbackTitle = 'Unknown Title',
  }) {
    final cleanTitle = title?.trim();
    final cleanArtist = artist?.trim();
    
    // Case 1: Title is generic/unknown but artist exists and is meaningful
    if (_isGenericTitle(cleanTitle) && 
        cleanArtist != null && 
        cleanArtist.isNotEmpty && 
        !_isGenericArtist(cleanArtist)) {
      return MediaDisplayInfo(
        displayTitle: cleanArtist,
        displaySubtitle: null, // No subtitle when using artist as title
      );
    }
    
    // Case 2: Title exists and is meaningful, use it as primary
    if (cleanTitle != null && cleanTitle.isNotEmpty && !_isGenericTitle(cleanTitle)) {
      return MediaDisplayInfo(
        displayTitle: cleanTitle,
        displaySubtitle: cleanArtist, // Can be null, that's fine
      );
    }
    
    // Case 3: No meaningful title but artist exists, use artist as title
    if (cleanArtist != null && cleanArtist.isNotEmpty && !_isGenericArtist(cleanArtist)) {
      return MediaDisplayInfo(
        displayTitle: cleanArtist,
        displaySubtitle: null, // No subtitle in this case
      );
    }
    
    // Case 4: Both are null/empty or generic, use fallback
    return MediaDisplayInfo(
      displayTitle: fallbackTitle,
      displaySubtitle: null,
    );
  }

  /// Check if a title is generic/placeholder
  static bool _isGenericTitle(String? title) {
    if (title == null || title.isEmpty) return true;
    
    final lowerTitle = title.toLowerCase().trim();
    return lowerTitle == 'unknown' ||
           lowerTitle == 'unknown title' ||
           lowerTitle == 'untitled' ||
           lowerTitle == 'no title' ||
           lowerTitle == '' ||
           lowerTitle.startsWith('unknown ');
  }

  /// Check if an artist name is generic/placeholder
  static bool _isGenericArtist(String? artist) {
    if (artist == null || artist.isEmpty) return true;
    
    final lowerArtist = artist.toLowerCase().trim();
    return lowerArtist == 'unknown' ||
           lowerArtist == 'unknown artist' ||
           lowerArtist == 'various artists' ||
           lowerArtist == 'various' ||
           lowerArtist == '' ||
           lowerArtist.startsWith('unknown ');
  }
}

/// Container for resolved display information
class MediaDisplayInfo {
  final String displayTitle;
  final String? displaySubtitle;
  
  MediaDisplayInfo({
    required this.displayTitle,
    this.displaySubtitle,
  });
  
  /// Whether this has a subtitle to display
  bool get hasSubtitle => displaySubtitle != null && displaySubtitle!.isNotEmpty;
}
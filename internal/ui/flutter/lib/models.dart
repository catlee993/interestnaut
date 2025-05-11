class SimpleTrack {
  final String id;
  final String name;
  final String artist;
  final String album;
  final String albumArtUrl;
  final String previewUrl;
  final String uri;

  SimpleTrack({
    required this.id,
    required this.name,
    required this.artist,
    required this.album,
    required this.albumArtUrl,
    required this.previewUrl,
    required this.uri,
  });
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
}

class Artist {
  final String name;
  Artist({required this.name});
}

class Album {
  final String name;
  final List<ImageData> images;
  Album({required this.name, required this.images});
}

class ImageData {
  final String url;
  ImageData({required this.url});
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
  });
}
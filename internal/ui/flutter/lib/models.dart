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

class MediaItem {
  final int id;
  final String title;
  final String? overview;
  final String? posterPath;
  final double voteAverage;
  final int voteCount;
  final String? date;
  final bool isSaved;
  final String? director;
  final String? writer;
  final String? author;
  final List<String>? subjects;
  final String mediaType; // 'movie', 'tv', 'book', 'game', 'music'

  MediaItem({
    required this.id,
    required this.title,
    this.overview,
    this.posterPath,
    required this.voteAverage,
    required this.voteCount,
    this.date,
    this.isSaved = false,
    this.director,
    this.writer,
    this.author,
    this.subjects,
    required this.mediaType,
  });
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
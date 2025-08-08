import '../models/models.dart'; // For SimpleTrack
import '../../shared/services/wikidata_service.dart'; // For WikidataSearchResult

/// Base class for all track search results
abstract class BaseTrack {
  String get id;
  String get name;
  String get artist;
  String? get album;
  String? get albumArtUrl;
  String? get previewUrl;
  
  /// Check if this track can be played on YouTube
  bool get hasYouTubeId;
  
  /// Check if this track can be played on Spotify
  bool get hasSpotifyId;
  
  /// Get YouTube ID if available
  String? get youtubeId;
  
  /// Get Spotify ID if available
  String? get spotifyId;
}

/// Interestnaut track from our database with potential external IDs
class InterestnautTrack extends BaseTrack {
  @override
  final String id;
  @override
  final String name;
  @override
  final String artist;
  @override
  final String? album;
  @override
  final String? albumArtUrl;
  @override
  final String? previewUrl;
  @override
  final String? youtubeId;
  @override
  final String? spotifyId;
  
  // Additional Interestnaut-specific fields
  final String? wikidataId;
  final String? description;
  final String? themes;
  final List<String>? genres;
  final String? botReasoning;

  InterestnautTrack({
    required this.id,
    required this.name,
    required this.artist,
    this.album,
    this.albumArtUrl,
    this.previewUrl,
    this.youtubeId,
    this.spotifyId,
    this.wikidataId,
    this.description,
    this.themes,
    this.genres,
    this.botReasoning,
  });

  @override
  bool get hasYouTubeId => youtubeId != null && youtubeId!.isNotEmpty;
  
  @override
  bool get hasSpotifyId => spotifyId != null && spotifyId!.isNotEmpty;
  
  /// Create from WikidataSearchResult
  factory InterestnautTrack.fromWikidataResult(WikidataSearchResult result) {
    return InterestnautTrack(
      id: result.id,
      name: result.title,
      artist: result.artist ?? 'Unknown Artist',
      album: result.description,
      albumArtUrl: result.imageUrl,
      previewUrl: null,
      youtubeId: result.additionalData?['youtubeId'] as String?,
      spotifyId: result.additionalData?['spotifyId'] as String?,
      wikidataId: result.additionalData?['wikidataId'] as String?,
      description: result.description,
      themes: result.additionalData?['themes'] as String?,
      genres: result.additionalData?['genres'] != null 
          ? (result.additionalData!['genres'] as String).split(', ')
          : null,
      botReasoning: result.additionalData?['reasoning'] as String?,
    );
  }
}

/// Spotify track from Spotify API
class SpotifyTrack extends BaseTrack {
  @override
  final String id;
  @override
  final String name;
  @override
  final String artist;
  @override
  final String? album;
  @override
  final String? albumArtUrl;
  @override
  final String? previewUrl;
  final String uri; // Spotify URI
  
  SpotifyTrack({
    required this.id,
    required this.name,
    required this.artist,
    this.album,
    this.albumArtUrl,
    this.previewUrl,
    required this.uri,
  });

  @override
  bool get hasYouTubeId => false; // Spotify tracks don't have YouTube IDs
  
  @override
  bool get hasSpotifyId => true; // Spotify tracks always have Spotify access
  
  @override
  String? get youtubeId => null;
  
  @override
  String get spotifyId => id; // The track ID is the Spotify ID
  
  /// Create from SimpleTrack (legacy)
  factory SpotifyTrack.fromSimpleTrack(SimpleTrack track) {
    return SpotifyTrack(
      id: track.id,
      name: track.name,
      artist: track.artist,
      album: track.album,
      albumArtUrl: track.albumArtUrl,
      previewUrl: track.previewUrl,
      uri: track.uri,
    );
  }
}
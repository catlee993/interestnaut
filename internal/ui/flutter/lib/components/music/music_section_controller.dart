import 'dart:async';
import 'package:flutter/material.dart';
import '../common/base_media_section_controller.dart';
import '../../services/recommendation_service.dart';
import 'spotify_service.dart';
import 'player/spotify_player_view.dart'; // For SpotifyEvents
import '../../models.dart';

/// Music-specific controller that extends the base controller
/// Handles Spotify integration and music-specific behavior
class MusicSectionController extends BaseMediaSectionController {
  // Spotify-specific state
  bool _isAuthenticated = false;
  List<Track> _likedTracks = [];
  bool _isLoadingLibrary = false;
  bool _isPaginating = false; // New state for pagination loading
  Track? _nowPlayingTrack;
  bool _isPlaybackPaused = true;
  
  // Pagination state for Spotify library
  int _currentSpotifyPage = 1;
  int _totalSpotifyTracks = 0;
  final int _itemsPerPage = 20;
  
  // Spotify services
  final SpotifyService _spotifyService = SpotifyService();
  
  // Track if this controller has been disposed
  bool _isDisposed = false;
  
  // Spotify subscriptions
  StreamSubscription? _authSubscription;
  StreamSubscription? _deviceIdSubscription;
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _trackChangeSubscription;
  StreamSubscription? _spotifyEventsTrackSubscription;
  StreamSubscription? _spotifyEventsPlaybackSubscription;
  StreamSubscription? _playerReadySubscription;
  
  MusicSectionController(RecommendationService recommendationService) : super('music', recommendationService) {
    _setupSpotifyListeners();
    _checkAuthentication();
  }
  
  // Getters for music-specific state
  bool get isAuthenticated => _isAuthenticated;
  List<Track> get likedTracks => _likedTracks;
  bool get isLoadingLibrary => _isLoadingLibrary;
  bool get isPaginating => _isPaginating;
  Track? get nowPlayingTrack => _nowPlayingTrack;
  bool get isPlaybackPaused => _isPlaybackPaused;
  
  // Pagination getters
  int get currentSpotifyPage => _currentSpotifyPage;
  int get totalSpotifyTracks => _totalSpotifyTracks;
  int get itemsPerPage => _itemsPerPage;
  
  void _setupSpotifyListeners() {
    // Listen for Spotify player ready event
    _playerReadySubscription = SpotifyEvents.onPlayerReady.listen((isReady) {
      if (!_isDisposed) {
        debugPrint('MusicSection received player ready event: $isReady');
        notifyListeners();
      }
    });
    
    // Listen for authentication status changes
    _authSubscription =
        _spotifyService.onAuthStatusChange.listen((authEvent) {
      if (!_isDisposed) {
        _isAuthenticated = authEvent.isAuthenticated;
        notifyListeners();
        
        if (authEvent.isAuthenticated) {
          _loadSpotifyLibrary();
        }
      }
    });

    // Listen for playback state changes
    _playbackStateSubscription =
        _spotifyService.onPlaybackStateChange.listen((isPaused) {
      if (!_isDisposed) {
        _isPlaybackPaused = isPaused;
        notifyListeners();
      }
    });

    // Listen for track changes
    _trackChangeSubscription = _spotifyService.onTrackChange.listen((trackEvent) {
      if (!_isDisposed) {
        // Convert MediaItem to Track if needed
        _nowPlayingTrack = trackEvent.item != null ? _convertMediaItemToTrack(trackEvent.item!) : null;
        notifyListeners();
      }
    });

    // Listen for device ID changes
    _deviceIdSubscription = _spotifyService.onDeviceIdChange.listen((deviceId) {
      if (!_isDisposed) {
        // Handle device ID changes if needed
        notifyListeners();
      }
    });

    // Listen for Spotify events
    _spotifyEventsTrackSubscription =
        SpotifyEvents.onTrackChange.listen((track) {
      if (!_isDisposed) {
        _nowPlayingTrack = track;
        notifyListeners();
      }
    });

    _spotifyEventsPlaybackSubscription =
        SpotifyEvents.onPlaybackStateChange.listen((playbackState) {
      if (!_isDisposed) {
        _isPlaybackPaused = !playbackState.isPlaying; // Use isPlaying instead of isPaused
        notifyListeners();
      }
    });
  }
  
  Future<void> _checkAuthentication() async {
    try {
      final isAuth = _spotifyService.isAuthenticated; // It's a getter, not a method
      _isAuthenticated = isAuth;
      if (!_isDisposed) {
        notifyListeners();
      }
      
      if (isAuth) {
        await _loadSpotifyLibrary();
      }
    } catch (e) {
      debugPrint('Error checking Spotify authentication: $e');
    }
  }
  
  Future<void> _loadSpotifyLibrary([int page = 1]) async {
    // Only show loading on initial load (when we have no tracks)
    final isInitialLoad = _likedTracks.isEmpty;
    final isPagination = !isInitialLoad && page != _currentSpotifyPage;
    
    if (isInitialLoad) {
      _isLoadingLibrary = true;
    } else if (isPagination) {
      _isPaginating = true;
    }
    
    if (!_isDisposed) {
      notifyListeners();
    }
    
    try {
      final offset = (page - 1) * _itemsPerPage;
      final result = await _spotifyService.getLikedTracks(limit: _itemsPerPage, offset: offset);
      final tracks = result['items'] as List<dynamic>;
      final total = result['total'] as int;
      
      _likedTracks = tracks.map((track) => _convertSimpleTrackToTrack(track)).toList();
      _currentSpotifyPage = page;
      _totalSpotifyTracks = total;
      _isLoadingLibrary = false;
      _isPaginating = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading Spotify library: $e');
      _isLoadingLibrary = false;
      _isPaginating = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }
  
  // Helper method to convert MediaItem to Track
  Track? _convertMediaItemToTrack(MediaItem mediaItem) {
    return Track(
      id: mediaItem.id.toString(),
      name: mediaItem.title,
      artists: [Artist(name: mediaItem.overview)],
      album: Album(name: '', images: []),
      uri: mediaItem.uri ?? '',
      previewUrl: mediaItem.previewUrl ?? '',
    );
  }

  // Helper method to convert SimpleTrack to Track
  Track _convertSimpleTrackToTrack(dynamic simpleTrack) {
    // If it's already a Track, return it
    if (simpleTrack is Track) {
      return simpleTrack;
    }
    
    // If it's a Map (from API response), convert it
    if (simpleTrack is Map<String, dynamic>) {
      // Create album images if available
      final albumImages = <ImageData>[];
      if (simpleTrack['albumArtUrl'] != null && simpleTrack['albumArtUrl'].isNotEmpty) {
        albumImages.add(ImageData(
          url: simpleTrack['albumArtUrl'],
          height: 300,
          width: 300,
        ));
      }
      
      return Track(
        id: simpleTrack['id'] ?? '',
        name: simpleTrack['name'] ?? '',
        artists: [Artist(name: simpleTrack['artist'] ?? '')],
        album: Album(name: simpleTrack['album'] ?? '', images: albumImages),
        uri: simpleTrack['uri'] ?? '',
        previewUrl: simpleTrack['previewUrl'] ?? '',
      );
    }
    
    // If it's a SimpleTrack object, access properties directly
    final albumImages = <ImageData>[];
    if (simpleTrack.albumArtUrl != null && simpleTrack.albumArtUrl.isNotEmpty) {
      albumImages.add(ImageData(
        url: simpleTrack.albumArtUrl,
        height: 300,
        width: 300,
      ));
    }
    
    return Track(
      id: simpleTrack.id ?? '',
      name: simpleTrack.name ?? '',
      artists: [Artist(name: simpleTrack.artist ?? 'Unknown Artist')], // Use artist (singular), not artists
      album: Album(name: simpleTrack.album ?? 'Unknown Album', images: albumImages),
      uri: simpleTrack.uri ?? '',
      previewUrl: simpleTrack.previewUrl ?? '',
    );
  }

  // Spotify-specific actions
  Future<void> authenticateSpotify([BuildContext? context]) async {
    try {
      if (context != null) {
        debugPrint('Starting Spotify authentication...');
        final success = await _spotifyService.authenticate(context);
        if (success) {
          debugPrint('Spotify authentication successful');
        } else {
          debugPrint('Spotify authentication failed');
        }
      } else {
        debugPrint('Spotify authentication requested but no context provided');
      }
    } catch (e) {
      debugPrint('Error authenticating with Spotify: $e');
    }
  }
  
  Future<void> playTrack(String trackUri) async {
    try {
      await _spotifyService.playTrack(trackUri);
    } catch (e) {
      debugPrint('Error playing track: $e');
    }
  }
  
  Future<void> pausePlayback() async {
    try {
      await _spotifyService.pausePlayback();
    } catch (e) {
      debugPrint('Error pausing playback: $e');
    }
  }
  
  Future<void> resumePlayback() async {
    try {
      await _spotifyService.resumePlayback();
    } catch (e) {
      debugPrint('Error resuming playback: $e');
    }
  }
  
  Future<void> refreshSpotifyLibrary() async {
    await _loadSpotifyLibrary(_currentSpotifyPage);
  }
  
  // Pagination methods for Spotify library
  void nextSpotifyPage() {
    if (_currentSpotifyPage * _itemsPerPage < _totalSpotifyTracks) {
      _loadSpotifyLibrary(_currentSpotifyPage + 1);
    }
  }
  
  void prevSpotifyPage() {
    if (_currentSpotifyPage > 1) {
      _loadSpotifyLibrary(_currentSpotifyPage - 1);
    }
  }
  
  // Track action methods for LibrarySection
  Future<void> playSpotifyTrack(Track track) async {
    try {
      // Check if this track is currently playing
      if (_nowPlayingTrack?.id == track.id) {
        // Same track - toggle play/pause
        if (_isPlaybackPaused) {
          await resumePlayback();
        } else {
          await pausePlayback();
        }
      } else {
        // Different track - play the new track
        await _spotifyService.playTrack(track.uri);
      }
    } catch (e) {
      debugPrint('Error playing Spotify track: $e');
    }
  }
  
  Future<void> saveSpotifyTrack(Track track) async {
    // For liked tracks, this would be removing from library
    try {
      // Implementation would depend on your Spotify service methods
      debugPrint('Save/unsave Spotify track: ${track.name}');
    } catch (e) {
      debugPrint('Error saving Spotify track: $e');
    }
  }
  
  Future<void> removeSpotifyTrack(Track track) async {
    // Remove from liked tracks
    try {
      // Implementation would depend on your Spotify service methods
      debugPrint('Remove Spotify track: ${track.name}');
      // Refresh the current page after removal
      await refreshSpotifyLibrary();
    } catch (e) {
      debugPrint('Error removing Spotify track: $e');
    }
  }
  
  // Override base controller methods for music-specific behavior
  @override
  void onSuggestionLiked(MediaSuggestion suggestion) {
    // Music-specific behavior when suggestion is liked
    debugPrint('Music suggestion liked: ${suggestion.title}');
  }
  
  @override
  void onSuggestionDisliked(MediaSuggestion suggestion) {
    // Music-specific behavior when suggestion is disliked
    debugPrint('Music suggestion disliked: ${suggestion.title}');
  }
  
  @override
  void onSuggestionSkipped(MediaSuggestion suggestion) {
    // Music-specific behavior when suggestion is skipped
    debugPrint('Music suggestion skipped: ${suggestion.title}');
  }
  
  @override
  void onSuggestionFavorited(MediaSuggestion suggestion) {
    // Music-specific behavior when suggestion is favorited
    debugPrint('Music suggestion favorited: ${suggestion.title}');
  }
  
  @override
  void onSuggestionAddedToWatchlist(MediaSuggestion suggestion) {
    // Music-specific behavior when suggestion is added to playlist
    debugPrint('Music suggestion added to playlist: ${suggestion.title}');
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _authSubscription?.cancel();
    _deviceIdSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _trackChangeSubscription?.cancel();
    _spotifyEventsTrackSubscription?.cancel();
    _spotifyEventsPlaybackSubscription?.cancel();
    _playerReadySubscription?.cancel();
    super.dispose();
  }
} 
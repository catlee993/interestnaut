import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../features/music/presentation/spotify_service.dart';
import '../models/models.dart';
import 'sqlite_db.dart';

/// Service to handle continuous playback of liked songs
class ContinuousPlaybackService {
  static final ContinuousPlaybackService _instance = ContinuousPlaybackService._internal();
  factory ContinuousPlaybackService() => _instance;
  ContinuousPlaybackService._internal();

  final SpotifyService _spotifyService = SpotifyService();
  final SQLiteDatabase _db = SQLiteDatabase();
  
  Timer? _trackCheckTimer;
  List<SimpleTrack> _likedTracks = [];
  int _currentTrackIndex = 0;
  bool _isEnabled = false;
  bool _isShuffled = false;
  String? _currentTrackId;
  
  // Stream to notify about playback changes
  final _playbackStateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPlaybackStateChange => _playbackStateController.stream;

  /// Initialize the continuous playback service
  Future<void> initialize() async {
    debugPrint('🎵 Initializing continuous playback service...');
    
    // Check if continuous playback is enabled in settings
    _isEnabled = await isEnabled();
    
    // Listen for Spotify authentication status
    _spotifyService.onAuthStatusChange.listen((authEvent) async {
      if (authEvent.isAuthenticated) {
        // Re-check settings and prepare if enabled
        _isEnabled = await isEnabled();
        if (_isEnabled) {
          // Don't reload tracks on token refresh if we already have them
          if (_likedTracks.isEmpty) {
            await _prepareService();
          } else {
            // Just restart monitoring, keep existing tracks
            _startPlaybackMonitoring();
            debugPrint('✅ Continuous playback reconnected after token refresh (keeping ${_likedTracks.length} tracks)');
          }
        }
      } else {
        _stop();
      }
    });

    // Listen for playback state changes from Spotify
    // Note: We don't auto-play on pause events anymore
    // The monitoring timer handles natural track endings

    // If already authenticated and enabled, prepare the service
    if (_spotifyService.isAuthenticated && _isEnabled) {
      await _prepareService();
    }

    debugPrint('✅ Continuous playback service initialized (enabled: $_isEnabled)');
  }

  /// Check if continuous playback is enabled for music
  Future<bool> isEnabled() async {
    try {
      _isEnabled = await _db.getContinuousPlaybackSetting();
      return _isEnabled;
    } catch (e) {
      debugPrint('Error checking continuous playback setting: $e');
      return false;
    }
  }

  /// Enable or disable continuous playback
  Future<void> setEnabled(bool enabled) async {
    try {
      await _db.setContinuousPlaybackSetting(enabled);
      _isEnabled = enabled;
      
      if (enabled) {
        // Don't auto-start playback, just prepare the service
        await _prepareService();
      } else {
        _stop();
      }
      
      _emitStateChange();
    } catch (e) {
      debugPrint('Error setting continuous playback: $e');
    }
  }

  /// Prepare the continuous playback service (start monitoring, lazy load tracks)
  Future<void> _prepareService() async {
    if (!_spotifyService.isAuthenticated) {
      debugPrint('Cannot prepare continuous playback: Spotify not authenticated');
      return;
    }

    debugPrint('🎵 Preparing continuous playback service (lazy loading)...');
    
    // Clear existing tracks to force reload when needed
    _likedTracks.clear();
    _currentTrackIndex = 0;

    // Start monitoring playback (but don't start playing or load tracks yet)
    _startPlaybackMonitoring();
    
    debugPrint('✅ Continuous playback prepared (tracks will load when needed)');
  }

  /// Stop continuous playback
  void _stop() {
    debugPrint('🛑 Stopping continuous playback...');
    
    _trackCheckTimer?.cancel();
    _trackCheckTimer = null;
    
    _emitStateChange();
  }

  /// Refresh the list of liked tracks from Spotify
  Future<void> _refreshLikedTracks() async {
    try {
      debugPrint('🔄 Refreshing liked tracks for continuous playback...');
      
      // Get user's liked tracks from Spotify (first batch)
      final likedTracksResponse = await _spotifyService.getLikedTracks(limit: 50);
      _likedTracks = likedTracksResponse['items'] as List<SimpleTrack>? ?? [];
      
      // If there are more tracks, get them all
      final totalTracks = likedTracksResponse['total'] as int? ?? 0;
      if (totalTracks > 50) {
        // Get all remaining tracks in batches
        for (int offset = 50; offset < min(totalTracks, 500); offset += 50) {
          final batch = await _spotifyService.getLikedTracks(limit: 50, offset: offset);
          final batchTracks = batch['items'] as List<SimpleTrack>? ?? [];
          _likedTracks.addAll(batchTracks);
        }
      }
      
      if (_isShuffled) {
        _shuffleTracks();
      }
      
      debugPrint('✅ Loaded ${_likedTracks.length} liked tracks for continuous playback');
    } catch (e) {
      debugPrint('Error refreshing liked tracks: $e');
    }
  }

  /// Shuffle the track list
  void _shuffleTracks() {
    if (_likedTracks.isEmpty) return;
    
    final random = Random();
    for (int i = _likedTracks.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = _likedTracks[i];
      _likedTracks[i] = _likedTracks[j];
      _likedTracks[j] = temp;
    }
    
    _currentTrackIndex = 0;
    debugPrint('🔀 Shuffled ${_likedTracks.length} tracks');
  }

  /// Enable or disable shuffle
  void setShuffle(bool shuffle) {
    _isShuffled = shuffle;
    if (shuffle) {
      _shuffleTracks();
    }
    _emitStateChange();
  }

  /// Start monitoring playback to detect when tracks end
  void _startPlaybackMonitoring() {
    _trackCheckTimer?.cancel();
    
    // Keep track of the last known state
    bool wasPlaying = false;
    int? lastPositionMs;
    
    _trackCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isEnabled) {
        timer.cancel();
        return;
      }
      
      // Check current playback state
      final playbackState = await _spotifyService.getPlaybackState();
      if (playbackState == null) return;
      
      final isPlaying = playbackState['is_playing'] as bool? ?? false;
      final currentTrack = playbackState['item'] as Map<String, dynamic>?;
      final progressMs = playbackState['progress_ms'] as int?;
      final durationMs = currentTrack?['duration_ms'] as int?;
      
      if (currentTrack != null) {
        final trackId = currentTrack['id'] as String?;
        
        // Track changed
        if (trackId != _currentTrackId) {
          _currentTrackId = trackId;
          lastPositionMs = progressMs;
          wasPlaying = isPlaying;
          return;
        }
        
        // Check if track naturally ended (was playing, now stopped, and position is near the end)
        if (wasPlaying && !isPlaying && progressMs != null && durationMs != null) {
          // Track ended if we're within 1 second of the end
          final nearEnd = durationMs - progressMs < 1000;
          
          // Also check if position went backwards (new track started)
          final wentBackwards = lastPositionMs != null && progressMs < (lastPositionMs! - 1000);
          
          if (nearEnd || wentBackwards) {
            debugPrint('🎵 Track naturally ended, playing next...');
            await _playNextTrack();
          } else {
            debugPrint('⏸️ Playback paused by user at ${progressMs}ms/${durationMs}ms');
          }
        }
        
        lastPositionMs = progressMs;
      }
      
      wasPlaying = isPlaying;
    });
  }


  /// Play the next track in the queue
  Future<void> _playNextTrack() async {
    // Lazy load tracks if not already loaded
    if (_likedTracks.isEmpty) {
      debugPrint('🔄 Lazy loading liked tracks for continuous playback...');
      await _refreshLikedTracks();
      
      if (_likedTracks.isEmpty) {
        debugPrint('No tracks available for continuous playback');
        return;
      }
    }

    // Move to next track
    _currentTrackIndex = (_currentTrackIndex + 1) % _likedTracks.length;
    
    final nextTrack = _likedTracks[_currentTrackIndex];
    final trackUri = 'spotify:track:${nextTrack.id}';
    
    debugPrint('🎵 Playing next track: ${nextTrack.name} by ${nextTrack.artist}');
    
    // Play the track
    final success = await _spotifyService.playTrack(trackUri);
    if (success) {
      _currentTrackId = nextTrack.id;
      _emitStateChange();
    } else {
      debugPrint('Failed to play next track, trying another...');
      // Try the next track if this one failed
      await Future.delayed(const Duration(seconds: 1));
      await _playNextTrack();
    }
  }

  /// Skip to the next track manually
  Future<void> skipToNext() async {
    if (!_isEnabled) return;
    
    await _playNextTrack();
  }

  /// Skip to the previous track manually
  Future<void> skipToPrevious() async {
    if (!_isEnabled) return;
    
    // Lazy load tracks if not already loaded
    if (_likedTracks.isEmpty) {
      debugPrint('🔄 Lazy loading liked tracks for continuous playback...');
      await _refreshLikedTracks();
      
      if (_likedTracks.isEmpty) {
        debugPrint('No tracks available for continuous playback');
        return;
      }
    }
    
    // Move to previous track
    _currentTrackIndex = (_currentTrackIndex - 1 + _likedTracks.length) % _likedTracks.length;
    
    final prevTrack = _likedTracks[_currentTrackIndex];
    final trackUri = 'spotify:track:${prevTrack.id}';
    
    debugPrint('🎵 Playing previous track: ${prevTrack.name} by ${prevTrack.artist}');
    
    final success = await _spotifyService.playTrack(trackUri);
    if (success) {
      _currentTrackId = prevTrack.id;
      _emitStateChange();
    }
  }

  /// Get the current track information
  SimpleTrack? getCurrentTrack() {
    if (_likedTracks.isEmpty || _currentTrackIndex >= _likedTracks.length) {
      return null;
    }
    return _likedTracks[_currentTrackIndex];
  }

  /// Get the queue information
  Map<String, dynamic> getQueueInfo() {
    return {
      'totalTracks': _likedTracks.length,
      'currentIndex': _currentTrackIndex,
      'isShuffled': _isShuffled,
      'isEnabled': _isEnabled,
    };
  }

  /// Emit state change to listeners
  void _emitStateChange() {
    final currentTrack = getCurrentTrack();
    _playbackStateController.add({
      'isEnabled': _isEnabled,
      'isShuffled': _isShuffled,
      'currentTrack': currentTrack != null ? {
        'id': currentTrack.id,
        'name': currentTrack.name,
        'artist': currentTrack.artist,
        'album': currentTrack.album,
        'albumArtUrl': currentTrack.albumArtUrl,
        'uri': currentTrack.uri,
      } : null,
      'queueInfo': getQueueInfo(),
    });
  }

  /// Dispose of resources
  void dispose() {
    _trackCheckTimer?.cancel();
    _playbackStateController.close();
  }
}
import 'dart:ui';
import 'dart:async';
import 'dart:async';
import 'package:flutter/material.dart';
import '../common/scroll_content_wrapper.dart';

import '../common/media_library_grid.dart';
import '../common/suggestion_action_buttons.dart';
import '../common/loading_suggestion.dart';
import '../../models.dart';
import '../../services/recommendation_service.dart';
import '../../services/recommendation_event_service.dart';
import '../../services/sqlite_db.dart';
import 'library/library_section.dart';

import 'player/spotify_player_view.dart';
import 'player/spotify_web_player.dart';
import 'spotify_service.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/text_utils.dart';


// A helper class to adapt Track to MediaItem for compatibility
class TrackAdapter {
  static MediaItem toMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      title: track.name,
      mediaType: 'music',
      overview: '',
      posterPath: track.albumArtUrl,
      uri: track.uri,
      previewUrl: track.previewUrl,
    );
  }
  
  // Convert MediaItem to Track if possible
  static Track? fromMediaItem(MediaItem? mediaItem) {
    if (mediaItem == null) return null;
    
    return Track(
      id: mediaItem.id.toString(),
      name: mediaItem.title,
      artists: [Artist(name: mediaItem.title.split(' - ').length > 1 ? mediaItem.title.split(' - ')[1] : '')],
      album: Album(
        name: '',
        images: mediaItem.posterPath.isNotEmpty 
          ? [ImageData(url: mediaItem.posterPath, height: 300, width: 300)] 
          : [],
      ),
      uri: mediaItem.uri ?? '',
      previewUrl: mediaItem.previewUrl ?? '',
    );
  }
}

class MusicSection extends StatefulWidget {
  const MusicSection({
    super.key,
  });

  @override
  State<MusicSection> createState() => _MusicSectionState();
}

class _MusicSectionState extends State<MusicSection> {
  // State variables
  bool _isAuthenticated = false;
  final bool _isLoading = true;
  String? _errorMessage;
  String? _activeDeviceId;
  String? _pendingTrackUri;
  bool _isPlayerReady = false;

  // Database suggestion state
  MediaSuggestion? _currentDbSuggestion;
  Track? _dbSuggestedTrack;
  String? _dbSuggestionError;
  bool _isLoadingDbSuggestion = false;
  bool _hasLikedCurrentSuggestion = false;
  bool _hasFavoritedCurrentSuggestion = false; // Added this state variable

  // Playback state
  Track? _nowPlayingTrack;
  bool _isPlaybackPaused = true;

  // Library state (for Spotify liked tracks)
  List<Track> _likedTracks = [];
  bool _isLoadingLibrary = false;
  int _currentLibraryPage = 1;
  int _totalLibraryTracks = 0;
  final int _tracksPerPage = 20; // Show 20 tracks per page (4x5 grid)

  // Local DB library state (for liked suggestions)
  List<MediaSuggestion> _dbLikedSuggestions = [];
  bool _isLoadingDbLibrary = false;

  // Local DB playlist state (for watchlist suggestions)
  List<MediaSuggestion> _dbPlaylistSuggestions = [];
  bool _isLoadingDbPlaylist = false;

  // Keep services and other components
  final SpotifyService _spotifyService = SpotifyService();
  final RecommendationService _recommendationService = RecommendationService();
  final RecommendationEventService _eventService = RecommendationEventService();
  final SQLiteDatabase _db = SQLiteDatabase();

  StreamSubscription? _authSubscription;
  StreamSubscription? _deviceIdSubscription;
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _trackChangeSubscription;
  StreamSubscription? _spotifyEventsTrackSubscription;
  StreamSubscription? _spotifyEventsPlaybackSubscription;
  StreamSubscription? _playerReadySubscription;
  StreamSubscription? _recommendationEventSubscription;

  @override
  void initState() {
    super.initState();
    
    _setupListeners();
    _setupRecommendationEventListener();
    _checkAuthentication();
    
    // Load initial DB suggestion
    _loadDbSuggestion();
    // Load DB library and playlist
    _loadDbLibrary();
    _loadDbPlaylist();
  }

  void _setupRecommendationEventListener() {
    // Listen for recommendation events for music
    _recommendationEventSubscription = _eventService.eventsForMediaType('music').listen((event) {
      if (!mounted) return;
      
      debugPrint('🎵 Music section received event: ${event.type}');
      // Defer all UI updates to next frame to avoid blocking
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        switch (event.type) {
          case RecommendationEventType.suggestionReady:
            if (event.suggestion != null) {
              _updateWithRealSuggestion(event.suggestion!);
            }
            break;
          case RecommendationEventType.suggestionError:
            setState(() {
              _dbSuggestionError = event.error ?? 'Unknown error';
              _isLoadingDbSuggestion = false;
            });
            break;
          case RecommendationEventType.suggestionStarted:
            // Loading state is already set when we call generateSuggestionOnDemand
            break;
        }
      });
    });
  }

  void _setupListeners() {
    // Listen for Spotify player ready event
    _playerReadySubscription = SpotifyEvents.onPlayerReady.listen((isReady) {
      debugPrint('MusicSection received player ready event: $isReady');
      setState(() {
        _isPlayerReady = isReady;
        
        // If we have a pending track and the player is now ready, play it
        if (_isPlayerReady && _pendingTrackUri != null) {
          debugPrint('Playing pending track now that player is ready: $_pendingTrackUri');
          _playTrack(_pendingTrackUri!);
          _pendingTrackUri = null;
        }
      });
    });
    
    // Listen for track changes
    _trackChangeSubscription = _spotifyService.onTrackChange.listen((event) {
      // The event is a TrackChangeEvent with a MediaItem
      if (event.item != null) {
        final track = TrackAdapter.fromMediaItem(event.item);
        if (track != null) {
          setState(() {
            _nowPlayingTrack = track;
          });
        }
      }
    });
    
    // Also listen for track changes from SpotifyEvents
    _spotifyEventsTrackSubscription = SpotifyEvents.onTrackChange.listen((track) {
      debugPrint('MusicSection received SpotifyEvents track change: ${track.name}');
      setState(() {
        _nowPlayingTrack = track;
      });
    });
    
    // Listen for auth state changes
    _authSubscription = _spotifyService.onAuthStatusChange.listen((event) {
      setState(() {
        _isAuthenticated = event.isAuthenticated;
      });

      if (_isAuthenticated) {
        // Log player conditions to help with debugging
        debugPrint('Player conditions: isAuthenticated=$_isAuthenticated, nowPlayingTrack=$_nowPlayingTrack');
        
        _loadLibrary();
        
        // Check player readiness after a short delay to allow for initialization
        Future.delayed(const Duration(seconds: 1), () {
          if (_pendingTrackUri != null && SpotifyEvents.isPlayerReady) {
            debugPrint('Auth completed and player is ready - playing pending track: $_pendingTrackUri');
            _playTrack(_pendingTrackUri!);
            _pendingTrackUri = null;
          } else if (_pendingTrackUri != null) {
            debugPrint('Auth completed but player not ready - track remains pending: $_pendingTrackUri');
            // Keep the track pending until the player is ready
          }
        });
      } else {
        debugPrint('User logged out - clearing player state');
        // Clear player state on logout
        setState(() {
          _pendingTrackUri = null;
          _nowPlayingTrack = null;
        });
      }
    });
    
    // Listen for device ID changes - this is crucial for proper playback
    _deviceIdSubscription = _spotifyService.onDeviceIdChange.listen((deviceId) {
      debugPrint('Spotify device ready: $deviceId');
      setState(() {
        _activeDeviceId = deviceId;
      });
      
      // Play any pending track
      if (_pendingTrackUri != null) {
        debugPrint('Device reconnected - playing pending track: $_pendingTrackUri');
        _playTrack(_pendingTrackUri!);
        _pendingTrackUri = null;
      }
      
      // If we were trying to play a track but got "Device not found", retry now
      if (_nowPlayingTrack != null && _isPlaybackPaused) {
        debugPrint('Device reconnected - retrying playback for current track: ${_nowPlayingTrack!.name}');
        Future.delayed(const Duration(milliseconds: 500), () {
          _playTrack(_nowPlayingTrack!.uri);
        });
      }
    });

    // Listen for playback state changes via SpotifyEvents
    _spotifyEventsPlaybackSubscription = SpotifyEvents.onPlaybackStateChange.listen((state) {
      debugPrint('MusicSection received SpotifyEvents playback state change: playing=${state.isPlaying}');
      setState(() {
        _isPlaybackPaused = !state.isPlaying;
      });
    });
    
    // Also listen for playback state changes via service for backward compatibility
    _playbackStateSubscription = _spotifyService.onPlaybackStateChange.listen((isPlaying) {
      setState(() {
        _isPlaybackPaused = !isPlaying;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _deviceIdSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _trackChangeSubscription?.cancel();
    _spotifyEventsTrackSubscription?.cancel();
    _spotifyEventsPlaybackSubscription?.cancel();
    _playerReadySubscription?.cancel();
    _recommendationEventSubscription?.cancel();
    super.dispose();
  }

  // Check if user is authenticated on init and when the auth state changes
  Future<void> _checkAuthentication() async {
    final isAuthenticated = await _spotifyService.checkAuthentication();
    
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuthenticated;
      });
    }

    if (_isAuthenticated) {
      _loadLibrary();
    }
  }

  // Fetch user's liked tracks from Spotify
  Future<void> _loadLibrary() async {
    setState(() {
      _isLoadingLibrary = true;
    });

    try {
      final response = await _spotifyService.getLikedTracks(
        limit: _tracksPerPage,
        offset: (_currentLibraryPage - 1) * _tracksPerPage,
      );

      final List<Track> tracks = [];
      
      if (response.containsKey('items')) {
        final items = response['items'];
        final total = response['total'] as int?;
        
        if (items is List) {
          for (int i = 0; i < items.length; i++) {
            final item = items[i];
            if (item is SimpleTrack) {
              // Direct conversion from SimpleTrack to Track
              tracks.add(_convertSimpleTrackToTrack(item));
            }
          }
        }
        
        setState(() {
          _likedTracks = tracks;
          _totalLibraryTracks = total ?? 0;
          _isLoadingLibrary = false;
          debugPrint('Set _likedTracks with ${_likedTracks.length} tracks');
          debugPrint('Total library tracks: $_totalLibraryTracks');
        });
      } else if (response is List) {
        for (int i = 0; i <response.length; i++) {
          final item = response[i];
          if (item is SimpleTrack) {
            tracks.add(_convertSimpleTrackToTrack(item));
          }
        }
        
        setState(() {
          _likedTracks = tracks;
          _totalLibraryTracks = tracks.length;
          _isLoadingLibrary = false;
        });
      } else {
        setState(() {
          _likedTracks = [];
          _totalLibraryTracks = 0;
          _isLoadingLibrary = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading library: $e');
      setState(() {
        _isLoadingLibrary = false;
      });
    }
  }

  // Convert SimpleTrack to Track
  Track _convertSimpleTrackToTrack(SimpleTrack simpleTrack) {
    return Track(
      id: simpleTrack.id,
      name: simpleTrack.name,
      artists: [Artist(name: simpleTrack.artist)],
      album: Album(
        name: simpleTrack.album,
        images: simpleTrack.albumArtUrl.isNotEmpty 
          ? [ImageData(url: simpleTrack.albumArtUrl, height: 300, width: 300)] 
          : [],
      ),
      uri: simpleTrack.uri,
      previewUrl: simpleTrack.previewUrl ?? '',
    );
  }
  
  // Load next page of tracks
  void _loadNextPage() {
    setState(() {
      _currentLibraryPage++;
    });
    _loadLibrary();
  }

  // Load previous page of tracks
  void _loadPreviousPage() {
    if (_currentLibraryPage > 1) {
      setState(() {
        _currentLibraryPage--;
      });
      _loadLibrary();
    }
  }

  // Remove a track from library
  Future<void> _removeTrack(Track track) async {
    try {
      await _spotifyService.removeTrack(track.id.toString());
      // Reload the current page to update the list
      _loadLibrary();
    } catch (e) {
      debugPrint('Error removing track: $e');
    }
  }

  // Play a track with the given URI
  Future<void> _playTrack(String trackUri) async {
    try {
      // First try to use the WebView player if it's ready
      if (SpotifyEvents.isPlayerReady) {
        // Use global web player directly for immediate UI response
        globalPlayTrack(trackUri);
        
        // Set state optimistically for better UI responsiveness
        setState(() {
          _isPlaybackPaused = false;
        });
      } else {
        // Fallback: Try to use the Spotify API directly
        debugPrint('WebView player not ready, trying API fallback...');
        
        // Try to play using any active device
        final success = await _spotifyService.playTrack(trackUri);
        
        if (success) {
          setState(() {
            _isPlaybackPaused = false;
          });
        } else {
          // Store as pending and trigger reconnection
          _pendingTrackUri = trackUri;
          debugPrint('Storing track URI as pending: $trackUri');
          
          // Try to force player reconnection
          final reconnected = forceSpotifyPlayerReconnection();
          if (reconnected) {
            debugPrint('Triggered player reconnection, will retry when ready');
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connecting to Spotify player...'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error playing track: $e');
      
      // Handle device not found errors specifically
      if (e.toString().contains('Device not found')) {
        _pendingTrackUri = trackUri;
        debugPrint('Device not found - storing track as pending and triggering reconnection');
        
        final reconnected = forceSpotifyPlayerReconnection();
        if (reconnected) {
          debugPrint('Triggered player reconnection due to device error');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reconnecting to Spotify...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Other errors
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error playing track: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // Save a track to library
  Future<void> _saveTrack(String trackId) async {
    if (trackId.isEmpty) {
      return;
    }

    // Store context state before async gap
    final scaffoldMessengerState = ScaffoldMessenger.of(context);
    final contextMounted = context.mounted;

    try {
      final success = await _spotifyService.saveTrack(trackId);

      if (success) {
        // Load library again to refresh saved tracks
        await _loadLibrary();

        if (contextMounted) {
          scaffoldMessengerState.showSnackBar(
            const SnackBar(
              content: Text('Track added to your library'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving track: $e');
      if (contextMounted) {
        scaffoldMessengerState.showSnackBar(
          SnackBar(
            content: Text('Failed to add track: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Save a track from the library section
  Future<void> _saveFromLibrary(Track track) async {
    if (track.id.isEmpty) return;
    await _saveTrack(track.id.toString());
  }

  // Save a database track to Spotify likes
  Future<void> _saveSpotifyTrack(Track track) async {
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to Spotify first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // For database tracks, we would need to search for them on Spotify first
      // since they don't have Spotify track IDs
      final searchResults = await _spotifyService.searchTracks(
        '${track.name} ${track.artists.first.name}',
        limit: 1,
      );
      
      if (searchResults.isNotEmpty) {
        final spotifyTrack = searchResults.first;
        await _saveTrack(spotifyTrack.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${track.name}" to your Spotify likes'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not find "${track.name}" on Spotify'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving track to Spotify: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add track to Spotify: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Handle track card play/pause
  Future<void> _handleTrackCardAction(MediaItem trackItem) async {
    // Get the track URI and ID directly
    String? trackUri;
    String? trackId;
    
    if (trackItem is Track) {
      trackUri = trackItem.uri;
      trackId = trackItem.id;
    } else {
      // Try to get URI and ID directly from MediaItem
      trackUri = trackItem.uri;
      trackId = trackItem.id;
    }
    
    if (trackUri == null || trackUri.isEmpty) {
      debugPrint('Cannot handle track action: No valid URI found');
      return;
    }
    
    // Check if this is the currently playing track
    final isCurrentlyPlaying = _nowPlayingTrack != null && 
      trackId != null && trackId == _nowPlayingTrack!.id;
    
    debugPrint('Track card action: isCurrentlyPlaying=$isCurrentlyPlaying, ID=$trackId');
    
    if (isCurrentlyPlaying) {
      // If this is the active track, just toggle play/pause without restarting
      await _togglePlayback();
    } else {
      // If not the active track, start playing it from the beginning
      await _playTrack(trackUri);
    }
  }

  // Toggle play/pause for the current track
  Future<void> _togglePlayback() async {
    try {
      if (_nowPlayingTrack == null) {
        debugPrint('Cannot toggle playback: No track is currently playing');
        return;
      }
      
      // Use the centralized player ready state from SpotifyEvents
      if (!SpotifyEvents.isPlayerReady) {
        debugPrint('Cannot toggle playback: Player not ready yet');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Waiting for Spotify player to be ready...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // Check current playback state before toggling
      debugPrint('Toggle playback: isPlaybackPaused=$_isPlaybackPaused');
      
      if (_isPlaybackPaused) {
        // Resume playback instead of restarting the track
        debugPrint('Resuming track: ${_nowPlayingTrack!.name}');
        globalResumePlayback();
        
        // Set state optimistically for UI responsiveness
        setState(() {
          _isPlaybackPaused = false;
        });
      } else {
        // Pause playback via web player directly for immediate UI response
        debugPrint('Pausing track: ${_nowPlayingTrack!.name}');
        globalPausePlayback();
        
        // Set state optimistically for UI responsiveness
        setState(() {
          _isPlaybackPaused = true;
        });
      }
    } catch (e) {
      debugPrint('Error toggling playback: $e');
    }
  }

  // Handle feedback for database suggestions
  Future<void> _handleDbSuggestionFeedback(String feedback) async {
    if (_currentDbSuggestion == null) return;

    try {
      switch (feedback) {
        case 'like':
          await _likeDbSuggestion();
          break;
        case 'dislike':
          await _dislikeDbSuggestion();
          break;
        case 'skip':
          await _skipDbSuggestion();
          break;
      }
    } catch (e) {
      debugPrint('Error handling DB suggestion feedback: $e');
    }
  }

  // Like a database suggestion (just sets liked status, doesn't add to library)
  Future<void> _likeDbSuggestion() async {
    if (_currentDbSuggestion == null) return;

    try {
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.liked,
      );

      setState(() {
        _hasLikedCurrentSuggestion = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Liked "${_currentDbSuggestion!.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Note: Liked items don't appear in library, only favorited items do
    } catch (e) {
      debugPrint('Error liking DB suggestion: $e');
    }
  }

  // Add to favorites and move to next suggestion
  Future<void> _addToFavorites() async {
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) return;

    setState(() {
      _isLoadingDbSuggestion = true;
    });

    try {
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.added,
      );

      setState(() {
        _hasFavoritedCurrentSuggestion = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to your favorites'),
          duration: const Duration(seconds: 2),
        ),
      );

      _loadDbLibrary();

      // Note: Favorite action keeps the suggestion active until user manually hits next
      debugPrint('🎵 _addToFavorites completed - keeping suggestion active');
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
    } finally {
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Remove from favorites
  Future<void> _removeFromFavorites() async {
    if (_currentDbSuggestion == null) return;

    try {
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.skipped,
      );

      setState(() {
        _hasFavoritedCurrentSuggestion = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${_currentDbSuggestion!.title}" from favorites'),
          duration: const Duration(seconds: 2),
        ),
      );

      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error removing from favorites: $e');
    }
  }

  // Dislike a database suggestion
  Future<void> _dislikeDbSuggestion() async {
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) return;

    setState(() {
      _isLoadingDbSuggestion = true;
    });

    try {
      // Check if ID is valid and remove from playlist if present
      if (_currentDbSuggestion!.id > 0) {
        final isInWatchlist = await _db.isInWatchlist(_currentDbSuggestion!.id);
        if (isInWatchlist) {
          await _db.removeFromWatchlist(_currentDbSuggestion!.id);
          // Refresh playlist since item was removed from there too
          _loadDbPlaylist();
        }
      }
      
      // Set status to disliked (this will remove from favorites if favorited)
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.disliked,
      );
      
      // Refresh library in case item was favorited
      _loadDbLibrary();

      // Get next suggestion (this will reset the like state) - non-blocking
      _moveToNextSuggestion();
      
      // Trigger new suggestion generation (non-blocking)
      _recommendationService.generateSuggestionOnDemand('music').then((loadingSuggestion) {
        if (loadingSuggestion != null) {
          debugPrint('🎵 New suggestion generation started after dislike');
        } else {
          debugPrint('🎵 No immediate suggestion available - background generation in progress');
          
          // Set 30-second timeout for background generation
          Timer(const Duration(seconds: 30), () {
            if (mounted && _isLoadingDbSuggestion && _currentDbSuggestion == null) {
              setState(() {
                _dbSuggestionError = 'Suggestion generation timed out. Please try again.';
                _isLoadingDbSuggestion = false;
              });
            }
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _dbSuggestionError = 'Error generating suggestion: $e';
            _isLoadingDbSuggestion = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Error disliking DB suggestion: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Skip a database suggestion (mark as skipped and move to next) - NON-BLOCKING
  Future<void> _skipDbSuggestion() async {
    final uiStopwatch = Stopwatch()..start();
    debugPrint('🔘 [${uiStopwatch.elapsedMilliseconds}ms] Skip button pressed');
    
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) return;

    // Immediately set loading state for responsive UI
    final setStateStart = uiStopwatch.elapsedMilliseconds;
    setState(() {
      _isLoadingDbSuggestion = true;
    });
    final setStateEnd = uiStopwatch.elapsedMilliseconds;
    debugPrint('🔘 [${uiStopwatch.elapsedMilliseconds}ms] setState completed in ${setStateEnd - setStateStart}ms');

    try {
      // Only mark as skipped if it hasn't been liked or favorited
      if (!_hasLikedCurrentSuggestion && !_hasFavoritedCurrentSuggestion) {
        debugPrint('🔘 [${uiStopwatch.elapsedMilliseconds}ms] Updating suggestion status...');
        // Non-blocking: Don't await the database update
        _recommendationService.updateSuggestionStatus(
          _currentDbSuggestion!.id,
          SuggestionStatus.skipped,
        );
      }

      // Clear current suggestion immediately (non-blocking)
      debugPrint('🔘 [${uiStopwatch.elapsedMilliseconds}ms] Moving to next suggestion...');
      _moveToNextSuggestion();
      
      // Trigger new suggestion generation (non-blocking)
      debugPrint('🔘 [${uiStopwatch.elapsedMilliseconds}ms] Starting suggestion generation...');
      _recommendationService.generateSuggestionOnDemand('music').then((loadingSuggestion) {
        debugPrint('🔘 [${uiStopwatch.elapsedMilliseconds}ms] Suggestion generation promise resolved');
        if (loadingSuggestion != null) {
          debugPrint('🎵 New suggestion generation started after skip');
        } else {
          // Don't treat null as error - background generation might be in progress
          // The event system will handle delivering the suggestion when ready
          debugPrint('🎵 No immediate suggestion available - background generation in progress');
          
          // Set 30-second timeout for background generation
          Timer(const Duration(seconds: 30), () {
            if (mounted && _isLoadingDbSuggestion && _currentDbSuggestion == null) {
              setState(() {
                _dbSuggestionError = 'Suggestion generation timed out. Please try again.';
                _isLoadingDbSuggestion = false;
              });
            }
          });
        }
      }).catchError((e) {
        debugPrint('🔘 [${uiStopwatch.elapsedMilliseconds}ms] Error in suggestion generation: $e');
        if (mounted) {
          setState(() {
            _dbSuggestionError = 'Error generating suggestion: $e';
            _isLoadingDbSuggestion = false;
          });
        }
      });
      
      debugPrint('🔘 [${uiStopwatch.elapsedMilliseconds}ms] Skip method completed - returning control to UI');
    } catch (e) {
      debugPrint('🔘 [${uiStopwatch.elapsedMilliseconds}ms] Error skipping DB suggestion: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Move to next suggestion (for both skip and next actions) - FULLY NON-BLOCKING
  void _moveToNextSuggestion() {
    try {
      final clearedSuggestionTitle = _currentDbSuggestion?.title ?? 'None';
      final clearedSuggestionId = _currentDbSuggestion?.id ?? 0;
      
      // Immediate UI update - clear current suggestion and show loading
      setState(() {
        _isLoadingDbSuggestion = true;
        _dbSuggestedTrack = null;
        _currentDbSuggestion = null;
        _dbSuggestionError = null;
        _hasLikedCurrentSuggestion = false; // Reset like state
        _hasFavoritedCurrentSuggestion = false; // Reset favorite state
      });
      
      // DON'T call _loadDbSuggestion() - let the skip handler trigger new generation
      // The event system will handle delivering the next suggestion
      debugPrint('🎵 Cleared current suggestion: "$clearedSuggestionTitle" (ID: $clearedSuggestionId) - waiting for events to deliver next one');
    } catch (e) {
      debugPrint('Error moving to next suggestion: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Add database suggestion to playlist and move to next
  Future<void> _addDbSuggestionToPlaylist() async {
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) return;

    final previousSuggestionTitle = _currentDbSuggestion!.title;
    final previousSuggestionId = _currentDbSuggestion!.id;
    debugPrint('🔘 Adding to playlist: "$previousSuggestionTitle" (ID: $previousSuggestionId)');

    setState(() {
      _isLoadingDbSuggestion = true;
    });

    try {
      // Add to watchlist table
      await _db.addToWatchlist(_currentDbSuggestion!.id);

      // Update suggestion status so it's no longer pending (won't appear in queue again)
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.watchlist, // Mark as watchlisted for future LLM learning
      );

      // Immediately update local state so button updates right away
      setState(() {
        _dbPlaylistSuggestions.add(_currentDbSuggestion!);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to ${_getWatchlistTerminology(isAction: true)}'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh playlist in background to ensure consistency
      _loadDbPlaylist();

      // Note: Add to playlist action keeps the suggestion active until user manually hits next
      debugPrint('🎵 _addDbSuggestionToPlaylist completed - keeping suggestion active');
    } catch (e) {
      debugPrint('Error adding DB suggestion to playlist: $e');
      // Revert local state on error
      setState(() {
        _dbPlaylistSuggestions.removeWhere((item) => item.id == _currentDbSuggestion!.id);
      });
    } finally {
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Build the main music section UI
  @override
  Widget build(BuildContext context) {
    debugPrint('🎵 build() method called - starting to build widget tree');
    
    final stackWidget = Stack(
      children: [
        // Main content using universal layout system
        MediaSectionLayout(
          headerHeight: 106.0,
          builder: (scrollOffset) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 100), // Add padding for playbar
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with consistent spacing
                  ComponentSpacing(
                    child: Center(
                      child: Opacity(
                        opacity: (scrollOffset <= 70) ? 1.0 : 0.0,
                        child: const Text(
                          'Suggested for You',
                          style: TextStyle(
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  
                  // Suggestion content with consistent spacing
                  ComponentSpacing(
                    child: _buildSuggestionContent(scrollOffset),
                  ),
                  
                  // Playlist section with proper spacing - only show if not empty or loading
                  if (_dbPlaylistSuggestions.isNotEmpty || _isLoadingDbPlaylist)
                    SectionSpacing(
                      child: _buildPlaylistSection(),
                    ),
                  
                  // Library section with proper spacing - only show if not empty or loading
                  if (_dbLikedSuggestions.isNotEmpty || _isLoadingDbLibrary)
                    SectionSpacing(
                      child: _buildDbLibrarySectionWrapper(),
                    ),
                  
                  // Spotify library section with proper spacing - only show if not empty or loading
                  if (_likedTracks.isNotEmpty || _isLoadingLibrary)
                    SectionSpacing(
                      child: _buildSpotifyLibrarySection(),
                    ),
                ],
              ),
            );
          },
        ),

      ],
    );
    
    debugPrint('🎵 build() method completed - returning widget tree');
    return stackWidget;
  }

  // Helper method to build suggestion content
  Widget _buildSuggestionContent(double scrollOffset) {
    if (_isLoadingDbSuggestion) {
      return const LoadingSuggestion(mediaType: 'music');
    } else if (_dbSuggestionError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Error: $_dbSuggestionError',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 100, // Fixed width matching music paging buttons
                child: OutlinedButton(
                  onPressed: _loadDbSuggestion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFA855F7),
                    side: const BorderSide(color: Color(0xFFA855F7)),
                  ),
                  child: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_dbSuggestedTrack == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No suggestions available',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      // Current suggestion container (matching movie section layout)
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album artwork
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8C86E2).withOpacity(0.7), // Reasoning color
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10), // Slightly smaller to account for border
                child: Container(
                  width: 300,
                  height: 450,
                  color: Colors.grey[900],
                  child: _currentDbSuggestion!.coverArtUrl != null
                    ? Image.network(
                        _currentDbSuggestion!.coverArtUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.music_note,
                              size: 48,
                              color: Colors.white54,
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Icon(
                          Icons.music_note,
                          size: 48,
                          color: Colors.white54,
                        ),
                      ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            
            // Track info
            Expanded(
              child: SizedBox(
                height: 450,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Track title
                    Text(
                      _currentDbSuggestion!.title ?? 'Unknown Track',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    // Artist info
                    Text(
                      'by ${TextUtils.formatArtistNames(_currentDbSuggestion!.artist)}',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    
                    // Flexible content area for description and reasoning
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            children: [
                              // Description text - flexible height
                              if (_currentDbSuggestion?.description?.isNotEmpty == true)
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: SingleChildScrollView(
                                      child: Text(
                                        _currentDbSuggestion!.description!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                          height: 1.5,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              
                              const SizedBox(height: 16),
                              
                              // Bot reasoning - flexible height
                              if (_currentDbSuggestion?.botReasoning?.isNotEmpty == true)
                                Flexible(
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              FontAwesomeIcons.robot,
                                              size: 16,
                                              color: const Color(0xFF8C86E2).withOpacity(0.7),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Reasoning',
                                              style: TextStyle(
                                                color: const Color(0xFF8C86E2).withOpacity(0.7),
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          height: 1,
                                          color: const Color(0xFF7B68EE).withOpacity(0.2),
                                        ),
                                        const SizedBox(height: 12),
                                        Flexible(
                                          child: SingleChildScrollView(
                                            child: Text(
                                              _currentDbSuggestion!.botReasoning!,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white.withOpacity(0.6),
                                                height: 1.5,
                                                fontWeight: FontWeight.w400,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    
                    // Action buttons using generic component
                    SuggestionActionButtons(
                      mediaType: 'music',
                      hasLikedCurrentSuggestion: _hasLikedCurrentSuggestion,
                      hasFavoritedCurrentSuggestion: _hasFavoritedCurrentSuggestion,
                      isInWatchlist: _currentDbSuggestion != null && 
                        _dbPlaylistSuggestions.any((item) => item.id == _currentDbSuggestion!.id),
                      isProcessing: _isLoadingDbSuggestion,
                      onLike: _likeDbSuggestion,
                      onDislike: _dislikeDbSuggestion,
                      onFavorite: _addToFavorites,
                      onUnfavorite: _removeFromFavorites,
                      onAddToWatchlist: _addDbSuggestionToPlaylist,
                      onSkip: _skipDbSuggestion,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  // Helper method to build playlist section
  Widget _buildPlaylistSection() {
    return Column(
      children: [
        const Center(
          child: Text(
            'Your Playlist',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ComponentSpacing(
          child: _isLoadingDbPlaylist
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFA855F7),
                ),
              )
            : _dbPlaylistSuggestions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No tracks in your playlist yet. Add suggestions to your playlist to see them here.',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildDbPlaylistSection(),
        ),
      ],
    );
  }

  // Helper method to build database library section
  Widget _buildDbLibrarySectionWrapper() {
    return Column(
      children: [
        const Center(
          child: Text(
            'Your Library',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ComponentSpacing(
          child: _isLoadingDbLibrary
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFA855F7),
                ),
              )
            : _dbLikedSuggestions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                                              'No tracks in your library yet. Favorite suggestions to see them here.',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildDbLibrarySection(),
        ),
      ],
    );
  }

  // Helper method to build Spotify library section
  Widget _buildSpotifyLibrarySection() {
    return Column(
      children: [
        const SizedBox(height: 32.0), // Add spacing before the title
        const Center(
          child: Text(
            'Your Spotify Liked Tracks',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 24.0), // Add more spacing between title and content
        ComponentSpacing(
          child: !_isAuthenticated
            ? _buildAuthPrompt()
            : _isLoadingLibrary
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFA855F7),
                  ),
                )
              : _buildLibrarySection(),
        ),
      ],
    );
  }

  // Build the library section with user's saved tracks
  Widget _buildLibrarySection() {
    return LibrarySection(
      savedTracks: _likedTracks,
      currentPage: _currentLibraryPage,
      totalTracks: _totalLibraryTracks,
      itemsPerPage: _tracksPerPage,
      nowPlayingTrack: _nowPlayingTrack,
      isPlaybackPaused: _isPlaybackPaused,
      onPlay: (track) async {
        // Convert Track to MediaItem before passing to _handleTrackCardAction
        final mediaItem = TrackAdapter.toMediaItem(track);
        await _handleTrackCardAction(mediaItem);
        return; // Explicit return for Future<void>
      },
      onSave: _saveFromLibrary,
      onRemove: _removeTrack,
      onNextPage: _loadNextPage,
      onPrevPage: _loadPreviousPage,
      showHeader: false, // Don't show the header in the LibrarySection component
    );
  }

  // Build login prompt for unauthenticated users
  Widget _buildAuthPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Connect to Spotify',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'To view and play music, connect your Spotify account.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              // Use the authenticate method from SpotifyService
              final success = await _spotifyService.authenticate(context);
              if (success) {
                setState(() {
                  _isAuthenticated = true;
                });
                _loadLibrary();
              }
            },
            child: const Text('Connect Spotify'),
          ),
        ],
      ),
    );
  }

  // Load a suggestion from the database
  Future<void> _loadDbSuggestion() async {
    setState(() {
      _isLoadingDbSuggestion = true;
      _dbSuggestionError = null;
      _hasLikedCurrentSuggestion = false; // Reset like state
      _hasFavoritedCurrentSuggestion = false; // Reset favorite state
    });

    // Give the UI a chance to update and show the loading state
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      // First check if the music database is available
      final databaseStatus = await _recommendationService.getMediaTypeStatus('music');
      final isDatabaseAvailable = databaseStatus == 'available';
      
      if (!isDatabaseAvailable) {
        setState(() {
          _dbSuggestedTrack = null;
          _currentDbSuggestion = null;
          _dbSuggestionError = null; // No error, just database not installed
          _isLoadingDbSuggestion = false;
        });
        return;
      }
      
      // Get pending music suggestions that are NOT in watchlist
      final suggestions = await _db.getPendingSuggestionsNotInWatchlist('music');
      
      if (suggestions.isNotEmpty) {
        final suggestion = suggestions.first;
        
        // Convert MediaSuggestion to Track for compatibility
        final track = Track(
          id: suggestion.id.toString(),
          name: suggestion.title ?? 'Unknown',
          artists: [Artist(name: suggestion.artist ?? 'Unknown Artist')],
          album: Album(
            name: suggestion.album ?? 'Unknown Album',
            images: suggestion.coverArtUrl?.isNotEmpty == true 
              ? [ImageData(url: suggestion.coverArtUrl!, height: 300, width: 300)] 
              : [],
          ),
          uri: '', // No Spotify URI for database suggestions
          previewUrl: '',
        );
        
        setState(() {
          _dbSuggestedTrack = track;
          _currentDbSuggestion = suggestion;
          _isLoadingDbSuggestion = false;
        });
      } else {
        // Try to generate a new suggestion on-demand (non-blocking)
        final loadingSuggestion = await _recommendationService.generateSuggestionOnDemand('music');
        
        if (loadingSuggestion != null) {
          debugPrint('🎵 Music suggestion generation started in background');
          // Set loading state immediately - actual suggestion will come via events
          setState(() {
            _dbSuggestedTrack = null; // Clear current track
            _currentDbSuggestion = null; // Clear current suggestion
            _isLoadingDbSuggestion = true; // Keep loading until real suggestion arrives via events
            _dbSuggestionError = null;
            _hasLikedCurrentSuggestion = false;
            _hasFavoritedCurrentSuggestion = false;
          });
        } else {
          // Don't treat null as error - background generation might be in progress
          // Keep loading state and let the event system deliver the suggestion when ready
          debugPrint('🎵 No immediate suggestion available - background generation in progress');
          setState(() {
            _dbSuggestedTrack = null;
            _currentDbSuggestion = null;
            _isLoadingDbSuggestion = true; // Keep loading state
            _dbSuggestionError = null; // Clear any previous errors
            _hasLikedCurrentSuggestion = false;
            _hasFavoritedCurrentSuggestion = false;
          });
          
          // Set 30-second timeout for background generation
          Timer(const Duration(seconds: 30), () {
            if (mounted && _isLoadingDbSuggestion && _currentDbSuggestion == null) {
              setState(() {
                _dbSuggestionError = 'Suggestion generation timed out. Please try again.';
                _isLoadingDbSuggestion = false;
              });
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _dbSuggestedTrack = null;
        _currentDbSuggestion = null;
        _dbSuggestionError = 'Failed to get suggestion: $e';
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Helper method to update UI with real suggestion (optimized for performance)
  void _updateWithRealSuggestion(MediaSuggestion realSuggestion) {
    final eventStopwatch = Stopwatch()..start();
    debugPrint('🎵 [${eventStopwatch.elapsedMilliseconds}ms] _updateWithRealSuggestion called for: ${realSuggestion.title} (ID: ${realSuggestion.id})');
    
    // Use Future.delayed to ensure this runs in next event loop iteration
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      
      debugPrint('🎵 [${eventStopwatch.elapsedMilliseconds}ms] Future.delayed callback executing');
      
      // Convert MediaSuggestion to Track for compatibility
      final conversionStart = eventStopwatch.elapsedMilliseconds;
      final track = Track(
        id: realSuggestion.id.toString(),
        name: realSuggestion.title ?? 'Unknown',
        artists: [Artist(name: realSuggestion.artist ?? 'Unknown Artist')],
        album: Album(
          name: realSuggestion.album ?? 'Unknown Album',
          images: realSuggestion.coverArtUrl?.isNotEmpty == true 
            ? [ImageData(url: realSuggestion.coverArtUrl!, height: 300, width: 300)] 
            : [],
        ),
        uri: '', // No Spotify URI for database suggestions
        previewUrl: '',
      );
      final conversionEnd = eventStopwatch.elapsedMilliseconds;
      debugPrint('🎵 [${eventStopwatch.elapsedMilliseconds}ms] Track conversion took ${conversionEnd - conversionStart}ms');
      
      debugPrint('🎵 [${eventStopwatch.elapsedMilliseconds}ms] Starting setState for suggestion update');
      final setStateStart = eventStopwatch.elapsedMilliseconds;
      
      // Single setState - let's see if this is what's blocking
      setState(() {
        _dbSuggestedTrack = track;
        _currentDbSuggestion = realSuggestion;
        _isLoadingDbSuggestion = false;
        _dbSuggestionError = null; // Clear any previous errors
        _hasLikedCurrentSuggestion = false;
        _hasFavoritedCurrentSuggestion = false;
      });
      
      final setStateEnd = eventStopwatch.elapsedMilliseconds;
      debugPrint('🎵 [${eventStopwatch.elapsedMilliseconds}ms] setState completed in ${setStateEnd - setStateStart}ms');
      
      // Add a post-frame callback to see when the UI actually finishes rebuilding
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('🎵 [${eventStopwatch.elapsedMilliseconds}ms] UI rebuild completed - TOTAL EVENT TIME: ${eventStopwatch.elapsedMilliseconds}ms');
      });
    });
  }

  // Load favorited suggestions from database (only added/favorited items)
  Future<void> _loadDbLibrary() async {
    setState(() {
      _isLoadingDbLibrary = true;
    });

    try {
      // Get all favorites (both recommendation-based and user-added)
      final allFavorites = await _db.getAllFavorites('music');
      
      setState(() {
        _dbLikedSuggestions = allFavorites;
        _isLoadingDbLibrary = false;
      });
    } catch (e) {
      debugPrint('Error loading DB library: $e');
      setState(() {
        _isLoadingDbLibrary = false;
      });
    }
  }

  // Load watchlist suggestions from database
  Future<void> _loadDbPlaylist() async {
    setState(() {
      _isLoadingDbPlaylist = true;
    });

    try {
      // Use the proper watchlist query instead of status-based filtering
      final playlistSuggestions = await _db.getWatchlist('music');
      
      setState(() {
        _dbPlaylistSuggestions = playlistSuggestions;
        _isLoadingDbPlaylist = false;
      });
      
      debugPrint('Loaded ${playlistSuggestions.length} items in playlist');
    } catch (e) {
      debugPrint('Error loading DB playlist: $e');
      setState(() {
        _isLoadingDbPlaylist = false;
      });
    }
  }

  // Build DB playlist section with reusable component
  Widget _buildDbPlaylistSection() {
    return MediaLibraryGrid(
      suggestions: _dbPlaylistSuggestions,
      mediaType: 'music',
      isWatchlist: true,
      onRemove: _removeFromWatchlist,
      onLike: _likeWatchlistItem,
      onDislike: _dislikeWatchlistItem,
      onFavorite: _favoriteWatchlistItem,
    );
  }

  // Build DB library section with reusable component
  Widget _buildDbLibrarySection() {
    return MediaLibraryGrid(
      suggestions: _dbLikedSuggestions,
      mediaType: 'music',
      isWatchlist: false,
      onAddToWatchlist: _addLibraryItemToPlaylist,
      onUnfavorite: _removeFromLibrary,
      watchlistItems: _dbPlaylistSuggestions,
    );
  }

  // Unfavorite a suggestion (remove from library)
  Future<void> _unfavoriteSuggestion(MediaSuggestion suggestion) async {
    try {
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.skipped,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${suggestion.title}" from your library'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Refresh both library and main suggestions (since this item is now back to pending)
      _loadDbLibrary();
      _loadDbSuggestion(); // This might show the unfavorited item again as a suggestion
    } catch (e) {
      debugPrint('Error unfavoriting suggestion: $e');
    }
  }

  // Add to watchlist (now with real implementation)
  Future<void> _addToWatchlist(MediaSuggestion suggestion) async {
    try {
      await _db.addToWatchlist(suggestion.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${suggestion.title}" to ${_getWatchlistTerminology(isAction: true)}'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Refresh both library and playlist sections
      _loadDbLibrary(); // This will update the watchlist icon state
      _loadDbPlaylist();
    } catch (e) {
      debugPrint('Error adding to playlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to ${_getWatchlistTerminology(isAction: true)}: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Remove from watchlist
  Future<void> _removeFromWatchlist(MediaSuggestion suggestion) async {
    try {
      await _db.removeFromWatchlist(suggestion.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${suggestion.title}" from ${_getWatchlistTerminology(isAction: true)}'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Refresh both playlist and library sections
      _loadDbPlaylist();
      _loadDbLibrary(); // This will update the watchlist icon state
    } catch (e) {
      debugPrint('Error removing from ${_getWatchlistTerminology(isAction: true)}: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove from ${_getWatchlistTerminology(isAction: true)}: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Dislike a watchlist item (removes from both playlist and favorites if applicable)
  Future<void> _dislikeWatchlistItem(MediaSuggestion suggestion) async {
    try {
      // First, remove from watchlist table
      await _db.removeFromWatchlist(suggestion.id);
      
      // Then, if the item is liked/added (in favorites), set status to disliked
      // This will remove it from both playlist and library sections
      if (suggestion.status == SuggestionStatus.liked || 
          suggestion.status == SuggestionStatus.added) {
        await _recommendationService.updateSuggestionStatus(
          suggestion.id,
          SuggestionStatus.disliked,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disliked "${suggestion.title}" - removed from ${_getWatchlistTerminology(isAction: true)} and library'),
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Refresh both sections since item was removed from both
        _loadDbPlaylist();
        _loadDbLibrary();
      } else {
        // Item was only in playlist, just set to disliked
        await _recommendationService.updateSuggestionStatus(
          suggestion.id,
          SuggestionStatus.disliked,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disliked "${suggestion.title}" - removed from ${_getWatchlistTerminology(isAction: true)}'),
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Only refresh playlist section
        _loadDbPlaylist();
      }
    } catch (e) {
      debugPrint('Error disliking watchlist item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to dislike item: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Like a watchlist item (removes from watchlist and sets status to "liked")
  Future<void> _likeWatchlistItem(MediaSuggestion suggestion) async {
    try {
      // Remove from watchlist table
      await _db.removeFromWatchlist(suggestion.id);
      
      // Only change status if not already favorited (added)
      if (suggestion.status != SuggestionStatus.added) {
        await _recommendationService.updateSuggestionStatus(
          suggestion.id,
          SuggestionStatus.liked,
        );
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Liked "${suggestion.title}" - removed from ${_getWatchlistTerminology(isAction: true)}'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Refresh both sections
      _loadDbPlaylist();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error liking watchlist item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to like item: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Favorite a watchlist item (removes from watchlist and sets status to "added")
  Future<void> _favoriteWatchlistItem(MediaSuggestion suggestion) async {
    try {
      // Use the new method that handles both recommendation-based and user-added items
      await _db.moveFromWatchlistToFavorites(suggestion.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Favorited "${suggestion.title}" - moved to library'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Refresh both sections
      _loadDbPlaylist();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error favoriting watchlist item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to favorite item: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Add library item to playlist
  Future<void> _addLibraryItemToPlaylist(MediaSuggestion suggestion) async {
    try {
      await _db.addToWatchlist(suggestion.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${suggestion.title}" to ${_getWatchlistTerminology(isAction: true)}'),
          duration: const Duration(seconds: 2),
        ),
      );

      _loadDbPlaylist();
    } catch (e) {
      debugPrint('Error adding library item to ${_getWatchlistTerminology(isAction: true)}: $e');
    }
  }

  // Remove from library
  Future<void> _removeFromLibrary(MediaSuggestion suggestion) async {
    try {
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.skipped,
      );

      // If the removed item is the currently displayed suggestion, update the state
      if (_currentDbSuggestion != null && _currentDbSuggestion!.id == suggestion.id) {
        setState(() {
          _hasFavoritedCurrentSuggestion = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${suggestion.title}" from library'),
          duration: const Duration(seconds: 2),
        ),
      );

      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error removing from library: $e');
    }
  }

  // Helper method to get media-specific terminology
  String _getWatchlistTerminology({bool isAction = false}) {
    // For music, we use "playlist"
    // For other media types, this would be different:
    // - Books: "reading list" or "read list"  
    // - Movies/TV: "watchlist"
    // - Video Games: "playlist"
    
    if (isAction) {
      return 'playlist'; // "Add to playlist", "Remove from playlist"
    } else {
      return 'playlist'; // "Your Playlist"
    }
  }

  String _getWatchlistSectionTitle() {
    return 'Your ${_getWatchlistTerminology().split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')}';
  }
}

// Custom painter for X button (similar to React MediaItemWrapper)
class XButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    
    // Purple outline
    paint.color = const Color(0xFF6a1b9a);
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.8),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.2),
      paint,
    );
    
    // White inner X
    paint.color = Colors.white;
    paint.strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.8),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.2),
      paint,
    );
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

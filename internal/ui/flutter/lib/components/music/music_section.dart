import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import '../common/scroll_content_wrapper.dart';
import '../common/media_grid.dart';
import '../../models.dart';
import '../../services/recommendation_service.dart';
import '../../services/sqlite_db.dart';
import 'library/library_section.dart';
import 'tracks/track_card.dart';
import 'player/spotify_player_view.dart';
import 'player/spotify_web_player.dart';
import 'spotify_service.dart';
import 'suggestions/suggestion_display.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  final GlobalKey<SpotifyWebPlayerState> _webPlayerKey = GlobalKey();
  String? _activeDeviceId;
  String? _pendingTrackUri;
  bool _isPlayerReady = false;

  // Database suggestion state
  MediaSuggestion? _currentDbSuggestion;
  Track? _dbSuggestedTrack;
  String? _dbSuggestionError;
  bool _isLoadingDbSuggestion = false;

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
  final SQLiteDatabase _db = SQLiteDatabase();

  StreamSubscription? _authSubscription;
  StreamSubscription? _deviceIdSubscription;
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _trackChangeSubscription;
  StreamSubscription? _spotifyEventsTrackSubscription;
  StreamSubscription? _spotifyEventsPlaybackSubscription;
  StreamSubscription? _playerReadySubscription;

  @override
  void initState() {
    super.initState();
    
    _setupListeners();
    _checkAuthentication();
    
    // Load initial DB suggestion
    _loadDbSuggestion();
    // Load DB library and playlist
    _loadDbLibrary();
    _loadDbPlaylist();
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
        _playTrack(_pendingTrackUri!);
        _pendingTrackUri = null;
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
        // Use web player directly for immediate UI response
        _webPlayerKey.currentState?.playTrack(trackUri);
        
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
          // Store as pending
        _pendingTrackUri = trackUri;
        debugPrint('Storing track URI as pending: $trackUri');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No Spotify devices available. Please open Spotify on any device.'),
                duration: Duration(seconds: 3),
            ),
          );
          }
        }
      }
    } catch (e) {
      debugPrint('Error playing track: $e');
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
        _webPlayerKey.currentState?.resumePlayback();
        
        // Set state optimistically for UI responsiveness
        setState(() {
          _isPlaybackPaused = false;
        });
      } else {
        // Pause playback via web player directly for immediate UI response
        debugPrint('Pausing track: ${_nowPlayingTrack!.name}');
        _webPlayerKey.currentState?.pausePlayback();
        
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

  // Like a database suggestion (add to library)
  Future<void> _likeDbSuggestion() async {
    if (_currentDbSuggestion == null) return;

    try {
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.liked,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to your library'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Reload library and get next suggestion
      _loadDbLibrary();
      _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error liking DB suggestion: $e');
    }
  }

  // Dislike a database suggestion
  Future<void> _dislikeDbSuggestion() async {
    if (_currentDbSuggestion == null) return;

    try {
      // First, check if item is in watchlist and remove it
      final isInWatchlist = await _db.isInWatchlist(_currentDbSuggestion!.id);
      if (isInWatchlist) {
        await _db.removeFromWatchlist(_currentDbSuggestion!.id);
        // Refresh playlist since item was removed from there too
        _loadDbPlaylist();
      }
      
      // Then set status to disliked
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.disliked,
      );

      // Get next suggestion
      _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error disliking DB suggestion: $e');
    }
  }

  // Skip a database suggestion
  Future<void> _skipDbSuggestion() async {
    if (_currentDbSuggestion == null) return;

    try {
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.skipped,
      );

      // Get next suggestion
      _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error skipping DB suggestion: $e');
    }
  }

  // Add database suggestion to playlist
  Future<void> _addDbSuggestionToPlaylist() async {
    if (_currentDbSuggestion == null) return;

    try {
      // Add to watchlist table instead of changing status
      await _db.addToWatchlist(_currentDbSuggestion!.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to ${_getWatchlistTerminology(isAction: true)}'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh both playlist and main suggestions
      _loadDbPlaylist();
      _loadDbSuggestion(); // This will get the next suggestion
    } catch (e) {
      debugPrint('Error adding DB suggestion to playlist: $e');
    }
  }

  // Build the main music section UI
  @override
  Widget build(BuildContext context) {
    const double headerHeight = 145;
    return Stack(
      children: [
        // Main content (text, lists, errors) now all inside ScrollContentWrapper
        ScrollContentWrapper(
          headerHeight: 106.0,
          builder: (scrollOffset) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 100), // Add padding for playbar
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 1,
                  height: 1,
                  child: SpotifyWebPlayer(
                    key: _webPlayerKey,
                    spotifyService: _spotifyService,
                    visible: false,
                  ),
                ),
                const SizedBox(height: 12),
                  // Database suggestion section
                Center(
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
                const SizedBox(height: 12),
                  if (_isLoadingDbSuggestion)
                  const SizedBox.shrink()
                  else if (_dbSuggestionError != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                          'Error: $_dbSuggestionError',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                  else if (_dbSuggestedTrack == null)
                  const Center(
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
                  )
                else
                    // Current suggestion container (only shows when there's a suggestion)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF282828), // Surface color from React (--surface-color)
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Album art (takes full height)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 300,
                                  height: 450, // Match movie poster height
                                  color: Colors.grey[900],
                                  child: _dbSuggestedTrack!.album.images.isNotEmpty
                                    ? Image.network(
                                        _dbSuggestedTrack!.album.images.first.url,
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
                              const SizedBox(width: 24),
                              
                              // Track info (centered alignment)
                              Expanded(
                                child: SizedBox(
                                  height: 450, // Match the album art height
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center, // Center everything
                                    children: [
                                      // Track title
                                      Text(
                                        _dbSuggestedTrack!.name,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      // Artist and Album info
                                      Text(
                                        '${_dbSuggestedTrack!.artists.first.name} • ${_dbSuggestedTrack!.album.name}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.white.withOpacity(0.7),
                                          fontWeight: FontWeight.w400,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Description text (same color as title)
                                      if (_currentDbSuggestion?.description?.isNotEmpty == true)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: Text(
                                            _currentDbSuggestion!.description!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white, // Same as title
                                              height: 1.5,
                                              fontWeight: FontWeight.w400,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      
                                      // Use Expanded to push reasoning to bottom
                                      Expanded(child: Container()),
                                      
                                      // Bot reasoning (no background, clean styling)
                                      if (_currentDbSuggestion?.botReasoning?.isNotEmpty == true)
                                        Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(bottom: 24),
                                          child: Column(
                                            children: [
                                              // Reasoning header with Font Awesome robot icon
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    FontAwesomeIcons.robot, // Clean robot icon from Font Awesome
                                                    size: 16,
                                                    color: const Color(0xFF8C86E2).withOpacity(0.7), // rgba(140, 134, 258, 0.7)
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
                                              
                                              // Divider line
                                              Container(
                                                height: 1,
                                                color: const Color(0xFF7B68EE).withOpacity(0.2), // Primary color with opacity
                                              ),
                                              const SizedBox(height: 12),
                                              
                                              // Reasoning text
                                              Text(
                                                _currentDbSuggestion!.botReasoning!,
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.6), // More gray
                                                  fontSize: 14,
                                                  height: 1.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              
                                              // Action buttons (moved inside container)
                                              const SizedBox(height: 24),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 24), // Center between image and container edge
                                                child: Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  alignment: WrapAlignment.center,
                                                  children: [
                                                    // Like button (black background)
                                                    ElevatedButton.icon(
                                                      onPressed: _likeDbSuggestion,
                                                      icon: const Icon(Icons.thumb_up, size: 16),
                                                      label: const Text('Like', style: TextStyle(fontSize: 13)),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.black.withOpacity(0.7),
                                                        foregroundColor: Colors.white,
                                                        elevation: 0,
                                                        side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(25),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                        minimumSize: const Size(0, 44),
                                                      ),
                                                    ),
                                                    
                                                    // Dislike button (black background)
                                                    ElevatedButton.icon(
                                                      onPressed: _dislikeDbSuggestion,
                                                      icon: const Icon(Icons.thumb_down, size: 16),
                                                      label: const Text('Dislike', style: TextStyle(fontSize: 13)),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.black.withOpacity(0.7),
                                                        foregroundColor: Colors.white,
                                                        elevation: 0,
                                                        side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(25),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                        minimumSize: const Size(0, 44),
                                                      ),
                                                    ),
                                                    
                                                    // Favorite button (gray background)
                                                    ElevatedButton.icon(
                                                      onPressed: _likeDbSuggestion, // TODO: Create separate favorite function
                                                      icon: const Icon(Icons.favorite, size: 16),
                                                      label: const Text('Favorite', style: TextStyle(fontSize: 13)),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.white.withOpacity(0.15),
                                                        foregroundColor: Colors.white,
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(25),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                        minimumSize: const Size(0, 44),
                                                      ),
                                                    ),
                                                    
                                                    // Playlist button - dynamic state based on whether current suggestion is in playlist
                                                    Builder(
                                                      builder: (context) {
                                                        final inPlaylist = _currentDbSuggestion != null && 
                                                          _dbPlaylistSuggestions.any((item) => item.id == _currentDbSuggestion!.id);
                                                        
                                                        return ElevatedButton.icon(
                                                          onPressed: inPlaylist 
                                                            ? () => _currentDbSuggestion != null ? _removeFromWatchlist(_currentDbSuggestion!) : null
                                                            : _addDbSuggestionToPlaylist,
                                                          icon: Icon(
                                                            inPlaylist ? Icons.playlist_add_check : Icons.playlist_add, 
                                                            size: 16
                                                          ),
                                                          label: Text(
                                                            inPlaylist ? 'In Playlist' : 'Playlist', 
                                                            style: const TextStyle(fontSize: 13)
                                                          ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: inPlaylist 
                                                              ? Colors.blue.withOpacity(0.3)
                                                              : Colors.white.withOpacity(0.15),
                                                            foregroundColor: inPlaylist ? Colors.blue : Colors.white,
                                                            elevation: 0,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(25),
                                                            ),
                                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                            minimumSize: const Size(0, 44),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    
                                                    // Skip button with legacy skip icon
                                                    ElevatedButton.icon(
                                                      onPressed: _skipDbSuggestion,
                                                      icon: const Icon(Icons.skip_next, size: 16),
                                                      label: const Text('Skip', style: TextStyle(fontSize: 13)),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.white.withOpacity(0.15),
                                                        foregroundColor: Colors.white,
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(25),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                        minimumSize: const Size(0, 44),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                
                // Library sections (always show regardless of suggestion availability)
                const SizedBox(height: 32),
                
                // Your Playlist section
                Center(
                  child: Text(
                    _getWatchlistSectionTitle(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoadingDbPlaylist)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFA855F7),
                    ),
                  )
                else if (_dbPlaylistSuggestions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No tracks in your ${_getWatchlistTerminology()} yet. Add suggestions to your ${_getWatchlistTerminology()} to see them here.',
                        style: const TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  _buildDbPlaylistSection(),
                
                // Your Library section (for liked DB suggestions)
                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    'Your Library',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoadingDbLibrary)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFA855F7),
                    ),
                  )
                else if (_dbLikedSuggestions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No tracks in your library yet. Like or add suggestions to see them here.',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  _buildDbLibrarySection(),
                
                // Your Spotify Liked Tracks section (existing library)
                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    'Your Spotify Liked Tracks',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!_isAuthenticated)
                  _buildAuthPrompt()
                else if (_isLoadingLibrary)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFA855F7),
                    ),
                  )
                else
                  _buildLibrarySection(),
                ],
              ),
            );
          },
        ),
        // Player positioned at the bottom (unchanged)
        Builder(builder: (context) {
          if (_isAuthenticated && _nowPlayingTrack != null) {
            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).canvasColor.withOpacity(0.7),
                    ),
                    child: const SpotifyPlayer(
                      key: ValueKey('spotify_player'),
                    ),
                  ),
                ),
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
        }),
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
          ElevatedButton(
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
            child: const Text('Connect to Spotify'),
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
    });

    try {
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
        setState(() {
          _dbSuggestedTrack = null;
          _currentDbSuggestion = null;
          _dbSuggestionError = 'No suggestions available';
          _isLoadingDbSuggestion = false;
        });
      }
    } catch (e) {
      setState(() {
        _dbSuggestedTrack = null;
        _currentDbSuggestion = null;
        _dbSuggestionError = 'Failed to get suggestion';
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Load liked suggestions from database
  Future<void> _loadDbLibrary() async {
    setState(() {
      _isLoadingDbLibrary = true;
    });

    try {
      // Get both liked and added suggestions for the library
      final likedSuggestions = await _recommendationService.getSuggestions(
        'music',
        status: SuggestionStatus.liked,
      );
      
      final addedSuggestions = await _recommendationService.getSuggestions(
        'music',
        status: SuggestionStatus.added,
      );
      
      // Combine both lists
      final allLibrarySuggestions = [...likedSuggestions, ...addedSuggestions];
      
      setState(() {
        _dbLikedSuggestions = allLibrarySuggestions;
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

  // Build DB playlist section with custom cards
  Widget _buildDbPlaylistSection() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2, // Shorter cards - was 0.6, now 1.2 (half the height)
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _dbPlaylistSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _dbPlaylistSuggestions[index];
        return _buildLibraryCard(suggestion, isWatchlist: true);
      },
    );
  }

  // Build DB library section with custom cards
  Widget _buildDbLibrarySection() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2, // Shorter cards - was 0.6, now 1.2 (half the height)
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _dbLikedSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _dbLikedSuggestions[index];
        return _buildLibraryCard(suggestion, isWatchlist: false);
      },
    );
  }

  // Build individual library card
  Widget _buildLibraryCard(MediaSuggestion suggestion, {bool isWatchlist = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF7B68EE).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Full image background
            Positioned.fill(
              child: suggestion.coverArtUrl?.isNotEmpty == true
                ? Image.network(
                    suggestion.coverArtUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF7B68EE).withOpacity(0.1),
                        child: const Center(
                          child: Icon(
                            Icons.music_note,
                            size: 60,
                            color: Colors.white54,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    color: const Color(0xFF7B68EE).withOpacity(0.1),
                    child: const Center(
                      child: Icon(
                        Icons.music_note,
                        size: 60,
                        color: Colors.white54,
                      ),
                    ),
                  ),
            ),
            
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x40000000), // rgba(0,0,0,0.25) at 70%
                      Color(0x66000000), // rgba(0,0,0,0.4) at 85%
                      Color(0x99000000), // rgba(0,0,0,0.6) at 95%
                      Colors.black,      // rgba(0,0,0,1) at 100%
                    ],
                    stops: [0.0, 0.70, 0.85, 0.95, 1.0],
                  ),
                ),
              ),
            ),
            
            // Remove button for watchlist/saved views (top-right)
            if (isWatchlist)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _removeFromWatchlist(suggestion),
                  child: Container(
                    width: 24,
                    height: 24,
                    child: CustomPaint(
                      painter: XButtonPainter(),
                    ),
                  ),
                ),
              ),
            
            // Content overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      suggestion.title ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Year and rating info
                    if (suggestion.createdAt != null)
                      Text(
                        suggestion.createdAt!.year.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Action buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left side - metadata
                        if (suggestion.artist?.isNotEmpty == true)
                          Flexible(
                            child: Text(
                              suggestion.artist!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        
                        // Right side - action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isWatchlist) ...[
                              // Add to playlist button (playlist icon) - blue with checkmark if in watchlist, white if not
                              Builder(
                                builder: (context) {
                                  // Check if this suggestion is already in our loaded playlist
                                  final inWatchlist = _dbPlaylistSuggestions.any((item) => item.id == suggestion.id);
                                  return IconButton(
                                    onPressed: () => inWatchlist 
                                      ? _removeFromWatchlist(suggestion)
                                      : _addToWatchlist(suggestion),
                                    icon: Icon(
                                      inWatchlist ? Icons.playlist_add_check : Icons.playlist_add,
                                      color: inWatchlist ? Colors.blue : Colors.white,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  );
                                },
                              ),
                            ] else ...[
                              // Like button for watchlist items (removes from watchlist only)
                              IconButton(
                                onPressed: () => _likeWatchlistItem(suggestion),
                                icon: const Icon(
                                  Icons.thumb_up,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                              
                              // Dislike button for watchlist items
                              IconButton(
                                onPressed: () => _dislikeWatchlistItem(suggestion),
                                icon: const Icon(
                                  Icons.thumb_down,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ],
                            
                            // Purple heart to unfavorite/remove from library
                            IconButton(
                              onPressed: () => isWatchlist 
                                ? _favoriteWatchlistItem(suggestion)
                                : _unfavoriteSuggestion(suggestion),
                              icon: const Icon(
                                Icons.favorite,
                                color: Color(0xFF7B68EE), // Primary purple color
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Unfavorite a suggestion (remove from library)
  Future<void> _unfavoriteSuggestion(MediaSuggestion suggestion) async {
    try {
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.pending,
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
      
      // Set status to "liked" so it gets added to library
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.liked,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Liked "${suggestion.title}" - removed from ${_getWatchlistTerminology(isAction: true)} and added to library'),
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
      // Remove from watchlist table
      await _db.removeFromWatchlist(suggestion.id);
      
      // Set status to "added" so it stays in library
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.added,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Favorited "${suggestion.title}" - removed from ${_getWatchlistTerminology(isAction: true)} and added to library'),
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

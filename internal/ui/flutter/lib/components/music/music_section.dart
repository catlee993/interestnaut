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

  // Suggestion state (for Spotify suggestions)
  Track? _suggestion;
  String? _suggestionError;
  bool _isLoadingSuggestion = false;

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
    
    // Reset suggestion state on init to avoid any loading indicators
    _resetSuggestionState();
    
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
        _loadSuggestion(); // Ensure we load a suggestion on authentication
        
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
      _loadSuggestion(); // Ensure we load a suggestion on authentication
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

  // Load a suggestion based on library
  Future<void> _loadSuggestion() async {
    setState(() {
      _isLoadingSuggestion = false; // Prevent loading indicator from showing
      _suggestionError = null;
    });
    try {
      final recommendations = await _spotifyService.getRecommendations();
      
      if (recommendations.isNotEmpty) {
        final simpleTrack = recommendations.first;
        final track = _convertSimpleTrackToTrack(simpleTrack);
        
        setState(() {
          _suggestion = track;
        });
      } else {
        setState(() {
          _suggestion = null;
          _suggestionError = 'No suggestions available';
        });
      }
    } catch (e) {
      setState(() {
        _suggestion = null;
        _suggestionError = e.toString();
      });
    }
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

  // Reset all state variables related to suggestions
  void _resetSuggestionState() {
    setState(() {
      _isLoadingSuggestion = false;
      _suggestionError = null;
      _suggestion = null;
    });
  }

  // Provide feedback for a suggestion
  Future<void> _provideFeedback(String feedback) async {
    if (_suggestion == null) return;

    try {
      // Extract info from the suggestion
      final String title = _suggestion!.name;
      final String artist = _suggestion!.artists.first.name;

      // Show feedback message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$feedback: $title by $artist'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Load a new suggestion
      _loadSuggestion();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error providing feedback: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
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
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.watchlist,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to your playlist'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Reload playlist and get next suggestion
      _loadDbPlaylist();
      _loadDbSuggestion();
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
        // Album art background (scrolls under header)
        Positioned.fill(
          child: _suggestion != null && _suggestion!.album.images.isNotEmpty
              ? Image.network(
                  _suggestion!.album.images.first.url,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                )
              : Container(color: Colors.transparent),
        ),
        // Main content (text, lists, errors) now all inside ScrollContentWrapper
        ScrollContentWrapper(
          headerHeight: 106.0,
          builder: (scrollOffset) {
            return Column(
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
                  Column(
                    children: [
                      SuggestionDisplay(
                        suggestedTrack: TrackAdapter.toMediaItem(_dbSuggestedTrack!),
                        onRequestSuggestion: _loadDbSuggestion,
                        onSkipSuggestion: _skipDbSuggestion,
                        onSuggestionFeedback: _handleDbSuggestionFeedback,
                        onAddToLibrary: _likeDbSuggestion,
                        onPlay: (mediaItem) => {}, // DB suggestions can't be played through Spotify
                        isPlaybackPaused: true,
                        nowPlayingTrack: null,
                        onPlayPause: () => {},
                        isPlayerReady: false,
                      ),
                      const SizedBox(height: 16),
                      // Add to Playlist button
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _addDbSuggestionToPlaylist,
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('Add to Playlist'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFA855F7),
                            side: const BorderSide(color: Color(0xFFA855F7)),
                          ),
                        ),
                      ),
                    ],
                  ),
                
                // Your Playlist section
                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    'Your Playlist',
                    style: TextStyle(
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No tracks in your playlist yet. Add suggestions to your playlist to see them here.',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
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
                    child: Text(
                      'No tracks in your library yet. Like suggestions to add them to your library.',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
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
      // Ensure we have test data
      await _insertTestDataIfNeeded();
      
      // Get pending music suggestions from database
      final suggestions = await _recommendationService.getSuggestions(
        'music', 
        status: SuggestionStatus.pending,
      );
      
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
      final likedSuggestions = await _recommendationService.getSuggestions(
        'music',
        status: SuggestionStatus.liked,
      );
      
      setState(() {
        _dbLikedSuggestions = likedSuggestions;
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
      final playlistSuggestions = await _recommendationService.getSuggestions(
        'music',
        status: SuggestionStatus.watchlist,
      );
      
      setState(() {
        _dbPlaylistSuggestions = playlistSuggestions;
        _isLoadingDbPlaylist = false;
      });
    } catch (e) {
      debugPrint('Error loading DB playlist: $e');
      setState(() {
        _isLoadingDbPlaylist = false;
      });
    }
  }

  // Insert test data for development
  Future<void> _insertTestDataIfNeeded() async {
    try {
      // Check if we already have music suggestions
      final existingSuggestions = await _recommendationService.getSuggestions('music');
      
      if (existingSuggestions.isEmpty) {
        // Insert the "Saint John" test data
        final testSuggestion = MediaSuggestion(
          query: 'indie folk music similar to current library',
          mediaType: 'music',
          title: 'Saint John',
          artist: 'No Clear Mind',
          album: 'Makena',
          coverArtUrl: 'https://f4.bcbits.com/img/a2164956462_16.jpg',
          description: 'A beautiful indie folk track with dreamy vocals and atmospheric soundscape. This London-based band creates ethereal music that blends folk and shoegaze elements.',
          wikiUrl: 'https://noclearmind.bandcamp.com/track/saint-john',
          botReasoning: 'This track combines indie folk with dreamy, atmospheric elements that should appeal to your taste. The ethereal vocals and gentle instrumentation create a perfect listening experience.',
          status: SuggestionStatus.pending,
        );
        
        await _db.saveMediaSuggestion(testSuggestion);
        debugPrint('Inserted test music suggestion: Saint John by No Clear Mind');
      }
    } catch (e) {
      debugPrint('Error inserting test data: $e');
    }
  }

  // Build DB playlist section
  Widget _buildDbPlaylistSection() {
    return MediaGrid(
      children: _dbPlaylistSuggestions.map((suggestion) {
        // Convert MediaSuggestion to Track for TrackCard
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
          uri: '',
          previewUrl: '',
        );
        
        // Convert to SimpleTrack for TrackCard compatibility
        final simpleTrack = SimpleTrack(
          id: track.id,
          name: track.name,
          artist: track.artists.isNotEmpty ? track.artists.first.name : 'Unknown Artist',
          album: track.album.name,
          albumArtUrl: track.album.images.isNotEmpty ? track.album.images.first.url : '',
          uri: track.uri,
          previewUrl: track.previewUrl,
        );
        
        return TrackCard(
          track: simpleTrack,
          isSaved: true,
          isPlaying: false, // DB tracks can't be played
          onPlay: (t) => {}, // DB tracks can't be played
          onSave: (t) => {},
          onRemove: (t) async {
            // Remove from playlist by changing status back to pending
            await _recommendationService.updateSuggestionStatus(
              suggestion.id,
              SuggestionStatus.pending,
            );
            _loadDbPlaylist();
          },
        );
      }).toList(),
    );
  }

  // Build DB library section
  Widget _buildDbLibrarySection() {
    return MediaGrid(
      children: _dbLikedSuggestions.map((suggestion) {
        // Convert MediaSuggestion to Track for TrackCard
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
          uri: '',
          previewUrl: '',
        );
        
        // Convert to SimpleTrack for TrackCard compatibility
        final simpleTrack = SimpleTrack(
          id: track.id,
          name: track.name,
          artist: track.artists.isNotEmpty ? track.artists.first.name : 'Unknown Artist',
          album: track.album.name,
          albumArtUrl: track.album.images.isNotEmpty ? track.album.images.first.url : '',
          uri: track.uri,
          previewUrl: track.previewUrl,
        );
        
        return TrackCard(
          track: simpleTrack,
          isSaved: true,
          isPlaying: false, // DB tracks can't be played
          onPlay: (t) => {}, // DB tracks can't be played
          onSave: (t) => {},
          onRemove: (t) async {
            // Remove from library by changing status back to pending
            await _recommendationService.updateSuggestionStatus(
              suggestion.id,
              SuggestionStatus.pending,
            );
            _loadDbLibrary();
          },
        );
      }).toList(),
    );
  }
}

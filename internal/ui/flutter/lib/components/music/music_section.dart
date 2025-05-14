import 'dart:async';
import 'package:flutter/material.dart';
import '../common/media_grid.dart';
import '../common/scroll_content_wrapper.dart';
import '../../models.dart';
import 'library/library_section.dart';
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
  bool _isLoading = true;
  String? _errorMessage;
  GlobalKey<SpotifyWebPlayerState> _webPlayerKey = GlobalKey();
  String? _activeDeviceId;

  // Suggestion state
  Track? _suggestion;
  String? _suggestionError;
  bool _isLoadingSuggestion = false;

  // Playback state
  Track? _nowPlayingTrack;
  bool _isPlaybackPaused = true;

  // Library state
  List<Track> _likedTracks = [];
  bool _isLoadingLibrary = false;
  int _currentLibraryPage = 1;
  int _totalLibraryTracks = 0;
  final int _tracksPerPage = 20; // Show 20 tracks per page (4x5 grid)

  // Keep services and other components
  final SpotifyService _spotifyService = SpotifyService();

  StreamSubscription? _authSubscription;
  StreamSubscription? _deviceIdSubscription;
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _trackChangeSubscription;

  @override
  void initState() {
    super.initState();
    
    // Reset suggestion state on init to avoid any loading indicators
    _resetSuggestionState();
    
    _setupListeners();
    _checkAuthentication();
  }

  void _setupListeners() {
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
    
    // Listen for auth state changes
    _authSubscription = _spotifyService.onAuthStatusChange.listen((event) {
      setState(() {
        _isAuthenticated = event.isAuthenticated;
      });

      if (_isAuthenticated) {
        _loadLibrary();
        _loadSuggestion();
      }
    });

    // Listen for device ID changes
    _deviceIdSubscription = _spotifyService.onDeviceIdChange.listen((deviceId) {
      setState(() {
        _activeDeviceId = deviceId;
      });
    });

    // Listen for playback state changes
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
    super.dispose();
  }

  // Check if user is already authenticated
  Future<void> _checkAuthentication() async {
    final isAuthenticated = await _spotifyService.checkAuthentication();
    setState(() {
      _isAuthenticated = isAuthenticated;
    });

    if (_isAuthenticated) {
      _loadLibrary();
      _loadSuggestion();
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
      
      if (response is Map<String, dynamic> && response.containsKey('items')) {
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
        });
      } else if (response is List) {
        for (int i = 0; i < response.length; i++) {
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

  // Play a track on the active device
  Future<void> _playTrack(String trackUri) async {
    if (_activeDeviceId == null) {
      debugPrint('No active Spotify device available. Using web player.');
      // Try to play via the web player directly
      _webPlayerKey.currentState?.playTrack(trackUri);
    } else {
      // Use the stored device ID
      await _spotifyService.playTrack(trackUri, deviceId: _activeDeviceId);
    }
    
    // Set paused state immediately for responsive UI
    setState(() {
      _isPlaybackPaused = false;
    });
    
    // If track is not set by event listener, find and set it for immediate UI update
    if (_nowPlayingTrack == null || _nowPlayingTrack!.uri != trackUri) {
      // Find the track in either liked tracks or current suggestion
      Track? track;
      
      // First check if it's the current suggestion
      if (_suggestion != null && _suggestion!.uri == trackUri) {
        track = _suggestion;
      } else {
        // Search in liked tracks
        for (final t in _likedTracks) {
          if (t.uri == trackUri) {
            track = t;
            break;
          }
        }
      }
      
      // If we found the track, update it and emit the track change event
      if (track != null) {
        setState(() {
          _nowPlayingTrack = track;
        });
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

  // Handle play/pause action from track cards
  Future<void> _handleTrackCardAction(dynamic trackData) async {
    Map<String, dynamic> trackInfo;
    
    if (trackData is Track) {
      trackInfo = {
        'uri': trackData.uri,
        'id': trackData.id,
      };
    } else if (trackData is MediaItem) {
      trackInfo = {
        'uri': trackData.uri ?? '',
        'id': trackData.id,
      };
    } else {
      trackInfo = {
        'uri': trackData.uri ?? '',
        'id': trackData.id ?? '',
      };
    }
    
    String trackUri = trackInfo['uri'] as String;
    
    // Check if this is the currently playing track
    if (_nowPlayingTrack != null && _nowPlayingTrack!.uri == trackUri) {
      // Toggle pause/play instead of restarting the track
      if (_isPlaybackPaused) {
        // Resume by playing the current track (no resumePlayback method available)
        await _spotifyService.playTrack(trackUri, deviceId: _activeDeviceId);
        setState(() {
          _isPlaybackPaused = false;
        });
      } else {
        await _spotifyService.pausePlayback();
        setState(() {
          _isPlaybackPaused = true;
        });
      }
    } else {
      // New track, play it
      await _playTrack(trackUri);
    }
  }

  // Toggle play/pause for the current track
  Future<void> _togglePlayback() async {
    try {
      if (_isPlaybackPaused) {
        // If we have a track, use its URI to resume playback
        if (_nowPlayingTrack != null) {
          await _spotifyService.playTrack(_nowPlayingTrack!.uri, deviceId: _activeDeviceId);
        }
      } else {
        await _spotifyService.pausePlayback();
      }
      setState(() {
        _isPlaybackPaused = !_isPlaybackPaused;
      });
    } catch (e) {
      debugPrint('Error toggling playback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error controlling playback: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

  // Build the main music section UI
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Position the web player absolutely to avoid any visual elements
        Positioned(
          left: -1000, // Position it far off-screen
          top: -1000,
          child: SizedBox(
            width: 1,
            height: 1,
            child: Opacity(
              opacity: 0, // Make fully transparent
              child: SpotifyWebPlayer(
                key: _webPlayerKey,
                spotifyService: _spotifyService,
                visible: false,
              ),
            ),
          ),
        ),
        
        // Main content area with scrolling - needs to start behind the header
        // but hide text elements when they cross the header boundary
        ScrollContentWrapper(
          headerHeight: 106, // Original value
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add extra padding at the top to ensure "Suggested for You" is below header
              const SizedBox(height: 40),

              // Content area
              !_isAuthenticated
                ? _buildAuthPrompt()
                : _buildAuthenticatedView(),
            ],
          ),
        ),

        // Player positioned at the bottom
        if (_isAuthenticated && _nowPlayingTrack != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: const SpotifyPlayer(
              key: ValueKey('spotify_player'),
            ),
          ),
      ],
    );
  }

  // Build the UI for authenticated users
  Widget _buildAuthenticatedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. SUGGESTION SECTION AT THE TOP
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            children: [
              Center(
                child: const Text(
                  'Suggested for You',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoadingSuggestion)
                const SizedBox.shrink()
              else if (_suggestionError != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Error: $_suggestionError',
                      style: const TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (_suggestion == null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No suggestions available',
                      style: const TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                SuggestionDisplay(
                  suggestedTrack: TrackAdapter.toMediaItem(_suggestion!),
                  onRequestSuggestion: _loadSuggestion,
                  onSkipSuggestion: _loadSuggestion,
                  onSuggestionFeedback: (feedback) => _provideFeedback(feedback),
                  onAddToLibrary: () => _saveTrack(_suggestion!.id),
                  onPlay: (mediaItem) => _handleTrackCardAction(mediaItem),
                  isPlaybackPaused: _isPlaybackPaused,
                  nowPlayingTrack: _nowPlayingTrack != null ? TrackAdapter.toMediaItem(_nowPlayingTrack!) : null,
                  onPlayPause: () => _togglePlayback(),
                ),
            ],
          ),
        ),

        // 2. LIBRARY SECTION (LIKED SONGS) AT THE BOTTOM
        const SizedBox(height: 24),
        Center(
          child: const Text(
            'Your Library',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Library content in a grid
        _buildLibrarySection(),
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
      onPlay: (track) => _handleTrackCardAction(track),
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
                _loadSuggestion();
              }
            },
            child: const Text('Connect to Spotify'),
          ),
        ],
      ),
    );
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
}

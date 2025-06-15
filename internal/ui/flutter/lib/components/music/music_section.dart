import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import '../common/scroll_content_wrapper.dart';
import '../common/media_grid.dart';
import '../common/media_library_grid.dart';
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
  final GlobalKey<SpotifyWebPlayerState> _webPlayerKey = GlobalKey();
  String? _activeDeviceId;
  String? _pendingTrackUri;
  bool _isPlayerReady = false;

  // Database suggestion state
  MediaSuggestion? _currentDbSuggestion;
  Track? _dbSuggestedTrack;
  String? _dbSuggestionError;
  bool _isLoadingDbSuggestion = false;
  bool _hasLikedCurrentSuggestion = false;

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

  // Like a database suggestion (mark as liked but stay on current)
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

      // Reload library to show the new liked item
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error liking DB suggestion: $e');
    }
  }

  // Add to favorites (same as like but with different messaging)
  Future<void> _addToFavorites() async {
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
          content: Text('Added "${_currentDbSuggestion!.title}" to your favorites'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Reload library
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
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

      // Get next suggestion (this will reset the like state)
      _moveToNextSuggestion();
    } catch (e) {
      debugPrint('Error disliking DB suggestion: $e');
    }
  }

  // Skip a database suggestion (mark as skipped and move to next)
  Future<void> _skipDbSuggestion() async {
    if (_currentDbSuggestion == null) return;

    try {
      // Only mark as skipped if it hasn't been liked
      if (!_hasLikedCurrentSuggestion) {
        await _recommendationService.updateSuggestionStatus(
          _currentDbSuggestion!.id,
          SuggestionStatus.skipped,
        );
      }

      _moveToNextSuggestion();
    } catch (e) {
      debugPrint('Error skipping DB suggestion: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Move to next suggestion (for both skip and next actions)
  Future<void> _moveToNextSuggestion() async {
    try {
      setState(() {
        _isLoadingDbSuggestion = true;
        _dbSuggestedTrack = null;
        _currentDbSuggestion = null;
        _dbSuggestionError = null;
        _hasLikedCurrentSuggestion = false; // Reset like state
      });
      
      // Load next suggestion
      _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error moving to next suggestion: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
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
    return Stack(
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
                  SizedBox(
                    width: 1,
                    height: 1,
                    child: SpotifyWebPlayer(
                      key: _webPlayerKey,
                      spotifyService: _spotifyService,
                      visible: false,
                    ),
                  ),
                  
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
                  
                  // Playlist section with proper spacing
                  SectionSpacing(
                    child: _buildPlaylistSection(),
                  ),
                  
                  // Library section with proper spacing
                  SectionSpacing(
                    child: _buildDbLibrarySectionWrapper(),
                  ),
                  
                  // Spotify library section with proper spacing
                  SectionSpacing(
                    child: _buildSpotifyLibrarySection(),
                  ),
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

  // Helper method to build suggestion content
  Widget _buildSuggestionContent(double scrollOffset) {
    if (_isLoadingDbSuggestion) {
      return const SizedBox.shrink();
    } else if (_dbSuggestionError != null) {
      return Center(
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
      // Current suggestion container (no extra horizontal padding - handled by MediaSectionLayout)
      return Column(
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
                          '${TextUtils.formatArtistNames(_dbSuggestedTrack!.artists.first.name)} • ${_dbSuggestedTrack!.album.name}',
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
                          child: Column(
                            children: [
                              // Description text - flexible height based on reasoning length
                              if (_currentDbSuggestion?.description?.isNotEmpty == true)
                                Builder(
                                  builder: (context) {
                                    // Calculate reasoning length to determine description space
                                    final reasoningLength = _currentDbSuggestion?.botReasoning?.length ?? 0;
                                    final isReasoningShort = reasoningLength < 200; // Threshold for "short" reasoning
                                    final maxDescriptionHeight = isReasoningShort ? 180.0 : 120.0; // More space if reasoning is short
                                    
                                    return Container(
                                      constraints: BoxConstraints(maxHeight: maxDescriptionHeight),
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
                                    );
                                  },
                                ),
                              
                              const SizedBox(height: 16),
                              
                              // Bot reasoning - takes remaining space but ensures minimum padding
                              if (_currentDbSuggestion?.botReasoning?.isNotEmpty == true)
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 24), // Ensure bottom padding
                                    child: Column(
                                      children: [
                                        // Reasoning header with Font Awesome robot icon
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
                                        
                                        // Reasoning text - scrollable with constraints to prevent overflow
                                        Expanded(
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              return Container(
                                                constraints: BoxConstraints(
                                                  maxHeight: constraints.maxHeight,
                                                  minHeight: 40, // Minimum height for reasoning
                                                ),
                                                child: SingleChildScrollView(
                                                  child: Text(
                                                    _currentDbSuggestion!.botReasoning!,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: const Color(0xFF8C86E2).withOpacity(0.8),
                                                      height: 1.4,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Action buttons - wrap layout like other media sections
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              // Like button
                              ElevatedButton.icon(
                                onPressed: _hasLikedCurrentSuggestion ? null : _likeDbSuggestion,
                                icon: Icon(
                                  _hasLikedCurrentSuggestion ? Icons.thumb_up : Icons.thumb_up_outlined, 
                                  size: 16
                                ),
                                label: Text(
                                  _hasLikedCurrentSuggestion ? 'Liked' : 'Like', 
                                  style: const TextStyle(fontSize: 13)
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _hasLikedCurrentSuggestion 
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.15),
                                  foregroundColor: _hasLikedCurrentSuggestion ? Colors.green : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  minimumSize: const Size(0, 44),
                                ),
                              ),
                              
                              // Dislike button
                              ElevatedButton.icon(
                                onPressed: _dislikeDbSuggestion,
                                icon: const Icon(Icons.thumb_down, size: 16),
                                label: const Text('Dislike', style: TextStyle(fontSize: 13)),
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
                              
                              // Favorite button
                              ElevatedButton.icon(
                                onPressed: _hasLikedCurrentSuggestion ? null : _addToFavorites,
                                icon: Icon(
                                  _hasLikedCurrentSuggestion ? Icons.favorite : Icons.favorite_border, 
                                  size: 16
                                ),
                                label: Text(
                                  _hasLikedCurrentSuggestion ? 'Favorited' : 'Favorite', 
                                  style: const TextStyle(fontSize: 13)
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _hasLikedCurrentSuggestion 
                                    ? Colors.red.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.15),
                                  foregroundColor: _hasLikedCurrentSuggestion ? Colors.red : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  minimumSize: const Size(0, 44),
                                ),
                              ),
                              
                              // Playlist button
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
                              
                              // Skip/Next button
                              ElevatedButton.icon(
                                onPressed: _skipDbSuggestion,
                                icon: Icon(
                                  _hasLikedCurrentSuggestion ? Icons.arrow_forward : Icons.skip_next, 
                                  size: 16
                                ),
                                label: Text(
                                  _hasLikedCurrentSuggestion ? 'Next' : 'Skip', 
                                  style: const TextStyle(fontSize: 13)
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _hasLikedCurrentSuggestion 
                                    ? const Color(0xFF7B68EE).withOpacity(0.3)
                                    : Colors.white.withOpacity(0.15),
                                  foregroundColor: _hasLikedCurrentSuggestion 
                                    ? const Color(0xFF7B68EE) 
                                    : Colors.white,
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
                ),
              ],
            ),
          ),
        ],
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
                      'No tracks in your library yet. Like or add suggestions to see them here.',
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
        const Center(
          child: Text(
            'Your Spotify Liked Tracks',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
      _hasLikedCurrentSuggestion = false; // Reset like state
    });

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
        // Try to generate a new suggestion on-demand
        final newSuggestion = await _recommendationService.generateSuggestionOnDemand('music');
        if (newSuggestion != null) {
          // Convert MediaSuggestion to Track for compatibility
          final track = Track(
            id: newSuggestion.id.toString(),
            name: newSuggestion.title ?? 'Unknown',
            artists: [Artist(name: newSuggestion.artist ?? 'Unknown Artist')],
            album: Album(
              name: newSuggestion.album ?? 'Unknown Album',
              images: newSuggestion.coverArtUrl?.isNotEmpty == true 
                ? [ImageData(url: newSuggestion.coverArtUrl!, height: 300, width: 300)] 
                : [],
            ),
            uri: '', // No Spotify URI for database suggestions
            previewUrl: '',
          );
          
          setState(() {
            _dbSuggestedTrack = track;
            _currentDbSuggestion = newSuggestion;
            _isLoadingDbSuggestion = false;
          });
        } else {
          setState(() {
            _dbSuggestedTrack = null;
            _currentDbSuggestion = null;
            _dbSuggestionError = 'Unable to generate music suggestions. Make sure TinyLlama model is installed.';
            _isLoadingDbSuggestion = false;
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

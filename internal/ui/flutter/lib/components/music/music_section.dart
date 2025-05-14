import 'package:flutter/material.dart';
import 'dart:async'; // Timer import

import '../../models.dart';
import './spotify_service.dart';
import '../../theme.dart';
import 'suggestions/suggestion_display.dart';
import 'tracks/track_card.dart';
import 'spotify_player_view.dart';
import 'spotify_web_player.dart'; // Add import for web player

class MusicSection extends StatefulWidget {
  const MusicSection({
    super.key,
  });

  @override
  State<MusicSection> createState() => _MusicSectionState();
}

class _MusicSectionState extends State<MusicSection> {
  List<Map<String, dynamic>> _library = [];
  bool _isLoadingLibrary = false;
  bool _isLoadingSuggestion = false;
  MediaItem? _suggestion;
  String? _suggestionError;
  int _totalTracks = 0;
  bool _isAuthenticated = false;
  int _currentPage = 0; // Start at page 0 instead of 1
  final int _itemsPerPage = 20; // Show 20 items per page
  bool _isPlaybackPaused = true;
  MediaItem? _nowPlayingTrack;
  String? _activeDeviceId;
  
  // Create a GlobalKey to access the SpotifyWebPlayer instance
  final GlobalKey<SpotifyWebPlayerState> _webPlayerKey = GlobalKey();
  
  // Replace Timer with StreamSubscription - no more polling!
  StreamSubscription? _authSubscription;
  StreamSubscription? _deviceIdSubscription;
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _trackChangeSubscription;
  
  // Keep services and other components
  final SpotifyService _spotifyService = SpotifyService();

  @override
  void initState() {
    super.initState();
    _initSpotifyListeners();
    _checkAuthentication();
  }
  
  @override
  void dispose() {
    _authSubscription?.cancel();
    _deviceIdSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _trackChangeSubscription?.cancel();
    super.dispose();
  }
  
  // Initialize Spotify listeners to replace polling
  void _initSpotifyListeners() {
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
    
    // Listen for track changes
    _trackChangeSubscription = _spotifyService.onTrackChange.listen((event) {
      setState(() {
        _nowPlayingTrack = event.item;
      });
    });
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

  // Load saved tracks from library
  Future<void> _loadLibrary() async {
    if (!_isAuthenticated) return;
    
    setState(() {
      _isLoadingLibrary = true;
    });

    try {
      // Calculate offset based on current page
      final int offset = _currentPage * _itemsPerPage;
      
      // Get liked tracks from the user's library with pagination
      final response = await _spotifyService.getLikedTracks(
        limit: _itemsPerPage,
        offset: offset
      );
      
      // Cast safely using generics
      final items = response['items'];
      final List<SimpleTrack> trackList = (items is List<SimpleTrack>)
          ? items
          : (items as List).cast<SimpleTrack>();
      
      final int totalTracks = response['total'] as int;
      
      setState(() {
        // Convert SimpleTrack objects to Map format
        _library = trackList.map<Map<String, dynamic>>((SimpleTrack track) => {
          'id': track.id,
          'name': track.name,
          'artist': track.artist,
          'album': track.album,
          'imageUrl': track.albumArtUrl,
          'uri': track.uri,
          'previewUrl': track.previewUrl,
        }).toList();
        
        _isLoadingLibrary = false;
        _totalTracks = totalTracks;
      });
    } catch (e) {
      debugPrint('Error loading library: $e');
      setState(() {
        _isLoadingLibrary = false;
      });
    }
  }

  // Load a suggestion based on library
  Future<void> _loadSuggestion() async {
    if (!_isAuthenticated) return;
    
    setState(() {
      _isLoadingSuggestion = true;
      _suggestionError = null;
    });

    try {
      // Use getRecommendations for suggestions
      final recommendations = await _spotifyService.getRecommendations();
      
      // Convert SimpleTrack to MediaItem
      if (recommendations.isNotEmpty) {
        final suggestion = recommendations.first;
        setState(() {
          _suggestion = MediaItem(
            id: suggestion.id,
            title: suggestion.name,
            overview: suggestion.artist,
            posterPath: suggestion.albumArtUrl,
            mediaType: 'music',
            uri: suggestion.uri,
            previewUrl: suggestion.previewUrl,
          );
          _isLoadingSuggestion = false;
        });
      } else {
        setState(() {
          _suggestion = null;
          _suggestionError = 'No suggestions available';
          _isLoadingSuggestion = false;
        });
      }
    } catch (e) {
      setState(() {
        _suggestionError = 'Error loading suggestion: $e';
        _isLoadingSuggestion = false;
      });
    }
  }

  // Play a track with the new device ID approach
  Future<void> _playTrack(String trackUri) async {
    if (_activeDeviceId == null) {
      debugPrint('No active Spotify device available. Using web player.');
      // Try to play via the web player directly
      _webPlayerKey.currentState?.playTrack(trackUri);
    } else {
      // Use the stored device ID
      await _spotifyService.playTrack(trackUri, deviceId: _activeDeviceId);
    }
  }
  
  // Pause playback
  Future<void> _pausePlayback() async {
    if (_activeDeviceId == null) {
      debugPrint('No active Spotify device available. Using web player.');
      // Try to pause via the web player directly
      _webPlayerKey.currentState?.pausePlayback();
    } else {
      // Use the stored device ID
      await _spotifyService.pausePlayback(deviceId: _activeDeviceId);
    }
  }

  // Build the main music section UI
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add the web player (hidden but active)
        SizedBox(
          width: 1,
          height: 1,
          child: SpotifyWebPlayer(
            key: _webPlayerKey,
            spotifyService: _spotifyService,
            visible: false,
          ),
        ),
        
        // Rest of your build method
        if (!_isAuthenticated) _buildAuthPrompt() else _buildAuthenticatedView(),
      ],
    );
  }

  // Build the UI for authenticated users
  Widget _buildAuthenticatedView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. SUGGESTION SECTION AT THE TOP
          const Text(
            'Suggested for You',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _isLoadingSuggestion
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _suggestionError != null
                  ? Text('Error: $_suggestionError')
                  : _suggestion == null
                      ? const Text('No suggestions available')
                      : SuggestionDisplay(
                          suggestedTrack: _suggestion,
                          onRequestSuggestion: _loadSuggestion,
                          onSkipSuggestion: _loadSuggestion,
                          onSuggestionFeedback: (feedback) => _provideFeedback(feedback),
                          onAddToLibrary: () => _saveTrack(_suggestion!.id.toString()),
                          onPlay: (track) => _playTrack(track.uri ?? ''),
                          isPlaybackPaused: _isPlaybackPaused,
                          nowPlayingTrack: _nowPlayingTrack,
                          onPlayPause: () => _togglePlayback(),
                        ),
          
          // 2. PLAYER CONTROLS
          const SizedBox(height: 24),
          const SpotifyPlayer(
            key: ValueKey('spotify_player'),
          ),
          
          // 3. LIBRARY SECTION (LIKED SONGS) AT THE BOTTOM
          const SizedBox(height: 24),
          const Text(
            'Your Library',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Library content in a grid
          _buildLibrarySection(),
        ],
      ),
    );
  }
  
  // Build the library section with pagination
  Widget _buildLibrarySection() {
    if (_isLoadingLibrary) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_library.isEmpty) {
      return const Text('Your library is empty. Search for tracks to add them to your library.');
    }
    
    // We don't need to calculate indices or use sublist anymore since our data is already paginated from the API
    // We can directly use the _library which contains the current page's data
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid of tracks
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,  // Changed from 4 to 3 columns
            childAspectRatio: 0.8,  // Keeping the same aspect ratio
            crossAxisSpacing: 12.0,
            mainAxisSpacing: 16.0,
          ),
          itemCount: _library.length,
          itemBuilder: (context, index) {
            final track = _library[index];
            final isPlaying = !_isPlaybackPaused && 
                _nowPlayingTrack?.id == track['id'];
            
            return TrackCard(
              track: MediaItem(
                id: track['id'] ?? '',
                title: track['name'] ?? 'Unknown Track',
                overview: track['artist'] ?? 'Unknown Artist',
                posterPath: track['imageUrl'] ?? '',
                mediaType: 'music',
                uri: track['uri'],
                previewUrl: track['previewUrl'],
              ),
              isSaved: true,
              isPlaying: isPlaying,
              onPlay: (_) => _playTrack(track['uri'] ?? ''),
              onRemove: (_) => _removeTrack(track['id'] ?? ''),
            );
          },
        ),
        
        // Pagination controls
        const SizedBox(height: 16),
        _buildPaginationControls(),
      ],
    );
  }

  // Previous and Next page buttons for the library section
  Widget _buildPaginationControls() {
    // Calculate total pages
    final int totalPages = (_totalTracks / _itemsPerPage).ceil();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _currentPage > 0
              ? () {
                  setState(() {
                    _currentPage--;
                  });
                  _loadLibrary(); // Reload library with new page
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.3),
          ),
          child: const Text('Previous'),
        ),
        const SizedBox(width: 20),
        Text(
          'Page ${_currentPage + 1} of $totalPages',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(width: 20),
        ElevatedButton(
          onPressed: _currentPage < totalPages - 1
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                  _loadLibrary(); // Reload library with new page
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.3),
          ),
          child: const Text('Next'),
        ),
      ],
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
  
  // Toggle play/pause
  Future<void> _togglePlayback() async {
    try {
      if (_isPlaybackPaused) {
        await _spotifyService.playTrack(_nowPlayingTrack!.uri!);
      } else {
        await _spotifyService.pausePlayback();
      }
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
        if (contextMounted && mounted) {
          scaffoldMessengerState.showSnackBar(
            const SnackBar(content: Text('Track saved to your library')),
          );
        }
      } else {
        if (contextMounted && mounted) {
          scaffoldMessengerState.showSnackBar(
            const SnackBar(content: Text('Failed to save track')),
          );
        }
      }
    } catch (e) {
      if (contextMounted && mounted) {
        scaffoldMessengerState.showSnackBar(
          SnackBar(content: Text('Error saving track: $e')),
        );
      }
    }
  }

  // Remove a track from library
  Future<void> _removeTrack(String trackId) async {
    if (trackId.isEmpty) {
      return;
    }

    // Store context state before async gap
    final scaffoldMessengerState = ScaffoldMessenger.of(context);
    final contextMounted = context.mounted;
    
    try {
      final success = await _spotifyService.removeTrack(trackId);
      if (success) {
        // Load library again to refresh saved tracks
        await _loadLibrary();
        if (contextMounted && mounted) {
          scaffoldMessengerState.showSnackBar(
            const SnackBar(content: Text('Track removed from your library')),
          );
        }
      } else {
        if (contextMounted && mounted) {
          scaffoldMessengerState.showSnackBar(
            const SnackBar(content: Text('Failed to remove track')),
          );
        }
      }
    } catch (e) {
      if (contextMounted && mounted) {
        scaffoldMessengerState.showSnackBar(
          SnackBar(content: Text('Error removing track: $e')),
        );
      }
    }
  }

  // Provide feedback for a suggestion
  Future<void> _provideFeedback(String feedback) async {
    if (_suggestion == null) return;
    
    try {
      // Extract info from the suggestion
      final String title = _suggestion!.title;
      final String artist = _suggestion!.overview; // Artist name is stored in overview
      
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

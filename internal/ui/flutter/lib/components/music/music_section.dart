import 'package:flutter/material.dart';
import 'dart:async'; // Timer import

import '../../models.dart';
import './spotify_service.dart';
import '../../theme.dart';
import 'suggestions/suggestion_display.dart';
import 'tracks/track_card.dart';
import 'spotify_player_view.dart';

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
  Timer? _playbackStateTimer;
  
  // Use the direct Spotify service instead of MusicFFI
  final SpotifyService _spotifyService = SpotifyService();

  @override
  void initState() {
    super.initState();
    _initializeSpotify();
    _startPlaybackStatePolling();
  }

  @override
  void dispose() {
    _playbackStateTimer?.cancel();
    super.dispose();
  }

  void _startPlaybackStatePolling() {
    _playbackStateTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      // Only poll for playback state if authenticated
      if (!_isAuthenticated) {
        return;
      }
      
      try {
        final playbackState = await _spotifyService.getPlaybackState();
        
        if (mounted && playbackState != null) {
          setState(() {
            _isPlaybackPaused = !(playbackState['is_playing'] ?? false);
            
            // Check if there's a current track playing
            final trackData = playbackState['item'] as Map<String, dynamic>?;
            if (trackData != null) {
              // Extract artist names from the artists array
              final List<dynamic> artists = trackData['artists'] ?? [];
              final String artistNames = artists.isNotEmpty 
                  ? artists.map((a) => a['name']).join(', ')
                  : 'Unknown Artist';
                  
              // Get album art URL
              String albumArtUrl = '';
              if (trackData['album'] != null) {
                final List<dynamic> images = trackData['album']['images'] ?? [];
                if (images.isNotEmpty) {
                  albumArtUrl = images[0]['url'] ?? '';
                }
              }
              
              _nowPlayingTrack = MediaItem(
                id: trackData['id'] ?? '',
                title: trackData['name'] ?? 'Unknown Track',
                overview: artistNames,
                posterPath: albumArtUrl,
                mediaType: 'music',
                uri: trackData['uri'] ?? '',
                previewUrl: trackData['preview_url'] ?? '',
              );
            }
          });
        }
      } catch (e) {
        debugPrint('Error polling playback state: $e');
      }
    });
  }

  Future<void> _initializeSpotify() async {
    await _spotifyService.initialize();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    // Check if authenticated with Spotify
    final isAuthenticated = await _spotifyService.checkAuthentication();
    
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuthenticated;
      });
    }
    
    // Only start loading library and listening for auth events 
    // if we're authenticated
    if (isAuthenticated) {
      _loadLibrary();
      _loadSuggestion();
      // Listen for authentication status changes
      _listenToAuthEvents();
    } else {
      // Clear any existing data since we're not authenticated
      if (mounted) {
        setState(() {
          _library = [];
          _nowPlayingTrack = null;
          _suggestion = null;
        });
      }
    }
  }
  
  /// Set up event listeners for authentication status changes
  void _listenToAuthEvents() {
    _spotifyService.onAuthStatusChange.listen((event) {
      if (mounted) {
        setState(() {
          _isAuthenticated = event.isAuthenticated;
        });
        
        if (event.isAuthenticated) {
          // Fetch user's library and suggestion when authenticated
          // This ensures data loads when auth happens from either component
          _loadLibrary();
          _loadSuggestion();
        } else {
          // Clear user data if logged out
          setState(() {
            _library = [];
            _nowPlayingTrack = null;
            _suggestion = null;
          });
        }
      }
    });
    
    _spotifyService.onTrackChange.listen((event) {
      if (mounted) {
        // Update the now playing track
        setState(() {
          final media = event.item;
          _nowPlayingTrack = media;
          _isPlaybackPaused = false;
        });
      }
    });
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
      
      debugPrint('Loading page $_currentPage (offset: $offset, limit: $_itemsPerPage)');
      
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
        
        // Debug pagination info
        debugPrint('Library loaded with ${_library.length} tracks for page $_currentPage');
        debugPrint('Total tracks in library: $totalTracks');
        debugPrint('Total pages: ${(totalTracks / _itemsPerPage).ceil()}');
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

  // Authenticate with Spotify
  Future<void> _authenticate(BuildContext context) async {
    // This method is no longer directly used, since auth happens in main.dart
    // But we keep it for reference or future use
    try {
      // Explicitly initiate Spotify authentication flow
      final success = await _spotifyService.authenticate(context);
      debugPrint('Spotify auth initiated successfully');
      
      if (success) {
        // Get user profile through the event stream instead of direct call
        setState(() {
          _isAuthenticated = true;
        });
        
        // Load library and suggestions
        _loadLibrary();
        _loadSuggestion();
      }
    } catch (e) {
      debugPrint('Error authenticating with Spotify: $e');
    }
  }

  // Build the main music section UI
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.all(16.0),
      child: _isAuthenticated
          ? _buildAuthenticatedView()
          : _buildLoginPrompt(context),
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
    
    // Debug pagination values
    debugPrint('_currentPage: $_currentPage, totalPages: $totalPages');
    debugPrint('_totalTracks: $_totalTracks, _itemsPerPage: $_itemsPerPage');
    debugPrint('Current library size: ${_library.length}');
    
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
  Widget _buildLoginPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Connect to Spotify to access your music',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _authenticate(context),
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

  // Play a track
  Future<void> _playTrack(String uri) async {
    if (uri.isEmpty) {
      debugPrint('Cannot play track: URI is empty');
      return;
    }
    
    try {
      // Store the scaffold messenger before async operation
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      
      // Play the track using the Spotify service
      final success = await _spotifyService.playTrack(uri);
      
      if (success) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Playing track'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to play track - No active device found'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing track: $e'),
            duration: const Duration(seconds: 5),
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

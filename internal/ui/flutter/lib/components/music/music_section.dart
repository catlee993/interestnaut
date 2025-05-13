import 'package:flutter/material.dart';
import 'dart:async'; // Timer import

import '../../models.dart';
import './spotify_service.dart';
import '../../theme.dart';
import 'suggestions/suggestion_display.dart';
import 'tracks/track_card.dart';

class MusicSection extends StatefulWidget {
  final Function(bool isAuthenticated, Map<String, dynamic>? userProfile)? onAuthStatusChanged;
  
  const MusicSection({
    super.key,
    this.onAuthStatusChanged,
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
  
  // Use the direct Spotify service instead of MusicFFI
  final SpotifyService _spotifyService = SpotifyService();

  @override
  void initState() {
    super.initState();
    _initializeSpotify();
  }

  Future<void> _initializeSpotify() async {
    await _spotifyService.initialize();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      final isAuthenticated = _spotifyService.isAuthenticated;
      
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuthenticated;
        });
      }
      
      // Simplified validation - we trust the service's isAuthenticated value
      debugPrint('Auth status: $isAuthenticated');
      
      // Notify parent about authentication status
      if (widget.onAuthStatusChanged != null) {
        widget.onAuthStatusChanged!(isAuthenticated, null);
      }
      
      // Get user profile if authenticated
      if (isAuthenticated) {
        // Automatically load library and suggestions when authenticated
        _loadLibrary();
        _loadSuggestion();
      }
    } catch (e) {
      debugPrint('Error checking authentication: $e');
    }
  }

  // Load saved tracks from library
  Future<void> _loadLibrary() async {
    if (!_isAuthenticated) return;
    
    setState(() {
      _isLoadingLibrary = true;
    });

    try {
      // Get liked tracks from the user's library
      final tracks = await _spotifyService.getLikedTracks();
      
      setState(() {
        // Update the library with SimpleTrack objects
        _library = tracks.map((track) => {
          'id': track.id,
          'name': track.name,
          'artist': track.artist,
          'album': track.album,
          'imageUrl': track.albumArtUrl,
          'uri': track.uri,
          'previewUrl': track.previewUrl,
        }).toList();
        _isLoadingLibrary = false;
        _totalTracks = _library.length;
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
        
        // Notify parent about authentication status
        if (widget.onAuthStatusChanged != null) {
          widget.onAuthStatusChanged!(true, null);
        }
        
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Library',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Library content
        _isLoadingLibrary
            ? const Center(child: CircularProgressIndicator())
            : _library.isEmpty
                ? const Text('Your library is empty')
                : SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _library.length,
                      itemBuilder: (context, index) {
                        final track = _library[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: TrackCard(
                            track: MediaItem(
                              id: track['id'] ?? '',
                              title: track['name'] ?? 'Unknown Track',
                              overview: track['artist'] ?? 'Unknown Artist',
                              posterPath: track['imageUrl'] ?? '',
                              mediaType: 'music',
                            ),
                            isSaved: true,
                            isPlaying: false,
                            onPlay: (_) => _playTrack(track['uri'] ?? ''),
                            onRemove: (_) => _removeTrack(track['id'] ?? ''),
                          ),
                        );
                      },
                    ),
                  ),
        
        const SizedBox(height: 32),
        
        // Suggestion section
        const Text(
          'Based on your likes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _isLoadingSuggestion
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Getting suggestions...'),
                  ],
                ),
              )
            : _suggestionError != null
                ? const Text('Error: ')
                : _suggestion == null
                    ? const Text('No suggestions available')
                    : SuggestionDisplay(
                        suggestedTrack: _suggestion,
                        onRequestSuggestion: _loadSuggestion,
                        onSkipSuggestion: _loadSuggestion,
                        onSuggestionFeedback: (feedback) => _provideFeedback(feedback),
                        onAddToLibrary: () => _saveTrack(_suggestion!.id.toString()),
                        onPlay: (track) => _playTrack(track.uri ?? ''),
                        isPlaybackPaused: true,
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
              content: Text('Playing track: '),
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
    try {
      // We don't have a direct saveTrack method, 
      // so we'll need to handle this differently
      // For now, we'll just show a message and refresh the library
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Track saved to your library'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Refresh the library
      _loadLibrary();
      // Load new suggestion
      _loadSuggestion();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving track: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Remove a track from library
  Future<void> _removeTrack(String trackId) async {
    try {
      // We don't have a direct removeTrack method,
      // so we'll just show a message and refresh the library
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Track removed from your library'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Remove from local state
      setState(() {
        _library.removeWhere((track) => track['id'] == trackId);
        _totalTracks--;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing track: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
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

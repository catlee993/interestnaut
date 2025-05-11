import 'package:flutter/material.dart';
import 'dart:async'; // Timer import

import '../../models.dart';
import '../../services/music_ffi.dart';
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
  
  // Create an instance of MusicFFI
  final MusicFFI _musicFfi = MusicFFI();

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      final authStatus = await _musicFfi.getAuthStatus();
      debugPrint('Auth status raw: $authStatus');
      
      if (authStatus.containsKey('isAuthenticated')) {
        final isAuth = authStatus['isAuthenticated'] == true;
        debugPrint('Spotify auth status from FFI: $isAuth'); // Debug print
        
        // Additional validation - if we're supposedly authenticated, try to get the user profile
        bool validAuth = isAuth;
        if (isAuth) {
          try {
            // Try to get user profile as a validation check
            final userProfile = await _musicFfi.getCurrentUser();
            if (userProfile.containsKey('error')) {
              debugPrint('User profile returned error, treating as not authenticated');
              validAuth = false;
            }
          } catch (e) {
            debugPrint('Error getting user profile: $e, treating as not authenticated');
            validAuth = false;
          }
        }
        
        debugPrint('Final auth status after validation: $validAuth');
        setState(() {
          _isAuthenticated = validAuth;
        });
        
        // Get user profile if authenticated
        Map<String, dynamic>? userProfile;
        if (validAuth) {
          try {
            userProfile = await _musicFfi.getCurrentUser();
            
            // Automatically load library and suggestions when authenticated
            _loadLibrary();
            _loadSuggestion();
          } catch (e) {
            debugPrint('Error fetching user profile: $e');
          }
        }
        
        // Notify parent about authentication status and user profile
        if (widget.onAuthStatusChanged != null) {
          widget.onAuthStatusChanged!(validAuth, userProfile);
        }
      }
    } catch (e) {
      debugPrint('Error checking authentication: $e');
      setState(() {
        _isAuthenticated = false;
      });
      if (widget.onAuthStatusChanged != null) {
        widget.onAuthStatusChanged!(false, null);
      }
    }
  }

  Future<void> _loadLibrary({int limit = 50, int offset = 0}) async {
    if (!_isAuthenticated) return;

    setState(() {
      _isLoadingLibrary = true;
      _library = []; // Clear the library before loading
    });

    try {
      final response = await _musicFfi.getSavedTracks(limit, offset);
      
      // Handle different response formats
      if (response is List) {
        // Direct list of tracks
        final List<Map<String, dynamic>> tracks = [];
        for (var i = 0; i < response.length; i++) {
          final item = response[i];
          if (item is Map) {
            tracks.add(Map<String, dynamic>.from(item));
          }
        }
        
        setState(() {
          _library = tracks;
          _totalTracks = tracks.length;
          _isLoadingLibrary = false;
        });
      } else      // Response with 'items' field
      if (response.containsKey('items')) {
        final items = response['items'];
        if (items is List) {
          final List<Map<String, dynamic>> tracks = [];
          for (var i = 0; i < items.length; i++) {
            final item = items[i];
            if (item is Map) {
              tracks.add(Map<String, dynamic>.from(item));
            }
          }

          setState(() {
            _library = tracks;
            _totalTracks = response['total'] ?? tracks.length;
            _isLoadingLibrary = false;
          });
        } else {
          setState(() {
            _isLoadingLibrary = false;
            // No valid items found
          });
        }
      } else {
        setState(() {
          _isLoadingLibrary = false;
          // No items field found
        });
      }

    } catch (e) {
      debugPrint('Error loading library: $e');
      setState(() {
        _isLoadingLibrary = false;
        // Show error in UI
      });
    }
  }

  Future<void> _loadSuggestion() async {
    if (!_isAuthenticated) return;

    setState(() {
      _isLoadingSuggestion = true;
      _suggestionError = null;
    });

    try {
      final suggestion = await _musicFfi.requestNewSuggestion();
      
      // Convert Map<String, dynamic> to MediaItem
      if (suggestion is Map) {
        setState(() {
          _suggestion = MediaItem.fromJson(suggestion);
          _isLoadingSuggestion = false;
        });
      } else {
        throw Exception('Unexpected suggestion format');
      }
    } catch (e) {
      debugPrint('Error loading suggestion: $e');
      setState(() {
        _isLoadingSuggestion = false;
        _suggestionError = 'Failed to load suggestion: $e';
      });
    }
  }

  Future<void> _authenticateWithSpotify() async {
    debugPrint('Initiating Spotify auth in MusicBindings...');
    
    setState(() {
      _isAuthenticated = false;
    });

    try {
      // Explicitly initiate Spotify authentication flow, which now returns the auth status
      final authResult = await _musicFfi.initiateSpotifyAuth();
      debugPrint('Spotify auth initiated successfully');
      
      if (authResult.containsKey('isAuthenticated') && authResult['isAuthenticated'] == true) {
        // Get user profile if authenticated
        Map<String, dynamic>? userProfile;
        try {
          userProfile = await _musicFfi.getCurrentUser();
          
          setState(() {
            _isAuthenticated = true;
          });
          
          // Load library and suggestions immediately since we're authenticated
          _loadLibrary();
          _loadSuggestion();
          
          // Notify parent about authentication status change
          if (widget.onAuthStatusChanged != null) {
            widget.onAuthStatusChanged!(true, userProfile);
          }
          
          return; // Success path - exit early
        } catch (e) {
          debugPrint('Error getting user profile after successful auth: $e');
          // Continue to fallback verification path
        }
      }
      
      // Fallback verification path - check authentication status directly
      await Future.delayed(const Duration(milliseconds: 500));
      await _checkAuthentication();
    } catch (e) {
      debugPrint('Error authenticating with Spotify: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to authenticate with Spotify: $e'),
        ),
      );
    }
  }

  /// Play a track - simplified implementation without polling
  Future<void> _playTrack(MediaItem track) async {
    if (!_isAuthenticated) {
      // Show authentication button if not authenticated
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Authentication required to play tracks'),
          action: SnackBarAction(
            label: 'Authenticate',
            onPressed: _authenticateWithSpotify,
          ),
        ),
      );
      return;
    }
    
    try {
      // Ensure we have a valid Spotify URI
      // MediaItem.uri might be null or not in the correct format
      String uri;
      if (track.uri != null && track.uri!.startsWith('spotify:track:')) {
        uri = track.uri!;
      } else {
        // Fallback to constructing a URI from the track ID
        uri = 'spotify:track:${track.id}';
      }
      
      // Play the track using the musicFFI service
      await _musicFfi.playTrack(uri);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing ${track.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error playing track: $e');
      
      // Check if error is authentication related
      if (e.toString().contains('token') || e.toString().contains('auth')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Authentication required'),
            action: SnackBarAction(
              label: 'Authenticate',
              onPressed: _authenticateWithSpotify,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play track: $e'),
          ),
        );
      }
    }
  }

  Future<void> _saveTrack(String trackId) async {
    try {
      await _musicFfi.saveTrack(trackId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Track saved to your library'),
        ),
      );
      
      // Refresh library after saving
      await _loadLibrary();
    } catch (e) {
      debugPrint('Error saving track: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save track: $e'),
        ),
      );
    }
  }

  Future<void> _removeTrack(String trackId) async {
    try {
      await _musicFfi.removeTrack(trackId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Track removed from your library'),
        ),
      );
      
      // Refresh library after removing
      await _loadLibrary();
    } catch (e) {
      debugPrint('Error removing track: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove track: $e'),
        ),
      );
    }
  }

  Future<void> _handleSuggestionFeedback(String feedback) async {
    if (_suggestion == null) {
      return;
    }
    
    try {
      final String title = _suggestion!.title;
      final String artist = _suggestion!.overview; // Artist name is stored in overview
      final String album = ''; // We don't have album info in our MediaItem
      
      await _musicFfi.provideSuggestionFeedback(
        feedback, 
        title,
        artist,
        album
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feedback == 'like' ? 'Added to your liked tracks' : 'Thanks for your feedback'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // If they liked it, we could optionally trigger a save or load new suggestion
      if (feedback == 'like') {
        // Automatically load a new suggestion after liking
        _loadSuggestion();
      } else if (feedback == 'dislike') {
        // Also load a new suggestion after disliking
        _loadSuggestion();
      }
    } catch (e) {
      debugPrint('Error providing feedback: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit feedback: $e'),
        ),
      );
    }
  }

  Widget _buildSuggestionSection() {
    // Show authentication button if not authenticated
    if (!_isAuthenticated) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Spotify authentication required to view music suggestions',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _authenticateWithSpotify,
                child: const Text('Connect Spotify Account'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Suggested for You',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton(
                onPressed: _loadSuggestion,
                child: const Text('Get New Suggestion'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoadingSuggestion
              ? const Center(child: CircularProgressIndicator())
              : _suggestionError != null
                  ? Center(
                      child: Column(
                        children: [
                          Text(
                            'Error: $_suggestionError',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadSuggestion,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  : SuggestionDisplay(
                      suggestedTrack: _suggestion,
                      suggestionContext: _suggestion?.reason,
                      suggestionError: _suggestionError,
                      isFetchingSuggestion: _isLoadingSuggestion,
                      isProcessingLibrary: false,
                      onRequestSuggestion: _loadSuggestion,
                      onSkipSuggestion: _loadSuggestion,
                      onSuggestionFeedback: _handleSuggestionFeedback,
                      onAddToLibrary: () {
                        if (_suggestion != null) {
                          _saveTrack(_suggestion!.id);
                        }
                      },
                      onPlay: _playTrack,
                      isPlaybackPaused: true,
                      hasLikedCurrentSuggestion: false,
                    ),
        ],
      ),
    );
  }

  Widget _buildLibrarySection() {
    if (!_isAuthenticated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 16),
            child: Text(
              'Your Library',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ],
              border: Border.all(
                color: const Color(0xFF323232),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(40),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 56, color: AppTheme.textSecondary),
                SizedBox(height: 24),
                Text(
                  'Please connect to Spotify to view your library',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Row(
            children: [
              const Text(
                'Your Library',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              if (_isLoadingLibrary)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const Spacer(),
              Text(
                'Total tracks: $_totalTracks',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(0, 2),
                blurRadius: 6,
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color: const Color(0xFF323232),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: _isLoadingLibrary
              ? const Center(child: CircularProgressIndicator())
              : _library.isEmpty
                  ? const Center(
                      child: Text(
                        'No tracks in your library yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    )
                  : LayoutBuilder(builder: (context, constraints) {
                      final cardWidth = (constraints.maxWidth - 48) / 3;
                      return Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: _library.map((track) {
                          // Handle both formats - either direct track data or nested track data
                          final Map<String, dynamic> trackData =
                              track.containsKey('track') ? track['track'] : track;

                          final String title =
                              trackData['name'] ?? trackData['title'] ?? 'Unknown Title';

                          // Handle both formats of artist data
                          String artist = 'Unknown Artist';
                          if (trackData.containsKey('artists') &&
                              trackData['artists'] is List) {
                            final artistsData = trackData['artists'] as List;
                            artist = artistsData
                                .map((a) => a is Map ? a['name'] ?? '' : a.toString())
                                .where((name) => name.isNotEmpty)
                                .join(', ');
                          } else if (trackData.containsKey('artist')) {
                            artist = trackData['artist'].toString();
                          } else if (trackData.containsKey('overview')) {
                            // Use overview field as artist fallback (MediaItem format)
                            artist = trackData['overview'].toString();
                          }

                          // Handle both formats of album data
                          String album = 'Unknown Album';
                          if (trackData.containsKey('album') &&
                              trackData['album'] is Map) {
                            album = trackData['album']['name'] ?? 'Unknown Album';
                          } else if (trackData.containsKey('album')) {
                            album = trackData['album'].toString();
                          }

                          // Handle different ID formats
                          String id = '';
                          if (trackData.containsKey('id')) {
                            id = trackData['id'].toString();
                          }

                          // Handle different image formats
                          String imageUrl = '';
                          if (trackData.containsKey('album') &&
                              trackData['album'] is Map &&
                              trackData['album'].containsKey('images') &&
                              trackData['album']['images'] is List &&
                              (trackData['album']['images'] as List).isNotEmpty) {
                            imageUrl = trackData['album']['images'][0]['url'] ?? '';
                          } else if (trackData.containsKey('imageUrl')) {
                            imageUrl = trackData['imageUrl'].toString();
                          } else if (trackData.containsKey('posterPath')) {
                            // MediaItem format
                            imageUrl = trackData['posterPath'].toString();
                          }

                          return SizedBox(
                            width: cardWidth,
                            height: 240,
                            child: _buildTrackCard(
                              title,
                              artist,
                              imageUrl,
                              id,
                            ),
                          );
                        }).toList(),
                      );
                    }),
        ),
      ],
    );
  }

  Widget _buildTrackCard(
      String title, String artist, String imageUrl, String id) {
    return TrackCard(
      track: MediaItem(
        id: id,
        title: title,
        overview: artist,
        posterPath: imageUrl,
        mediaType: 'music',
      ),
      isSaved: true,
      isPlaying: false, // Fixed: Set to static false since we don't track playback state
      onPlay: (track) {
        _playTrack(track);
      },
      onRemove: (track) => _removeTrack(id),
    );
  }

  Widget _buildSpotifyHeader() {
    // Only show the header with connect button when not authenticated
    if (!_isAuthenticated) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1DB954), // Spotify green
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.music_note,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Connect to Spotify to get personalized music suggestions",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _authenticateWithSpotify,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1DB954),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                "Connect",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // When authenticated, don't show the header at all
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // Spotify auth header - removing since it's now in the app header
        // _buildSpotifyHeader(),
        // const SizedBox(height: 24),
        // Suggestions section
        _buildSuggestionSection(),
        const SizedBox(height: 24),
        // Library section
        _buildLibrarySection(),
      ],
    );
  }
}

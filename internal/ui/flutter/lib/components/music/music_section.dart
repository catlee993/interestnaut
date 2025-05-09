import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/go_bindings.dart';
import '../../models.dart';
import '../common/icons.dart';
import 'suggestions/suggestion_display.dart';
import 'tracks/track_card.dart';

class MusicSection extends StatefulWidget {
  const MusicSection({super.key});

  @override
  State<MusicSection> createState() => _MusicSectionState();
}

class _MusicSectionState extends State<MusicSection> {
  bool _isLoadingLibrary = false;
  bool _isLoadingSuggestion = false;
  List<Map<String, dynamic>> _library = [];
  MediaItem? _suggestion;
  String? _suggestionError;
  int _totalTracks = 0;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
    _loadLibrary();
  }

  Future<void> _checkAuthentication() async {
    try {
      final authStatus = await GoBindings.instance.music.getAuthStatus();
      if (authStatus.containsKey('isAuthenticated')) {
        setState(() {
          _isAuthenticated = authStatus['isAuthenticated'] == true;
        });
        
        if (_isAuthenticated) {
          _loadUserProfile();
        }
      }
    } catch (e) {
      debugPrint('Error checking authentication: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await GoBindings.instance.music.getCurrentUser();
      setState(() {
        _userProfile = profile;
      });
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _loadLibrary({int limit = 50, int offset = 0}) async {
    if (!_isAuthenticated) return;
    
    setState(() {
      _isLoadingLibrary = true;
    });
    
    try {
      final response = await GoBindings.instance.music.getSavedTracks(limit, offset);
      
      if (response.containsKey('items') && response['items'] is List) {
        setState(() {
          _library = List<Map<String, dynamic>>.from(response['items'] as List);
          _totalTracks = response['total'] ?? 0;
          _isLoadingLibrary = false;
        });
      } else {
        setState(() {
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

  Future<void> _getNewSuggestion() async {
    if (!_isAuthenticated) return;
    
    setState(() {
      _isLoadingSuggestion = true;
      _suggestion = null;
      _suggestionError = null;
    });
    
    try {
      final suggestion = await GoBindings.instance.music.requestNewSuggestion();
      setState(() {
        _suggestion = suggestion;
        _isLoadingSuggestion = false;
      });
    } catch (e) {
      debugPrint('Error getting suggestion: $e');
      setState(() {
        _suggestionError = e.toString();
        _isLoadingSuggestion = false;
      });
    }
  }

  Future<void> _provideFeedback(String outcome) async {
    if (_suggestion == null) return;
    
    final title = _suggestion!.title;
    final artist = _suggestion!.overview;
    final album = ''; // We don't have album info in the MediaItem
    
    try {
      await GoBindings.instance.music.provideSuggestionFeedback(outcome, title, artist, album);
      // Show feedback confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feedback recorded: $outcome'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error providing feedback: $e');
    }
  }
  
  Future<void> _saveTrack(String trackId) async {
    try {
      await GoBindings.instance.music.saveTrack(trackId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Track saved to your library'),
          duration: Duration(seconds: 2),
        ),
      );
      // Refresh library
      _loadLibrary();
    } catch (e) {
      debugPrint('Error saving track: $e');
    }
  }
  
  Future<void> _removeTrack(String trackId) async {
    try {
      await GoBindings.instance.music.removeTrack(trackId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Track removed from your library'),
          duration: Duration(seconds: 2),
        ),
      );
      // Refresh library
      _loadLibrary();
    } catch (e) {
      debugPrint('Error removing track: $e');
    }
  }
  
  Future<void> _authenticate() async {
    // Show authentication in progress message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting Spotify authentication. Please check your browser to complete the process.'),
        duration: Duration(seconds: 5),
      ),
    );
    
    try {
      // Explicitly initiate Spotify authentication flow
      await GoBindings.instance.music.initiateSpotifyAuth();
      
      // Check authentication status after a short delay
      await Future.delayed(const Duration(seconds: 2));
      await _checkAuthentication();
      
      if (_isAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected to Spotify!'),
            duration: Duration(seconds: 3),
          ),
        );
        
        // Load user profile and library after successful authentication
        await _loadUserProfile();
        await _loadLibrary();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication did not complete. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Authentication error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication error: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
  
  Future<void> _clearAuth() async {
    try {
      await GoBindings.instance.music.clearSpotifyCredentials();
      setState(() {
        _isAuthenticated = false;
        _userProfile = null;
        _library = [];
        _suggestion = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spotify credentials cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error clearing auth: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Remove user/auth UI from here. Only show music content.
        const SizedBox(height: 24),
        // Suggestions section
        _buildSuggestionSection(),
        const SizedBox(height: 24),
        // Library section
        _buildLibrarySection(),
      ],
    );
  }
  
  Widget _buildSuggestionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            'Suggested for You',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: SuggestionDisplay(
            suggestedTrack: _suggestion,
            suggestionContext: _suggestion?.reason,
            isProcessingLibrary: _isLoadingLibrary,
            suggestionError: _suggestionError,
            isFetchingSuggestion: _isLoadingSuggestion,
            onRequestSuggestion: _getNewSuggestion,
            onSkipSuggestion: _getNewSuggestion,
            onSuggestionFeedback: _provideFeedback,
            onAddToLibrary: () {
              if (_suggestion?.id != null) {
                _saveTrack(_suggestion!.id.toString());
              }
            },
            onPlay: (track) {
              // Implementation would depend on your player system
              debugPrint('Playing ${track.title} by ${track.overview}');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLibrarySection() {
    if (!_isAuthenticated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 56, color: AppTheme.textSecondary),
                const SizedBox(height: 24),
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
              Text(
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
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => _loadLibrary(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Library',
                color: AppTheme.primaryColor,
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
                  ? Center(
                      child: Text(
                        'No tracks in your library yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = (constraints.maxWidth - 48) / 3;
                        return Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          children: _library.map((track) {
                            final trackData = track['track'] as Map<String, dynamic>;
                            final title = trackData['name'] as String;
                            final artistsData = trackData['artists'] as List;
                            final artistNames = artistsData
                                .cast<Map<String, dynamic>>()
                                .map((a) => a['name'] as String)
                                .join(', ');
                            
                            String imageUrl = '';
                            if (trackData.containsKey('album') && 
                                trackData['album'] is Map && 
                                trackData['album'].containsKey('images') && 
                                trackData['album']['images'] is List && 
                                (trackData['album']['images'] as List).isNotEmpty) {
                              imageUrl = (trackData['album']['images'] as List).first['url'] as String;
                            }
                            
                            final id = trackData['id'] as String;
                            
                            return SizedBox(
                              width: cardWidth,
                              height: 240,
                              child: _buildTrackCard(
                                title,
                                artistNames,
                                imageUrl,
                                id,
                              ),
                            );
                          }).toList(),
                        );
                      }
                    ),
        ),
      ],
    );
  }

  Widget _buildTrackCard(String title, String artist, String imageUrl, String id) {
    return TrackCard(
      track: MediaItem(
        id: id,
        title: title,
        overview: artist,
        posterPath: imageUrl,
        mediaType: 'music',
      ),
      isSaved: true,
      isPlaying: false, // Would be based on actual playback state
      onPlay: (track) {
        // Implementation would depend on your player system
        debugPrint('Playing $title by $artist');
      },
      onRemove: (track) => _removeTrack(id),
    );
  }
} 
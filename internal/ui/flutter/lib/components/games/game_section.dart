import 'dart:async';
import 'package:flutter/material.dart';
import '../common/scroll_content_wrapper.dart';
import '../common/media_grid.dart';
import '../common/media_library_grid.dart';
import '../common/suggestion_action_buttons.dart';
import '../common/loading_suggestion.dart';
import '../../services/recommendation_service.dart';
import '../../services/recommendation_event_service.dart';
import '../../services/sqlite_db.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class GameSection extends StatefulWidget {
  const GameSection({super.key});

  @override
  State<GameSection> createState() => _GameSectionState();
}

class _GameSectionState extends State<GameSection> {
  // Database suggestion state
  MediaSuggestion? _currentDbSuggestion;
  String? _dbSuggestionError;
  bool _isLoadingDbSuggestion = false;
  bool _hasLikedCurrentSuggestion = false; // Add this to track like state
  bool _hasFavoritedCurrentSuggestion = false; // Add this to track favorite state

  // Local DB library state (for liked suggestions)
  List<MediaSuggestion> _dbLikedSuggestions = [];
  bool _isLoadingDbLibrary = false;

  // Local DB playlist state
  List<MediaSuggestion> _dbPlaylistSuggestions = [];
  bool _isLoadingDbPlaylist = false;

  final RecommendationService _recommendationService = RecommendationService();
  final RecommendationEventService _eventService = RecommendationEventService();
  final SQLiteDatabase _db = SQLiteDatabase();

  @override
  void initState() {
    super.initState();
    
    // Listen for recommendation events
    _eventService.eventsForMediaType('video_game').listen((event) {
      if (event.type == RecommendationEventType.suggestionReady) {
        debugPrint('🎉 Game suggestion ready: ${event.suggestion?.title}');
        _loadDbSuggestion(); // Reload to get the new suggestion
      }
    });
    
    // Load initial DB suggestion
    _loadDbSuggestion();
    // Load DB library and playlist
    _loadDbLibrary();
    _loadDbPlaylist();
  }

  // Load a DB suggestion for video games
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
      // First check if the video game database is available
      final databaseStatus = await _recommendationService.getMediaTypeStatus('video_game');
      final isDatabaseAvailable = databaseStatus == 'available';
      
      if (!isDatabaseAvailable) {
        setState(() {
          _currentDbSuggestion = null;
          _dbSuggestionError = null; // No error, just database not installed
          _isLoadingDbSuggestion = false;
        });
        return;
      }
      
      final suggestions = await _db.getPendingSuggestionsNotInWatchlist('video_game');
      
      if (suggestions.isNotEmpty) {
        setState(() {
          _currentDbSuggestion = suggestions.first;
          _isLoadingDbSuggestion = false;
          // Reset button states for the new suggestion
          _hasLikedCurrentSuggestion = false;
          _hasFavoritedCurrentSuggestion = false;
        });
      } else {
        // Try to generate a new suggestion on-demand
        final loadingSuggestion = await _recommendationService.generateSuggestionOnDemand('video_game');
        if (loadingSuggestion != null) {
          // Don't set the loading suggestion as current - just keep loading state
          setState(() {
            _currentDbSuggestion = null; // Clear current suggestion
            _isLoadingDbSuggestion = true; // Keep loading until real suggestion arrives
            _hasLikedCurrentSuggestion = false;
            _hasFavoritedCurrentSuggestion = false;
          });
        } else {
          setState(() {
            _currentDbSuggestion = null;
            _dbSuggestionError = 'Unable to generate video game suggestions. Make sure TinyLlama model is installed.';
            _isLoadingDbSuggestion = false;
            _hasLikedCurrentSuggestion = false;
            _hasFavoritedCurrentSuggestion = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _dbSuggestionError = 'Error loading suggestions: $e';
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Load DB library (only favorited/added suggestions)
  Future<void> _loadDbLibrary() async {
    setState(() {
      _isLoadingDbLibrary = true;
    });

    try {
      final suggestions = await _recommendationService.getSuggestions('video_game');
      final libraryItems = suggestions.where((s) => 
        s.status == SuggestionStatus.added
      ).toList();
      
      setState(() {
        _dbLikedSuggestions = libraryItems;
        _isLoadingDbLibrary = false;
      });
    } catch (e) {
      debugPrint('Error loading DB library: $e');
      setState(() {
        _isLoadingDbLibrary = false;
      });
    }
  }

  // Load DB playlist
  Future<void> _loadDbPlaylist() async {
    setState(() {
      _isLoadingDbPlaylist = true;
    });

    try {
      final playlistItems = await _db.getWatchlist('video_game');
      setState(() {
        _dbPlaylistSuggestions = playlistItems;
        _isLoadingDbPlaylist = false;
      });
    } catch (e) {
      debugPrint('Error loading DB playlist: $e');
      setState(() {
        _isLoadingDbPlaylist = false;
      });
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

      // Load next suggestion after favoriting
      await _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
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
        final isInPlaylist = await _db.isInWatchlist(_currentDbSuggestion!.id);
        if (isInPlaylist) {
          await _db.removeFromWatchlist(_currentDbSuggestion!.id);
          _loadDbPlaylist(); // Refresh playlist
        }
      }
      
      // Set status to disliked (this will remove from favorites if favorited)
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.disliked,
      );
      
      // Refresh library in case item was favorited
      _loadDbLibrary();

      await _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error disliking DB suggestion: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Skip a database suggestion
  Future<void> _skipDbSuggestion() async {
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) return;

    setState(() {
      _isLoadingDbSuggestion = true;
    });

    try {
      // Only change status to skipped if the item is not already favorited
      if (!_hasFavoritedCurrentSuggestion && !_hasLikedCurrentSuggestion) {
        await _recommendationService.updateSuggestionStatus(
          _currentDbSuggestion!.id,
          SuggestionStatus.skipped,
        );
      }

      await _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error skipping DB suggestion: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Add database suggestion to playlist and move to next
  Future<void> _addDbSuggestionToPlaylist() async {
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) return;

    setState(() {
      _isLoadingDbSuggestion = true;
    });

    try {
      await _db.addToWatchlist(_currentDbSuggestion!.id);

      // Immediately update local state so button updates right away
      setState(() {
        _dbPlaylistSuggestions.add(_currentDbSuggestion!);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to playlist'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh playlist in background to ensure consistency
      _loadDbPlaylist();

      // Load next suggestion
      await _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error adding DB suggestion to playlist: $e');
      // Revert local state on error
      setState(() {
        _dbPlaylistSuggestions.removeWhere((item) => item.id == _currentDbSuggestion!.id);
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Build playlist section
  Widget _buildDbPlaylistSection() {
    return MediaLibraryGrid(
      suggestions: _dbPlaylistSuggestions,
      mediaType: 'video_game',
      isWatchlist: true,
      onRemove: _removeFromPlaylist,
      onLike: _likePlaylistItem,
      onDislike: _dislikePlaylistItem,
      onFavorite: _favoritePlaylistItem,
    );
  }

  // Build library section
  Widget _buildDbLibrarySection() {
    return MediaLibraryGrid(
      suggestions: _dbLikedSuggestions,
      mediaType: 'video_game',
      isWatchlist: false,
      onAddToWatchlist: _addLibraryItemToPlaylist,
      onUnfavorite: _removeFromLibrary,
      watchlistItems: _dbPlaylistSuggestions,
    );
  }



  // Remove from playlist
  Future<void> _removeFromPlaylist(MediaSuggestion suggestion) async {
    try {
      await _db.removeFromWatchlist(suggestion.id);
      
      // Immediately update local state so UI updates right away
      setState(() {
        _dbPlaylistSuggestions.removeWhere((item) => item.id == suggestion.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${suggestion.title}" from playlist'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Refresh playlist in background to ensure consistency
      _loadDbPlaylist();
    } catch (e) {
      debugPrint('Error removing from playlist: $e');
      // Revert local state on error
      setState(() {
        _dbPlaylistSuggestions.add(suggestion);
      });
    }
  }

  // Dislike a playlist item
  Future<void> _dislikePlaylistItem(MediaSuggestion suggestion) async {
    try {
      await _db.removeFromWatchlist(suggestion.id);
      
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.disliked,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disliked "${suggestion.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      _loadDbPlaylist();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error disliking playlist item: $e');
    }
  }

  // Like a playlist item
  Future<void> _likePlaylistItem(MediaSuggestion suggestion) async {
    try {
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
          content: Text('Liked "${suggestion.title}" - removed from playlist'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      _loadDbPlaylist();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error liking playlist item: $e');
    }
  }

  // Favorite a playlist item
  Future<void> _favoritePlaylistItem(MediaSuggestion suggestion) async {
    try {
      await _db.removeFromWatchlist(suggestion.id);
      
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.added,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Favorited "${suggestion.title}" - removed from playlist'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      _loadDbPlaylist();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error favoriting playlist item: $e');
    }
  }

  // Add library item to playlist
  Future<void> _addLibraryItemToPlaylist(MediaSuggestion suggestion) async {
    try {
      await _db.addToWatchlist(suggestion.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${suggestion.title}" to playlist'),
          duration: const Duration(seconds: 2),
        ),
      );

      _loadDbPlaylist();
    } catch (e) {
      debugPrint('Error adding library item to playlist: $e');
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ScrollContentWrapper(
          headerHeight: 60.0,
          builder: (scrollOffset) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
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
                    const LoadingSuggestion(mediaType: 'video_game')
                  else if (_dbSuggestionError != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                            ElevatedButton(
                              onPressed: _loadDbSuggestion,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_currentDbSuggestion == null)
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
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF282828),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Game cover
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
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
                                              Icons.videogame_asset,
                                              size: 48,
                                              color: Colors.white54,
                                            ),
                                          );
                                        },
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.videogame_asset,
                                          size: 48,
                                          color: Colors.white54,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              
                              // Game info
                              Expanded(
                                child: SizedBox(
                                  height: 450,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Game title
                                      Text(
                                        _currentDbSuggestion!.title ?? 'Unknown Title',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      // Developer info
                                      Text(
                                        'by ${_currentDbSuggestion!.artist ?? 'Unknown Developer'}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.white.withOpacity(0.7),
                                          fontWeight: FontWeight.w400,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Description text
                                      if (_currentDbSuggestion?.description?.isNotEmpty == true)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
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
                                      
                                      Expanded(child: Container()),
                                      
                                      // Bot reasoning
                                      if (_currentDbSuggestion?.botReasoning?.isNotEmpty == true)
                                        Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(bottom: 24),
                                          child: Column(
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
                                              Text(
                                                _currentDbSuggestion!.botReasoning!,
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.6),
                                                  fontSize: 14,
                                                  height: 1.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              
                                              // Action buttons using generic component
                                              const SizedBox(height: 24),
                                              SuggestionActionButtons(
                                                mediaType: 'video_game',
                                                hasLikedCurrentSuggestion: _hasLikedCurrentSuggestion, // Use the new state
                                                hasFavoritedCurrentSuggestion: _hasFavoritedCurrentSuggestion,
                                                isInWatchlist: _currentDbSuggestion != null && 
                                                  _dbPlaylistSuggestions.any((item) => item.id == _currentDbSuggestion!.id),
                                                isProcessing: _isLoadingDbSuggestion,
                                                onLike: _likeDbSuggestion,
                                                onDislike: _dislikeDbSuggestion,
                                                onFavorite: _addToFavorites, // Use the new method
                                                onUnfavorite: _removeFromFavorites, // Added this method
                                                onAddToWatchlist: () {
                                                  final inPlaylist = _currentDbSuggestion != null && 
                                                    _dbPlaylistSuggestions.any((item) => item.id == _currentDbSuggestion!.id);
                                                  if (inPlaylist) {
                                                    if (_currentDbSuggestion != null) {
                                                      _removeFromPlaylist(_currentDbSuggestion!);
                                                    }
                                                  } else {
                                                    _addDbSuggestionToPlaylist();
                                                  }
                                                },
                                                onSkip: _skipDbSuggestion,
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
                
                // Playlist section
                if (_dbPlaylistSuggestions.isNotEmpty || _isLoadingDbPlaylist) ...[
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
                      child: Center(
                        child: Text(
                          'No games in your playlist yet. Add suggestions to your playlist to see them here.',
                          style: TextStyle(color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    _buildDbPlaylistSection(),
                ],
                
                // Library section
                if (_dbLikedSuggestions.isNotEmpty || _isLoadingDbLibrary) ...[
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
                          'No games in your library yet. Favorite suggestions to see them here.',
                          style: TextStyle(color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    _buildDbLibrarySection(),
                ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
} 
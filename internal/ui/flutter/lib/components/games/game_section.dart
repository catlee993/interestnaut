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

  StreamSubscription<RecommendationEvent>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    
    // Listen to recommendation events for this media type
    _eventSubscription = _eventService.eventsForMediaType('video_game').listen((event) {
      debugPrint('🎮 Game section received event: ${event.type}');
      switch (event.type) {
        case RecommendationEventType.suggestionReady:
          if (event.suggestion != null) {
            setState(() {
              _currentDbSuggestion = event.suggestion;
              _isLoadingDbSuggestion = false;
              _dbSuggestionError = null;
              _hasLikedCurrentSuggestion = false;
              _hasFavoritedCurrentSuggestion = false;
            });
          }
          break;
        case RecommendationEventType.suggestionError:
          setState(() {
            _dbSuggestionError = event.error ?? 'Unknown error';
            _isLoadingDbSuggestion = false;
          });
          break;
        case RecommendationEventType.suggestionStarted:
          // Loading state is already set when we call generateSuggestionOnDemand
          break;
      }
    });
    
    _loadDbSuggestion();
    _loadDbLibrary();
    _loadDbPlaylist();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
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
        // Try to generate a new suggestion on-demand (non-blocking)
        final loadingSuggestion = await _recommendationService.generateSuggestionOnDemand('video_game');
        if (loadingSuggestion != null) {
          // Set loading state immediately - actual suggestion will come via events
          setState(() {
            _currentDbSuggestion = null; // Clear current suggestion
            _isLoadingDbSuggestion = true; // Keep loading until real suggestion arrives via events
            _dbSuggestionError = null;
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

  // Move to next suggestion (for both skip and next actions) - FULLY NON-BLOCKING
  void _moveToNextSuggestion() {
    try {
      // Immediate UI update - clear current suggestion and show loading
      setState(() {
        _isLoadingDbSuggestion = true;
        _currentDbSuggestion = null;
        _dbSuggestionError = null;
        _hasLikedCurrentSuggestion = false; // Reset like state
        _hasFavoritedCurrentSuggestion = false; // Reset favorite state
      });
      
      // DON'T call _loadDbSuggestion() - let the action handler trigger new generation
      // The event system will handle delivering the next suggestion
      debugPrint('🎮 Cleared current suggestion - waiting for events to deliver next one');
    } catch (e) {
      debugPrint('Error moving to next suggestion: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
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

      // Move to next suggestion after favoriting (non-blocking)
      _moveToNextSuggestion();
      
      // Trigger new suggestion generation (non-blocking)
      _recommendationService.generateSuggestionOnDemand('video_game').then((loadingSuggestion) {
        if (loadingSuggestion != null) {
          debugPrint('🎮 New suggestion generation started after favorite');
        } else {
          debugPrint('🎮 No immediate suggestion available - background generation in progress');
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _dbSuggestionError = 'Error generating suggestion: $e';
            _isLoadingDbSuggestion = false;
          });
        }
      });
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

      // Move to next suggestion after disliking (non-blocking)
      _moveToNextSuggestion();
      
      // Trigger new suggestion generation (non-blocking)
      _recommendationService.generateSuggestionOnDemand('video_game').then((loadingSuggestion) {
        if (loadingSuggestion != null) {
          debugPrint('🎮 New suggestion generation started after dislike');
        } else {
          debugPrint('🎮 No immediate suggestion available - background generation in progress');
          
          // Set 30-second timeout for background generation
          Timer(const Duration(seconds: 30), () {
            if (mounted && _isLoadingDbSuggestion && _currentDbSuggestion == null) {
              setState(() {
                _dbSuggestionError = 'Suggestion generation timed out. Please try again.';
                _isLoadingDbSuggestion = false;
              });
            }
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _dbSuggestionError = 'Error generating suggestion: $e';
            _isLoadingDbSuggestion = false;
          });
        }
      });
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

      // Move to next suggestion after skipping (non-blocking)
      _moveToNextSuggestion();
      
      // Trigger new suggestion generation (non-blocking)
      _recommendationService.generateSuggestionOnDemand('video_game').then((loadingSuggestion) {
        if (loadingSuggestion != null) {
          debugPrint('🎮 New suggestion generation started after skip');
        } else {
          debugPrint('🎮 No immediate suggestion available - background generation in progress');
          
          // Set 30-second timeout for background generation
          Timer(const Duration(seconds: 30), () {
            if (mounted && _isLoadingDbSuggestion && _currentDbSuggestion == null) {
              setState(() {
                _dbSuggestionError = 'Suggestion generation timed out. Please try again.';
                _isLoadingDbSuggestion = false;
              });
            }
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _dbSuggestionError = 'Error generating suggestion: $e';
            _isLoadingDbSuggestion = false;
          });
        }
      });
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

      // Update suggestion status so it's no longer pending (won't appear in queue again)
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.watchlist, // Mark as watchlisted for future LLM learning
      );

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

      // Move to next suggestion after adding to playlist (non-blocking)
      _moveToNextSuggestion();
      
      // Trigger new suggestion generation (non-blocking)
      _recommendationService.generateSuggestionOnDemand('video_game').then((loadingSuggestion) {
        if (loadingSuggestion != null) {
          debugPrint('🎮 New suggestion generation started after playlist');
        } else {
          debugPrint('🎮 No immediate suggestion available - background generation in progress');
          
          // Set 30-second timeout for background generation
          Timer(const Duration(seconds: 30), () {
            if (mounted && _isLoadingDbSuggestion && _currentDbSuggestion == null) {
              setState(() {
                _dbSuggestionError = 'Suggestion generation timed out. Please try again.';
                _isLoadingDbSuggestion = false;
              });
            }
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _dbSuggestionError = 'Error generating suggestion: $e';
            _isLoadingDbSuggestion = false;
          });
        }
      });
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
        // Main content using universal layout system
        MediaSectionLayout(
          headerHeight: 106.0,
          builder: (scrollOffset) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                
                // Library section with proper spacing
                SectionSpacing(
                  child: _buildLibrarySection(),
                ),
                
                // Playlist section with proper spacing
                SectionSpacing(
                  child: _buildPlaylistSection(),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // Helper method to build suggestion content
  Widget _buildSuggestionContent(double scrollOffset) {
    if (_isLoadingDbSuggestion) {
      return const LoadingSuggestion(mediaType: 'video_game');
    } else if (_dbSuggestionError != null) {
      return Center(
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
      );
    } else if (_currentDbSuggestion == null) {
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
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game cover
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8C86E2).withOpacity(0.7), // Reasoning color
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10), // Slightly smaller to account for border
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
                    
                    // Flexible content area for description and reasoning
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            children: [
                              // Description text - flexible height
                              if (_currentDbSuggestion?.description?.isNotEmpty == true)
                                Flexible(
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
                                ),
                              
                              const SizedBox(height: 16),
                              
                              // Bot reasoning - flexible height
                              if (_currentDbSuggestion?.botReasoning?.isNotEmpty == true)
                                Flexible(
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
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
                                        Flexible(
                                          child: SingleChildScrollView(
                                            child: Text(
                                              _currentDbSuggestion!.botReasoning!,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white.withOpacity(0.6),
                                                height: 1.5,
                                                fontWeight: FontWeight.w400,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    
                    // Action buttons using generic component
                    SuggestionActionButtons(
                      mediaType: 'video_game',
                      hasLikedCurrentSuggestion: _hasLikedCurrentSuggestion,
                      hasFavoritedCurrentSuggestion: _hasFavoritedCurrentSuggestion,
                      isInWatchlist: _currentDbSuggestion != null && 
                        _dbPlaylistSuggestions.any((item) => item.id == _currentDbSuggestion!.id),
                      isProcessing: _isLoadingDbSuggestion,
                      onLike: _likeDbSuggestion,
                      onDislike: _dislikeDbSuggestion,
                      onFavorite: _addToFavorites,
                      onUnfavorite: _removeFromFavorites,
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
            ),
          ],
        ),
      );
    }
  }

  // Helper method to build library section
  Widget _buildLibrarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Library',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (_dbLikedSuggestions.isNotEmpty)
              Text(
                '${_dbLikedSuggestions.length} games',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingDbLibrary)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_dbLikedSuggestions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF282828),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'No games in your library yet.\nFavorite games to see them here!',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          MediaLibraryGrid(
            suggestions: _dbLikedSuggestions,
            watchlistItems: _dbPlaylistSuggestions,
            mediaType: 'video_game',
            isWatchlist: false,
            onRemove: (suggestion) async {
              await _removeFromLibrary(suggestion);
            },
            onLike: (suggestion) async {
              await _recommendationService.updateSuggestionStatus(
                suggestion.id,
                SuggestionStatus.liked,
              );
            },
            onDislike: (suggestion) async {
              await _recommendationService.updateSuggestionStatus(
                suggestion.id,
                SuggestionStatus.disliked,
              );
            },
            onAddToWatchlist: (suggestion) async {
              await _addLibraryItemToPlaylist(suggestion);
            },
            onRemoveFromWatchlist: (suggestion) async {
              await _removeFromPlaylist(suggestion);
            },
            onFavorite: (suggestion) async {
              await _recommendationService.updateSuggestionStatus(
                suggestion.id,
                SuggestionStatus.added,
              );
            },
            onUnfavorite: (suggestion) async {
              await _removeFromLibrary(suggestion);
            },
          ),
      ],
    );
  }

  // Helper method to build playlist section
  Widget _buildPlaylistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Want to Play',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (_dbPlaylistSuggestions.isNotEmpty)
              Text(
                '${_dbPlaylistSuggestions.length} games',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingDbPlaylist)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_dbPlaylistSuggestions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF282828),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'No games in your playlist yet.\nAdd games you want to play later!',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          MediaLibraryGrid(
            suggestions: _dbPlaylistSuggestions,
            watchlistItems: _dbPlaylistSuggestions,
            mediaType: 'video_game',
            isWatchlist: true,
            onRemove: (suggestion) async {
              await _removeFromPlaylist(suggestion);
            },
            onLike: (suggestion) async {
              await _recommendationService.updateSuggestionStatus(
                suggestion.id,
                SuggestionStatus.liked,
              );
            },
            onDislike: (suggestion) async {
              await _recommendationService.updateSuggestionStatus(
                suggestion.id,
                SuggestionStatus.disliked,
              );
            },
            onAddToWatchlist: (suggestion) async {
              // Already in watchlist, no action needed
            },
            onRemoveFromWatchlist: (suggestion) async {
              await _removeFromPlaylist(suggestion);
            },
            onFavorite: (suggestion) async {
              await _recommendationService.updateSuggestionStatus(
                suggestion.id,
                SuggestionStatus.added,
              );
            },
            onUnfavorite: (suggestion) async {
              await _removeFromLibrary(suggestion);
            },
          ),
      ],
    );
  }


} 
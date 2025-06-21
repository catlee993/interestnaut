import 'dart:async';
import 'package:flutter/material.dart';
import '../common/scroll_content_wrapper.dart';
import '../common/media_library_grid.dart';
import '../common/suggestion_action_buttons.dart';
import '../common/loading_suggestion.dart';
import '../../services/recommendation_service.dart';
import '../../services/recommendation_event_service.dart';
import '../../services/sqlite_db.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/text_utils.dart';


class MovieSection extends StatefulWidget {
  const MovieSection({super.key});

  @override
  State<MovieSection> createState() => _MovieSectionState();
}

class _MovieSectionState extends State<MovieSection> {
  // Database suggestion state
  MediaSuggestion? _currentDbSuggestion;
  String? _dbSuggestionError;
  bool _isLoadingDbSuggestion = false;
  bool _hasLikedCurrentSuggestion = false;
  bool _hasFavoritedCurrentSuggestion = false;

  // Local DB library state (for liked suggestions)
  List<MediaSuggestion> _dbLikedSuggestions = [];
  bool _isLoadingDbLibrary = false;

  // Local DB watchlist state
  List<MediaSuggestion> _dbWatchlistSuggestions = [];
  bool _isLoadingDbWatchlist = false;

  final RecommendationService _recommendationService = RecommendationService();
  final RecommendationEventService _eventService = RecommendationEventService();
  final SQLiteDatabase _db = SQLiteDatabase();

  @override
  void initState() {
    super.initState();
    
    // Listen for recommendation events
    _eventService.eventsForMediaType('movie').listen((event) {
      if (event.type == RecommendationEventType.suggestionReady) {
        debugPrint('🎉 Movie suggestion ready: ${event.suggestion?.title}');
        _loadDbSuggestion(); // Reload to get the new suggestion
      }
    });
    
    // Load initial DB suggestion
    _loadDbSuggestion();
    // Load DB library and watchlist
    _loadDbLibrary();
    _loadDbWatchlist();
  }

  // Load a DB suggestion for movies
  Future<void> _loadDbSuggestion() async {
    debugPrint('📱 _loadDbSuggestion called - current isLoading: $_isLoadingDbSuggestion');
    
    // Only set loading state if not already loading (to avoid nested loading states)
    final wasAlreadyLoading = _isLoadingDbSuggestion;
    if (!wasAlreadyLoading) {
      debugPrint('📱 _loadDbSuggestion setting loading to true (was not already loading)');
      setState(() {
        _isLoadingDbSuggestion = true;
      });
    } else {
      debugPrint('📱 _loadDbSuggestion skipping loading state change (already loading)');
    }
    
    debugPrint('📱 _loadDbSuggestion resetting button states - before: liked=$_hasLikedCurrentSuggestion, favorited=$_hasFavoritedCurrentSuggestion');
    setState(() {
      _dbSuggestionError = null;
      _hasLikedCurrentSuggestion = false; // Reset like state
      _hasFavoritedCurrentSuggestion = false; // Reset favorite state
    });
    debugPrint('📱 _loadDbSuggestion button states reset - after: liked=$_hasLikedCurrentSuggestion, favorited=$_hasFavoritedCurrentSuggestion');

    // Give the UI a chance to update and show the loading state
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      debugPrint('📱 _loadDbSuggestion checking database status');
      // First check if the movie database is available
      final databaseStatus = await _recommendationService.getMediaTypeStatus('movie');
      final isDatabaseAvailable = databaseStatus == 'available';
      
      if (!isDatabaseAvailable) {
        debugPrint('📱 _loadDbSuggestion database not available, setting loading to false');
        setState(() {
          _currentDbSuggestion = null;
          _dbSuggestionError = null; // No error, just database not installed
          _isLoadingDbSuggestion = false;
        });
        return;
      }
      
      debugPrint('📱 _loadDbSuggestion fetching pending suggestions');
      final allSuggestions = await _db.getPendingSuggestionsNotInWatchlist('movie');
      
      // Filter out the current suggestion to avoid loading the same one
      final suggestions = allSuggestions.where((s) => 
        _currentDbSuggestion == null || s.id != _currentDbSuggestion!.id
      ).toList();
      
      debugPrint('📱 _loadDbSuggestion found ${allSuggestions.length} total pending, ${suggestions.length} after filtering current');
      
      if (suggestions.isNotEmpty) {
        debugPrint('📱 _loadDbSuggestion using suggestion: ${suggestions.first.title}');
        setState(() {
          _currentDbSuggestion = suggestions.first;
          _isLoadingDbSuggestion = false;
          // Reset button states for the new suggestion
          _hasLikedCurrentSuggestion = false;
          _hasFavoritedCurrentSuggestion = false;
        });
      } else {
        debugPrint('📱 _loadDbSuggestion no pending suggestions, generating on-demand');
        // Try to generate a new suggestion on-demand
        final loadingSuggestion = await _recommendationService.generateSuggestionOnDemand('movie');
        if (loadingSuggestion != null) {
          debugPrint('📱 _loadDbSuggestion started background generation');
          // Don't set the loading suggestion as current - just keep loading state
          setState(() {
            _currentDbSuggestion = null; // Clear current suggestion
            _isLoadingDbSuggestion = true; // Keep loading until real suggestion arrives
            _hasLikedCurrentSuggestion = false;
            _hasFavoritedCurrentSuggestion = false;
          });
        } else {
          debugPrint('📱 _loadDbSuggestion failed to generate suggestion, setting error');
          setState(() {
            _currentDbSuggestion = null;
            _dbSuggestionError = 'Unable to generate movie suggestions. Make sure TinyLlama model is installed.';
            _isLoadingDbSuggestion = false;
            // Reset button states when no suggestion available
            _hasLikedCurrentSuggestion = false;
            _hasFavoritedCurrentSuggestion = false;
          });
        }
      }
    } catch (e) {
      debugPrint('📱 _loadDbSuggestion error: $e, setting loading to false');
      setState(() {
        _dbSuggestionError = 'Error loading suggestions: $e';
        _isLoadingDbSuggestion = false;
      });
    }
    
    debugPrint('📱 _loadDbSuggestion completed - final isLoading: $_isLoadingDbSuggestion, suggestion: ${_currentDbSuggestion?.title}');
  }

  // Load DB library (liked/added suggestions)
  Future<void> _loadDbLibrary() async {
    debugPrint('📚 _loadDbLibrary called');
    setState(() {
      _isLoadingDbLibrary = true;
    });

    try {
      debugPrint('📚 _loadDbLibrary fetching all suggestions');
      final suggestions = await _recommendationService.getSuggestions('movie');
      debugPrint('📚 _loadDbLibrary found ${suggestions.length} total suggestions');
      
      final libraryItems = suggestions.where((s) => 
        s.status == SuggestionStatus.added
      ).toList();
      
      debugPrint('📚 _loadDbLibrary filtered to ${libraryItems.length} library items');
      for (final item in libraryItems) {
        debugPrint('📚   - ${item.title} (status: ${item.status})');
      }
      
      setState(() {
        _dbLikedSuggestions = libraryItems;
        _isLoadingDbLibrary = false;
      });
      debugPrint('📚 _loadDbLibrary completed - final count: ${_dbLikedSuggestions.length}');
    } catch (e) {
      debugPrint('📚 Error loading DB library: $e');
      setState(() {
        _isLoadingDbLibrary = false;
      });
    }
  }

  // Load DB watchlist
  Future<void> _loadDbWatchlist() async {
    debugPrint('📋 _loadDbWatchlist called');
    setState(() {
      _isLoadingDbWatchlist = true;
    });

    try {
      debugPrint('📋 _loadDbWatchlist fetching watchlist items');
      final watchlistItems = await _db.getWatchlist('movie');
      debugPrint('📋 _loadDbWatchlist found ${watchlistItems.length} watchlist items');
      for (final item in watchlistItems) {
        debugPrint('📋   - ${item.title}');
      }
      
      setState(() {
        _dbWatchlistSuggestions = watchlistItems;
        _isLoadingDbWatchlist = false;
      });
      debugPrint('📋 _loadDbWatchlist completed - final count: ${_dbWatchlistSuggestions.length}');
    } catch (e) {
      debugPrint('📋 Error loading DB watchlist: $e');
      setState(() {
        _isLoadingDbWatchlist = false;
      });
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

  // Like a database suggestion (just sets liked status, doesn't add to library)
  Future<void> _likeDbSuggestion() async {
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) return;

    setState(() {
      _isLoadingDbSuggestion = true;
    });

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
    } finally {
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Add to favorites and move to next suggestion
  Future<void> _addToFavorites() async {
    debugPrint('💜 _addToFavorites called - isLoading: $_isLoadingDbSuggestion, currentSuggestion: ${_currentDbSuggestion?.title}');
    
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) {
      debugPrint('💜 _addToFavorites early return - isLoading: $_isLoadingDbSuggestion, currentSuggestion null: ${_currentDbSuggestion == null}');
      return;
    }

    debugPrint('💜 _addToFavorites setting loading to true');
    setState(() {
      _isLoadingDbSuggestion = true;
    });

    try {
      debugPrint('💜 _addToFavorites updating status to added');
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.added,
      );

      debugPrint('💜 _addToFavorites setting favorited state to true');
      setState(() {
        _hasFavoritedCurrentSuggestion = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to your favorites'),
          duration: const Duration(seconds: 2),
        ),
      );

      debugPrint('💜 _addToFavorites loading library');
      _loadDbLibrary();

      debugPrint('💜 _addToFavorites loading next suggestion');
      // Load next suggestion after favoriting
      await _loadDbSuggestion();
    } catch (e) {
      debugPrint('💜 Error adding to favorites: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Remove from favorites
  Future<void> _removeFromFavorites() async {
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) return;

    setState(() {
      _isLoadingDbSuggestion = true;
    });

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
    } finally {
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Dislike a database suggestion
  Future<void> _dislikeDbSuggestion() async {
    debugPrint('🔴 _dislikeDbSuggestion called - isLoading: $_isLoadingDbSuggestion, currentSuggestion: ${_currentDbSuggestion?.title}');
    
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) {
      debugPrint('🔴 _dislikeDbSuggestion early return - isLoading: $_isLoadingDbSuggestion, currentSuggestion null: ${_currentDbSuggestion == null}');
      return;
    }

    debugPrint('🔴 _dislikeDbSuggestion setting loading to true');
    setState(() {
      _isLoadingDbSuggestion = true;
    });

    try {
      debugPrint('🔴 _dislikeDbSuggestion currentSuggestion ID: ${_currentDbSuggestion!.id}');
      
      // Check if ID is valid
      if (_currentDbSuggestion!.id <= 0) {
        debugPrint('🔴 _dislikeDbSuggestion invalid ID, skipping watchlist check');
      } else {
        debugPrint('🔴 _dislikeDbSuggestion checking watchlist status');
        // First, check if item is in watchlist and remove it
        final isInWatchlist = await _db.isInWatchlist(_currentDbSuggestion!.id);
        if (isInWatchlist) {
          debugPrint('🔴 _dislikeDbSuggestion removing from watchlist');
          await _db.removeFromWatchlist(_currentDbSuggestion!.id);
          // Refresh watchlist since item was removed from there too
          _loadDbWatchlist();
        }
      }
      
      debugPrint('🔴 _dislikeDbSuggestion updating status to disliked');
      // Then set status to disliked (this will remove from favorites if favorited)
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.disliked,
      );
      
      // Refresh library in case item was favorited
      _loadDbLibrary();

      // Small delay to ensure database update is committed
      debugPrint('🔴 _dislikeDbSuggestion waiting for database update to commit');
      await Future.delayed(const Duration(milliseconds: 100));

      debugPrint('🔴 _dislikeDbSuggestion calling _loadDbSuggestion');
      // Get next suggestion
      await _loadDbSuggestion();
      debugPrint('🔴 _dislikeDbSuggestion completed _loadDbSuggestion');
    } catch (e) {
      debugPrint('🔴 Error disliking DB suggestion: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Skip a database suggestion
  Future<void> _skipDbSuggestion() async {
    debugPrint('⏭️ _skipDbSuggestion called - isLoading: $_isLoadingDbSuggestion, currentSuggestion: ${_currentDbSuggestion?.title}');
    
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) {
      debugPrint('⏭️ _skipDbSuggestion early return - isLoading: $_isLoadingDbSuggestion, currentSuggestion null: ${_currentDbSuggestion == null}');
      return;
    }

    debugPrint('⏭️ _skipDbSuggestion setting loading to true');
    setState(() {
      _isLoadingDbSuggestion = true;
    });

    try {
      // Only change status to skipped if the item is not already favorited
      if (!_hasFavoritedCurrentSuggestion && !_hasLikedCurrentSuggestion) {
        debugPrint('⏭️ _skipDbSuggestion updating status to skipped (not favorited/liked)');
        await _recommendationService.updateSuggestionStatus(
          _currentDbSuggestion!.id,
          SuggestionStatus.skipped,
        );
      } else {
        debugPrint('⏭️ _skipDbSuggestion skipping status update (already favorited/liked)');
      }

      // Small delay to ensure database update is committed
      debugPrint('⏭️ _skipDbSuggestion waiting for database update to commit');
      await Future.delayed(const Duration(milliseconds: 100));

      debugPrint('⏭️ _skipDbSuggestion calling _loadDbSuggestion');
      // Get next suggestion
      await _loadDbSuggestion();
      debugPrint('⏭️ _skipDbSuggestion completed _loadDbSuggestion');
    } catch (e) {
      debugPrint('⏭️ Error skipping DB suggestion: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Add database suggestion to watchlist and move to next
  Future<void> _addDbSuggestionToWatchlist() async {
    debugPrint('📚 _addDbSuggestionToWatchlist called - currentSuggestion: ${_currentDbSuggestion?.title}');
    
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) {
      debugPrint('📚 _addDbSuggestionToWatchlist early return - currentSuggestion is null or loading');
      return;
    }

    setState(() {
      _isLoadingDbSuggestion = true;
    });

    try {
      debugPrint('📚 _addDbSuggestionToWatchlist adding to watchlist table');
      // Add to watchlist table instead of changing status
      await _db.addToWatchlist(_currentDbSuggestion!.id);

      debugPrint('📚 _addDbSuggestionToWatchlist updating local state');
      // Immediately update local state so button updates right away
      setState(() {
        _dbWatchlistSuggestions.add(_currentDbSuggestion!);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to watchlist'),
          duration: const Duration(seconds: 2),
        ),
      );

      debugPrint('📚 _addDbSuggestionToWatchlist refreshing watchlist');
      // Refresh watchlist in background to ensure consistency
      _loadDbWatchlist();

      debugPrint('📚 _addDbSuggestionToWatchlist loading next suggestion');
      // Load next suggestion
      await _loadDbSuggestion();
      
    } catch (e) {
      debugPrint('📚 Error adding DB suggestion to watchlist: $e');
      // Revert local state on error
      setState(() {
        _dbWatchlistSuggestions.removeWhere((item) => item.id == _currentDbSuggestion!.id);
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Build watchlist section
  Widget _buildDbWatchlistSection() {
    return MediaLibraryGrid(
      suggestions: _dbWatchlistSuggestions,
      mediaType: 'movie',
      isWatchlist: true,
      onRemove: _removeFromWatchlist,
      onLike: _likeWatchlistItem,
      onDislike: _dislikeWatchlistItem,
      onFavorite: _favoriteWatchlistItem,
    );
  }

  // Build library section
  Widget _buildDbLibrarySection() {
    return MediaLibraryGrid(
      suggestions: _dbLikedSuggestions,
      mediaType: 'movie',
      isWatchlist: false,
      onAddToWatchlist: _addLibraryItemToWatchlist,
      onUnfavorite: _removeFromLibrary,
      watchlistItems: _dbWatchlistSuggestions,
    );
  }

  // Build a suggestion card widget
  Widget _buildSuggestionCard(
    MediaSuggestion suggestion, {
    VoidCallback? onRemove,
    VoidCallback? onLike,
    VoidCallback? onDislike,
    bool showWatchlistActions = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Movie poster
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: suggestion.coverArtUrl != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                      suggestion.coverArtUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.movie,
                            size: 48,
                            color: Colors.white54,
                          ),
                        );
                      },
                    ),
                  )
                : const Center(
                    child: Icon(
                      Icons.movie,
                      size: 48,
                      color: Colors.white54,
                    ),
                  ),
            ),
          ),
          
          // Movie info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title ?? 'Unknown Title',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion.artist ?? 'Unknown Director',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                // Action buttons for watchlist items
                if (showWatchlistActions) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: onLike,
                        icon: const Icon(Icons.thumb_up, size: 16),
                        color: Colors.green,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      ),
                      IconButton(
                        onPressed: onDislike,
                        icon: const Icon(Icons.thumb_down, size: 16),
                        color: Colors.red,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      ),
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.close, size: 16),
                        color: Colors.white54,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Remove from watchlist
  Future<void> _removeFromWatchlist(MediaSuggestion suggestion) async {
    try {
      await _db.removeFromWatchlist(suggestion.id);
      
      // Immediately update local state so button updates right away
      setState(() {
        _dbWatchlistSuggestions.removeWhere((item) => item.id == suggestion.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${suggestion.title}" from watchlist'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Refresh watchlist in background to ensure consistency
      _loadDbWatchlist();
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
      // Revert local state on error by reloading
      _loadDbWatchlist();
    }
  }

  // Dislike a watchlist item
  Future<void> _dislikeWatchlistItem(MediaSuggestion suggestion) async {
    try {
      // Remove from watchlist table
      await _db.removeFromWatchlist(suggestion.id);
      
      // Set status to disliked
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
      
      // Refresh both sections
      _loadDbWatchlist();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error disliking watchlist item: $e');
    }
  }

  // Like a watchlist item
  Future<void> _likeWatchlistItem(MediaSuggestion suggestion) async {
    try {
      // Remove from watchlist table
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
          content: Text('Liked "${suggestion.title}" - removed from watchlist'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Refresh both sections
      _loadDbWatchlist();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error liking watchlist item: $e');
    }
  }

  // Favorite watchlist item
  Future<void> _favoriteWatchlistItem(MediaSuggestion suggestion) async {
    try {
      // Remove from watchlist table
      await _db.removeFromWatchlist(suggestion.id);
      
      // Set status to "added" (favorited)
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.added,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Favorited "${suggestion.title}" - removed from watchlist'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh both sections
      _loadDbWatchlist();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error favoriting watchlist item: $e');
    }
  }

  // Add library item to watchlist
  Future<void> _addLibraryItemToWatchlist(MediaSuggestion suggestion) async {
    try {
      await _db.addToWatchlist(suggestion.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${suggestion.title}" to watchlist'),
          duration: const Duration(seconds: 2),
        ),
      );

      _loadDbWatchlist();
    } catch (e) {
      debugPrint('Error adding library item to watchlist: $e');
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
                
                // Watchlist section with proper spacing
                SectionSpacing(
                  child: _buildWatchlistSection(),
                ),
                
                // Library section with proper spacing
                SectionSpacing(
                  child: _buildLibrarySection(),
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
      return const LoadingSuggestion(mediaType: 'movie');
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
            // Movie poster
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
                            Icons.movie,
                            size: 48,
                            color: Colors.white54,
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(
                        Icons.movie,
                        size: 48,
                        color: Colors.white54,
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 24),
            
            // Movie info
            Expanded(
              child: SizedBox(
                height: 450,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Movie title
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
                    
                    // Director info
                    Text(
                      'Directed by ${TextUtils.formatArtistNames(_currentDbSuggestion!.artist)}',
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
                    
                    // Description text - scrollable with max height
                    if (_currentDbSuggestion?.description?.isNotEmpty == true)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 120),
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
                    
                    // Bot reasoning - scrollable
                    if (_currentDbSuggestion?.botReasoning?.isNotEmpty == true)
                      Expanded(
                        child: Container(
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
                              Expanded(
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
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Action buttons using generic component
                    SuggestionActionButtons(
                      mediaType: 'movie',
                      hasLikedCurrentSuggestion: _hasLikedCurrentSuggestion,
                      hasFavoritedCurrentSuggestion: _hasFavoritedCurrentSuggestion,
                      isInWatchlist: _currentDbSuggestion != null && 
                        _dbWatchlistSuggestions.any((item) => item.id == _currentDbSuggestion!.id),
                      isProcessing: _isLoadingDbSuggestion,
                      onLike: _likeDbSuggestion,
                      onDislike: _dislikeDbSuggestion,
                      onFavorite: _addToFavorites,
                      onUnfavorite: _removeFromFavorites,
                      onAddToWatchlist: () {
                        final inWatchlist = _currentDbSuggestion != null && 
                          _dbWatchlistSuggestions.any((item) => item.id == _currentDbSuggestion!.id);
                        if (inWatchlist) {
                          if (_currentDbSuggestion != null) {
                            _removeFromWatchlist(_currentDbSuggestion!);
                          }
                        } else {
                          _addDbSuggestionToWatchlist();
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

  // Helper method to build watchlist section
  Widget _buildWatchlistSection() {
    return Column(
      children: [
        const Center(
          child: Text(
            'Your Watchlist',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ComponentSpacing(
          child: _isLoadingDbWatchlist
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFA855F7),
                ),
              )
            : _dbWatchlistSuggestions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No movies in your watchlist yet. Add suggestions to your watchlist to see them here.',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildDbWatchlistSection(),
        ),
      ],
    );
  }

  // Helper method to build library section
  Widget _buildLibrarySection() {
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
                                              'No movies in your library yet. Favorite suggestions to see them here.',
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
} 
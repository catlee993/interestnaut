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

class TVShowSection extends StatefulWidget {
  const TVShowSection({super.key});

  @override
  State<TVShowSection> createState() => _TVShowSectionState();
}

class _TVShowSectionState extends State<TVShowSection> {
  // Database suggestion state
  MediaSuggestion? _currentDbSuggestion;
  String? _dbSuggestionError;
  bool _isLoadingDbSuggestion = false;
  bool _hasLikedCurrentSuggestion = false; // Add this to track like state
  bool _hasFavoritedCurrentSuggestion = false; // Add this to track favorite state

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
    _eventService.eventsForMediaType('tv_show').listen((event) {
      if (event.type == RecommendationEventType.suggestionReady) {
        debugPrint('🎉 TV Show suggestion ready: ${event.suggestion?.title}');
        _loadDbSuggestion(); // Reload to get the new suggestion
      }
    });
    
    // Load initial DB suggestion
    _loadDbSuggestion();
    // Load DB library and watchlist
    _loadDbLibrary();
    _loadDbWatchlist();
  }

  // Load a DB suggestion for TV shows
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
      // First check if the TV show database is available
      final databaseStatus = await _recommendationService.getMediaTypeStatus('tv_show');
      final isDatabaseAvailable = databaseStatus == 'available';
      
      if (!isDatabaseAvailable) {
        setState(() {
          _currentDbSuggestion = null;
          _dbSuggestionError = null; // No error, just database not installed
          _isLoadingDbSuggestion = false;
        });
        return;
      }
      
      final suggestions = await _db.getPendingSuggestionsNotInWatchlist('tv_show');
      debugPrint('📱 _loadDbSuggestion found ${suggestions.length} total pending, ${suggestions.length} after filtering current');
      
      if (suggestions.isNotEmpty) {
        debugPrint('📱 _loadDbSuggestion using suggestion: ${suggestions.first.title} (media_type: ${suggestions.first.mediaType})');
        if (suggestions.first.mediaType != 'tv_show') {
          debugPrint('⚠️ WARNING: Found suggestion with wrong media type! Expected tv_show, got ${suggestions.first.mediaType}');
        }
        setState(() {
          _currentDbSuggestion = suggestions.first;
          _isLoadingDbSuggestion = false;
          // Reset button states for the new suggestion
          _hasLikedCurrentSuggestion = false;
          _hasFavoritedCurrentSuggestion = false;
        });
      } else {
        // Try to generate a new suggestion on-demand
        final loadingSuggestion = await _recommendationService.generateSuggestionOnDemand('tv_show');
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
            _dbSuggestionError = 'Unable to generate TV show suggestions. Make sure TinyLlama model is installed.';
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

  // Load DB library (liked/added suggestions)
  Future<void> _loadDbLibrary() async {
    setState(() {
      _isLoadingDbLibrary = true;
    });

    try {
      final suggestions = await _recommendationService.getSuggestions('tv_show');
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

  // Load DB watchlist
  Future<void> _loadDbWatchlist() async {
    setState(() {
      _isLoadingDbWatchlist = true;
    });

    try {
      final watchlistItems = await _db.getWatchlist('tv_show');
      setState(() {
        _dbWatchlistSuggestions = watchlistItems;
        _isLoadingDbWatchlist = false;
      });
    } catch (e) {
      debugPrint('Error loading DB watchlist: $e');
      setState(() {
        _isLoadingDbWatchlist = false;
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
      // Check if ID is valid and remove from watchlist if present
      if (_currentDbSuggestion!.id > 0) {
        final isInWatchlist = await _db.isInWatchlist(_currentDbSuggestion!.id);
        if (isInWatchlist) {
          await _db.removeFromWatchlist(_currentDbSuggestion!.id);
          _loadDbWatchlist(); // Refresh watchlist
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

  // Add database suggestion to watchlist and move to next
  Future<void> _addDbSuggestionToWatchlist() async {
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) return;

    setState(() {
      _isLoadingDbSuggestion = true;
    });

    try {
      await _db.addToWatchlist(_currentDbSuggestion!.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to watchlist'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Immediately update the local state to reflect the change
      setState(() {
        _dbWatchlistSuggestions.add(_currentDbSuggestion!);
      });

      // Refresh watchlist in background
      _loadDbWatchlist();

      // Load next suggestion
      await _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error adding DB suggestion to watchlist: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Build watchlist section
  Widget _buildDbWatchlistSection() {
    return MediaLibraryGrid(
      suggestions: _dbWatchlistSuggestions,
      mediaType: 'tv_show',
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
      mediaType: 'tv_show',
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
          // TV show poster
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
                            Icons.tv,
                            size: 48,
                            color: Colors.white54,
                          ),
                        );
                      },
                    ),
                  )
                : const Center(
                    child: Icon(
                      Icons.tv,
                      size: 48,
                      color: Colors.white54,
                    ),
                  ),
            ),
          ),
          
          // TV show info
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
                  suggestion.artist ?? 'Unknown Network',
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${suggestion.title}" from watchlist'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      _loadDbWatchlist();
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
    }
  }

  // Dislike a watchlist item
  Future<void> _dislikeWatchlistItem(MediaSuggestion suggestion) async {
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
      
      _loadDbWatchlist();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error disliking watchlist item: $e');
    }
  }

  // Like a watchlist item
  Future<void> _likeWatchlistItem(MediaSuggestion suggestion) async {
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
          content: Text('Liked "${suggestion.title}" - removed from watchlist'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      _loadDbWatchlist();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error liking watchlist item: $e');
    }
  }

  // Remove from library
  Future<void> _removeFromLibrary(MediaSuggestion suggestion) async {
    try {
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.pending,  // Use pending so it can appear in suggestions again
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

  // Favorite a watchlist item
  Future<void> _favoriteWatchlistItem(MediaSuggestion suggestion) async {
    try {
      // Remove from watchlist table
      await _db.removeFromWatchlist(suggestion.id);
      
      // Set status to added (favorited)
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.added,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${suggestion.title}" to favorites'),
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
                    const LoadingSuggestion(mediaType: 'tv_show')
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
                              // TV show poster
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
                                              Icons.tv,
                                              size: 48,
                                              color: Colors.white54,
                                            ),
                                          );
                                        },
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.tv,
                                          size: 48,
                                          color: Colors.white54,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              
                              // TV show info
                              Expanded(
                                child: SizedBox(
                                  height: 450,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // TV show title
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
                                      
                                      // Network info
                                      Text(
                                        'on ${_currentDbSuggestion!.artist ?? 'Unknown Network'}',
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
                                                mediaType: 'tv_show',
                                                hasLikedCurrentSuggestion: _hasLikedCurrentSuggestion, // Use _hasLikedCurrentSuggestion
                                                hasFavoritedCurrentSuggestion: _hasFavoritedCurrentSuggestion,
                                                isInWatchlist: _currentDbSuggestion != null && 
                                                  _dbWatchlistSuggestions.any((item) => item.id == _currentDbSuggestion!.id),
                                                isProcessing: _isLoadingDbSuggestion,
                                                onLike: _likeDbSuggestion,
                                                onDislike: _dislikeDbSuggestion,
                                                onFavorite: _addToFavorites, // Changed from _likeDbSuggestion to _addToFavorites
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
                
                // Watchlist section
                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    'Your Watchlist',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoadingDbWatchlist)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFA855F7),
                    ),
                  )
                else if (_dbWatchlistSuggestions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No shows in your watchlist yet. Add suggestions to your watchlist to see them here.',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  _buildDbWatchlistSection(),
                
                // Library section
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
                        'No shows in your library yet. Favorite suggestions to see them here.',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  _buildDbLibrarySection(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
} 
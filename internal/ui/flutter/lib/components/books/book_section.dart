import 'dart:async';
import 'package:flutter/material.dart';
import '../common/scroll_content_wrapper.dart';
import '../common/media_library_grid.dart';
import '../common/suggestion_action_buttons.dart';
import '../common/loading_suggestion.dart';
import '../../models.dart';
import '../../services/recommendation_service.dart';
import '../../services/recommendation_event_service.dart';
import '../../services/sqlite_db.dart';
import 'book_card.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BookSection extends StatefulWidget {
  const BookSection({super.key});

  @override
  State<BookSection> createState() => _BookSectionState();
}

class _BookSectionState extends State<BookSection> {
  // Database suggestion state
  MediaSuggestion? _currentDbSuggestion;
  String? _dbSuggestionError;
  bool _isLoadingDbSuggestion = false;
  bool _hasLikedCurrentSuggestion = false;
  bool _hasFavoritedCurrentSuggestion = false;

  // Local DB library state (for liked suggestions)
  List<MediaSuggestion> _dbLikedSuggestions = [];
  bool _isLoadingDbLibrary = false;

  // Local DB reading list state
  List<MediaSuggestion> _dbReadingListSuggestions = [];
  bool _isLoadingDbReadingList = false;

  // UI state
  bool _showWatchlist = true;
  bool _showLibrary = true;

  final RecommendationService _recommendationService = RecommendationService();
  final RecommendationEventService _eventService = RecommendationEventService();
  final SQLiteDatabase _db = SQLiteDatabase();
  final GlobalKey _searchResultsKey = GlobalKey();

  StreamSubscription<RecommendationEvent>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    
    // Listen to recommendation events for this media type
    _eventSubscription = _eventService.eventsForMediaType('book').listen((event) {
      debugPrint('📚 Book section received event: ${event.type}');
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
    _loadDbReadingList();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  // Convert MediaSuggestion to MediaSuggestionItem for the unified layout
  MediaSuggestionItem _mapToSuggestionItem(MediaSuggestion suggestion) {
    return MediaSuggestionItem(
      id: suggestion.id,
      title: suggestion.title ?? 'Unknown Title',
      artist: suggestion.artist,
      description: suggestion.description,
      imageUrl: suggestion.coverArtUrl,
    );
  }

  // Load a DB suggestion for books
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
      // First check if the book database is available
      final databaseStatus = await _recommendationService.getMediaTypeStatus('book');
      final isDatabaseAvailable = databaseStatus == 'available';
      
      if (!isDatabaseAvailable) {
        setState(() {
          _currentDbSuggestion = null;
          _dbSuggestionError = null; // No error, just database not installed
          _isLoadingDbSuggestion = false;
        });
        return;
      }
      
      final suggestions = await _db.getPendingSuggestionsNotInWatchlist('book');
      
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
        final loadingSuggestion = await _recommendationService.generateSuggestionOnDemand('book');
        
        if (loadingSuggestion != null) {
          debugPrint('📚 Book suggestion generation started in background');
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
            _dbSuggestionError = 'Unable to generate book suggestions. Make sure TinyLlama model is installed.';
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
    debugPrint('📚 _loadDbLibrary called');
    setState(() {
      _isLoadingDbLibrary = true;
    });

    try {
      debugPrint('📚 _loadDbLibrary fetching all favorites (recommendations + user-added)');
      final allFavorites = await _db.getAllFavorites('book');
      debugPrint('📚 _loadDbLibrary found ${allFavorites.length} total favorites');
      
      // Debug print each library item
      for (final item in allFavorites) {
        debugPrint('📚   - ${item.title} (ID: ${item.id}, status: ${item.status})');
      }
      
      setState(() {
        _dbLikedSuggestions = allFavorites;
        _isLoadingDbLibrary = false;
      });
      debugPrint('📚 _loadDbLibrary completed - final count: ${_dbLikedSuggestions.length}');
    } catch (e) {
      debugPrint('Error loading DB library: $e');
      setState(() {
        _isLoadingDbLibrary = false;
      });
    }
  }

  // Load DB reading list
  Future<void> _loadDbReadingList() async {
    setState(() {
      _isLoadingDbReadingList = true;
    });

    try {
      final readingListItems = await _db.getWatchlist('book');
      setState(() {
        _dbReadingListSuggestions = readingListItems;
        _isLoadingDbReadingList = false;
      });
    } catch (e) {
      debugPrint('Error loading DB reading list: $e');
      setState(() {
        _isLoadingDbReadingList = false;
      });
    }
  }

  // Like a database suggestion
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

          // Note: Don't reload library - liking doesn't add to favorites
    } catch (e) {
      debugPrint('Error liking DB suggestion: $e');
    } finally {
      setState(() {
        _isLoadingDbSuggestion = false;
      });
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
      debugPrint('📚 Cleared current suggestion - waiting for events to deliver next one');
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
    debugPrint('💜 _addToFavorites called - currentSuggestion: ${_currentDbSuggestion!.title} (ID: ${_currentDbSuggestion!.id})');

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

      // Note: Favorite action keeps the suggestion active until user manually hits next
      debugPrint('💜 _addToFavorites completed - keeping suggestion active');
    } catch (e) {
      debugPrint('💜 Error adding to favorites: $e');
    } finally {
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
    
    debugPrint('🔴 _dislikeDbSuggestion called - currentSuggestion: ${_currentDbSuggestion!.title} (ID: ${_currentDbSuggestion!.id})');

    setState(() {
      _isLoadingDbSuggestion = true;
    });

    try {
      // Check if ID is valid and remove from watchlist if present
      if (_currentDbSuggestion!.id > 0) {
        final isInWatchlist = await _db.isInWatchlist(_currentDbSuggestion!.id);
        if (isInWatchlist) {
          await _db.removeFromWatchlist(_currentDbSuggestion!.id);
          _loadDbReadingList(); // Refresh reading list
        }
      }
      
      // Set status to disliked (this will remove from favorites if favorited)
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.disliked,
      );
      
      // Refresh library in case item was favorited
      _loadDbLibrary();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disliked "${_currentDbSuggestion!.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Move to next suggestion after disliking (non-blocking)
      _moveToNextSuggestion();
      
      // Trigger new suggestion generation (non-blocking)
      _recommendationService.generateSuggestionOnDemand('book').then((loadingSuggestion) {
        if (loadingSuggestion != null) {
          debugPrint('📚 New suggestion generation started after dislike');
        } else {
          debugPrint('📚 No immediate suggestion available - background generation in progress');
          
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Skipped "${_currentDbSuggestion!.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Move to next suggestion after skipping (non-blocking)
      _moveToNextSuggestion();
      
      // Trigger new suggestion generation (non-blocking)
      _recommendationService.generateSuggestionOnDemand('book').then((loadingSuggestion) {
        if (loadingSuggestion != null) {
          debugPrint('📚 New suggestion generation started after skip');
        } else {
          debugPrint('📚 No immediate suggestion available - background generation in progress');
          
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

  // Add DB suggestion to reading list and move to next
  Future<void> _addDbSuggestionToReadingList() async {
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to reading list'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Immediately update the local state to reflect the change
      setState(() {
        _dbReadingListSuggestions.add(_currentDbSuggestion!);
      });

      // Refresh reading list in background
      _loadDbReadingList();

      // Note: Add to reading list action keeps the suggestion active until user manually hits next
      debugPrint('📚 _addDbSuggestionToReadingList completed - keeping suggestion active');
    } catch (e) {
      debugPrint('Error adding to reading list: $e');
    } finally {
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Remove from reading list
  Future<void> _removeFromReadingList(MediaSuggestion suggestion) async {
    try {
      await _db.removeFromWatchlist(suggestion.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${suggestion.title}" from reading list'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      _loadDbReadingList();
    } catch (e) {
      debugPrint('Error removing from reading list: $e');
    }
  }

  // Like a reading list item
  Future<void> _likeReadingListItem(MediaSuggestion suggestion) async {
    try {
      // Remove from reading list since user has reacted
      await _db.removeFromWatchlist(suggestion.id);
      
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.liked,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Liked "${suggestion.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      _loadDbReadingList();
    } catch (e) {
      debugPrint('Error liking reading list item: $e');
    }
  }

  // Dislike a reading list item
  Future<void> _dislikeReadingListItem(MediaSuggestion suggestion) async {
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
      
      _loadDbReadingList();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error disliking reading list item: $e');
    }
  }

  // Favorite a reading list item
  Future<void> _favoriteReadingListItem(MediaSuggestion suggestion) async {
    try {
      await _db.removeFromWatchlist(suggestion.id);
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
      
      _loadDbReadingList();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error favoriting reading list item: $e');
    }
  }

  // Add library item to reading list
  Future<void> _addLibraryItemToReadingList(MediaSuggestion suggestion) async {
    try {
      await _db.addToWatchlist(suggestion.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${suggestion.title}" to reading list'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      _loadDbReadingList();
    } catch (e) {
      debugPrint('Error adding library item to reading list: $e');
    }
  }

  // Remove from library (unfavorite)
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
    return MediaSectionLayout(
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
              child: _buildSuggestionContent(),
            ),
            
            // Reading List section with proper spacing
            if (_dbReadingListSuggestions.isNotEmpty || _isLoadingDbReadingList)
              SectionSpacing(
                child: _buildReadingListSection(),
              ),
            
            // Library section with proper spacing
            if (_dbLikedSuggestions.isNotEmpty || _isLoadingDbLibrary)
              SectionSpacing(
                child: _buildLibrarySection(),
              ),
          ],
        );
      },
    );
  }

  // Helper method to build suggestion content
  Widget _buildSuggestionContent() {
    if (_isLoadingDbSuggestion) {
      return const LoadingSuggestion(mediaType: 'book');
    } else if (_dbSuggestionError != null) {
      return Center(
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
      );
    } else if (_currentDbSuggestion == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No book suggestions available',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoadingDbSuggestion ? null : () async {
                setState(() {
                  _isLoadingDbSuggestion = true;
                  _dbSuggestionError = null;
                });
                
                final loadingSuggestion = await _recommendationService.generateSuggestionOnDemand('book');
                
                if (loadingSuggestion != null) {
                  // Don't set the loading suggestion as current - just keep loading state
                  setState(() {
                    _currentDbSuggestion = null; // Clear current suggestion
                    // Keep _isLoadingDbSuggestion = true until real suggestion arrives
                  });
                } else {
                  setState(() {
                    _dbSuggestionError = 'Unable to generate book suggestions. Make sure TinyLlama model is installed.';
                    _isLoadingDbSuggestion = false;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: _isLoadingDbSuggestion
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Get a Suggestion'),
            ),
          ],
        ),
      );
    } else {
      // Current suggestion display
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book cover
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
                              Icons.book,
                              size: 48,
                              color: Colors.white54,
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Icon(
                          Icons.book,
                          size: 48,
                          color: Colors.white54,
                        ),
                      ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            
            // Book info
            Expanded(
              child: SizedBox(
                height: 450,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Book title
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
                    
                    // Author info
                    Text(
                      'by ${_currentDbSuggestion!.artist ?? "Unknown Author"}',
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
                                                color: Colors.white.withOpacity(0.6),
                                                fontSize: 14,
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
                    
                    // Action buttons using SuggestionActionButtons component (has proper purple favorite styling)
                    SuggestionActionButtons(
                      mediaType: 'book',
                      hasLikedCurrentSuggestion: _hasLikedCurrentSuggestion,
                      hasFavoritedCurrentSuggestion: _hasFavoritedCurrentSuggestion,
                      isInWatchlist: _currentDbSuggestion != null && 
                        _dbReadingListSuggestions.any((item) => item.id == _currentDbSuggestion!.id),
                      isProcessing: _isLoadingDbSuggestion,
                      onLike: _likeDbSuggestion,
                      onDislike: _dislikeDbSuggestion,
                      onFavorite: _addToFavorites,
                      onUnfavorite: _removeFromFavorites,
                      onAddToWatchlist: () {
                        final inReadingList = _currentDbSuggestion != null && 
                          _dbReadingListSuggestions.any((item) => item.id == _currentDbSuggestion!.id);
                        if (inReadingList) {
                          if (_currentDbSuggestion != null) {
                            _removeFromReadingList(_currentDbSuggestion!);
                          }
                        } else {
                          _addDbSuggestionToReadingList();
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

  // Helper method to build reading list section
  Widget _buildReadingListSection() {
    return Column(
      children: [
        const Center(
          child: Text(
            'Your Reading List',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingDbReadingList)
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFA855F7),
            ),
          )
        else if (_dbReadingListSuggestions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No books in your reading list yet. Add suggestions to your reading list to see them here.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          MediaLibraryGrid(
            suggestions: _dbReadingListSuggestions,
            mediaType: 'book',
            isWatchlist: true,
            onRemove: _removeFromReadingList,
            onLike: _likeReadingListItem,
            onDislike: _dislikeReadingListItem,
            onFavorite: _favoriteReadingListItem,
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
                'No books in your library yet. Favorite suggestions to see them here.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          MediaLibraryGrid(
            suggestions: _dbLikedSuggestions,
            mediaType: 'book',
            isWatchlist: false,
            onAddToWatchlist: _addLibraryItemToReadingList,
            onUnfavorite: _removeFromLibrary,
            watchlistItems: _dbReadingListSuggestions,
          ),
      ],
    );
  }
}
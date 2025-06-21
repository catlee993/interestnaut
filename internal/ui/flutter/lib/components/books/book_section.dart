import 'dart:async';
import 'package:flutter/material.dart';
import '../common/scroll_content_wrapper.dart' as wrapper;
import '../common/media_library_grid.dart';
import '../common/suggestion_action_buttons.dart';
import '../common/media_section_layout.dart';
import '../../models.dart';
import '../../services/recommendation_service.dart';
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
  final SQLiteDatabase _db = SQLiteDatabase();
  final GlobalKey _searchResultsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    
    // Load initial DB suggestion
    _loadDbSuggestion();
    // Load DB library and reading list
    _loadDbLibrary();
    _loadDbReadingList();
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
        // Try to generate a new suggestion on-demand
        final newSuggestion = await _recommendationService.generateSuggestionOnDemand('book');
        if (newSuggestion != null) {
          debugPrint('📱 _loadDbSuggestion setting currentSuggestion: ${newSuggestion.title} (ID: ${newSuggestion.id})');
          setState(() {
            _currentDbSuggestion = newSuggestion;
            _isLoadingDbSuggestion = false;
            // Reset button states for the new suggestion
            _hasLikedCurrentSuggestion = false;
            _hasFavoritedCurrentSuggestion = false;
          });
        } else {
          setState(() {
            _currentDbSuggestion = null;
            _dbSuggestionError = 'Unable to generate book suggestions. Make sure TinyLlama model is installed.';
            _isLoadingDbSuggestion = false;
            // Reset button states when no suggestion available
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
      debugPrint('📚 _loadDbLibrary fetching all suggestions');
      final suggestions = await _recommendationService.getSuggestions('book');
      debugPrint('📚 _loadDbLibrary found ${suggestions.length} total suggestions');
      final libraryItems = suggestions.where((s) => 
        s.status == SuggestionStatus.added
      ).toList();
      debugPrint('📚 _loadDbLibrary filtered to ${libraryItems.length} library items');
      
      // Debug print each library item
      for (final item in libraryItems) {
        debugPrint('📚   - ${item.title} (status: ${item.status})');
      }
      
      setState(() {
        _dbLikedSuggestions = libraryItems;
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

      // Load next suggestion
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Skipped "${_currentDbSuggestion!.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Load next suggestion
      await _loadDbSuggestion();
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

      // Load next suggestion
      await _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error adding to reading list: $e');
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
    return wrapper.ScrollContentWrapper(
      builder: (context) => Column(
        children: [
          // Suggestion section
          _buildSuggestionContent(),
          
          const SizedBox(height: 32),
          
          // Reading List section
          if (_dbReadingListSuggestions.isNotEmpty || _isLoadingDbReadingList) ...[
            _buildReadingListSection(),
            const SizedBox(height: 32),
          ],
          
          // Library section
          if (_dbLikedSuggestions.isNotEmpty || _isLoadingDbLibrary) ...[
            _buildLibrarySection(),
          ],
        ],
      ),
    );
  }

  // Helper method to build suggestion content
  Widget _buildSuggestionContent() {
    if (_isLoadingDbSuggestion) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFA855F7),
        ),
      );
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
                });
                
                final newSuggestion = await _recommendationService.generateSuggestionOnDemand('book');
                if (newSuggestion != null) {
                  setState(() {
                    _currentDbSuggestion = newSuggestion;
                    _isLoadingDbSuggestion = false;
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
                          margin: const EdgeInsets.only(bottom: 16),
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
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    _currentDbSuggestion!.botReasoning!,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
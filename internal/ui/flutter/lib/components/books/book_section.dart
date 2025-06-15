import 'dart:async';
import 'package:flutter/material.dart';
import '../common/scroll_content_wrapper.dart';
import '../common/install_library_card.dart';
import '../common/media_library_grid.dart';
import '../common/consistent_layout_wrapper.dart';
import '../../services/recommendation_service.dart';
import '../../services/sqlite_db.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/text_utils.dart';

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
  bool _isDatabaseAvailable = false;

  // Local DB library state (for liked suggestions)
  List<MediaSuggestion> _dbLikedSuggestions = [];
  bool _isLoadingDbLibrary = false;

  // Local DB reading list state
  List<MediaSuggestion> _dbReadingListSuggestions = [];
  bool _isLoadingDbReadingList = false;

  final RecommendationService _recommendationService = RecommendationService();
  final SQLiteDatabase _db = SQLiteDatabase();

  @override
  void initState() {
    super.initState();
    
    // Load initial DB suggestion
    _loadDbSuggestion();
    // Load DB library and reading list
    _loadDbLibrary();
    _loadDbReadingList();
  }

  // Load a DB suggestion for books
  Future<void> _loadDbSuggestion() async {
    setState(() {
      _isLoadingDbSuggestion = true;
      _dbSuggestionError = null;
      _hasLikedCurrentSuggestion = false; // Reset like state
    });

    try {
      // First check if the book database is available
      final databaseStatus = await _recommendationService.getMediaTypeStatus('book');
      _isDatabaseAvailable = databaseStatus == 'available';
      
      if (!_isDatabaseAvailable) {
        setState(() {
          _currentDbSuggestion = null;
          _dbSuggestionError = null; // No error, just database not installed
          _isLoadingDbSuggestion = false;
        });
        return;
      }
      
      final suggestions = await _recommendationService.getSuggestions(
        'book',
        status: SuggestionStatus.pending,
      );
      
      if (suggestions.isNotEmpty) {
        setState(() {
          _currentDbSuggestion = suggestions.first;
          _isLoadingDbSuggestion = false;
        });
      } else {
        // Try to generate a new suggestion on-demand
        final newSuggestion = await _recommendationService.generateSuggestionOnDemand('book');
        if (newSuggestion != null) {
          setState(() {
            _currentDbSuggestion = newSuggestion;
          _isLoadingDbSuggestion = false;
        });
      } else {
        setState(() {
          _currentDbSuggestion = null;
            _dbSuggestionError = 'Unable to generate book suggestions. Make sure TinyLlama model is installed.';
          _isLoadingDbSuggestion = false;
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
      final suggestions = await _recommendationService.getSuggestions('book');
      final libraryItems = suggestions.where((s) => 
        s.status == SuggestionStatus.liked || s.status == SuggestionStatus.added
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

  // Like a database suggestion (mark as liked but stay on current)
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

      // Reload library to show the new liked item
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error liking DB suggestion: $e');
    }
  }

  // Add to favorites (same as like but with different messaging)
  Future<void> _addToFavorites() async {
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
          content: Text('Added "${_currentDbSuggestion!.title}" to your favorites'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Reload library
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
    }
  }

  // Dislike a database suggestion
  Future<void> _dislikeDbSuggestion() async {
    if (_currentDbSuggestion == null) return;

    try {
      // First, check if item is in reading list and remove it
      final isInReadingList = await _db.isInWatchlist(_currentDbSuggestion!.id);
      if (isInReadingList) {
        await _db.removeFromWatchlist(_currentDbSuggestion!.id);
        _loadDbReadingList();
      }
      
      // Then set status to disliked
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.disliked,
      );

      // Get next suggestion (this will reset the like state)
      _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error disliking DB suggestion: $e');
    }
  }

  // Skip a database suggestion (mark as skipped and move to next)
  Future<void> _skipDbSuggestion() async {
    if (_currentDbSuggestion == null) return;

    try {
      // Only mark as skipped if it hasn't been liked
      if (!_hasLikedCurrentSuggestion) {
        await _recommendationService.updateSuggestionStatus(
          _currentDbSuggestion!.id,
          SuggestionStatus.skipped,
        );
      }

      _moveToNextSuggestion();
    } catch (e) {
      debugPrint('Error skipping DB suggestion: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Move to next suggestion (for both skip and next actions)
  Future<void> _moveToNextSuggestion() async {
    try {
      // Generate next suggestion on-demand
      setState(() {
        _isLoadingDbSuggestion = true;
        _currentDbSuggestion = null;
        _dbSuggestionError = null;
        _hasLikedCurrentSuggestion = false; // Reset like state
      });
      
      final newSuggestion = await _recommendationService.generateSuggestionOnDemand('book');
      if (newSuggestion != null) {
        setState(() {
          _currentDbSuggestion = newSuggestion;
          _isLoadingDbSuggestion = false;
        });
      } else {
        // Fallback to loading existing suggestions
        _loadDbSuggestion();
      }
    } catch (e) {
      debugPrint('Error moving to next suggestion: $e');
      setState(() {
        _isLoadingDbSuggestion = false;
      });
    }
  }

  // Add database suggestion to reading list
  Future<void> _addDbSuggestionToReadingList() async {
    if (_currentDbSuggestion == null) return;

    try {
      await _db.addToWatchlist(_currentDbSuggestion!.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to reading list'),
          duration: const Duration(seconds: 2),
        ),
      );

      _loadDbReadingList();
      _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error adding DB suggestion to reading list: $e');
    }
  }

  // Favorite reading list item
  Future<void> _favoriteReadingListItem(MediaSuggestion suggestion) async {
    try {
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.liked,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${suggestion.title}" to favorites'),
          duration: const Duration(seconds: 2),
        ),
      );

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

  // Remove from library
  Future<void> _removeFromLibrary(MediaSuggestion suggestion) async {
    try {
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.skipped,
      );

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

  // Build reading list section with reusable component
  Widget _buildDbReadingListSection() {
    return MediaLibraryGrid(
      suggestions: _dbReadingListSuggestions,
      mediaType: 'book',
      isWatchlist: true,
      onRemove: _removeFromReadingList,
      onLike: _likeReadingListItem,
      onDislike: _dislikeReadingListItem,
      onFavorite: _favoriteReadingListItem,
    );
  }

  // Build library section with reusable component
  Widget _buildDbLibrarySection() {
    return MediaLibraryGrid(
      suggestions: _dbLikedSuggestions,
      mediaType: 'book',
      isWatchlist: false,
      onAddToWatchlist: _addLibraryItemToReadingList,
      onUnfavorite: _removeFromLibrary,
      watchlistItems: _dbReadingListSuggestions,
    );
  }

  // Build a suggestion card widget
  Widget _buildSuggestionCard(
    MediaSuggestion suggestion, {
    VoidCallback? onRemove,
    VoidCallback? onLike,
    VoidCallback? onDislike,
    bool showReadingListActions = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book cover
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
                            Icons.book,
                            size: 48,
                            color: Colors.white54,
                          ),
                        );
                      },
                    ),
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
          
          // Book info
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
                  suggestion.artist ?? 'Unknown Author',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                // Action buttons for reading list items
                if (showReadingListActions) ...[
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

  // Like a reading list item
  Future<void> _likeReadingListItem(MediaSuggestion suggestion) async {
    try {
      await _db.removeFromWatchlist(suggestion.id);
      
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.liked,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Liked "${suggestion.title}" - added to library'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      _loadDbReadingList();
      _loadDbLibrary();
    } catch (e) {
      debugPrint('Error liking reading list item: $e');
    }
  }

  // Helper method to build suggestion content
  Widget _buildSuggestionContent(double scrollOffset) {
    if (_isLoadingDbSuggestion) {
      return const SizedBox.shrink();
    } else if (!_isDatabaseAvailable) {
      // Show install library card when database is not available
      return Center(
        child: InstallLibraryCard(
          mediaType: 'book',
          onInstalled: () {
            // Reload suggestions after database is installed
            setState(() {
              _isDatabaseAvailable = true;
            });
            _loadDbSuggestion();
          },
        ),
      );
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const Text(
                'No suggestions available',
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
        ),
      );
    } else {
      // Current suggestion container using SuggestionDisplayWrapper
      return SuggestionDisplayWrapper(
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
                      'by ${TextUtils.formatArtistNames(_currentDbSuggestion!.artist)}',
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
                    
                    // Action buttons using ActionButtonsWrapper
                    ActionButtonsWrapper(
                      children: [
                        // Like button
                        ElevatedButton.icon(
                          onPressed: _hasLikedCurrentSuggestion ? null : _likeDbSuggestion,
                          icon: Icon(
                            _hasLikedCurrentSuggestion ? Icons.thumb_up : Icons.thumb_up_outlined, 
                            size: 16
                          ),
                          label: Text(
                            _hasLikedCurrentSuggestion ? 'Liked' : 'Like', 
                            style: const TextStyle(fontSize: 13)
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasLikedCurrentSuggestion 
                              ? Colors.green.withOpacity(0.3)
                              : Colors.black.withOpacity(0.7),
                            foregroundColor: _hasLikedCurrentSuggestion ? Colors.green : Colors.white,
                            elevation: 0,
                            side: BorderSide(
                              color: _hasLikedCurrentSuggestion 
                                ? Colors.green.withOpacity(0.5)
                                : Colors.white.withOpacity(0.3), 
                              width: 1
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                        
                        // Dislike button
                        ElevatedButton.icon(
                          onPressed: _dislikeDbSuggestion,
                          icon: const Icon(Icons.thumb_down, size: 16),
                          label: const Text('Dislike', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                        
                        // Favorite button
                        ElevatedButton.icon(
                          onPressed: _hasLikedCurrentSuggestion ? null : _addToFavorites,
                          icon: Icon(
                            _hasLikedCurrentSuggestion ? Icons.favorite : Icons.favorite_border, 
                            size: 16
                          ),
                          label: Text(
                            _hasLikedCurrentSuggestion ? 'Favorited' : 'Favorite', 
                            style: const TextStyle(fontSize: 13)
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasLikedCurrentSuggestion 
                              ? Colors.red.withOpacity(0.3)
                              : Colors.white.withOpacity(0.15),
                            foregroundColor: _hasLikedCurrentSuggestion ? Colors.red : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                        
                        // Reading list button
                        Builder(
                          builder: (context) {
                            final inReadingList = _currentDbSuggestion != null && 
                              _dbReadingListSuggestions.any((item) => item.id == _currentDbSuggestion!.id);
                            
                            return ElevatedButton.icon(
                              onPressed: inReadingList 
                                ? () => _currentDbSuggestion != null ? _removeFromReadingList(_currentDbSuggestion!) : null
                                : _addDbSuggestionToReadingList,
                              icon: Icon(
                                inReadingList ? Icons.bookmark_added : Icons.bookmark_add, 
                                size: 16
                              ),
                              label: Text(
                                inReadingList ? 'In Reading List' : 'Reading List', 
                                style: const TextStyle(fontSize: 13)
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: inReadingList 
                                  ? Colors.blue.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.15),
                                foregroundColor: inReadingList ? Colors.blue : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                minimumSize: const Size(0, 44),
                              ),
                            );
                          },
                        ),
                        
                        // Skip/Next button
                        ElevatedButton.icon(
                          onPressed: _skipDbSuggestion,
                          icon: Icon(
                            _hasLikedCurrentSuggestion ? Icons.arrow_forward : Icons.skip_next, 
                            size: 16
                          ),
                          label: Text(
                            _hasLikedCurrentSuggestion ? 'Next' : 'Skip', 
                            style: const TextStyle(fontSize: 13)
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasLikedCurrentSuggestion 
                              ? const Color(0xFF7B68EE).withOpacity(0.3)
                              : Colors.white.withOpacity(0.15),
                            foregroundColor: _hasLikedCurrentSuggestion 
                              ? const Color(0xFF7B68EE) 
                              : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ],
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
          _buildDbReadingListSection(),
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
                'No books in your library yet. Like or add suggestions to see them here.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          _buildDbLibrarySection(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        ScrollContentWrapper(
          headerHeight: 106.0,
          builder: (scrollOffset) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                
                // Suggestion content
                ComponentSpacing(
                  child: _buildSuggestionContent(scrollOffset),
                ),
                
                // Library sections with proper spacing
                SectionSpacing(
                  child: _buildReadingListSection(),
                ),
                
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
} 
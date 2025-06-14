import 'dart:async';
import 'package:flutter/material.dart';
import '../common/scroll_content_wrapper.dart';
import '../common/media_grid.dart';
import '../common/install_library_card.dart';
import '../common/media_library_grid.dart';
import '../../models.dart';
import '../../services/recommendation_service.dart';
import '../../services/sqlite_db.dart';
import 'movie_card.dart';
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

  // Local DB library state (for liked suggestions)
  List<MediaSuggestion> _dbLikedSuggestions = [];
  bool _isLoadingDbLibrary = false;

  // Local DB watchlist state
  List<MediaSuggestion> _dbWatchlistSuggestions = [];
  bool _isLoadingDbWatchlist = false;

  final RecommendationService _recommendationService = RecommendationService();
  final SQLiteDatabase _db = SQLiteDatabase();

  @override
  void initState() {
    super.initState();
    
    // Load initial DB suggestion
    _loadDbSuggestion();
    // Load DB library and watchlist
    _loadDbLibrary();
    _loadDbWatchlist();
  }

  // Load a DB suggestion for movies
  Future<void> _loadDbSuggestion() async {
    setState(() {
      _isLoadingDbSuggestion = true;
      _dbSuggestionError = null;
    });

    try {
      final suggestions = await _recommendationService.getSuggestions(
        'movie',
        status: SuggestionStatus.pending,
      );
      
      if (suggestions.isNotEmpty) {
        setState(() {
          _currentDbSuggestion = suggestions.first;
          _isLoadingDbSuggestion = false;
        });
      } else {
        setState(() {
          _currentDbSuggestion = null;
          _dbSuggestionError = 'No movie suggestions available';
          _isLoadingDbSuggestion = false;
        });
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
      final suggestions = await _recommendationService.getSuggestions('movie');
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

  // Load DB watchlist
  Future<void> _loadDbWatchlist() async {
    setState(() {
      _isLoadingDbWatchlist = true;
    });

    try {
      final watchlistItems = await _db.getWatchlist('movie');
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

  // Like a database suggestion (add to library)
  Future<void> _likeDbSuggestion() async {
    if (_currentDbSuggestion == null) return;

    try {
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.liked,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to your library'),
          duration: const Duration(seconds: 2),
        ),
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
      // First, check if item is in watchlist and remove it
      final isInWatchlist = await _db.isInWatchlist(_currentDbSuggestion!.id);
      if (isInWatchlist) {
        await _db.removeFromWatchlist(_currentDbSuggestion!.id);
        // Refresh watchlist since item was removed from there too
        _loadDbWatchlist();
      }
      
      // Then set status to disliked
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.disliked,
      );

      // Get next suggestion
      _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error disliking DB suggestion: $e');
    }
  }

  // Skip a database suggestion
  Future<void> _skipDbSuggestion() async {
    if (_currentDbSuggestion == null) return;

    try {
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.skipped,
      );

      // Get next suggestion
      _loadDbSuggestion();
    } catch (e) {
      debugPrint('Error skipping DB suggestion: $e');
    }
  }

  // Add database suggestion to watchlist
  Future<void> _addDbSuggestionToWatchlist() async {
    if (_currentDbSuggestion == null) return;

    try {
      // Add to watchlist table instead of changing status
      await _db.addToWatchlist(_currentDbSuggestion!.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${_currentDbSuggestion!.title}" to watchlist'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh both watchlist and main suggestions
      _loadDbWatchlist();
      _loadDbSuggestion(); // This will get the next suggestion
    } catch (e) {
      debugPrint('Error adding DB suggestion to watchlist: $e');
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${suggestion.title}" from watchlist'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Refresh watchlist
      _loadDbWatchlist();
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
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
      
      // Set status to "liked" so it gets added to library
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
        // Main content
        ScrollContentWrapper(
          headerHeight: 60.0, // Smaller header without Spotify info
          builder: (scrollOffset) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Database suggestion section
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
                    const SizedBox.shrink()
                  else if (_dbSuggestionError != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Error: $_dbSuggestionError',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
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
                    // Current suggestion container
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0), // Match library sections
                      child: Column(
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
                                          constraints: const BoxConstraints(maxHeight: 120), // Limit description height
                                          child: Padding(
                                            padding: const EdgeInsets.only(bottom: 8), // Reduced padding
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
                                        Container(
                                          width: double.infinity,
                                          constraints: const BoxConstraints(maxHeight: 180), // Limit reasoning height
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
                                              
                                              // Action buttons
                                              const SizedBox(height: 24),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                                child: Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  alignment: WrapAlignment.center,
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
                                                    
                                                    // Watchlist button
                                                    Builder(
                                                      builder: (context) {
                                                        final inWatchlist = _currentDbSuggestion != null && 
                                                          _dbWatchlistSuggestions.any((item) => item.id == _currentDbSuggestion!.id);
                                                        
                                                        return ElevatedButton.icon(
                                                          onPressed: inWatchlist 
                                                            ? () => _currentDbSuggestion != null ? _removeFromWatchlist(_currentDbSuggestion!) : null
                                                            : _addDbSuggestionToWatchlist,
                                                          icon: Icon(
                                                            inWatchlist ? Icons.bookmark_added : Icons.bookmark_add, 
                                                            size: 16
                                                          ),
                                                          label: Text(
                                                            inWatchlist ? 'In Watchlist' : 'Watchlist', 
                                                            style: const TextStyle(fontSize: 13)
                                                          ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: inWatchlist 
                                                              ? Colors.blue.withOpacity(0.3)
                                                              : Colors.white.withOpacity(0.15),
                                                            foregroundColor: inWatchlist ? Colors.blue : Colors.white,
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
                        'No movies in your watchlist yet. Add suggestions to your watchlist to see them here.',
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
                        'No movies in your library yet. Like or add suggestions to see them here.',
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
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/recommendation_service.dart';
import '../../services/recommendation_event_service.dart';
import '../../services/sqlite_db.dart';

/// Base controller for media section suggestion management
/// Handles all the common logic that's duplicated across media types
abstract class BaseMediaSectionController extends ChangeNotifier {
  final String mediaType;
  final RecommendationService _recommendationService = RecommendationService();
  final SQLiteDatabase _db = SQLiteDatabase();
  
  // Common suggestion state
  MediaSuggestion? _currentDbSuggestion;
  bool _isLoadingDbSuggestion = false;
  String? _dbSuggestionError;
  bool _hasLikedCurrentSuggestion = false;
  bool _hasFavoritedCurrentSuggestion = false;
  bool _isInWatchlistCurrentSuggestion = false;
  
  // Common library/watchlist state
  List<MediaSuggestion> _dbLikedSuggestions = [];
  List<MediaSuggestion> _dbWatchlistSuggestions = [];
  bool _isLoadingDbLibrary = false;
  bool _isLoadingDbWatchlist = false;
  
  StreamSubscription<RecommendationEvent>? _eventSubscription;
  
  BaseMediaSectionController(this.mediaType) {
    _initializeEventListener();
    _loadInitialData();
  }
  
  // Getters for current state
  MediaSuggestion? get currentDbSuggestion => _currentDbSuggestion;
  bool get isLoadingDbSuggestion => _isLoadingDbSuggestion;
  String? get dbSuggestionError => _dbSuggestionError;
  bool get hasLikedCurrentSuggestion => _hasLikedCurrentSuggestion;
  bool get hasFavoritedCurrentSuggestion => _hasFavoritedCurrentSuggestion;
  bool get isInWatchlistCurrentSuggestion => _isInWatchlistCurrentSuggestion;
  
  List<MediaSuggestion> get dbLikedSuggestions => _dbLikedSuggestions;
  List<MediaSuggestion> get dbWatchlistSuggestions => _dbWatchlistSuggestions;
  bool get isLoadingDbLibrary => _isLoadingDbLibrary;
  bool get isLoadingDbWatchlist => _isLoadingDbWatchlist;
  
  void _initializeEventListener() {
    final eventService = RecommendationEventService();
    _eventSubscription = eventService.eventsForMediaType(mediaType).listen((event) {
      switch (event.type) {
        case RecommendationEventType.suggestionReady:
          if (event.suggestion != null) {
            _reloadSuggestionFromDatabase(event.suggestion!.id);
          }
          break;
        case RecommendationEventType.suggestionError:
          _dbSuggestionError = event.error ?? 'Unknown error';
          _isLoadingDbSuggestion = false;
          notifyListeners();
          break;
        case RecommendationEventType.suggestionStarted:
          // Loading state is already set when we call generateSuggestionOnDemand
          break;
      }
    });
  }
  
  Future<void> _loadInitialData() async {
    await Future.wait([
      loadDbSuggestion(),
      loadDbLibrary(),
      loadDbWatchlist(),
    ]);
  }

  /// Update the state flags for the current suggestion based on database status
  Future<void> _updateCurrentSuggestionState() async {
    if (_currentDbSuggestion == null) {
      _hasLikedCurrentSuggestion = false;
      _hasFavoritedCurrentSuggestion = false;
      _isInWatchlistCurrentSuggestion = false;
      return;
    }

    try {
      // Use the new database query to get status with joins
      final suggestionWithStatus = await _db.getSuggestionWithStatus(_currentDbSuggestion!.id);
      
      if (suggestionWithStatus != null) {
        _hasLikedCurrentSuggestion = suggestionWithStatus.hasLiked;
        _hasFavoritedCurrentSuggestion = suggestionWithStatus.hasFavorited;
        _isInWatchlistCurrentSuggestion = suggestionWithStatus.isInWatchlist;
      } else {
        // Fallback to default state if query fails
        _hasLikedCurrentSuggestion = false;
        _hasFavoritedCurrentSuggestion = false;
        _isInWatchlistCurrentSuggestion = false;
      }
      
    } catch (e) {
      debugPrint('Error updating current suggestion state: $e');
      _hasLikedCurrentSuggestion = false;
      _hasFavoritedCurrentSuggestion = false;
      _isInWatchlistCurrentSuggestion = false;
    }
  }

  /// Check if a suggestion is the current active suggestion and sync state if needed
  Future<void> _syncCurrentSuggestionIfMatches(MediaSuggestion suggestion) async {
    if (_currentDbSuggestion != null && 
        (_currentDbSuggestion!.id == suggestion.id || 
         _currentDbSuggestion!.mediaItemId == suggestion.mediaItemId)) {
      debugPrint('🔄 Syncing current suggestion state after external action');
      await _updateCurrentSuggestionState();
      notifyListeners();
    }
  }

  /// Check if a search item matches the current suggestion by title/creator and sync state
  Future<void> _syncCurrentSuggestionIfMatchesSearchItem({
    required String title,
    required String primaryCreator,
  }) async {
    if (_currentDbSuggestion != null) {
      // Check if title and creator match the current suggestion
      final currentTitle = _currentDbSuggestion!.title?.toLowerCase() ?? '';
      final currentCreator = _currentDbSuggestion!.artist?.toLowerCase() ?? '';
      
      if (currentTitle == title.toLowerCase() && 
          currentCreator == primaryCreator.toLowerCase()) {
        debugPrint('🔄 Syncing current suggestion state after search item action: $title by $primaryCreator');
        await _updateCurrentSuggestionState();
        notifyListeners();
      }
    }
  }

  /// Public method to sync current suggestion state from external search actions
  Future<void> syncCurrentSuggestionFromSearch({
    required String title,
    required String primaryCreator,
  }) async {
    await _syncCurrentSuggestionIfMatchesSearchItem(
      title: title,
      primaryCreator: primaryCreator,
    );
  }

  /// Check if a suggestion is the current active suggestion and handle dislike auto-next
  Future<void> _handleCurrentSuggestionDislike(MediaSuggestion suggestion) async {
    if (_currentDbSuggestion != null && 
        (_currentDbSuggestion!.id == suggestion.id || 
         _currentDbSuggestion!.mediaItemId == suggestion.mediaItemId)) {
      debugPrint('🔄 Current suggestion was disliked from external action - moving to next');
      
             // Update the current suggestion status
       _currentDbSuggestion!.status = SuggestionStatus.disliked;
      
      // Trigger the dislike callback and move to next
      onSuggestionDisliked(_currentDbSuggestion!);
      _moveToNextSuggestion();
      _recommendationService.generateSuggestionOnDemand(mediaType);
    }
  }
  
  /// Load suggestion from database
  Future<void> loadDbSuggestion() async {
    _isLoadingDbSuggestion = true;
    _dbSuggestionError = null;
    _hasLikedCurrentSuggestion = false;
    _hasFavoritedCurrentSuggestion = false;
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 50));
    
    try {
      final databaseStatus = await _recommendationService.getMediaTypeStatus(mediaType);
      final isDatabaseAvailable = databaseStatus == 'available';
      
      if (!isDatabaseAvailable) {
        _currentDbSuggestion = null;
        _dbSuggestionError = null;
        _isLoadingDbSuggestion = false;
        notifyListeners();
        return;
      }
      
      final suggestions = await _db.getPendingSuggestionsNotInWatchlist(mediaType);
      
      if (suggestions.isNotEmpty) {
        _currentDbSuggestion = suggestions.first;
        _isLoadingDbSuggestion = false;
        await _updateCurrentSuggestionState();
        notifyListeners();
      } else {
        final loadingSuggestion = await _recommendationService.generateSuggestionOnDemand(mediaType);
        
        if (loadingSuggestion != null) {
          _currentDbSuggestion = null;
          _isLoadingDbSuggestion = true;
          _dbSuggestionError = null;
          _hasLikedCurrentSuggestion = false;
          _hasFavoritedCurrentSuggestion = false;
          notifyListeners();
        } else {
          _currentDbSuggestion = null;
          _dbSuggestionError = 'Unable to generate ${mediaType} suggestions. Make sure TinyLlama model is installed.';
          _isLoadingDbSuggestion = false;
          _hasLikedCurrentSuggestion = false;
          _hasFavoritedCurrentSuggestion = false;
          notifyListeners();
        }
      }
    } catch (e) {
      _dbSuggestionError = 'Error loading suggestions: $e';
      _isLoadingDbSuggestion = false;
      notifyListeners();
    }
  }
  
  /// Load library (favorites)
  Future<void> loadDbLibrary() async {
    _isLoadingDbLibrary = true;
    notifyListeners();
    
    try {
      final allFavorites = await _db.getAllFavorites(mediaType);
      _dbLikedSuggestions = allFavorites;
      _isLoadingDbLibrary = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading DB library: $e');
      _isLoadingDbLibrary = false;
      notifyListeners();
    }
  }
  
  /// Load watchlist
  Future<void> loadDbWatchlist() async {
    _isLoadingDbWatchlist = true;
    notifyListeners();
    
    try {
      final allWatchlist = await _db.getWatchlist(mediaType);
      _dbWatchlistSuggestions = allWatchlist;
      _isLoadingDbWatchlist = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading DB watchlist: $e');
      _isLoadingDbWatchlist = false;
      notifyListeners();
    }
  }
  
  /// Like current suggestion (toggle like/unlike)
  Future<void> likeDbSuggestion() async {
    if (_currentDbSuggestion == null) return;
    
    try {
      if (_hasLikedCurrentSuggestion) {
        // Unlike: clear all relationships and set to disliked/skipped
        await _unlikeCurrentSuggestion();
      } else {
        // Like: set status to liked
        await _recommendationService.updateSuggestionStatus(
          _currentDbSuggestion!.id,
          SuggestionStatus.liked,
        );
        
        // Update state from database
        await _updateCurrentSuggestionState();
        notifyListeners();
        
        onSuggestionLiked(_currentDbSuggestion!);
      }
    } catch (e) {
      debugPrint('Error toggling like on DB suggestion: $e');
    }
  }

  /// Unlike current suggestion (clear all relationships and restore to pending)
  Future<void> _unlikeCurrentSuggestion() async {
    if (_currentDbSuggestion == null) return;
    
    try {
      // Remove from favorites if favorited
      if (_hasFavoritedCurrentSuggestion && _currentDbSuggestion!.mediaItemId != null) {
        await _db.removeFromFavorites(_currentDbSuggestion!.mediaItemId!);
        loadDbLibrary();
      }
      
      // Remove from watchlist if in watchlist
      if (_isInWatchlistCurrentSuggestion && _currentDbSuggestion!.mediaItemId != null) {
        await _db.removeFromWatchlist(_currentDbSuggestion!.mediaItemId!);
        loadDbWatchlist();
      }
      
      // Set status back to pending (since user undid all actions, treat as no action taken)
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.pending,
      );
      
      // Update state from database
      await _updateCurrentSuggestionState();
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error unliking current suggestion: $e');
    }
  }
  
  /// Dislike current suggestion
  Future<void> dislikeDbSuggestion() async {
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) return;
    
    _isLoadingDbSuggestion = true;
    notifyListeners();
    
    try {
      if (_currentDbSuggestion!.mediaItemId != null) {
        final isInWatchlist = await _db.isInWatchlist(_currentDbSuggestion!.mediaItemId!);
        if (isInWatchlist) {
          await _db.removeFromWatchlist(_currentDbSuggestion!.mediaItemId!);
          loadDbWatchlist();
        }
      }
      
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.disliked,
      );
      
      if (_hasFavoritedCurrentSuggestion && _currentDbSuggestion!.mediaItemId != null) {
        await _db.removeFromFavorites(_currentDbSuggestion!.mediaItemId!);
      }
      
      loadDbLibrary();
      _moveToNextSuggestion();
      
      onSuggestionDisliked(_currentDbSuggestion!);
      
      _recommendationService.generateSuggestionOnDemand(mediaType);
    } catch (e) {
      debugPrint('Error disliking DB suggestion: $e');
      _isLoadingDbSuggestion = false;
      notifyListeners();
    }
  }
  
  /// Skip current suggestion
  Future<void> skipDbSuggestion() async {
    if (_currentDbSuggestion == null || _isLoadingDbSuggestion) return;
    
    _isLoadingDbSuggestion = true;
    notifyListeners();
    
    try {
      // Only mark as skipped if no action has been taken 
      // (not liked, favorited, watchlisted, or already disliked/unliked)
      final currentStatus = _currentDbSuggestion!.status;
      if (!_hasFavoritedCurrentSuggestion && 
          !_hasLikedCurrentSuggestion && 
          !_isInWatchlistCurrentSuggestion &&
          currentStatus != SuggestionStatus.disliked) {
        await _recommendationService.updateSuggestionStatus(
          _currentDbSuggestion!.id,
          SuggestionStatus.skipped,
        );
      }
      
      onSuggestionSkipped(_currentDbSuggestion!);
      
      _moveToNextSuggestion();
      _recommendationService.generateSuggestionOnDemand(mediaType);
    } catch (e) {
      debugPrint('Error skipping DB suggestion: $e');
      _isLoadingDbSuggestion = false;
      notifyListeners();
    }
  }
  
  /// Add current suggestion to favorites
  Future<void> addToFavorites() async {
    if (_currentDbSuggestion == null) return;
    
    try {
      await _db.addToFavorites(_currentDbSuggestion!.mediaItemId!);
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.added,
      );
      
      // Update state from database
      await _updateCurrentSuggestionState();
      notifyListeners();
      
      loadDbLibrary();
      onSuggestionFavorited(_currentDbSuggestion!);
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
    }
  }

  /// Remove current suggestion from favorites (unfavorite)
  Future<void> unfavoriteCurrentSuggestion() async {
    if (_currentDbSuggestion == null) return;
    
    try {
      await _db.removeFromFavorites(_currentDbSuggestion!.mediaItemId!);
      
      // Determine the status to restore based on current state
      SuggestionStatus statusToRestore;
      if (_hasLikedCurrentSuggestion) {
        // If it's liked, restore to liked status
        statusToRestore = SuggestionStatus.liked;
      } else {
        // If not liked (regardless of watchlist status), restore to pending
        statusToRestore = SuggestionStatus.pending;
      }
      
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        statusToRestore,
      );
      
      // Update state from database
      await _updateCurrentSuggestionState();
      notifyListeners();
      
      loadDbLibrary();
    } catch (e) {
      debugPrint('Error unfavoriting current suggestion: $e');
    }
  }
  
  /// Add current suggestion to watchlist
  Future<void> addDbSuggestionToWatchlist() async {
    if (_currentDbSuggestion == null) return;
    
    try {
      await _db.addToWatchlist(_currentDbSuggestion!.mediaItemId!);
      
      // Update state from database
      await _updateCurrentSuggestionState();
      notifyListeners();
      
      loadDbWatchlist();
      onSuggestionAddedToWatchlist(_currentDbSuggestion!);
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
    }
  }

  /// Remove current suggestion from watchlist
  Future<void> removeCurrentSuggestionFromWatchlist() async {
    if (_currentDbSuggestion == null) return;
    
    try {
      await _db.removeFromWatchlist(_currentDbSuggestion!.mediaItemId!);
      
      // If this was the only action (not liked, not favorited), ensure status is pending
      if (!_hasLikedCurrentSuggestion && !_hasFavoritedCurrentSuggestion) {
        await _recommendationService.updateSuggestionStatus(
          _currentDbSuggestion!.id,
          SuggestionStatus.pending,
        );
      }
      
      // Update state from database
      await _updateCurrentSuggestionState();
      notifyListeners();
      
      loadDbWatchlist();
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
    }
  }
  
  void _moveToNextSuggestion() async {
    final suggestions = await _db.getPendingSuggestionsNotInWatchlist(mediaType);
    final filteredSuggestions = suggestions.where((s) => 
      _currentDbSuggestion == null || s.id != _currentDbSuggestion!.id
    ).toList();
    
    if (filteredSuggestions.isNotEmpty) {
      _currentDbSuggestion = filteredSuggestions.first;
      _isLoadingDbSuggestion = false;
      await _updateCurrentSuggestionState();
      notifyListeners();
            } else {
          _currentDbSuggestion = null;
          _isLoadingDbSuggestion = true;
          _hasLikedCurrentSuggestion = false;
          _hasFavoritedCurrentSuggestion = false;
          _isInWatchlistCurrentSuggestion = false;
          notifyListeners();
      
      Timer(const Duration(seconds: 30), () {
        if (_isLoadingDbSuggestion && _currentDbSuggestion == null) {
          _dbSuggestionError = 'Suggestion generation timed out. Please try again.';
          _isLoadingDbSuggestion = false;
          notifyListeners();
        }
      });
    }
  }
  
  Future<void> _reloadSuggestionFromDatabase(int suggestionId) async {
    try {
      final suggestion = await _db.getRecommendationById(suggestionId);
      if (suggestion != null) {
        _currentDbSuggestion = suggestion;
        _isLoadingDbSuggestion = false;
        _dbSuggestionError = null;
        await _updateCurrentSuggestionState();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error reloading suggestion: $e');
      _dbSuggestionError = 'Error loading suggestion: $e';
      _isLoadingDbSuggestion = false;
      notifyListeners();
    }
  }
  
  /// Remove item from favorites
  Future<void> removeFromFavorites(int mediaItemId) async {
    try {
      await _db.removeFromFavorites(mediaItemId);
      loadDbLibrary();
      
      // Check if this affects the current suggestion
      if (_currentDbSuggestion?.mediaItemId == mediaItemId) {
        await _updateCurrentSuggestionState();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error removing from favorites: $e');
    }
  }
  
  /// Remove item from watchlist
  Future<void> removeFromWatchlist(int mediaItemId) async {
    try {
      await _db.removeFromWatchlist(mediaItemId);
      loadDbWatchlist();
      
      // Check if this affects the current suggestion
      if (_currentDbSuggestion?.mediaItemId == mediaItemId) {
        await _updateCurrentSuggestionState();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
    }
  }
  
  /// Like a watchlist item
  Future<void> likeWatchlistItem(MediaSuggestion suggestion) async {
    try {
      await _db.removeFromWatchlist(suggestion.mediaItemId!);
      
      // Only change status if not already favorited (added)
      if (suggestion.status != SuggestionStatus.added) {
        await _recommendationService.updateSuggestionStatus(
          suggestion.id,
          SuggestionStatus.liked,
        );
      }
      
      loadDbWatchlist();
      loadDbLibrary();
      
      // Sync current suggestion state if this item matches
      await _syncCurrentSuggestionIfMatches(suggestion);
    } catch (e) {
      debugPrint('Error liking watchlist item: $e');
    }
  }
  
  /// Dislike a watchlist item
  Future<void> dislikeWatchlistItem(MediaSuggestion suggestion) async {
    try {
      await _db.removeFromWatchlist(suggestion.mediaItemId!);
      
      await _recommendationService.updateSuggestionStatus(
        suggestion.id,
        SuggestionStatus.disliked,
      );
      
      loadDbWatchlist();
      loadDbLibrary();
      
      // Handle current suggestion dislike (auto-next behavior)
      await _handleCurrentSuggestionDislike(suggestion);
    } catch (e) {
      debugPrint('Error disliking watchlist item: $e');
    }
  }
  
  /// Favorite a watchlist item (move from watchlist to favorites)
  Future<void> favoriteWatchlistItem(MediaSuggestion suggestion) async {
    try {
      await _db.moveFromWatchlistToFavorites(suggestion.mediaItemId!);
      
      // Refresh both sections
      loadDbWatchlist();
      loadDbLibrary();
      
      // Sync current suggestion state if this item matches
      await _syncCurrentSuggestionIfMatches(suggestion);
    } catch (e) {
      debugPrint('Error favoriting watchlist item: $e');
    }
  }
  
  /// Add library item to watchlist
  Future<void> addLibraryItemToWatchlist(MediaSuggestion suggestion) async {
    try {
      await _db.addToWatchlist(suggestion.mediaItemId!);
      loadDbWatchlist();
      
      // Sync current suggestion state if this item matches
      await _syncCurrentSuggestionIfMatches(suggestion);
    } catch (e) {
      debugPrint('Error adding library item to watchlist: $e');
    }
  }
  
  // Abstract methods for media-specific behavior
  void onSuggestionLiked(MediaSuggestion suggestion) {}
  void onSuggestionDisliked(MediaSuggestion suggestion) {}
  void onSuggestionSkipped(MediaSuggestion suggestion) {}
  void onSuggestionFavorited(MediaSuggestion suggestion) {}
  void onSuggestionAddedToWatchlist(MediaSuggestion suggestion) {}
  
  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
} 
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
        _hasLikedCurrentSuggestion = false;
        _hasFavoritedCurrentSuggestion = false;
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
  
  /// Like current suggestion
  Future<void> likeDbSuggestion() async {
    if (_currentDbSuggestion == null) return;
    
    try {
      await _recommendationService.updateSuggestionStatus(
        _currentDbSuggestion!.id,
        SuggestionStatus.liked,
      );
      
      _hasLikedCurrentSuggestion = true;
      notifyListeners();
      
      onSuggestionLiked(_currentDbSuggestion!);
    } catch (e) {
      debugPrint('Error liking DB suggestion: $e');
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
      if (!_hasFavoritedCurrentSuggestion && !_hasLikedCurrentSuggestion) {
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
      
      _hasFavoritedCurrentSuggestion = true;
      notifyListeners();
      
      loadDbLibrary();
      onSuggestionFavorited(_currentDbSuggestion!);
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
    }
  }
  
  /// Add current suggestion to watchlist
  Future<void> addDbSuggestionToWatchlist() async {
    if (_currentDbSuggestion == null) return;
    
    try {
      await _db.addToWatchlist(_currentDbSuggestion!.mediaItemId!);
      loadDbWatchlist();
      onSuggestionAddedToWatchlist(_currentDbSuggestion!);
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
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
      _hasLikedCurrentSuggestion = false;
      _hasFavoritedCurrentSuggestion = false;
      notifyListeners();
    } else {
      _currentDbSuggestion = null;
      _isLoadingDbSuggestion = true;
      _hasLikedCurrentSuggestion = false;
      _hasFavoritedCurrentSuggestion = false;
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
        _hasLikedCurrentSuggestion = false;
        _hasFavoritedCurrentSuggestion = false;
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
    } catch (e) {
      debugPrint('Error removing from favorites: $e');
    }
  }
  
  /// Remove item from watchlist
  Future<void> removeFromWatchlist(int mediaItemId) async {
    try {
      await _db.removeFromWatchlist(mediaItemId);
      loadDbWatchlist();
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
    } catch (e) {
      debugPrint('Error favoriting watchlist item: $e');
    }
  }
  
  /// Add library item to watchlist
  Future<void> addLibraryItemToWatchlist(MediaSuggestion suggestion) async {
    try {
      await _db.addToWatchlist(suggestion.mediaItemId!);
      loadDbWatchlist();
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
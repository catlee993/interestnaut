import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'sqlite_db.dart';
import 'grpc_client.dart';
import 'recommendation_event_service.dart';

/// Status enum for recommendation suggestions
enum SuggestionStatus {
  pending,    // Not yet acted upon
  liked,      // User liked this suggestion
  disliked,   // User disliked this suggestion
  favorited,  // User added to favorites
  watchlist,  // User added to watchlist
  skipped,    // User skipped this suggestion
  added,      // User added this item (generic)
}

/// Data class representing a media suggestion
class MediaSuggestion {
  final int id;
  final String query;
  final String mediaType;
  final String? title;
  final String? artist;
  final String? album;
  final String? coverArtUrl;
  final String? description;
  final String? wikiUrl;
  final String? wikidataId;
  final String? themes;
  final List<String>? genres;
  final String? botReasoning;
  final String? mediaId;
  final String? youtubeId;
  final String? spotifyId;
  SuggestionStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MediaSuggestion({
    required this.id,
    required this.query,
    required this.mediaType,
    this.title,
    this.artist,
    this.album,
    this.coverArtUrl,
    this.description,
    this.wikiUrl,
    this.wikidataId,
    this.themes,
    this.genres,
    this.botReasoning,
    this.mediaId,
    this.youtubeId,
    this.spotifyId,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  // Getter for backwards compatibility
  String? get mediaItemId => mediaId;

  /// Copy this suggestion with updated fields
  MediaSuggestion copyWith({
    int? id,
    String? query,
    String? mediaType,
    String? title,
    String? artist,
    String? album,
    String? coverArtUrl,
    String? description,
    String? wikiUrl,
    String? wikidataId,
    String? themes,
    List<String>? genres,
    String? botReasoning,
    String? mediaId,
    String? youtubeId,
    String? spotifyId,
    SuggestionStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaSuggestion(
      id: id ?? this.id,
      query: query ?? this.query,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverArtUrl: coverArtUrl ?? this.coverArtUrl,
      description: description ?? this.description,
      wikiUrl: wikiUrl ?? this.wikiUrl,
      wikidataId: wikidataId ?? this.wikidataId,
      themes: themes ?? this.themes,
      genres: genres ?? this.genres,
      botReasoning: botReasoning ?? this.botReasoning,
      mediaId: mediaId ?? this.mediaId,
      youtubeId: youtubeId ?? this.youtubeId,
      spotifyId: spotifyId ?? this.spotifyId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Class representing a suggestion with its current status
class SuggestionWithStatus {
  final MediaSuggestion suggestion;
  final bool isLiked;
  final bool isFavorited;
  final bool isInWatchlist;
  final bool isDisliked;
  final bool isSkipped;

  SuggestionWithStatus({
    required this.suggestion,
    this.isLiked = false,
    this.isFavorited = false,
    this.isInWatchlist = false,
    this.isDisliked = false,
    this.isSkipped = false,
  });

  // Getters for backwards compatibility
  bool get hasLiked => isLiked;
  bool get hasFavorited => isFavorited;
}

/// Modern RecommendationService that uses gRPC backend instead of local vector databases
/// This replaces the vector database operations with remote gRPC calls
class RecommendationService extends ChangeNotifier {
  static final RecommendationService _instance = RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();
  
  final SQLiteDatabase _db = SQLiteDatabase();
  final GrpcRecommendationClient _grpcClient = GrpcRecommendationClient();
  final RecommendationEventService _eventService = RecommendationEventService();
  
  bool _isProcessingQueue = false;
  final Map<String, bool> _queueBeingFilled = {};
  final Map<String, bool> _backgroundGenerationInProgress = {};
  final Map<String, Completer<void>> _cancellationTokens = {};
  
  Timer? _queueTimer;
  
  /// Initialize the service - connects to gRPC backend and local SQLite
  Future<void> init() async {
    try {
      // Initialize local SQLite database for user data
      await _db.init();
      
      // Initialize gRPC client for recommendations
      await _grpcClient.init();
      
      debugPrint('✅ GrpcRecommendationService initialized - Backend: ${_grpcClient.isInitialized ? "Connected" : "Disconnected"}');
    } catch (e) {
      debugPrint('❌ Error initializing GrpcRecommendationService: $e');
      // Continue without gRPC if backend is unavailable
    }
  }
  
  /// Check if a media type is available for recommendations
  Future<dynamic> getMediaTypeStatus(String mediaType) async {
    try {
      if (!_grpcClient.isInitialized) {
        return {'available': false, 'reason': 'Backend unavailable'};
      }
      
      final healthCheck = await _grpcClient.healthCheck();
      final isAvailable = healthCheck['database_status']?[mediaType] == true;
      
      return {
        'available': isAvailable,
        'backend_healthy': healthCheck['healthy'],
        'backend_version': healthCheck['version'],
      };
    } catch (e) {
      debugPrint('❌ Error checking media type status: $e');
      return {'available': false, 'reason': 'Health check failed'};
    }
  }
  
  /// Check if media type is available (simplified)
  Future<bool> isMediaTypeAvailable(String mediaType) async {
    try {
      final status = await getMediaTypeStatus(mediaType);
      if (status is Map<String, dynamic>) {
        return status['available'] == true;
      }
      return status == 'available';
    } catch (e) {
      return false;
    }
  }
  
  /// Generate a single suggestion on-demand using gRPC backend
  Future<MediaSuggestion?> generateSuggestionOnDemand(String mediaType) async {
    if (_queueBeingFilled[mediaType] == true) {
      debugPrint('Already generating suggestion for $mediaType');
      return null;
    }
    
    if (!_grpcClient.isInitialized) {
      debugPrint('❌ gRPC client not initialized');
      _eventService.emitSuggestionError(mediaType, 'Backend service unavailable');
      return null;
    }
    
    _queueBeingFilled[mediaType] = true;
    _cancellationTokens[mediaType] = Completer<void>();
    
    // Emit started event
    _eventService.emitSuggestionStarted(mediaType);
    
    // Create loading suggestion
    final loadingSuggestion = MediaSuggestion(
      id: -1,
      query: 'Generating $mediaType suggestion...',
      mediaType: mediaType,
      title: 'Loading...',
      artist: 'Generating suggestion',
      botReasoning: 'Finding the perfect $mediaType for you...',
      mediaId: 'loading_${mediaType}_${DateTime.now().millisecondsSinceEpoch}',
      status: SuggestionStatus.pending,
    );
    
    // Start background generation
    _generateSuggestionViaGrpc(mediaType).then((result) {
      _queueBeingFilled[mediaType] = false;
      _cancellationTokens.remove(mediaType);
      
      if (result != null) {
        debugPrint('✅ gRPC suggestion ready: ${result.title}');
        _eventService.emitSuggestionReady(mediaType, result);
      } else {
        debugPrint('❌ gRPC suggestion generation failed');
        _eventService.emitSuggestionError(mediaType, 'Failed to generate suggestion');
      }
    }).catchError((error) {
      _queueBeingFilled[mediaType] = false;
      _cancellationTokens.remove(mediaType);
      debugPrint('❌ gRPC suggestion error: $error');
      _eventService.emitSuggestionError(mediaType, 'Error generating suggestion: $error');
    });
    
    return loadingSuggestion;
  }
  
  /// Generate suggestion using gRPC backend
  Future<MediaSuggestion?> _generateSuggestionViaGrpc(String mediaType) async {
    try {
      // Gather user behavioral data from local database
      final userBehaviorData = await _gatherUserBehaviorData(mediaType);
      
      // Get user's media settings
      final mediaSettings = await _db.getMediaSettings(mediaType);
      final similarityThreshold = mediaSettings?['similarity_matching'] ?? 0.35;
      final attributesToMatch = mediaSettings?['themes_matching'] ?? 3;
      
      // Convert similarity score to distance threshold for FAISS
      // FAISS returns cosine distances (0=identical, 2=opposite)
      // User expects: Bohemian(loose)=0.15, Eclectic=0.25, Versatile=0.35, Discerning=0.55, Meticulous(tight)=0.75
      // Convert to distance thresholds: lower similarity_matching = higher distance threshold (more permissive)
      final distanceThreshold = _convertSimilarityToDistanceThreshold(similarityThreshold);
      
      debugPrint('🎯 Using settings: similarity=$similarityThreshold -> distance=$distanceThreshold, themes=$attributesToMatch');
      
      // Get recommendations from gRPC backend
      final recommendations = await _grpcClient.getRecommendations(
        mediaType: mediaType,
        userQuery: 'Suggest $mediaType based on user preferences',
        likedMediaIds: userBehaviorData['likedMediaIds'],
        favoritedMediaIds: userBehaviorData['favoritedMediaIds'],
        watchlistMediaIds: userBehaviorData['watchlistMediaIds'],
        dislikedMediaIds: userBehaviorData['dislikedMediaIds'],
        skippedMediaIds: userBehaviorData['skippedMediaIds'],
        excludeMediaIds: userBehaviorData['excludeMediaIds'],
        constraints: userBehaviorData['constraints'],
        limit: 1,
        useBehavioralMatching: userBehaviorData['hasSignals'],
        similarityThreshold: distanceThreshold,
        attributesToMatch: attributesToMatch,
        priorityTitleIds: [], // TODO: Get from user priority titles
      );
      
      if (recommendations.isNotEmpty) {
        final suggestion = recommendations.first;
        
        // Save to local database
        final savedSuggestion = await _saveValidatedSuggestion(suggestion);
        return savedSuggestion ?? suggestion;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error generating suggestion via gRPC: $e');
      return null;
    }
  }
  
  /// Gather user behavior data from local SQLite database
  Future<Map<String, dynamic>> _gatherUserBehaviorData(String mediaType) async {
    try {
      // Get user preferences and history from local database
      final likedSuggestions = await _db.getLikedRecommendations(mediaType);
      final dislikedSuggestions = await _db.getDislikedRecommendations(mediaType);
      final favoriteSuggestions = await _db.getAllFavorites(mediaType);
      final watchlistSuggestions = await _db.getWatchlist(mediaType);
      final skippedSuggestions = await _db.getSkippedRecommendations(mediaType);
      final allExistingSuggestions = await _db.getAllMediaSuggestions(mediaType);
      
      // Extract vector media IDs for gRPC calls (filter out nulls)
      final likedMediaIds = likedSuggestions.map((s) => s.mediaId).where((id) => id != null).cast<String>().toList();
      final dislikedMediaIds = dislikedSuggestions.map((s) => s.mediaId).where((id) => id != null).cast<String>().toList();
      final favoritedMediaIds = favoriteSuggestions.map((s) => s.mediaId).where((id) => id != null).cast<String>().toList();
      final watchlistMediaIds = watchlistSuggestions.map((s) => s.mediaId).where((id) => id != null).cast<String>().toList();
      final skippedMediaIds = skippedSuggestions.map((s) => s.mediaId).where((id) => id != null).cast<String>().toList();
      final excludeMediaIds = allExistingSuggestions.map((s) => s.mediaId).where((id) => id != null).cast<String>().toList();
      
             // Get user constraints from settings (include/exclude format)
       List<String> constraints = [];
       try {
         final matchingConstraints = await _db.getMediaMatchingConstraints(mediaType);
         final positiveConstraints = matchingConstraints['positive'] ?? <String>[];
         final negativeConstraints = matchingConstraints['negative'] ?? <String>[];
         
         // Format constraints for backend: "Include: theme" or "Exclude: genre"
         for (final constraint in positiveConstraints) {
           constraints.add('Include: $constraint');
         }
         for (final constraint in negativeConstraints) {
           constraints.add('Exclude: $constraint');
         }
         
         debugPrint('🎯 [GRPC] Formatted constraints: ${constraints.join(', ')}');
       } catch (e) {
         debugPrint('⚠️ Could not load user constraints: $e');
       }
      
      final hasSignals = likedMediaIds.isNotEmpty || 
                        favoritedMediaIds.isNotEmpty || 
                        watchlistMediaIds.isNotEmpty ||
                        dislikedMediaIds.isNotEmpty ||
                        skippedMediaIds.isNotEmpty;
      
      debugPrint('🎯 User behavior for $mediaType: ${likedMediaIds.length} liked, ${dislikedMediaIds.length} disliked, ${excludeMediaIds.length} total to exclude');
      
      return {
        'likedMediaIds': likedMediaIds,
        'dislikedMediaIds': dislikedMediaIds,
        'favoritedMediaIds': favoritedMediaIds,
        'watchlistMediaIds': watchlistMediaIds,
        'skippedMediaIds': skippedMediaIds,
        'excludeMediaIds': excludeMediaIds,
        'constraints': constraints,
        'hasSignals': hasSignals,
      };
    } catch (e) {
      debugPrint('❌ Error gathering user behavior data: $e');
      return {
        'likedMediaIds': <String>[],
        'dislikedMediaIds': <String>[],
        'favoritedMediaIds': <String>[],
        'watchlistMediaIds': <String>[],
        'skippedMediaIds': <String>[],
        'excludeMediaIds': <String>[],
        'constraints': <String>[],
        'hasSignals': false,
      };
    }
  }
  
  /// Save a validated suggestion to local database
  Future<MediaSuggestion?> _saveValidatedSuggestion(MediaSuggestion suggestion) async {
    try {
      final savedId = await _db.saveMediaSuggestion(suggestion);
      debugPrint('💾 Saved gRPC suggestion with ID: $savedId');
      
      return MediaSuggestion(
        id: savedId,
        query: suggestion.query,
        mediaType: suggestion.mediaType,
        title: suggestion.title,
        artist: suggestion.artist,
        album: suggestion.album,
        coverArtUrl: suggestion.coverArtUrl,
        description: suggestion.description,
        wikiUrl: suggestion.wikiUrl,
        wikidataId: suggestion.wikidataId,
        themes: suggestion.themes,
        botReasoning: suggestion.botReasoning,
        mediaId: suggestion.mediaId,
        status: suggestion.status,
        createdAt: suggestion.createdAt,
        updatedAt: suggestion.updatedAt,
      );
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        debugPrint('Duplicate suggestion prevented by database constraint: ${suggestion.title}');
      } else {
        debugPrint('💾 Error saving gRPC suggestion: $e');
      }
      return null;
    }
  }
  
  /// Get suggestions from local database
  Future<List<MediaSuggestion>> getSuggestions(String mediaType, {SuggestionStatus? status}) async {
    try {
      if (status != null) {
        return await _db.getAllMediaSuggestions(mediaType, status: status.toString().split('.').last);
      } else {
        return await _db.getAllMediaSuggestions(mediaType);
      }
    } catch (e) {
      debugPrint('Error getting suggestions: $e');
      return [];
    }
  }
  
  /// Update suggestion status in local database
  Future<bool> updateSuggestionStatus(int suggestionId, SuggestionStatus newStatus) async {
    debugPrint('🗄️ GrpcRecommendationService.updateSuggestionStatus called - ID: $suggestionId, Status: $newStatus');
    try {
      final result = await _db.updateMediaSuggestionStatus(suggestionId, newStatus);
      debugPrint('🗄️ Database update result: $result');
      return result;
    } catch (e) {
      debugPrint('🗄️ Error updating suggestion status: $e');
      return false;
    }
  }
  
  /// Delete suggestion from local database
  Future<bool> deleteSuggestion(int suggestionId) async {
    try {
      await _db.deleteMediaSuggestion(suggestionId);
      return true;
    } catch (e) {
      debugPrint('Error deleting suggestion: $e');
      return false;
    }
  }
  
  /// Search media using gRPC backend
  Future<List<MediaSuggestion>> searchMedia({
    required String mediaType,
    List<String> constraints = const [],
    List<String> excludeMediaIds = const [],
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      if (!_grpcClient.isInitialized) {
        debugPrint('❌ gRPC client not initialized for search');
        return [];
      }
      
      return await _grpcClient.searchMedia(
        mediaType: mediaType,
        constraints: constraints,
        excludeMediaIds: excludeMediaIds,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      debugPrint('❌ Error searching media via gRPC: $e');
      return [];
    }
  }
  
  /// Get similar items using gRPC backend
  Future<List<MediaSuggestion>> getSimilarItems({
    required String referenceMediaId,
    required String mediaType,
    List<String> excludeMediaIds = const [],
    int limit = 5,
  }) async {
    try {
      if (!_grpcClient.isInitialized) {
        debugPrint('❌ gRPC client not initialized for similar items');
        return [];
      }
      
      return await _grpcClient.getSimilarItems(
        referenceMediaId: referenceMediaId,
        mediaType: mediaType,
        excludeMediaIds: excludeMediaIds,
        limit: limit,
      );
    } catch (e) {
      debugPrint('❌ Error getting similar items via gRPC: $e');
      return [];
    }
  }
  
  /// Get random media using gRPC backend
  Future<List<MediaSuggestion>> getRandomMedia({
    required String mediaType,
    List<String> excludeMediaIds = const [],
    int limit = 1,
  }) async {
    try {
      if (!_grpcClient.isInitialized) {
        debugPrint('❌ gRPC client not initialized for random media');
        return [];
      }
      
      return await _grpcClient.getRandomMedia(
        mediaType: mediaType,
        excludeMediaIds: excludeMediaIds,
        limit: limit,
      );
    } catch (e) {
      debugPrint('❌ Error getting random media via gRPC: $e');
      return [];
    }
  }
  
  // Legacy methods for compatibility (disabled)
  Future<void> prefillQueues() async {
    debugPrint('prefillQueues disabled - using gRPC on-demand generation');
    return;
  }
  
  Future<void> ensureSuggestionQueue(String mediaType) async {
    debugPrint('ensureSuggestionQueue disabled for $mediaType - use generateSuggestionOnDemand instead');
    return;
  }
  
  void _startBackgroundQueue() {
    debugPrint('Background queue disabled - using gRPC on-demand generation');
  }
  
  /// Dispose of resources
  @override
  void dispose() {
    _queueTimer?.cancel();
    _grpcClient.dispose();
    super.dispose();
  }

  /// Convert user similarity preference to FAISS similarity threshold
  /// 
  /// UPDATED: Using new Inner Product index with alphabetical genres/themes
  /// Returns similarity scores 0-1 (higher = more similar, 0.8 = 80% similar)
  /// User similarity_matching: lower values = more permissive, higher values = more restrictive
  double _convertSimilarityToDistanceThreshold(double similarityMatching) {
    // Map similarity_matching (0.0-1.0) to MINIMUM similarity thresholds (accept anything ABOVE this)
    // Using Inner Product similarity scores (0-1, higher = more similar)
    // EQUALLY SPACED with 0.1 (10%) increments for clear differentiation:
    //
    // Bohemian (0.15): Very loose → accept similarity above 0.2 (20% similar)
    // Eclectic (0.25): Loose → accept similarity above 0.3 (30% similar) 
    // Versatile (0.35): Moderate → accept similarity above 0.4 (40% similar)
    // Discerning (0.55): Tight → accept similarity above 0.5 (50% similar)
    // Meticulous (0.75): Very tight → accept similarity above 0.6 (60% similar)
    
    if (similarityMatching <= 0.15) {
      return 0.2; // Bohemian: accept 20%+ similarity (very permissive)
    } else if (similarityMatching <= 0.25) {
      return 0.3; // Eclectic: accept 30%+ similarity
    } else if (similarityMatching <= 0.35) {
      return 0.4; // Versatile: accept 40%+ similarity  
    } else if (similarityMatching <= 0.55) {
      return 0.5; // Discerning: accept 50%+ similarity
    } else {
      return 0.6; // Meticulous: accept 60%+ similarity (high-quality matches)
    }
  }
} 
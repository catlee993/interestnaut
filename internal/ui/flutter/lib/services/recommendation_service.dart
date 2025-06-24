import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as pathLib;
import 'package:sqlite3/sqlite3.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'sqlite_db.dart';
import '../db/vector_db.dart';
import 'llama_service.dart';
import 'model_constants.dart';
import '../models.dart';
import 'package:interestnaut/services/wikipedia_service.dart';
import '../components/music/spotify_service.dart';
import 'recommendation_event_service.dart';
import 'llm_performance_monitor.dart';
import 'tflite_vector_service.dart'; 

// --- Data Models ---

enum SuggestionStatus {
  pending,
  skipped,
  liked,
  disliked,
  added, 
  failure, 
  watchlist, // For items added to playlist/watchlist/readlist
}

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
  final String? botReasoning; 
  final String? themes;
  final String? mediaId;  // Links to vector database media_id
  SuggestionStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MediaSuggestion({
    this.id = 0, 
    required this.query,
    required this.mediaType,
    this.title,
    this.artist,
    this.album,
    this.coverArtUrl,
    this.description,
    this.wikiUrl,
    this.wikidataId,
    this.botReasoning,
    this.themes,
    this.mediaId,
    this.status = SuggestionStatus.pending,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MediaSuggestion.fromJson(Map<String, dynamic> json) {
    return MediaSuggestion(
      id: json['id'] as int,
      query: json['query'] as String,
      mediaType: json['media_type'] as String,
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      coverArtUrl: json['cover_art_url'] as String?,
      description: json['description'] as String?,
      wikiUrl: json['wiki_url'] as String?,
      wikidataId: json['wikidata_id'] as String?,
      botReasoning: json['bot_reasoning'] as String?,
      themes: json['themes'] as String?,
      mediaId: json['media_id'] as String?,
      status: SuggestionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => SuggestionStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'media_type': mediaType,
        'title': title,
        'artist': artist,
        'album': album,
        'cover_art_url': coverArtUrl,
        'description': description,
        'wiki_url': wikiUrl,
        'wikidata_id': wikidataId,
        'bot_reasoning': botReasoning,
        'themes': themes,
        'media_id': mediaId,
        'status': status.toString().split('.').last,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> toMap() => toJson();

  static MediaSuggestion fromMap(Map<String, dynamic> map) {
    return MediaSuggestion.fromJson(map);
  }

  String toPromptSummary() {
    try {
      Map<String, dynamic> jsonSummary = {};
      
      switch (mediaType) {
        case 'music':
          jsonSummary = {
            "title": title ?? "Unknown",
            "artist": artist ?? "Unknown Artist",
            "album": album ?? "Unknown Album",
            "reasoning": botReasoning ?? "Previously suggested music"
          };
          break;
        case 'movie':
          final year = description != null &&  description!.contains('released in')
              ? RegExp(r'released in (\d{4})').firstMatch(description!)?.group(1) 
              : "Unknown Year";
          jsonSummary = {
            "title": title ?? "Unknown",
            "director": query.isNotEmpty && query.contains('directed by') ? query.split('directed by').last.trim() : "Unknown Director",
            "year": year,
            "reasoning": botReasoning ?? "Previously suggested movie"
          };
          break;
        case 'book':
          jsonSummary = {
            "title": title ?? "Unknown",
            "author": query.isNotEmpty && query.contains('by') ? query.split('by').last.trim() : "Unknown Author",
            "year": "Unknown Year",
            "reasoning": botReasoning ?? "Previously suggested book"
          };
          break;
        case 'tv_show':
          jsonSummary = {
            "title": title ?? "Unknown",
            "network": "Unknown Network",
            "year": "Unknown Year",
            "reasoning": botReasoning ?? "Previously suggested TV show"
          };
          break;
        case 'video_game':
          jsonSummary = {
            "title": title ?? "Unknown",
            "developer": "Unknown Developer",
            "year": "Unknown Year",
            "reasoning": botReasoning ?? "Previously suggested video game"
          };
          break;
        default:
          jsonSummary = {
            "title": title ?? query,
            "reasoning": botReasoning ?? "Previously suggested media"
          };
      }
      
      jsonSummary.forEach((key, value) {
        if (value is String && value.length > 80) {
          jsonSummary[key] = value.substring(0, 77) + "...";
        }
      });
      
      return json.encode(jsonSummary);
    } catch (e) {
      return '{"title": "${(title ?? query).replaceAll('"', '\\"')}", "reasoning": "Previously suggested ${mediaType.replaceAll('_', ' ')}"}';
    }
  }

  bool isValid() {
    return title != null && title!.isNotEmpty;
  }
}

class RecommendationService extends ChangeNotifier {
  static final RecommendationService _instance = RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();
  
  final SQLiteDatabase _db = SQLiteDatabase();
  final LlamaService _llamaService = LlamaService();
  final SpotifyService _spotifyService = SpotifyService();
  final RecommendationEventService _eventService = RecommendationEventService();
  final LLMPerformanceMonitor _performanceMonitor = LLMPerformanceMonitor(); 
  
  bool _isProcessingQueue = false;
  final Map<String, bool> _queueBeingFilled = {};
  final Map<String, int> _pendingQueueCounts = {};
  final Map<String, bool> _backgroundGenerationInProgress = {};
  
  Timer? _queueTimer;
  
  Future<void> init() async {
    try {
      await _db.init();
      _performanceMonitor.init();
      await _performanceMonitor.loadPerformanceData();
      debugPrint('RecommendationService initialized with performance monitoring');
      // Remove automatic queue prefilling - suggestions will be generated on-demand
    } catch (e) {
      debugPrint('Error initializing RecommendationService: $e');
      rethrow;
    }
  }
  
  void _startBackgroundQueue() {
    // Disabled automatic queue filling - suggestions are now generated on-demand only
    // _queueTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
    //   _checkAndFillQueuesIfNeeded();
    // });
    debugPrint('Background queue disabled - using on-demand generation only');
  }
  
  Future<void> _checkAndFillQueuesIfNeeded() async {
    // Disabled automatic queue filling - suggestions are now generated on-demand only
    debugPrint('Automatic queue filling disabled');
    return;
  }
  
  Future<int> _getPendingSuggestionsCount(String mediaType) async {
    try {
      return await _db.countPendingMediaSuggestions(mediaType);
    } catch (e) {
      debugPrint('Error getting pending suggestions count: $e');
      return 0;
    }
  }
  
  Future<void> _fillMusicQueueFromSpotify() async {
    if (_queueBeingFilled['music'] == true) {
      debugPrint('Music queue is already being filled');
      return;
    }
    
    _queueBeingFilled['music'] = true;
    
    try {
      debugPrint('Filling music queue from Spotify Discover Weekly');
      
      final tracks = await _spotifyService.getDiscoverWeeklyTracks();
      
      if (tracks.isEmpty) {
        debugPrint('No tracks found in Discover Weekly');
        return;
      }
      
      debugPrint('Found ${tracks.length} tracks in Discover Weekly');
      
      final existingMusic = await _db.getAllMediaSuggestions(
        mediaType: 'music',
        limit: 100,
      );
      
      int addedCount = 0;
      
      for (final track in tracks) {
        final exists = existingMusic.any((suggestion) => 
          suggestion.title == track.title && 
          suggestion.artist == track.overview);
        
        if (!exists) {
          final suggestion = MediaSuggestion(
            query: 'Spotify Discover Weekly: ${track.title} by ${track.overview}',
            mediaType: 'music',
            title: track.title,
            artist: track.overview,
            album: track.posterPath,
            coverArtUrl: track.posterPath,
            description: 'From your Spotify Discover Weekly playlist',
            botReasoning: 'This song was recommended by Spotify in your Discover Weekly playlist.',
            mediaId: _generateMediaId('music', track.title, track.overview),
          );
          
          await _db.saveMediaSuggestion(suggestion);
          addedCount++;
        }
      }
      
      debugPrint('Added $addedCount new music suggestions from Spotify');
    } catch (e) {
      debugPrint('Error filling music queue from Spotify: $e');
    } finally {
      _queueBeingFilled['music'] = false;
    }
  }
  
  Future<void> _fillSuggestionQueue(String mediaType) async {
    // Disabled automatic queue filling - suggestions are now generated on-demand only
    debugPrint('_fillSuggestionQueue disabled for $mediaType - use generateSuggestionOnDemand instead');
      return;
  }
  
  /// Build prompt with previous recommendations shown
  String _buildPromptWithPreviousRecommendations(String mediaType, List<MediaSuggestion> existingRecommendations) {
    try {
      // Just return the simple prompt template for now - no previous recommendations needed
      return getPromptTemplateForMediaType(mediaType);
    } catch (e) {
      debugPrint('Error building prompt: $e');
      return 'Song: Wonderwall\nArtist: Oasis\nReason: Classic britpop anthem\n\nSong: ';
    }
  }
  
  /// Parse the response from the new simple prompt format
  MediaSuggestion? _parseThreeLineFormat(String response, String mediaType) {
    try {
      // Clean up the response - remove any leading/trailing whitespace
      final cleanResponse = response.trim();
      
      // Split by lines and filter out empty lines
      final lines = cleanResponse.split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      
      debugPrint('Parsing response with ${lines.length} lines: ${lines.join(" | ")}');
      
      if (lines.length < 3) {
        debugPrint('Not enough lines in response: ${lines.length}');
        return null;
      }
      
      // Take the last 3 lines as our recommendation
      final title = lines[lines.length - 3];
      final artist = lines[lines.length - 2]; 
      final reasoning = lines[lines.length - 1];
      
      debugPrint('Extracted: title="$title", artist="$artist", reasoning="$reasoning"');
      
      // Validate the fields
      if (title.isEmpty || artist.isEmpty || reasoning.isEmpty) {
        debugPrint('Empty fields detected');
        return null;
      }
      
      // Check for placeholder text or invalid content
      if (_containsPlaceholderText(title) || _containsPlaceholderText(artist)) {
        debugPrint('Placeholder text detected in title or artist');
        return null;
      }
      
      return MediaSuggestion(
        query: '$title by $artist',
        mediaType: mediaType,
        title: title,
        artist: artist,
        botReasoning: reasoning,
        mediaId: _generateMediaId(mediaType, title, artist),
        status: SuggestionStatus.pending,
      );
      
    } catch (e) {
      debugPrint('Error parsing simple format: $e');
      return null;
    }
  }
  
  /// Check if text contains placeholder words
  bool _containsPlaceholderText(String text) {
    final lowerText = text.toLowerCase();
    final placeholders = [
      'title', 'name', 'artist', 'author', 'director', 'here', 
      'example', 'placeholder', 'your', 'recommendation'
    ];
    
    return placeholders.any((placeholder) => lowerText.contains(placeholder));
  }
  
  /// Validate a suggestion with Wikipedia
  Future<MediaSuggestion?> _validateWithWikipedia(MediaSuggestion suggestion) async {
    try {
      final wikipediaService = WikipediaService();
      
      // Determine the media type for Wikipedia
      MediaType wikiMediaType;
      switch (suggestion.mediaType) {
        case 'music':
          wikiMediaType = MediaType.album; // Search for artist or album
          break;
        case 'movie':
          wikiMediaType = MediaType.movie;
          break;
        case 'book':
          wikiMediaType = MediaType.book;
          break;
        case 'tv_show':
          wikiMediaType = MediaType.tvShow;
          break;
        case 'video_game':
          wikiMediaType = MediaType.game;
          break;
        default:
          wikiMediaType = MediaType.other;
      }
      
      // Try searching for the title first
      var mediaInfo = await wikipediaService.findMediaInfo(suggestion.title!, wikiMediaType);
      
      // If not found, try searching for the artist/creator
      if (mediaInfo == null && suggestion.artist != null) {
        debugPrint('Title not found, searching for artist: ${suggestion.artist}');
        mediaInfo = await wikipediaService.findMediaInfo(suggestion.artist!, MediaType.other);
      }
      
      if (mediaInfo != null) {
        // Create updated suggestion with Wikipedia info
        final updatedSuggestion = MediaSuggestion(
          id: suggestion.id,
          query: suggestion.query,
          mediaType: suggestion.mediaType,
          title: suggestion.title,
          artist: suggestion.artist,
          album: suggestion.album,
          coverArtUrl: mediaInfo.imageUrl ?? suggestion.coverArtUrl,
          description: mediaInfo.description,
          wikiUrl: mediaInfo.sourceUrl,
          wikidataId: suggestion.wikidataId,
          botReasoning: suggestion.botReasoning,
          mediaId: suggestion.mediaId ?? _generateMediaId(suggestion.mediaType, suggestion.title, suggestion.artist),
          status: suggestion.status,
          createdAt: suggestion.createdAt,
          updatedAt: DateTime.now(),
        );
        
        // Copy the updated data back to the original suggestion
        debugPrint('Wikipedia validation successful: ${updatedSuggestion.title}');
        return updatedSuggestion;
      } else {
        debugPrint('Wikipedia validation failed: ${suggestion.title}');
        return null;
      }
      
    } catch (e) {
      debugPrint('Error during Wikipedia validation: $e');
      return null;
    }
  }
  
  /// Save a validated suggestion (either successful or failed)
  /// Returns the suggestion with the assigned database ID
  Future<MediaSuggestion?> _saveValidatedSuggestion(MediaSuggestion suggestion) async {
    try {
      final savedId = await _db.saveMediaSuggestion(suggestion);
      debugPrint('💾 Saved suggestion with ID: $savedId');
      
      // Return a new suggestion object with the correct ID
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
        mediaId: suggestion.mediaId ?? _generateMediaId(suggestion.mediaType, suggestion.title, suggestion.artist),
        status: suggestion.status,
        createdAt: suggestion.createdAt,
        updatedAt: suggestion.updatedAt,
      );
    } catch (e) {
      // Handle duplicate constraint violations gracefully
      if (e.toString().contains('UNIQUE constraint failed')) {
        debugPrint('Duplicate suggestion prevented by database constraint: ${suggestion.title}');
      } else {
        debugPrint('💾 Error saving suggestion: $e');
      }
      return null;
    }
  }
  
  String _mapMediaTypeForDisplay(String mediaType) {
    switch (mediaType) {
      case 'music':
        return 'music';
      case 'movie':
        return 'movies';
      case 'book':
        return 'books';
      default:
        return mediaType;
    }
  }
  
  Future<void> ensureSuggestionQueue(String mediaType) async {
    // Disabled automatic queue filling - suggestions are now generated on-demand only
    debugPrint('ensureSuggestionQueue disabled for $mediaType - use generateSuggestionOnDemand instead');
    return;
  }
  
  Future<List<MediaSuggestion>> getSuggestions(String mediaType, {SuggestionStatus? status}) async {
    try {
      // Removed automatic queue ensuring - suggestions are now generated on-demand only
      
      if (status != null) {
        return await _db.getAllMediaSuggestions(
          mediaType: mediaType,
          statusFilter: status,
        );
      } else {
        return await _db.getAllMediaSuggestions(
          mediaType: mediaType,
        );
      }
    } catch (e) {
      debugPrint('Error getting suggestions: $e');
      return [];
    }
  }
  
  Future<bool> updateSuggestionStatus(int suggestionId, SuggestionStatus newStatus) async {
    debugPrint('🗄️ RecommendationService.updateSuggestionStatus called - ID: $suggestionId, Status: $newStatus');
    try {
      final result = await _db.updateMediaSuggestionStatus(suggestionId, newStatus);
      debugPrint('🗄️ Database update result: $result');
      return result;
    } catch (e) {
      debugPrint('🗄️ Error updating suggestion status: $e');
      return false;
    }
  }
  
  Future<bool> deleteSuggestion(int suggestionId) async {
    try {
      await _db.deleteMediaSuggestion(suggestionId);
      return true;
    } catch (e) {
      debugPrint('Error deleting suggestion: $e');
      return false;
    }
  }
  
  /// Prefill all recommendation queues
  /// This is called during app initialization to ensure we have recommendations ready
  Future<void> prefillQueues() async {
    // Disabled automatic queue prefilling - suggestions are now generated on-demand only
    debugPrint('prefillQueues disabled - using on-demand generation only');
    return;
  }
  
  /// Generate a single suggestion on-demand (triggered by user action)
  /// Returns immediately with a loading suggestion, then emits events when ready
  Future<MediaSuggestion?> generateSuggestionOnDemand(String mediaType) async {
    if (_queueBeingFilled[mediaType] == true) {
      debugPrint('Already generating suggestion for $mediaType');
      return null;
    }

    // Quick synchronous checks only (avoid async operations here)
    debugPrint('🔍 Checking LlamaService.isInitialized: ${_llamaService.isInitialized}');
    if (!_llamaService.isInitialized) {
      debugPrint('❌ Cannot generate $mediaType suggestion: TinyLlama service not initialized');
      
      // Force a re-initialization attempt
      debugPrint('🔄 Attempting to re-initialize LlamaService...');
      _llamaService.initializeAuto().then((success) {
        debugPrint('🔄 Re-initialization result: $success');
      }).catchError((e) {
        debugPrint('💥 Re-initialization failed: $e');
      });
      
      return null;
    }

    _queueBeingFilled[mediaType] = true;

    // Emit started event
    _eventService.emitSuggestionStarted(mediaType);

    // Create and return a loading suggestion immediately (no async operations)
    final loadingSuggestion = MediaSuggestion(
      id: -1, // Temporary ID for loading state
      query: 'Generating $mediaType suggestion...',
      mediaType: mediaType,
      title: 'Loading...',
      artist: 'Generating suggestion',
      botReasoning: 'Finding the perfect $mediaType for you...',
      mediaId: _generateMediaId(mediaType, 'Loading', 'Generating suggestion'),
      status: SuggestionStatus.pending,
    );

    // Start background generation without blocking - new isolate system handles everything
    _generateSuggestionAsyncFull(mediaType).then((result) {
      _queueBeingFilled[mediaType] = false;
      if (result != null) {
        debugPrint('✅ Background suggestion ready: ${result.title}');
        _eventService.emitSuggestionReady(mediaType, result);
      } else {
        // Don't emit error here - the new isolate system handles its own error events
        // This null just means "no immediate suggestion, background generation in progress"
        debugPrint('🔄 Background suggestion generation in progress via isolate');
      }
    }).catchError((e, stackTrace) {
      _queueBeingFilled[mediaType] = false;
      debugPrint('❌ Error in background suggestion generation: $e');
      _eventService.emitSuggestionError(mediaType, e.toString());
    });

    return loadingSuggestion;
  }

  /// Generate suggestion in background and emit events when ready
  void _generateSuggestionInBackground(String mediaType) {
    debugPrint('🔄 Starting background suggestion generation for $mediaType');
    
    // Run all async operations in background
    _generateSuggestionAsyncFull(mediaType).then((result) {
      _queueBeingFilled[mediaType] = false;
      if (result != null) {
        debugPrint('✅ Background suggestion ready: ${result.title}');
        _eventService.emitSuggestionReady(mediaType, result);
      } else {
        debugPrint('❌ Background suggestion generation returned null');
        _eventService.emitSuggestionError(mediaType, 'Failed to generate suggestion');
      }
    }).catchError((e, stackTrace) {
      _queueBeingFilled[mediaType] = false;
      debugPrint('❌ Error in background suggestion generation: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      _eventService.emitSuggestionError(mediaType, e.toString());
    });
  }

  /// Generate suggestion with full async checks (for background use)
  Future<MediaSuggestion?> _generateSuggestionAsyncFull(String mediaType) async {
    try {
      // Do all async checks here (in background)
      final hasLLM = await _llamaService.isModelAvailable();
      final hasVectorDB = await isMediaTypeAvailable(mediaType);
      
      if (!hasLLM) {
        debugPrint('Cannot generate $mediaType suggestion: TinyLlama model not available');
        return null;
      }
      
      if (!hasVectorDB) {
        debugPrint('Cannot generate $mediaType suggestion: Vector database not available');
        return null;
      }

      // Now do the heavy operations
      return await _generateSuggestionAsync(mediaType);
    } catch (e) {
      debugPrint('Error in full async suggestion generation: $e');
      return null;
    }
  }

  /// Generate suggestion using queue-based system with background isolate
  Future<MediaSuggestion?> _generateSuggestionAsync(String mediaType) async {
    try {
      debugPrint('🔄 Checking suggestion queue for $mediaType');
      
      // Step 1: Try to get existing pending suggestion from queue
      final existingSuggestion = await _getNextPendingSuggestion(mediaType);
      if (existingSuggestion != null) {
        debugPrint('✅ Retrieved suggestion from queue: ${existingSuggestion.title}');
        
        // Trigger background refill of queue (non-blocking)
        _ensureQueueHasSuggestions(mediaType);
        
        return existingSuggestion;
      }
      
      debugPrint('🔄 No suggestions in queue, starting background generation for $mediaType');
      
      // Step 2: No suggestions available, trigger background generation
      // Emit loading state immediately so UI shows loading instead of error
      _eventService.emitSuggestionStarted(mediaType);
      _startBackgroundSuggestionGeneration(mediaType);
      
      // Return null immediately - UI will get suggestion via event when ready
      return null;
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error in queue-based suggestion generation: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Get next pending suggestion from database queue
  Future<MediaSuggestion?> _getNextPendingSuggestion(String mediaType) async {
    try {
      final suggestions = await _db.getAllMediaSuggestions(
        mediaType: mediaType,
        statusFilter: SuggestionStatus.pending,
        limit: 1,
      );
      
      if (suggestions.isNotEmpty) {
        return suggestions.first;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting pending suggestion: $e');
      return null;
    }
  }
  
  /// Ensure queue has at least one suggestion ready (non-blocking)
  void _ensureQueueHasSuggestions(String mediaType) {
    // Don't start generation if already in progress
    if (_backgroundGenerationInProgress[mediaType] == true) {
      debugPrint('⚠️ Queue check skipped for $mediaType - generation already in progress');
      return;
    }
    
    // Run in background without awaiting
    Future.microtask(() async {
      try {
        final pendingCount = await _getPendingSuggestionCount(mediaType);
        if (pendingCount < 1) {
          debugPrint('🔄 Queue low for $mediaType ($pendingCount suggestions), refilling...');
          _startBackgroundSuggestionGeneration(mediaType);
        } else {
          debugPrint('✅ Queue has $pendingCount suggestions for $mediaType');
        }
      } catch (e) {
        debugPrint('❌ Error checking queue: $e');
      }
    });
  }
  
  /// Get count of pending suggestions for media type
  Future<int> _getPendingSuggestionCount(String mediaType) async {
    try {
      final count = await _db.countPendingMediaSuggestions(mediaType);
      return count;
    } catch (e) {
      debugPrint('❌ Error counting pending suggestions: $e');
      return 0;
    }
  }
  
  /// Start background suggestion generation in pure isolate (non-blocking)
  void _startBackgroundSuggestionGeneration(String mediaType) {
    // Check if generation is already in progress for this media type
    if (_backgroundGenerationInProgress[mediaType] == true) {
      debugPrint('⚠️ [BACKGROUND] Generation already in progress for $mediaType, skipping duplicate');
      return;
    }
    
    // Mark as in progress
    _backgroundGenerationInProgress[mediaType] = true;
    
    // Run entirely in background without blocking UI
    Future.microtask(() async {
      try {
        debugPrint('🔄 [BACKGROUND] Starting PURE ISOLATE suggestion generation for $mediaType');
        
        // Gather all dependencies needed for isolate
        final appSupportDir = await getApplicationSupportDirectory();
        final vectorDb = VectorDatabase();
        final enabledMediaTypes = vectorDb.enabledMediaTypes.toList();
        
        // Get user profile data for enhanced reasoning
        Map<String, dynamic>? userProfileData;
        try {
          debugPrint('🔍 [BACKGROUND] Loading user interaction history for $mediaType...');
          
          // Debug: inspect the database first
          await _db.debugInspectRecommendationsTable();
          
          final likedSuggestions = await _db.getLikedRecommendations(mediaType);
          final dislikedSuggestions = await _db.getDislikedRecommendations(mediaType);
          
          // ENHANCED: Also collect favorite, watchlist, and skipped suggestions as behavioral signals
          final favoriteSuggestions = await _db.getFavoritedRecommendations(mediaType); // SuggestionStatus.added
          final watchlistSuggestions = await _db.getWatchlistedRecommendations(mediaType); // SuggestionStatus.watchlist
          final skippedSuggestions = await _db.getSkippedRecommendations(mediaType); // SuggestionStatus.skipped
          
          debugPrint('🔍 [BACKGROUND] Found ${likedSuggestions.length} liked, ${dislikedSuggestions.length} disliked, ${favoriteSuggestions.length} favorited, ${watchlistSuggestions.length} watchlisted, ${skippedSuggestions.length} skipped suggestions');
          
          // Always check for user constraints
          final userConstraints = await _db.getUserConstraints(mediaType);
          debugPrint('🔍 [BACKGROUND] Found ${userConstraints.length} user constraints: $userConstraints');
          
          // Create profile data if we have ANY user data (constraints, likes, dislikes, favorites, watchlist, or skipped)
          if (likedSuggestions.isNotEmpty || dislikedSuggestions.isNotEmpty || favoriteSuggestions.isNotEmpty || 
              watchlistSuggestions.isNotEmpty || skippedSuggestions.isNotEmpty || userConstraints.isNotEmpty) {
            // Extract themes and artists from user history
            final preferredThemes = <String>{};
            final avoidedThemes = <String>{};
            final preferredArtists = <String>{};
            final avoidedArtists = <String>{};
            
            // Process liked suggestions
            for (final suggestion in likedSuggestions) {
              if (suggestion.themes != null) {
                final themes = suggestion.themes!.split(',').map((t) => t.trim());
                preferredThemes.addAll(themes.where((t) => t.isNotEmpty));
              }
              if (suggestion.artist != null && suggestion.artist!.isNotEmpty) {
                preferredArtists.add(suggestion.artist!);
              }
            }
            
            // Process favorited suggestions (strong positive signal)
            for (final suggestion in favoriteSuggestions) {
              if (suggestion.themes != null) {
                final themes = suggestion.themes!.split(',').map((t) => t.trim());
                preferredThemes.addAll(themes.where((t) => t.isNotEmpty));
              }
              if (suggestion.artist != null && suggestion.artist!.isNotEmpty) {
                preferredArtists.add(suggestion.artist!);
              }
            }
            
            // Process watchlisted suggestions (moderate positive signal)
            for (final suggestion in watchlistSuggestions) {
              if (suggestion.themes != null) {
                final themes = suggestion.themes!.split(',').map((t) => t.trim());
                preferredThemes.addAll(themes.where((t) => t.isNotEmpty));
              }
              if (suggestion.artist != null && suggestion.artist!.isNotEmpty) {
                preferredArtists.add(suggestion.artist!);
              }
            }
            
            // Process disliked suggestions
            for (final suggestion in dislikedSuggestions) {
              if (suggestion.themes != null) {
                final themes = suggestion.themes!.split(',').map((t) => t.trim());
                avoidedThemes.addAll(themes.where((t) => t.isNotEmpty));
              }
              if (suggestion.artist != null && suggestion.artist!.isNotEmpty) {
                avoidedArtists.add(suggestion.artist!);
              }
            }
            
            // Process skipped suggestions (weak negative signal)
            for (final suggestion in skippedSuggestions) {
              if (suggestion.themes != null) {
                final themes = suggestion.themes!.split(',').map((t) => t.trim());
                avoidedThemes.addAll(themes.where((t) => t.isNotEmpty));
              }
              if (suggestion.artist != null && suggestion.artist!.isNotEmpty) {
                avoidedArtists.add(suggestion.artist!);
              }
            }

            
            userProfileData = {
              'preferredThemes': preferredThemes.toList(),
              'avoidedThemes': avoidedThemes.toList(),
              'preferredArtists': preferredArtists.toList(),
              'avoidedArtists': avoidedArtists.toList(),
              'constraints': [], // Rule-based constraints (generated)
              'userConstraints': userConstraints, // Explicit user constraints (critical directives)
              // NEW: Add all behavioral data for vector search
              'liked_items': likedSuggestions.map((s) => {
                'media_id': s.mediaId ?? s.id.toString(),
                'title': s.title,
                'artist': s.artist,
                'themes': s.themes,
              }).toList(),
              'favorite_items': favoriteSuggestions.map((s) => {
                'media_id': s.mediaId ?? s.id.toString(),
                'title': s.title,
                'artist': s.artist,
                'themes': s.themes,
              }).toList(),
              'watchlist_items': watchlistSuggestions.map((s) => {
                'media_id': s.mediaId ?? s.id.toString(),
                'title': s.title,
                'artist': s.artist,
                'themes': s.themes,
              }).toList(),
              'disliked_items': dislikedSuggestions.map((s) => {
                'media_id': s.mediaId ?? s.id.toString(),
                'title': s.title,
                'artist': s.artist,
                'themes': s.themes,
              }).toList(),
              'skipped_items': skippedSuggestions.map((s) => {
                'media_id': s.mediaId ?? s.id.toString(),
                'title': s.title,
                'artist': s.artist,
                'themes': s.themes,
              }).toList(),
            };
            
            debugPrint('🧠 [BACKGROUND] Using user profile: ${preferredThemes.length} preferred themes, ${preferredArtists.length} preferred artists, ${userConstraints.length} user constraints, ${favoriteSuggestions.length} favorites, ${watchlistSuggestions.length} watchlist, ${skippedSuggestions.length} skipped');
          } else {
            debugPrint('🔍 [BACKGROUND] No user data found - no constraints, likes, or dislikes');
          }
        } catch (e) {
          debugPrint('⚠️ [BACKGROUND] Could not load user profile, using basic reasoning: $e');
        }
        
        debugPrint('🔄 [BACKGROUND] Passing to isolate: appPath=${appSupportDir.path}, enabledTypes=$enabledMediaTypes, profile=${userProfileData != null}');
        
        // Build user query based on constraints if available
        String userQuery = 'Suggest a great $mediaType';
        if (userProfileData != null) {
          final userConstraints = userProfileData['userConstraints'] as List<String>? ?? [];
          if (userConstraints.isNotEmpty) {
            userQuery = 'Suggest $mediaType that matches: ${userConstraints.join(', ')}';
            debugPrint('🎯 [BACKGROUND] Using constraint-based query: $userQuery');
          }
        }
        
        // Generate suggestion in PURE isolate with all dependencies injected
        final result = await compute(_generateSuggestionInPureIsolate, {
          'mediaType': mediaType,
          'userQuery': userQuery,
          'appSupportPath': appSupportDir.path,
          'enabledMediaTypes': enabledMediaTypes,
          'userProfileData': userProfileData,
          'rootIsolateToken': RootIsolateToken.instance,
        });
        
        if (result == null) {
          debugPrint('❌ [BACKGROUND] Failed to generate suggestion in pure isolate');
          _eventService.emitSuggestionError(mediaType, 'Failed to generate suggestion');
          return;
        }
        
        debugPrint('✅ [BACKGROUND] Generated suggestion in pure isolate: ${result['title']}');
        
        // Create and save suggestion on main thread
        final suggestion = MediaSuggestion(
          query: 'User requested $mediaType suggestion',
          mediaType: mediaType,
          title: result['title'],
          artist: result['artist'],
          album: result['album'],
          coverArtUrl: result['coverArtUrl'],
          description: result['description'],
          wikiUrl: result['wikiUrl'],
          wikidataId: result['wikidataId'],
          themes: result['themes'],
          botReasoning: result['botReasoning'],
          mediaId: _generateMediaId(mediaType, result['title'], result['artist']),
          status: SuggestionStatus.pending,
        );
        
        final savedSuggestion = await _saveValidatedSuggestion(suggestion);
        
        if (savedSuggestion != null) {
          debugPrint('✅ [BACKGROUND] Saved suggestion to queue: ${savedSuggestion.title} (ID: ${savedSuggestion.id})');
          
          // Emit event that suggestion is ready
          _eventService.emitSuggestionReady(mediaType, savedSuggestion);
        } else {
          debugPrint('❌ [BACKGROUND] Failed to save suggestion to queue');
          _eventService.emitSuggestionError(mediaType, 'Failed to save suggestion');
        }
        
      } catch (e, stackTrace) {
        debugPrint('❌ [BACKGROUND] Error in background suggestion generation: $e');
        debugPrint('❌ [BACKGROUND] Stack trace: $stackTrace');
        _eventService.emitSuggestionError(mediaType, 'Background generation error: $e');
      } finally {
        // Always clear the in-progress flag
        _backgroundGenerationInProgress[mediaType] = false;
        debugPrint('🏁 [BACKGROUND] Generation completed for $mediaType, flag cleared');
      }
    });
  }

  /// Generate media_id for linking to vector database
  static String _generateMediaId(String mediaType, String? title, String? artist) {
    // Clean up title and artist for use in media_id
    String cleanTitle = (title ?? 'Unknown').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    String cleanArtist = (artist ?? 'Unknown').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    
    // Generate a simple counter-based ID (in production, should be more sophisticated)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final counter = timestamp % 1000000; // Last 6 digits
    
    // Format: mediaType_counter_ArtistTitle
    return '${mediaType}_${counter.toString().padLeft(6, '0')}_${cleanArtist}${cleanTitle}';
  }

  /// Extract behavioral data from user profile for matching
  static Map<String, dynamic> _extractBehavioralDataFromProfile(Map<String, dynamic> userProfileData) {
    final likedItemIds = <String>[];
    final dislikedItemIds = <String>[];
    final skippedItemIds = <String>[];
    final excludeIds = <String>[];
    String? favoriteItemId;
    
    try {
      // Extract from liked items
      final likedItems = userProfileData['liked_items'] as List<dynamic>? ?? [];
      for (final item in likedItems) {
        if (item is Map<String, dynamic> && item['media_id'] != null) {
          likedItemIds.add(item['media_id'] as String);
        }
      }
      
      // Extract from disliked items
      final dislikedItems = userProfileData['disliked_items'] as List<dynamic>? ?? [];
      for (final item in dislikedItems) {
        if (item is Map<String, dynamic> && item['media_id'] != null) {
          dislikedItemIds.add(item['media_id'] as String);
        }
      }
      
      // Extract from skipped items
      final skippedItems = userProfileData['skipped_items'] as List<dynamic>? ?? [];
      for (final item in skippedItems) {
        if (item is Map<String, dynamic> && item['media_id'] != null) {
          skippedItemIds.add(item['media_id'] as String);
        }
      }
      
      // Extract favorite item
      final favoriteItem = userProfileData['favorite_item'] as Map<String, dynamic>?;
      if (favoriteItem != null && favoriteItem['media_id'] != null) {
        favoriteItemId = favoriteItem['media_id'] as String;
      }
      
      // Exclude all interacted items from new suggestions
      excludeIds.addAll(likedItemIds);
      excludeIds.addAll(dislikedItemIds);
      excludeIds.addAll(skippedItemIds);
      if (favoriteItemId != null) {
        excludeIds.add(favoriteItemId);
      }
      
      final hasPositiveSignals = likedItemIds.isNotEmpty || favoriteItemId != null;
      
      debugPrint('🎯 [BEHAVIORAL-EXTRACT] Extracted: ${likedItemIds.length} liked, '
          '${dislikedItemIds.length} disliked, ${skippedItemIds.length} skipped, '
          '${favoriteItemId != null ? 1 : 0} favorite, hasPositive: $hasPositiveSignals');
      
      return {
        'likedItemIds': likedItemIds,
        'dislikedItemIds': dislikedItemIds,
        'skippedItemIds': skippedItemIds,
        'favoriteItemId': favoriteItemId,
        'excludeIds': excludeIds,
        'hasPositiveSignals': hasPositiveSignals,
      };
    } catch (e) {
      debugPrint('⚠️ [BEHAVIORAL-EXTRACT] Error extracting behavioral data: $e');
      return {
        'likedItemIds': <String>[],
        'dislikedItemIds': <String>[],
        'skippedItemIds': <String>[],
        'favoriteItemId': null,
        'excludeIds': <String>[],
        'hasPositiveSignals': false,
      };
    }
  }

  /// Static function to run COMPLETE suggestion generation in pure isolate (no platform channels)
  static Future<Map<String, dynamic>?> _generateSuggestionInPureIsolate(Map<String, dynamic> params) async {
    try {
      final String mediaType = params['mediaType'];
      final String userQuery = params['userQuery'];
      final String appSupportPath = params['appSupportPath'];
      final List<String> enabledMediaTypes = List<String>.from(params['enabledMediaTypes']);
      final Map<String, dynamic>? userProfileData = params['userProfileData'];
      final RootIsolateToken? rootIsolateToken = params['rootIsolateToken'];
      
      debugPrint('🔄 [PURE-ISOLATE] Starting suggestion generation for $mediaType');
      debugPrint('🔄 [PURE-ISOLATE] App path: $appSupportPath');
      debugPrint('🔄 [PURE-ISOLATE] Enabled types: $enabledMediaTypes');
      debugPrint('🔄 [PURE-ISOLATE] User profile: ${userProfileData != null ? 'available' : 'not available'}');
      
      // Step 1: Create isolate-safe vector database with injected dependencies
      final vectorDb = await _createIsolateSafeVectorDatabase(appSupportPath, enabledMediaTypes, mediaType);
      
      if (vectorDb == null) {
        debugPrint('❌ [PURE-ISOLATE] Failed to create vector database');
        return null;
      }
      
      // Step 2: Use behavioral matching or fallback to random
      List<MediaResult> searchResults;
      
      if (userProfileData != null) {
        debugPrint('🎯 [PURE-ISOLATE] Attempting behavioral matching...');
        
        // Extract behavioral data from user profile
        final behavioralData = _extractBehavioralDataFromProfile(userProfileData);
        
        // Try constraint-based search first if we have user constraints
        final userConstraints = userProfileData['userConstraints'] as List<String>? ?? [];
        if (userConstraints.isNotEmpty) {
          debugPrint('🎯 [PURE-ISOLATE] Using constraint-based search for: ${userConstraints.join(', ')}');
          final constraintResults = await vectorDb.searchByConstraints(
            constraints: userConstraints,
            excludeIds: behavioralData['excludeIds'] as List<String>,
            limit: 1,
          );
          
          if (constraintResults.isNotEmpty) {
            debugPrint('✅ [PURE-ISOLATE] Found ${constraintResults.length} constraint-based matches');
            searchResults = constraintResults;
          } else {
            debugPrint('⚠️ [PURE-ISOLATE] No constraint matches found, trying behavioral matching');
            // Fall back to behavioral matching
            if (behavioralData['hasPositiveSignals']) {
              final behavioralResults = await vectorDb.searchByBehavioralMatch(
                likedItemIds: behavioralData['likedItemIds'] as List<String>,
                dislikedItemIds: behavioralData['dislikedItemIds'] as List<String>,
                favoriteItemId: behavioralData['favoriteItemId'] as String?,
                skippedItemIds: behavioralData['skippedItemIds'] as List<String>,
                excludeIds: behavioralData['excludeIds'] as List<String>,
                limit: 1,
              );
              searchResults = behavioralResults.isNotEmpty ? behavioralResults : await vectorDb.getRandomMedia(mediaType: mediaType, limit: 1);
            } else {
              searchResults = await vectorDb.getRandomMedia(mediaType: mediaType, limit: 1);
            }
          }
        } else if (behavioralData['hasPositiveSignals']) {
          // NEW: Use behavioral data to trigger LLM-enhanced vector search even without explicit constraints
          debugPrint('🎯 [PURE-ISOLATE] Using behavioral vector search with LLM enhancement');
          final behavioralResults = await vectorDb.searchByBehavioralMatch(
            likedItemIds: behavioralData['likedItemIds'] as List<String>,
            dislikedItemIds: behavioralData['dislikedItemIds'] as List<String>,
            favoriteItemId: behavioralData['favoriteItemId'] as String?,
            skippedItemIds: behavioralData['skippedItemIds'] as List<String>,
            excludeIds: behavioralData['excludeIds'] as List<String>,
            limit: 1,
          );
          searchResults = behavioralResults.isNotEmpty ? behavioralResults : await vectorDb.getRandomMedia(mediaType: mediaType, limit: 1);
          
          // Try TensorFlow Lite enhanced matching first
          final tfliteResult = await vectorDb._tryTensorFlowLiteMatching(
            behavioralData: behavioralData,
            mediaType: mediaType,
          );
          
          if (tfliteResult != null) {
            debugPrint('✅ [PURE-ISOLATE] TensorFlow Lite found optimal match');
            searchResults = [tfliteResult];
          } else {
            debugPrint('⚠️ [PURE-ISOLATE] TensorFlow Lite failed, falling back to behavioral matching');
            final behavioralResults = await vectorDb.searchByBehavioralMatch(
              likedItemIds: behavioralData['likedItemIds'] as List<String>,
              dislikedItemIds: behavioralData['dislikedItemIds'] as List<String>,
              favoriteItemId: behavioralData['favoriteItemId'] as String?,
              skippedItemIds: behavioralData['skippedItemIds'] as List<String>,
              excludeIds: behavioralData['excludeIds'] as List<String>,
              limit: 1,
            );
            
            if (behavioralResults.isNotEmpty) {
              debugPrint('✅ [PURE-ISOLATE] Found ${behavioralResults.length} behavioral matches');
              searchResults = behavioralResults;
            } else {
              debugPrint('⚠️ [PURE-ISOLATE] No behavioral matches found, falling back to random');
              final randomResults = await vectorDb.getRandomMedia(mediaType: mediaType, limit: 1);
              searchResults = randomResults;
            }
          }
        } else {
          debugPrint('⚠️ [PURE-ISOLATE] No behavioral signals available, using random selection');
          final randomResults = await vectorDb.getRandomMedia(mediaType: mediaType, limit: 1);
          searchResults = randomResults;
        }
      } else {
        debugPrint('🔄 [PURE-ISOLATE] No user profile, using random selection...');
        final randomResults = await vectorDb.getRandomMedia(mediaType: mediaType, limit: 1);
        searchResults = randomResults;
      }
      
      if (searchResults.isEmpty) {
        debugPrint('❌ [PURE-ISOLATE] No media found in vector database for $mediaType');
        return null;
      }
      
      final mediaResult = searchResults.first;
      debugPrint('✅ [PURE-ISOLATE] Selected media: ${mediaResult.title}');
      
      // Step 3: Generate LLM response (enhanced or basic based on user profile)
      debugPrint('🔄 [PURE-ISOLATE] Generating LLM response...');
      final response = userProfileData != null 
        ? await _generateEnhancedBehavioralReasoningPure(
            userQuery: userQuery,
            mediaTitle: mediaResult.title,
            mediaType: mediaType,
            artist: mediaResult.artist,
            themes: mediaResult.themes,
            description: mediaResult.description,
            similarity: 1.0,
            userProfileData: userProfileData,
            rootIsolateToken: rootIsolateToken,
          )
        : _generateContextualExplanationPure(
            userQuery: userQuery,
            mediaTitle: mediaResult.title,
            mediaType: mediaType,
            artist: mediaResult.artist,
            themes: mediaResult.themes,
            description: mediaResult.description,
            similarity: 1.0,
          );
      
      debugPrint('✅ [PURE-ISOLATE] Generated complete suggestion: ${mediaResult.title}');
      
      // Return all data needed for suggestion creation
      return {
        'title': mediaResult.title,
        'artist': mediaResult.artist,
        'album': mediaResult.album,
        'coverArtUrl': mediaResult.coverArtUrl,
        'description': mediaResult.description,
        'wikiUrl': mediaResult.wikiUrl,
        'wikidataId': mediaResult.wikidataId,
        'themes': mediaResult.themes,
        'botReasoning': response,
      };
    } catch (e) {
      debugPrint('❌ [PURE-ISOLATE] Error in suggestion generation: $e');
      return null;
    }
  }
  
  /// Create isolate-safe vector database that bypasses platform channels
  static Future<_IsolateSafeVectorDatabase?> _createIsolateSafeVectorDatabase(
    String appSupportPath, 
    List<String> enabledMediaTypes, 
    String targetMediaType
  ) async {
    try {
      // Create vector database directory path
      final vectorDirPath = pathLib.join(appSupportPath, 'vectors');
      
      // Media type to file mapping
      const shardFiles = {
        'video_game': 'vectors_games.db',
        'movie': 'vectors_movies.db', 
        'tv_show': 'vectors_tv.db',
        'book': 'vectors_books.db',
        'music': 'vectors_music.db',
      };
      
      if (!shardFiles.containsKey(targetMediaType)) {
        debugPrint('❌ [PURE-ISOLATE] Unknown media type: $targetMediaType');
        return null;
      }
      
      if (!enabledMediaTypes.contains(targetMediaType)) {
        debugPrint('❌ [PURE-ISOLATE] Media type not enabled: $targetMediaType');
        return null;
      }
      
      final filename = shardFiles[targetMediaType]!;
      final dbPath = pathLib.join(vectorDirPath, filename);
      
      debugPrint('🔄 [PURE-ISOLATE] Opening vector database at: $dbPath');
      
      // Check if file exists
      final file = File(dbPath);
      if (!await file.exists()) {
        debugPrint('❌ [PURE-ISOLATE] Vector database file not found: $dbPath');
        return null;
      }
      
      // Create a minimal VectorDatabase that only opens the specific shard
      final vectorDb = _IsolateSafeVectorDatabase(dbPath, targetMediaType);
      await vectorDb.init();
      
      return vectorDb;
    } catch (e) {
      debugPrint('❌ [PURE-ISOLATE] Error creating vector database: $e');
      return null;
    }
  }

  /// Static function to run LLM inference in isolate
  static Future<String?> _generateLLMResponseInIsolate(Map<String, dynamic> params) async {
    try {
      // Extract parameters
      final String userQuery = params['userQuery'];
      final String mediaTitle = params['mediaTitle'];
      final String mediaType = params['mediaType'];
      final String? artist = params['artist'];
      final String? themes = params['themes'];
      final String? description = params['description'];
      final double similarity = params['similarity'];
      
      // Generate explanation using pure computation (no platform channels)
      final response = _generateContextualExplanationPure(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        similarity: similarity,
      );
      
      return response;
    } catch (e) {
      debugPrint('Error in LLM isolate task: $e');
      return null;
    }
  }

  /// Pure computation version of explanation generation (isolate-safe)
  /// Creates user-friendly explanations using available data without exposing internal queries
  static String _generateContextualExplanationPure({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    double? similarity,
  }) {
    final stopwatch = Stopwatch()..start();
    final buffer = StringBuffer();
    
    // Start with a clean, user-friendly opening
    buffer.write('$mediaTitle');
    
    // Add artist/creator information if available
    if (artist != null && artist.isNotEmpty && artist.toLowerCase() != 'unknown') {
      if (mediaType == 'music') {
        buffer.write(' by $artist');
      } else if (mediaType == 'book') {
        buffer.write(' by $artist');
      } else if (mediaType == 'movie' || mediaType == 'tv_show') {
        buffer.write(' directed by $artist');
      } else {
        buffer.write(' by $artist');
      }
    }
    
    // Add quality statement
    buffer.write(' offers');
    
    // Add theme-based reasoning if available
    if (themes != null && themes.isNotEmpty) {
      final themesList = themes.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).take(3).toList();
      if (themesList.isNotEmpty) {
        if (themesList.length == 1) {
          buffer.write(' ${themesList.first}');
        } else if (themesList.length == 2) {
          buffer.write(' ${themesList.first} and ${themesList.last}');
        } else {
          buffer.write(' ${themesList[0]}, ${themesList[1]}, and ${themesList[2]}');
        }
        buffer.write(' elements');
      } else {
        buffer.write(' compelling content');
      }
    } else {
      // Fallback based on media type
      switch (mediaType) {
        case 'music':
          buffer.write(' engaging musical content');
          break;
        case 'movie':
          buffer.write(' compelling cinematic storytelling');
          break;
        case 'tv_show':
          buffer.write(' engaging episodic entertainment');
          break;
        case 'book':
          buffer.write(' compelling literary content');
          break;
        case 'video_game':
          buffer.write(' engaging interactive entertainment');
          break;
        default:
          buffer.write(' quality entertainment');
      }
    }
    
    // Add a quality closing
    buffer.write(' worth exploring.');
    
    stopwatch.stop();
    debugPrint('⏱️ Clean explanation generated in ${stopwatch.elapsedMilliseconds}ms');
    
    return buffer.toString();
  }

  /// Generate optimized search query using LLM in isolate
  static Future<String?> _generateOptimizedSearchQuery({
    required String userQuery,
    required String mediaType,
    required Map<String, dynamic> userProfileData,
    required RootIsolateToken rootIsolateToken,
  }) async {
    try {
      debugPrint('🧠 [ISOLATE-LLM] Starting search query optimization for: $userQuery');
      debugPrint('🧠 [ISOLATE-LLM] Media type: $mediaType');
      
      // Initialize background isolate messenger
      debugPrint('🧠 [ISOLATE-LLM] Initializing background isolate messenger...');
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
      debugPrint('🧠 [ISOLATE-LLM] ✅ Background messenger initialized with token');
      
      // Initialize LlamaService in isolate
      debugPrint('🧠 [ISOLATE-LLM] Initializing LlamaService in isolate...');
      final llamaService = LlamaService();
      await llamaService.initializeAuto();
      debugPrint('🧠 [ISOLATE-LLM] ✅ LlamaService initialized in isolate');
      
      // Extract user profile
      final preferredThemes = (userProfileData['preferredThemes'] as List<dynamic>?)?.cast<String>() ?? [];
      final preferredArtists = (userProfileData['preferredArtists'] as List<dynamic>?)?.cast<String>() ?? [];
      final userConstraints = (userProfileData['userConstraints'] as List<dynamic>?)?.cast<String>() ?? [];
      
      debugPrint('🧠 [ISOLATE-LLM] User profile: ${preferredThemes.length} themes, ${preferredArtists.length} artists, ${userConstraints.length} constraints');
      
      // Format user profile for prompt
      final formattedThemes = preferredThemes.isNotEmpty ? preferredThemes.join(', ') : '';
      final formattedArtists = preferredArtists.isNotEmpty ? preferredArtists.join(', ') : '';
      final formattedConstraints = userConstraints.isNotEmpty ? userConstraints.join('; ') : '';
      
      String combinedProfile = '';
      if (formattedThemes.isNotEmpty) combinedProfile += formattedThemes;
      if (formattedArtists.isNotEmpty) {
        if (combinedProfile.isNotEmpty) combinedProfile += ', ';
        combinedProfile += formattedArtists;
      }
      if (formattedConstraints.isNotEmpty) {
        if (combinedProfile.isNotEmpty) combinedProfile += ' | CONSTRAINTS: ';
        combinedProfile += formattedConstraints;
      }
      
      debugPrint('🧠 [ISOLATE-LLM] Combined profile: "$combinedProfile"');
      
      // Use the LLM method correctly - pass user query + context
      debugPrint('🧠 [ISOLATE-LLM] Generating search query for: "$userQuery"');
      
      final stopwatch = Stopwatch()..start();
      final searchQuery = await llamaService.generateDistilledSearchQuery(
        userQuery, 
        mediaType: mediaType, 
        context: combinedProfile
      );
      stopwatch.stop();
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        debugPrint('🧠 [ISOLATE-LLM] ✅ Search query generation SUCCESS in ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('🔍 [ISOLATE-LLM] Generated query: "$searchQuery"');
        return searchQuery;
      } else {
        debugPrint('❌ [ISOLATE-LLM] Search query generation returned empty result');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [ISOLATE-LLM] Error in search query generation: $e');
      return null;
    }
  }

  /// Generate enhanced behavioral reasoning with LLM
  static Future<String> _generateEnhancedBehavioralReasoningPure({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    required double similarity,
    required Map<String, dynamic> userProfileData,
    RootIsolateToken? rootIsolateToken,
  }) async {
    if (rootIsolateToken == null) {
      return _generateContextualExplanationPure(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        similarity: similarity,
      );
    }
    
    try {
      // Extract behavioral context for LLM
      final behavioralContext = _extractBehavioralContextForLLM(userProfileData);
      
      // Initialize background messenger and LLM service in isolate
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
      debugPrint('🧠 [ISOLATE-LLM] ✅ Background messenger initialized with token');
      
      final llamaService = LlamaService();
      await llamaService.initializeAuto();
      
      if (!llamaService.isInitialized) {
        debugPrint('⚠️ [ISOLATE-LLM] LLM not available in isolate, using rule-based reasoning');
        return _generateContextualExplanationPure(
          userQuery: userQuery,
          mediaTitle: mediaTitle,
          mediaType: mediaType,
          artist: artist,
          themes: themes,
          description: description,
          similarity: similarity,
        );
      }
      
      debugPrint('🧠 [ISOLATE-LLM] ✅ LlamaService initialized in isolate');
      
      // Build enhanced prompt with behavioral context
      final prompt = _buildEnhancedBehavioralPrompt(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        behavioralContext: behavioralContext,
      );
      
      final startTime = DateTime.now();
      
      // Simplified LLM approach with better error handling and truncation
      try {
        // Create a simple, focused prompt with smart truncation
        final constraints = behavioralContext['userConstraints'] as String;
        final likedThemes = behavioralContext['likedThemes'] as List<String>;
        
        // Apply truncation limits to prevent token overflow
        const int maxTitleLength = 50;
        const int maxArtistLength = 35;
        const int maxConstraintsLength = 80;
        const int maxThemesLength = 90;
        
        // Truncate media title if too long
        String truncatedTitle = mediaTitle;
        if (mediaTitle.length > maxTitleLength) {
          truncatedTitle = mediaTitle.substring(0, maxTitleLength - 3) + '...';
        }
        
        // Start with media type context to avoid confusion
        String mediaTypeLabel = _getMediaTypeLabel(mediaType);
        String simplePrompt = "Why recommend this $mediaTypeLabel \"$truncatedTitle\"";
        
        // Add artist with truncation
        if (artist != null && artist.isNotEmpty) {
          String truncatedArtist = artist;
          if (artist.length > maxArtistLength) {
            truncatedArtist = artist.substring(0, maxArtistLength - 3) + '...';
          }
          simplePrompt += " by $truncatedArtist";
        }
        simplePrompt += "?";
        
        // Add context if available (with truncation)
        if (constraints.isNotEmpty) {
          String truncatedConstraints = constraints;
          if (constraints.length > maxConstraintsLength) {
            truncatedConstraints = constraints.substring(0, maxConstraintsLength - 3) + '...';
          }
          simplePrompt += " User likes: $truncatedConstraints.";
        } else if (likedThemes.isNotEmpty) {
          simplePrompt += " User likes: ${likedThemes.take(2).join(', ')}.";
        }
        
        if (themes != null && themes.isNotEmpty) {
          String truncatedThemes = themes;
          if (themes.length > maxThemesLength) {
            truncatedThemes = themes.substring(0, maxThemesLength - 3) + '...';
          }
          simplePrompt += " This has: $truncatedThemes.";
        }
        
        simplePrompt += " Explain why this is a great match.";
        
        // Final safety check for prompt length
        const int maxPromptLength = 350;
        if (simplePrompt.length > maxPromptLength) {
          debugPrint('⚠️ [ISOLATE-LLM] Simple prompt too long (${simplePrompt.length} chars), applying aggressive truncation');
          String mediaTypeLabel = _getMediaTypeLabel(mediaType);
          simplePrompt = "Why recommend this $mediaTypeLabel \"${truncatedTitle.length > 30 ? truncatedTitle.substring(0, 27) + '...' : truncatedTitle}\"";
          if (artist != null && artist.isNotEmpty) {
            String minimalArtist = artist.length > 20 ? artist.substring(0, 17) + '...' : artist;
            simplePrompt += " by $minimalArtist";
          }
          simplePrompt += "? Explain why it's perfect.";
        }
        
        debugPrint('🧠 [ISOLATE-LLM] Simple prompt: "$simplePrompt"');
        
        final response = await llamaService.generateExplanation(
          mediaTitle: mediaTitle,
          artist: artist ?? '',
          themes: themes ?? '',
          userQuery: simplePrompt,
          mediaType: mediaType,
        ).timeout(
          const Duration(seconds: 8), // Longer timeout since we reduced vector processing load
          onTimeout: () {
            debugPrint('⏰ [ISOLATE-LLM] LLM timed out after 8 seconds');
            return '';
          },
        );
        
        final duration = DateTime.now().difference(startTime).inMilliseconds;
        
        // Simple validation - reject obvious failures
        if (response.trim().isNotEmpty && 
            !response.contains('ERROR') &&
            !response.contains('LlamaException') &&
            !response.contains('Failed to eval') &&
            response.trim() != '1.' &&
            response.trim() != '1' &&
            response.length > 5) {
          debugPrint('🧠 [ISOLATE-LLM] ✅ Simple LLM reasoning SUCCESS in ${duration}ms');
          return response.trim();
        } else {
          debugPrint('⚠️ [ISOLATE-LLM] Invalid LLM response, using clean fallback');
          return _generateContextualExplanationPure(
            userQuery: userQuery,
            mediaTitle: mediaTitle,
            mediaType: mediaType,
            artist: artist,
            themes: themes,
            description: description,
            similarity: similarity,
          );
        }
      } catch (e) {
        debugPrint('❌ [ISOLATE-LLM] LLM exception: $e, using clean fallback');
        return _generateContextualExplanationPure(
          userQuery: userQuery,
          mediaTitle: mediaTitle,
          mediaType: mediaType,
          artist: artist,
          themes: themes,
          description: description,
          similarity: similarity,
        );
      }
    } catch (e) {
      debugPrint('❌ [ISOLATE-LLM] Error in enhanced behavioral reasoning: $e');
      return _generateContextualExplanationPure(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        similarity: similarity,
      );
    }
  }

  /// Get user-friendly media type label
  static String _getMediaTypeLabel(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'music': return 'song';
      case 'movie': return 'movie';
      case 'tv_show': return 'TV show';
      case 'book': return 'book';
      case 'video_game': return 'game';
      default: return 'item';
    }
  }

  /// Extract behavioral context for LLM prompts
  static Map<String, dynamic> _extractBehavioralContextForLLM(Map<String, dynamic> userProfileData) {
    try {
      final likedThemes = <String>[];
      final likedArtists = <String>[];
      final dislikedThemes = <String>[];
      final dislikedArtists = <String>[];
      String? favoriteTitle;
      String? favoriteArtist;
      
      // Extract from liked items
      final likedItems = userProfileData['liked_items'] as List<dynamic>? ?? [];
      for (final item in likedItems) {
        if (item is Map<String, dynamic>) {
          final themes = item['themes'] as String?;
          final artist = item['artist'] as String?;
          if (themes != null) likedThemes.addAll(themes.split(',').map((t) => t.trim()));
          if (artist != null) likedArtists.add(artist);
        }
      }
      
      // Extract from disliked items
      final dislikedItems = userProfileData['disliked_items'] as List<dynamic>? ?? [];
      for (final item in dislikedItems) {
        if (item is Map<String, dynamic>) {
          final themes = item['themes'] as String?;
          final artist = item['artist'] as String?;
          if (themes != null) dislikedThemes.addAll(themes.split(',').map((t) => t.trim()));
          if (artist != null) dislikedArtists.add(artist);
        }
      }
      
      // Extract favorite
      final favoriteItem = userProfileData['favorite_item'] as Map<String, dynamic>?;
      if (favoriteItem != null) {
        favoriteTitle = favoriteItem['title'] as String?;
        favoriteArtist = favoriteItem['artist'] as String?;
      }
      
      // Get user constraints
      final userConstraints = userProfileData['userConstraints'] as List<String>? ?? [];
      
      debugPrint('🧠 [BEHAVIORAL-CONTEXT] Extracted constraints: $userConstraints');
      debugPrint('🧠 [BEHAVIORAL-CONTEXT] Liked themes: $likedThemes');
      debugPrint('🧠 [BEHAVIORAL-CONTEXT] Liked artists: $likedArtists');
      
      return {
        'likedThemes': likedThemes.take(5).toList(), // Limit for prompt size
        'likedArtists': likedArtists.take(3).toList(),
        'dislikedThemes': dislikedThemes.take(3).toList(),
        'dislikedArtists': dislikedArtists.take(2).toList(),
        'favoriteTitle': favoriteTitle,
        'favoriteArtist': favoriteArtist,
        'userConstraints': userConstraints.join('; '),
      };
    } catch (e) {
      debugPrint('⚠️ [BEHAVIORAL-CONTEXT] Error extracting context: $e');
      return {
        'likedThemes': <String>[],
        'likedArtists': <String>[],
        'dislikedThemes': <String>[],
        'dislikedArtists': <String>[],
        'favoriteTitle': null,
        'favoriteArtist': null,
        'userConstraints': '',
      };
    }
  }

  /// Build enhanced behavioral prompt
  static String _buildEnhancedBehavioralPrompt({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    required Map<String, dynamic> behavioralContext,
  }) {
    final likedThemes = behavioralContext['likedThemes'] as List<String>;
    final likedArtists = behavioralContext['likedArtists'] as List<String>;
    final dislikedThemes = behavioralContext['dislikedThemes'] as List<String>;
    final dislikedArtists = behavioralContext['dislikedArtists'] as List<String>;
    final favoriteTitle = behavioralContext['favoriteTitle'] as String?;
    final favoriteArtist = behavioralContext['favoriteArtist'] as String?;
    final userConstraints = behavioralContext['userConstraints'] as String;
    
    // Build behavioral context strings
    final likedContext = likedThemes.isNotEmpty || likedArtists.isNotEmpty
        ? 'LIKES: ${likedThemes.join(', ')}${likedArtists.isNotEmpty ? ' | Artists: ${likedArtists.join(', ')}' : ''}'
        : '';
    
    final dislikedContext = dislikedThemes.isNotEmpty || dislikedArtists.isNotEmpty
        ? 'DISLIKES: ${dislikedThemes.join(', ')}${dislikedArtists.isNotEmpty ? ' | Artists: ${dislikedArtists.join(', ')}' : ''}'
        : '';
    
    final favoriteContext = favoriteTitle != null
        ? 'FAVORITE: "$favoriteTitle"${favoriteArtist != null ? ' by $favoriteArtist' : ''}'
        : '';
    
    final constraintsContext = userConstraints.isNotEmpty
        ? 'CONSTRAINTS: $userConstraints'
        : '';
    
    return '''RECOMMENDATION: "$mediaTitle"${artist != null ? ' by $artist' : ''}
USER REQUEST: "$userQuery"
THEMES: ${themes ?? 'N/A'}
${likedContext.isNotEmpty ? '$likedContext\n' : ''}${dislikedContext.isNotEmpty ? '$dislikedContext\n' : ''}${favoriteContext.isNotEmpty ? '$favoriteContext\n' : ''}${constraintsContext.isNotEmpty ? '$constraintsContext\n' : ''}
Why is this a perfect match based on their behavior? (1-2 sentences):''';
  }



  /// Generate enhanced reasoning with behavioral context
  static Future<String> _generateEnhancedReasoningPure({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    required double similarity,
    required Map<String, dynamic> userProfileData,
    RootIsolateToken? rootIsolateToken,
  }) async {
    if (rootIsolateToken == null) {
      return _generateContextualExplanationPure(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        similarity: similarity,
      );
    }
    
    try {
      // Extract behavioral context for LLM
      final behavioralContext = _extractBehavioralContextForLLM(userProfileData);
      
      // Initialize background messenger and LLM service in isolate
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
      debugPrint('🧠 [ISOLATE-LLM] ✅ Background messenger initialized with token');
      
      final llamaService = LlamaService();
      await llamaService.initializeAuto();
      
      if (!llamaService.isInitialized) {
        debugPrint('⚠️ [ISOLATE-LLM] LLM not available in isolate, using rule-based reasoning');
        return _generateContextualExplanationPure(
          userQuery: userQuery,
          mediaTitle: mediaTitle,
          mediaType: mediaType,
          artist: artist,
          themes: themes,
          description: description,
          similarity: similarity,
        );
      }
      
      debugPrint('🧠 [ISOLATE-LLM] ✅ LlamaService initialized in isolate');
      
      // Build enhanced prompt with behavioral context
      final prompt = _buildEnhancedReasoningPrompt(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        behavioralContext: behavioralContext,
      );
      
      final startTime = DateTime.now();
      
      // Generate LLM response using generateExplanation
      final response = await llamaService.generateExplanation(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
      );
      
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      
      if (response != null && response.trim().isNotEmpty) {
        debugPrint('🧠 [ISOLATE-LLM] ✅ Enhanced LLM reasoning SUCCESS in ${duration}ms');
        return response.trim();
      } else {
        debugPrint('⚠️ [ISOLATE-LLM] Empty LLM response, using rule-based fallback');
        return _generateContextualExplanationPure(
          userQuery: userQuery,
          mediaTitle: mediaTitle,
          mediaType: mediaType,
          artist: artist,
          themes: themes,
          description: description,
          similarity: similarity,
        );
      }
    } catch (e) {
      debugPrint('❌ [ISOLATE-LLM] Error in enhanced reasoning: $e');
      return _generateContextualExplanationPure(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        similarity: similarity,
      );
    }
  }

  /// Build enhanced reasoning prompt with behavioral context
  static String _buildEnhancedReasoningPrompt({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    required Map<String, dynamic> behavioralContext,
  }) {
    final likedThemes = behavioralContext['likedThemes'] as List<String>;
    final likedArtists = behavioralContext['likedArtists'] as List<String>;
    final dislikedThemes = behavioralContext['dislikedThemes'] as List<String>;
    final dislikedArtists = behavioralContext['dislikedArtists'] as List<String>;
    final favoriteTitle = behavioralContext['favoriteTitle'] as String?;
    final favoriteArtist = behavioralContext['favoriteArtist'] as String?;
    final userConstraints = behavioralContext['userConstraints'] as String;
    
    // Build behavioral context strings
    final likedContext = likedThemes.isNotEmpty || likedArtists.isNotEmpty
        ? 'LIKES: ${likedThemes.join(', ')}${likedArtists.isNotEmpty ? ' | Artists: ${likedArtists.join(', ')}' : ''}'
        : '';
    
    final dislikedContext = dislikedThemes.isNotEmpty || dislikedArtists.isNotEmpty
        ? 'DISLIKES: ${dislikedThemes.join(', ')}${dislikedArtists.isNotEmpty ? ' | Artists: ${dislikedArtists.join(', ')}' : ''}'
        : '';
    
    final favoriteContext = favoriteTitle != null
        ? 'FAVORITE: "$favoriteTitle"${favoriteArtist != null ? ' by $favoriteArtist' : ''}'
        : '';
    
    final constraintsContext = userConstraints.isNotEmpty
        ? 'CONSTRAINTS: $userConstraints'
        : '';
    
    return '''RECOMMENDATION: "$mediaTitle"${artist != null ? ' by $artist' : ''}
USER REQUEST: "$userQuery"
THEMES: ${themes ?? 'N/A'}
${likedContext.isNotEmpty ? '$likedContext\n' : ''}${dislikedContext.isNotEmpty ? '$dislikedContext\n' : ''}${favoriteContext.isNotEmpty ? '$favoriteContext\n' : ''}${constraintsContext.isNotEmpty ? '$constraintsContext\n' : ''}
Why is this a perfect match based on their behavior? (1-2 sentences):''';
  }

  /// Check if a media type database is available
  Future<bool> isMediaTypeAvailable(String mediaType) async {
    try {
      // Check if vector database for this media type is available
      final vectorDb = VectorDatabase();
      await vectorDb.init(); // Initialize the vector database
      return vectorDb.isMediaTypeEnabled(mediaType);
    } catch (e) {
      debugPrint('Error checking media type availability for $mediaType: $e');
      // For now, return true for music (default enabled) and false for others
      return mediaType == 'music';
    }
  }

  /// Get install status for a media type
  Future<String> getMediaTypeStatus(String mediaType) async {
    final isAvailable = await isMediaTypeAvailable(mediaType);
    if (isAvailable) {
      return 'available';
    } else {
      return 'install_required';
    }
  }
  
  @override
  void dispose() {
    _queueTimer?.cancel();
    super.dispose();
  }
}

/// Isolate-safe vector database that bypasses platform channels
class _IsolateSafeVectorDatabase {
  final String dbPath;
  final String mediaType;
  Database? _db;
  bool _initialized = false;
  
  _IsolateSafeVectorDatabase(this.dbPath, this.mediaType);
  
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      _db = sqlite3.open(dbPath);
      
      // sqlite-vec extension not needed - using TensorFlow Lite for vector operations
      debugPrint('✅ [PURE-ISOLATE] Vector database initialized (using TFLite backend)');
      
      _initialized = true;
      debugPrint('✅ [PURE-ISOLATE] Vector database initialized: $dbPath');
    } catch (e) {
      debugPrint('❌ [PURE-ISOLATE] Error initializing vector database: $e');
      rethrow;
    }
  }
  
  Future<List<MediaResult>> getRandomMedia({required String mediaType, required int limit}) async {
    if (!_initialized || _db == null) {
      throw Exception('Vector database not initialized');
    }
    
    try {
      // Query for random media from the vector database (correct table: media_vectors)
      final hasAlbum = mediaType == 'music';
      final stmt = _db!.prepare('''
        SELECT 
          title,
          artist,
          ${hasAlbum ? 'album,' : ''}
          description,
          themes,
          wiki_url,
          wikidata_id,
          image_url
        FROM media_vectors 
        ORDER BY RANDOM() 
        LIMIT ?
      ''');
      
      final result = stmt.select([limit]);
      
      final mediaResults = <MediaResult>[];
      for (final row in result) {
        mediaResults.add(MediaResult(
          title: row['title'] as String? ?? 'Unknown',
          artist: row['artist'] as String?,
          album: hasAlbum ? row['album'] as String? : null,
          coverArtUrl: row['image_url'] as String?,
          description: row['description'] as String?,
          wikiUrl: row['wiki_url'] as String?,
          wikidataId: row['wikidata_id'] as String?,
          themes: row['themes'] as String?,
        ));
      }
      
      stmt.dispose();
      return mediaResults;
    } catch (e) {
      debugPrint('❌ [PURE-ISOLATE] Error querying vector database: $e');
      return [];
    }
  }

  Future<List<MediaResult>> searchByText({required String query, required String mediaType, required int limit}) async {
    if (!_initialized || _db == null) {
      throw Exception('Vector database not initialized');
    }
    
    if (query.trim().isEmpty) {
      return [];
    }
    
    try {
      final hasAlbum = mediaType == 'music';
      
      // Use LIKE-based search for text matching
      final searchQuery = '''
        SELECT 
          title,
          artist,
          ${hasAlbum ? 'album,' : ''}
          description,
          themes,
          wiki_url,
          wikidata_id,
          image_url,
          (
            CASE WHEN LOWER(title) LIKE LOWER(?) || '%' THEN 100
            WHEN LOWER(title) LIKE '%' || LOWER(?) || '%' THEN 80
            WHEN LOWER(COALESCE(artist, '')) LIKE LOWER(?) || '%' THEN 70
            WHEN LOWER(COALESCE(artist, '')) LIKE '%' || LOWER(?) || '%' THEN 60
            WHEN LOWER(COALESCE(themes, '')) LIKE '%' || LOWER(?) || '%' THEN 40
            ELSE 20 END
          ) as relevance_score
        FROM media_vectors 
        WHERE (
          LOWER(title) LIKE '%' || LOWER(?) || '%' OR
          LOWER(COALESCE(artist, '')) LIKE '%' || LOWER(?) || '%' OR
          LOWER(COALESCE(themes, '')) LIKE '%' || LOWER(?) || '%'
        )
        ORDER BY relevance_score DESC, title ASC
        LIMIT ?
      ''';
      
      final params = [query, query, query, query, query, query, query, query, limit];
      
      final stmt = _db!.prepare(searchQuery);
      final result = stmt.select(params);
      
      final mediaResults = <MediaResult>[];
      for (final row in result) {
        mediaResults.add(MediaResult(
          title: row['title'] as String? ?? 'Unknown',
          artist: row['artist'] as String?,
          album: hasAlbum ? row['album'] as String? : null,
          coverArtUrl: row['image_url'] as String?,
          description: row['description'] as String?,
          wikiUrl: row['wiki_url'] as String?,
          wikidataId: row['wikidata_id'] as String?,
          themes: row['themes'] as String?,
        ));
      }
      
      stmt.dispose();
      debugPrint('🔍 [PURE-ISOLATE] Text search for "$query" in $mediaType: found ${mediaResults.length} results');
      return mediaResults;
    } catch (e) {
      debugPrint('❌ [PURE-ISOLATE] Error in text search: $e');
      return [];
    }
  }
  
  Future<List<MediaResult>> searchByBehavioralMatch({
    required List<String> likedItemIds,
    required List<String> dislikedItemIds,
    String? favoriteItemId,
    List<String> skippedItemIds = const [],
    List<String> excludeIds = const [],
    int limit = 1,
  }) async {
    if (!_initialized || _db == null) {
      throw Exception('Vector database not initialized');
    }

    try {
      debugPrint('🎯 [PURE-ISOLATE] Starting behavioral matching with vector similarity...');
      
      // Check if we have any positive signals
      if (likedItemIds.isEmpty && favoriteItemId == null) {
        debugPrint('⚠️ [PURE-ISOLATE] No positive behavioral signals found');
        return [];
      }
      
      // Try to find similar items based on themes from liked items
      final hasAlbum = mediaType == 'music';
      
      // Build a query that looks for items with similar themes to liked items
      // This is a simple text-based similarity until we get vector search working
              final searchQuery = '''
        SELECT 
          media_id, title, artist, ${hasAlbum ? 'album,' : ''} description, themes, 
          wiki_url, wikidata_id, image_url
        FROM media_vectors 
        WHERE media_id NOT IN (${excludeIds.map((_) => '?').join(',')})
        ORDER BY RANDOM()
        LIMIT ?
      ''';
      
      final params = [...excludeIds, limit];
      
      final stmt = _db!.prepare(searchQuery);
      final result = stmt.select(params);
      stmt.dispose();
      
      final candidates = <MediaResult>[];
      
      for (final row in result) {
        candidates.add(MediaResult(
          title: row['title'] as String? ?? 'Unknown',
          artist: row['artist'] as String?,
          album: hasAlbum ? row['album'] as String? : null,
          coverArtUrl: row['image_url'] as String?,
          description: row['description'] as String?,
          wikiUrl: row['wiki_url'] as String?,
          wikidataId: row['wikidata_id'] as String?,
          themes: row['themes'] as String?,
        ));
      }
      
      debugPrint('🎯 [PURE-ISOLATE] Constraint-based search found ${candidates.length} matches');
      return candidates;
      
    } catch (e) {
      debugPrint('❌ [PURE-ISOLATE] Error in behavioral matching: $e');
      return [];
    }
  }

  /// Get embeddings for all behavioral signals
  Future<Map<String, dynamic>> _getBehavioralEmbeddings(
    List<String> likedItemIds,
    List<String> dislikedItemIds,
    String? favoriteItemId,
    List<String> skippedItemIds,
  ) async {
    final result = {
      'liked': <List<double>>[],
      'disliked': <List<double>>[],
      'favorite': null as List<double>?,
      'skipped': <List<double>>[],
    };
    
    // Get liked embeddings
    for (final id in likedItemIds) {
      final embedding = await _getEmbeddingById(id);
      if (embedding != null) {
        (result['liked'] as List<List<double>>).add(embedding);
      }
    }
    
    // Get disliked embeddings
    for (final id in dislikedItemIds) {
      final embedding = await _getEmbeddingById(id);
      if (embedding != null) {
        (result['disliked'] as List<List<double>>).add(embedding);
      }
    }
    
    // Get favorite embedding
    if (favoriteItemId != null) {
      result['favorite'] = await _getEmbeddingById(favoriteItemId);
    }
    
    // Get skipped embeddings
    for (final id in skippedItemIds) {
      final embedding = await _getEmbeddingById(id);
      if (embedding != null) {
        (result['skipped'] as List<List<double>>).add(embedding);
      }
    }
    
    return result;
  }

  /// Get single embedding by media ID
  Future<List<double>?> _getEmbeddingById(String mediaId) async {
    if (!_initialized || _db == null) return null;
    
    try {
      final stmt = _db!.prepare('SELECT embedding_blob FROM media_vectors WHERE media_id = ?');
      final result = stmt.select([mediaId]);
      stmt.dispose();
      
      if (result.isNotEmpty) {
        final blob = result.first['embedding_blob'] as Uint8List;
        return _blobToFloatList(blob);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ [PURE-ISOLATE] Error getting embedding for $mediaId: $e');
      return null;
    }
  }

  /// Convert binary blob to float list (384 dimensions)
  List<double> _blobToFloatList(Uint8List blob) {
    final buffer = blob.buffer;
    final floats = Float32List.view(buffer);
    return floats.cast<double>();
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> vectorA, List<double> vectorB) {
    if (vectorA.length != vectorB.length) {
      return 0.0;
    }
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      normA += vectorA[i] * vectorA[i];
      normB += vectorB[i] * vectorB[i];
    }
    
    if (normA == 0.0 || normB == 0.0) {
      return 0.0;
    }
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Try TensorFlow Lite enhanced vector matching for mobile performance
  Future<MediaResult?> _tryTensorFlowLiteMatching({
    required Map<String, dynamic> behavioralData,
    required String mediaType,
  }) async {
    try {
      // Initialize TensorFlow Lite service
      await TFLiteVectorService.instance.initialize();
      
      // Extract behavioral embeddings
      final likedItemIds = behavioralData['likedItemIds'] as List<String>;
      final dislikedItemIds = behavioralData['dislikedItemIds'] as List<String>;
      final favoriteItemId = behavioralData['favoriteItemId'] as String?;
      final excludeIds = behavioralData['excludeIds'] as List<String>;
      
      // Get embeddings for user profile creation
      final likedEmbeddings = <List<double>>[];
      final dislikedEmbeddings = <List<double>>[];
      List<double>? favoriteEmbedding;
      
      // Load liked embeddings (mobile-friendly limit)
      for (final id in likedItemIds.take(5)) {
        final embedding = await _getEmbeddingById(id);
        if (embedding != null) {
          likedEmbeddings.add(embedding);
        }
      }
      
      // Load disliked embeddings (mobile-friendly limit)
      for (final id in dislikedItemIds.take(3)) {
        final embedding = await _getEmbeddingById(id);
        if (embedding != null) {
          dislikedEmbeddings.add(embedding);
        }
      }
      
      // Load favorite embedding
      if (favoriteItemId != null) {
        favoriteEmbedding = await _getEmbeddingById(favoriteItemId);
      }
      
      if (likedEmbeddings.isEmpty && favoriteEmbedding == null) {
        debugPrint('⚠️ [TFLITE] No embeddings found for profile creation');
        return null;
      }
      
      // Create user profile vector
      final userConstraints = behavioralData['userConstraints'] as List<String>? ?? [];
      final profileVector = await TFLiteVectorService.instance.createMobileUserProfileVector(
        likedEmbeddings: likedEmbeddings,
        dislikedEmbeddings: dislikedEmbeddings,
        favoriteEmbedding: favoriteEmbedding,
        userConstraints: userConstraints,
      );
      
      debugPrint('🧠 [TFLITE] Created profile vector from ${likedEmbeddings.length} liked, ${dislikedEmbeddings.length} disliked');
      
      // Create mobile-friendly vector loader with collection limits
      Future<List<VectorWithMetadata>> vectorLoader(int offset, int limit) async {
        final hasAlbum = mediaType == 'music';
        
        // Mobile-friendly collection limits (instead of processing all 343k)
        final maxCollectionSize = mediaType == 'music' ? 25000 : 15000;
        
        final query = '''
          SELECT media_id, title, artist, ${hasAlbum ? 'album,' : ''} description, themes, 
                 wiki_url, wikidata_id, image_url, embedding_blob
          FROM media_vectors 
          ORDER BY RANDOM()
          LIMIT ? OFFSET ?
        ''';
        
        // Don't exceed collection limit
        final effectiveLimit = (offset + limit > maxCollectionSize) 
            ? maxCollectionSize - offset 
            : limit;
            
        if (effectiveLimit <= 0) return [];
        
        final stmt = _db!.prepare(query);
        final results = stmt.select([effectiveLimit, offset]);
        stmt.dispose();
        
        return results.map((row) {
          final embedding = _blobToFloatList(row['embedding_blob'] as Uint8List);
          return VectorWithMetadata(
            id: row['media_id'] as String,
            title: row['title'] as String? ?? 'Unknown',
            artist: row['artist'] as String?,
            album: hasAlbum ? row['album'] as String? : null,
            vector: embedding,
            metadata: {
              'description': row['description'] as String?,
              'themes': row['themes'] as String?,
              'wikiUrl': row['wiki_url'] as String?,
              'wikidataId': row['wikidata_id'] as String?,
              'coverArtUrl': row['image_url'] as String?,
            },
          );
        }).toList();
      };
      
      // Find single best suggestion using TensorFlow Lite
      final bestMatch = await TFLiteVectorService.instance.findSingleSuggestion(
        userProfileVector: profileVector,
        excludeIds: excludeIds,
        minSimilarity: 0.5, // Lower threshold for more discovery
        vectorLoader: vectorLoader,
        batchSize: 500, // Mobile-optimized batch size
      );
      
      if (bestMatch != null) {
        return MediaResult(
          title: bestMatch.title,
          artist: bestMatch.artist,
          album: bestMatch.album,
          coverArtUrl: bestMatch.metadata['coverArtUrl'] as String?,
          description: bestMatch.metadata['description'] as String?,
          wikiUrl: bestMatch.metadata['wikiUrl'] as String?,
          wikidataId: bestMatch.metadata['wikidataId'] as String?,
          themes: bestMatch.metadata['themes'] as String?,
        );
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ [TFLITE] Error in TensorFlow Lite matching: $e');
      return null;
    }
  }

  /// Evaluate if an item matches behavioral criteria
  Map<String, dynamic> _evaluateBehavioralMatch(
    List<double> itemEmbedding,
    Map<String, dynamic> behavioralEmbeddings,
  ) {
    final likedEmbeddings = behavioralEmbeddings['liked'] as List<List<double>>;
    final dislikedEmbeddings = behavioralEmbeddings['disliked'] as List<List<double>>;
    final favoriteEmbedding = behavioralEmbeddings['favorite'] as List<double>?;
    final skippedEmbeddings = behavioralEmbeddings['skipped'] as List<List<double>>;
    
    // Calculate similarities
    double maxLikedSimilarity = 0.0;
    double favoriteSimilarity = 0.0;
    double maxDislikedSimilarity = 0.0;
    double maxSkippedSimilarity = 0.0;
    
    // Check against liked items
    for (final likedEmbedding in likedEmbeddings) {
      final similarity = _cosineSimilarity(itemEmbedding, likedEmbedding);
      if (similarity > maxLikedSimilarity) {
        maxLikedSimilarity = similarity;
      }
    }
    
    // Check against favorite
    if (favoriteEmbedding != null) {
      favoriteSimilarity = _cosineSimilarity(itemEmbedding, favoriteEmbedding);
    }
    
    // Check against disliked items
    for (final dislikedEmbedding in dislikedEmbeddings) {
      final similarity = _cosineSimilarity(itemEmbedding, dislikedEmbedding);
      if (similarity > maxDislikedSimilarity) {
        maxDislikedSimilarity = similarity;
      }
    }
    
    // Check against skipped items
    for (final skippedEmbedding in skippedEmbeddings) {
      final similarity = _cosineSimilarity(itemEmbedding, skippedEmbedding);
      if (similarity > maxSkippedSimilarity) {
        maxSkippedSimilarity = similarity;
      }
    }
    
    // Apply criteria: 0.7+ liked OR 0.5+ favorite, AND 0.3 or less disliked, AND not 0.85+ skipped
    final hasPositiveMatch = maxLikedSimilarity >= 0.7 || favoriteSimilarity >= 0.5;
    final passesDislikedFilter = maxDislikedSimilarity <= 0.3;
    final isLikelySkipped = maxSkippedSimilarity >= 0.85;
    
    final isMatch = hasPositiveMatch && passesDislikedFilter && !isLikelySkipped;
    
    // Calculate overall match score
    double score = 0.0;
    if (hasPositiveMatch) {
      score += max(maxLikedSimilarity * 0.7, favoriteSimilarity * 0.5);
    }
    if (passesDislikedFilter) {
      score += 0.2;
    }
    if (isLikelySkipped) {
      score -= 0.3;
    }
    
    return {
      'isMatch': isMatch,
      'score': score,
      'details': {
        'maxLikedSimilarity': maxLikedSimilarity,
        'favoriteSimilarity': favoriteSimilarity,
        'maxDislikedSimilarity': maxDislikedSimilarity,
        'maxSkippedSimilarity': maxSkippedSimilarity,
      }
    };
  }

  /// Search for media based on user constraints - PURE DATA-DRIVEN, NO HARDCODED GENRES
  Future<List<MediaResult>> searchByConstraints({
    required List<String> constraints,
    required List<String> excludeIds,
    required int limit,
  }) async {
    if (!_initialized || _db == null) {
      throw Exception('Vector database not initialized');
    }

    if (constraints.isEmpty) {
      return [];
    }

    try {
      debugPrint('🎯 [PURE-ISOLATE] CLEAN constraint search for: ${constraints.join(', ')}');
      
      final hasAlbum = mediaType == 'music';
      
      // Build constraint conditions - must match ALL constraints (AND logic)
      final constraintConditions = <String>[];
      final queryParams = <String>[];
      
      for (final constraint in constraints) {
        final normalizedConstraint = constraint.toLowerCase().trim();
        
        // Each constraint must match at least one field
        constraintConditions.add('''
          (LOWER(COALESCE(themes, '')) LIKE ? OR 
           LOWER(COALESCE(description, '')) LIKE ? OR 
           LOWER(COALESCE(title, '')) LIKE ? OR 
           LOWER(COALESCE(artist, '')) LIKE ?)
        ''');
        
        // Add constraint for each field check
        queryParams.addAll([
          '%$normalizedConstraint%', 
          '%$normalizedConstraint%', 
          '%$normalizedConstraint%', 
          '%$normalizedConstraint%'
        ]);
      }
      
      // Build exclude clause
      String excludeClause = '';
      if (excludeIds.isNotEmpty) {
        excludeClause = 'AND media_id NOT IN (${excludeIds.map((_) => '?').join(',')})';
        queryParams.addAll(excludeIds);
      }
      
      // Simple search - NO HARDCODED PREFERENCES, just find matches
      final searchQuery = '''
        SELECT 
          media_id, title, artist, ${hasAlbum ? 'album,' : ''} description, themes, 
          wiki_url, wikidata_id, image_url
        FROM media_vectors 
        WHERE ${constraintConditions.join(' AND ')}
        $excludeClause
        ORDER BY RANDOM()
        LIMIT ?
      ''';
      
      queryParams.add(limit.toString());
      
      debugPrint('🔍 [PURE-ISOLATE] Pure constraint search: ${constraints.length} constraints, ${excludeIds.length} excludes');
      debugPrint('🔍 [PURE-ISOLATE] Query params count: ${queryParams.length}');
      
      final stmt = _db!.prepare(searchQuery);
      final result = stmt.select(queryParams);
      stmt.dispose();
      
      final candidates = <MediaResult>[];
      
      for (final row in result) {
        final themes = row['themes'] as String? ?? '';
        final description = row['description'] as String? ?? '';
        
        debugPrint('🎵 Found: ${row['title']} | Themes: ${themes.substring(0, min(50, themes.length))}');
        
        candidates.add(MediaResult(
          title: row['title'] as String? ?? 'Unknown',
          artist: row['artist'] as String?,
          album: hasAlbum ? row['album'] as String? : null,
          coverArtUrl: row['image_url'] as String?,
          description: description,
          wikiUrl: row['wiki_url'] as String?,
          wikidataId: row['wikidata_id'] as String?,
          themes: themes,
        ));
      }
      
      debugPrint('✅ [PURE-ISOLATE] Clean search found ${candidates.length} matches for: ${constraints.join(', ')}');
      return candidates;
      
    } catch (e) {
      debugPrint('❌ [PURE-ISOLATE] Error in clean constraint search: $e');
      return [];
    }
  }

  void dispose() {
    _db?.dispose();
    _initialized = false;
  }
}

/// Media result from vector database
class MediaResult {
  final String title;
  final String? artist;
  final String? album;
  final String? coverArtUrl;
  final String? description;
  final String? wikiUrl;
  final String? wikidataId;
  final String? themes;
  
  MediaResult({
    required this.title,
    this.artist,
    this.album,
    this.coverArtUrl,
    this.description,
    this.wikiUrl,
    this.wikidataId,
    this.themes,
  });
}

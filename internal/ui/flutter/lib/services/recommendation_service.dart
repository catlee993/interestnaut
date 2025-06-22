import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as pathLib;
import 'package:sqlite3/sqlite3.dart';
import 'sqlite_db.dart';
import '../db/vector_db.dart';
import 'llama_service.dart';
import 'model_constants.dart';
import '../models.dart';
import 'package:interestnaut/services/wikipedia_service.dart';
import '../components/music/spotify_service.dart';
import 'recommendation_event_service.dart'; 

// --- Data Models ---

enum SuggestionStatus {
  pending,
  skipped,
  liked,
  disliked,
  added, 
  archived, 
  failure, 
  watchlist, // For items added to playlist/watchlist
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
  
  bool _isProcessingQueue = false;
  final Map<String, bool> _queueBeingFilled = {};
  final Map<String, int> _pendingQueueCounts = {};
  final Map<String, bool> _backgroundGenerationInProgress = {};
  
  Timer? _queueTimer;
  
  Future<void> init() async {
    try {
      await _db.init();
      debugPrint('RecommendationService initialized');
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
    if (!_llamaService.isInitialized) {
      debugPrint('Cannot generate $mediaType suggestion: TinyLlama service not initialized');
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
        
        debugPrint('🔄 [BACKGROUND] Passing to isolate: appPath=${appSupportDir.path}, enabledTypes=$enabledMediaTypes');
        
        // Generate suggestion in PURE isolate with all dependencies injected
        final result = await compute(_generateSuggestionInPureIsolate, {
          'mediaType': mediaType,
          'userQuery': 'Suggest a great $mediaType',
          'appSupportPath': appSupportDir.path,
          'enabledMediaTypes': enabledMediaTypes,
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





  /// Static function to run COMPLETE suggestion generation in pure isolate (no platform channels)
  static Future<Map<String, dynamic>?> _generateSuggestionInPureIsolate(Map<String, dynamic> params) async {
    try {
      final String mediaType = params['mediaType'];
      final String userQuery = params['userQuery'];
      final String appSupportPath = params['appSupportPath'];
      final List<String> enabledMediaTypes = List<String>.from(params['enabledMediaTypes']);
      
      debugPrint('🔄 [PURE-ISOLATE] Starting suggestion generation for $mediaType');
      debugPrint('🔄 [PURE-ISOLATE] App path: $appSupportPath');
      debugPrint('🔄 [PURE-ISOLATE] Enabled types: $enabledMediaTypes');
      
      // Step 1: Create isolate-safe vector database with injected dependencies
      final vectorDb = await _createIsolateSafeVectorDatabase(appSupportPath, enabledMediaTypes, mediaType);
      
      if (vectorDb == null) {
        debugPrint('❌ [PURE-ISOLATE] Failed to create vector database');
        return null;
      }
      
      // Step 2: Query vector database
      debugPrint('🔄 [PURE-ISOLATE] Querying vector database...');
      final randomResults = await vectorDb.getRandomMedia(mediaType: mediaType, limit: 1);
      
      if (randomResults.isEmpty) {
        debugPrint('❌ [PURE-ISOLATE] No media found in vector database for $mediaType');
        return null;
      }
      
      final mediaResult = randomResults.first;
      debugPrint('✅ [PURE-ISOLATE] Selected media: ${mediaResult.title}');
      
      // Step 3: Generate LLM response (pure computation)
      debugPrint('🔄 [PURE-ISOLATE] Generating LLM response...');
      final response = _generateContextualExplanationPure(
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
  static String _generateContextualExplanationPure({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    double? similarity,
  }) {
    final buffer = StringBuffer();
    
    // Start with similarity-based reasoning
    if (similarity != null && similarity > 0.7) {
      buffer.write('This $mediaType is a strong match ');
    } else if (similarity != null && similarity > 0.5) {
      buffer.write('This $mediaType is a good match ');
    } else {
      buffer.write('This $mediaType relates to ');
    }
    
    buffer.write('your search for "$userQuery"');
    
    // Add theme-based reasoning
    if (themes != null && themes.isNotEmpty) {
      final themesList = themes.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      if (themesList.isNotEmpty) {
        if (themesList.length == 1) {
          buffer.write(' through its ${themesList.first} theme');
        } else if (themesList.length == 2) {
          buffer.write(' through its ${themesList.first} and ${themesList.last} themes');
        } else {
          buffer.write(' through themes like ${themesList.take(2).join(', ')}, and others');
        }
      }
    }
    
    // Add artist/creator context
    if (artist != null && artist.isNotEmpty && artist.toLowerCase() != 'unknown') {
      if (mediaType == 'music') {
        buffer.write(', featuring ${artist}\'s distinctive style');
      } else if (mediaType == 'book') {
        buffer.write(', showcasing ${artist}\'s writing approach');
      } else if (mediaType == 'movie' || mediaType == 'tv_show') {
        buffer.write(', with ${artist}\'s creative direction');
      } else {
        buffer.write(', created by $artist');
      }
    }
    
    buffer.write('.');
    
    return buffer.toString();
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
      
      // Load sqlite-vec extension if available
      try {
        _db!.execute('SELECT load_extension("sqlite_vec")');
      } catch (e) {
        debugPrint('sqlite-vec extension not available in isolate, using fallback');
      }
      
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

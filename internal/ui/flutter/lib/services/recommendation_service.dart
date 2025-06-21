import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

    // Start background generation without blocking (all async operations moved here)
    _generateSuggestionInBackground(mediaType);

    return loadingSuggestion;
  }

  /// Generate suggestion in background and emit events when ready
  void _generateSuggestionInBackground(String mediaType) {
    // Run all async operations in background
    _generateSuggestionAsyncFull(mediaType).then((result) {
      _queueBeingFilled[mediaType] = false;
      if (result != null) {
        debugPrint('Background suggestion ready: ${result.title}');
        _eventService.emitSuggestionReady(mediaType, result);
      } else {
        _eventService.emitSuggestionError(mediaType, 'Failed to generate suggestion');
      }
    }).catchError((e) {
      _queueBeingFilled[mediaType] = false;
      debugPrint('Error in background suggestion generation: $e');
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

  /// Generate suggestion using vector DB on main thread and LLM in isolate
  Future<MediaSuggestion?> _generateSuggestionAsync(String mediaType) async {
    try {
      // Step 1: Get real data from vector DB on main thread (platform channels allowed)
      final vectorDb = VectorDatabase();
      await vectorDb.init();
      
      final randomResults = await vectorDb.getRandomMedia(mediaType: mediaType, limit: 1);
      
      if (randomResults.isEmpty) {
        debugPrint('No media found in vector database for $mediaType');
        return null;
      }
      
      final mediaResult = randomResults.first;
      debugPrint('Selected real media for LLM: ${mediaResult.title}');
      
      // Step 2: Run LLM operation in isolate (heavy computation)
      final response = await compute(_generateLLMResponseInIsolate, {
        'userQuery': 'Suggest a great $mediaType',
        'mediaTitle': mediaResult.title,
        'mediaType': mediaType,
        'artist': mediaResult.artist,
        'themes': mediaResult.themes,
        'description': mediaResult.description,
        'similarity': 1.0,
      });
      
      if (response == null) {
        debugPrint('Failed to generate LLM response');
        return null;
      }
      
      debugPrint('LLM response: "$response"');
      
      // Step 3: Create suggestion with real data
      final suggestion = MediaSuggestion(
        query: 'User requested $mediaType suggestion',
        mediaType: mediaType,
        title: mediaResult.title,
        artist: mediaResult.artist,
        album: mediaResult.album,
        coverArtUrl: mediaResult.coverArtUrl,
        description: mediaResult.description,
        wikiUrl: mediaResult.wikiUrl,
        wikidataId: mediaResult.wikidataId,
        themes: mediaResult.themes,
        botReasoning: response,
        status: SuggestionStatus.pending,
      );
      
      // Step 4: Save suggestion on main thread (needs platform channels)
      final savedSuggestion = await _saveValidatedSuggestion(suggestion);
      if (savedSuggestion != null) {
        debugPrint('Generated on-demand suggestion: ${savedSuggestion.title} (ID: ${savedSuggestion.id})');
        return savedSuggestion;
      } else {
        debugPrint('Failed to save on-demand suggestion: ${suggestion.title}');
        return null;
      }
    } catch (e) {
      debugPrint('Error in suggestion generation: $e');
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

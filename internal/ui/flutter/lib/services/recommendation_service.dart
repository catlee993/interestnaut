import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:interestnaut/services/llama_service.dart';
import 'package:interestnaut/services/sqlite_db.dart';
import 'package:interestnaut/services/model_constants.dart'; 
import 'package:interestnaut/services/wikipedia_service.dart';
import '../components/music/spotify_service.dart'; 

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
  
  bool _isProcessingQueue = false;
  final Map<String, bool> _queueBeingFilled = {};
  final Map<String, int> _pendingQueueCounts = {};
  
  Timer? _queueTimer;
  
  Future<void> init() async {
    await _db.init();
    _startBackgroundQueue();
  }
  
  void _startBackgroundQueue() {
    _queueTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkAndFillQueuesIfNeeded();
    });
  }
  
  Future<void> _checkAndFillQueuesIfNeeded() async {
    final musicCount = await _getPendingSuggestionsCount('music');
    if (musicCount < 5) {
      await _fillMusicQueueFromSpotify();
      
      final updatedMusicCount = await _getPendingSuggestionsCount('music');
      if (updatedMusicCount < 5) {
        await _fillSuggestionQueue('music');
      }
    }
    
    final movieCount = await _getPendingSuggestionsCount('movie');
    if (movieCount < 5) {
      await _fillSuggestionQueue('movie');
    }
    
    final bookCount = await _getPendingSuggestionsCount('book');
    if (bookCount < 5) {
      await _fillSuggestionQueue('book');
    }
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
    if (_queueBeingFilled[mediaType] == true) {
      debugPrint('$mediaType queue is already being filled');
      return;
    }
    
    _queueBeingFilled[mediaType] = true;
    
    try {
      debugPrint('Filling $mediaType queue with validated LLM generation');
      
      // Get existing recommendations to avoid duplicates
      final existingRecommendations = await _db.getAllMediaSuggestions(mediaType: mediaType, limit: 100);
      
      // Generate recommendations one at a time with validation
      int successfulGenerations = 0;
      int attempts = 0;
      const maxAttempts = 10; // Prevent infinite loops
      
      while (successfulGenerations < 3 && attempts < maxAttempts) {
        attempts++;
        debugPrint('Generation attempt $attempts for $mediaType');
        
        try {
          // Build the prompt with previous recommendations
          final prompt = _buildPromptWithPreviousRecommendations(mediaType, existingRecommendations);
          debugPrint('Generating $mediaType recommendation with ${existingRecommendations.length} previous items shown');
          
          // Generate one recommendation
          final response = await _llamaService.generateStructuredJsonResponse(prompt);
          debugPrint('Raw LLM response: "$response"');
          
          if (response.isNotEmpty) {
            // Parse the 3-line format
            final parsedSuggestion = _parseThreeLineFormat(response, mediaType);
            
            if (parsedSuggestion != null) {
              debugPrint('Parsed suggestion: ${parsedSuggestion.title} by ${parsedSuggestion.artist}');
              
              // Check for duplicates
              final isDuplicate = existingRecommendations.any((existing) => 
                existing.title?.toLowerCase() == parsedSuggestion.title?.toLowerCase() &&
                existing.artist?.toLowerCase() == parsedSuggestion.artist?.toLowerCase());
              
              if (isDuplicate) {
                debugPrint('Duplicate detected, skipping: ${parsedSuggestion.title}');
                continue;
              }
              
              // Validate with Wikipedia
              final validatedSuggestion = await _validateWithWikipedia(parsedSuggestion);
              
              if (validatedSuggestion != null) {
                // Save the validated suggestion
                await _saveValidatedSuggestion(validatedSuggestion);
                existingRecommendations.add(validatedSuggestion);
                successfulGenerations++;
                debugPrint('Successfully validated and saved: ${validatedSuggestion.title}');
              } else {
                // Mark as failed validation
                parsedSuggestion.status = SuggestionStatus.failure;
                await _saveValidatedSuggestion(parsedSuggestion);
                debugPrint('Failed Wikipedia validation: ${parsedSuggestion.title}');
              }
            } else {
              debugPrint('Failed to parse suggestion from response');
            }
          }
          
          // Small delay between generations
          await Future.delayed(const Duration(milliseconds: 500));
          
        } catch (e) {
          debugPrint('Error generating suggestion attempt $attempts for $mediaType: $e');
        }
      }
      
      debugPrint('Completed $mediaType queue generation: $successfulGenerations successful, $attempts total attempts');
    } catch (e) {
      debugPrint('Error filling suggestion queue: $e');
    } finally {
      _queueBeingFilled[mediaType] = false;
    }
  }
  
  /// Build prompt with previous recommendations shown
  String _buildPromptWithPreviousRecommendations(String mediaType, List<MediaSuggestion> existingRecommendations) {
    try {
      var basePrompt = getPromptTemplateForMediaType(mediaType);
      
      // Build the previous recommendations list
      final previousRecommendations = StringBuffer();
      
      if (existingRecommendations.isNotEmpty) {
        for (final rec in existingRecommendations.take(3)) { // Show only 3 previous
          previousRecommendations.writeln('${rec.title} - ${rec.artist}');
        }
      } else {
        previousRecommendations.writeln('None');
      }
      
      // Replace the placeholder with actual previous recommendations
      basePrompt = basePrompt.replaceFirst('{PREVIOUS_RECOMMENDATIONS}', previousRecommendations.toString().trim());
      
      return basePrompt;
    } catch (e) {
      debugPrint('Error building prompt: $e');
      return 'Generate a $mediaType recommendation.\nTitle:\nArtist:\nReason:';
    }
  }
  
  /// Parse the strict 3-line format: Title\nArtist\nReasoning
  MediaSuggestion? _parseThreeLineFormat(String response, String mediaType) {
    try {
      final lines = response.split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      
      if (lines.length < 3) {
        debugPrint('Not enough lines in response: ${lines.length}');
        return null;
      }
      
      final title = lines[0].trim();
      final artist = lines[1].trim();
      final reasoning = lines[2].trim();
      
      // Validate the fields
      if (title.isEmpty || artist.isEmpty || reasoning.isEmpty) {
        debugPrint('Empty fields detected: title="$title", artist="$artist", reasoning="$reasoning"');
        return null;
      }
      
      // Check for placeholder text
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
      debugPrint('Error parsing three-line format: $e');
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
  Future<void> _saveValidatedSuggestion(MediaSuggestion suggestion) async {
    try {
      await _db.saveMediaSuggestion(suggestion);
    } catch (e) {
      // Handle duplicate constraint violations gracefully
      if (e.toString().contains('UNIQUE constraint failed')) {
        debugPrint('Duplicate suggestion prevented by database constraint: ${suggestion.title}');
      } else {
        debugPrint('Error saving suggestion: $e');
      }
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
    final count = await _getPendingSuggestionsCount(mediaType);
    if (count < 5) {
      if (mediaType == 'music') {
        await _fillMusicQueueFromSpotify();
        
        final updatedCount = await _getPendingSuggestionsCount(mediaType);
        if (updatedCount < 5) {
          await _fillSuggestionQueue(mediaType);
        }
      } else {
        await _fillSuggestionQueue(mediaType);
      }
    }
  }
  
  Future<List<MediaSuggestion>> getSuggestions(String mediaType, {SuggestionStatus? status}) async {
    try {
      await ensureSuggestionQueue(mediaType);
      
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
    try {
      await _db.updateMediaSuggestionStatus(suggestionId, newStatus);
      return true;
    } catch (e) {
      debugPrint('Error updating suggestion status: $e');
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
    debugPrint('Prefilling recommendation queues with LLM generation only');
    
    // First try to fill music queue from Spotify
    await _fillMusicQueueFromSpotify();
    
    // Then fill any remaining queues with LLM suggestions
    final mediaTypes = ['music', 'movie', 'book'];
    
    for (final mediaType in mediaTypes) {
      final count = await _getPendingSuggestionsCount(mediaType);
      if (count < 5) {
        await _fillSuggestionQueue(mediaType);
      }
    }
    
    debugPrint('Finished prefilling recommendation queues');
  }
  
  @override
  void dispose() {
    _queueTimer?.cancel();
    super.dispose();
  }
}

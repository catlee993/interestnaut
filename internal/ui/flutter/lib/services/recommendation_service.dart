import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:interestnaut/services/llama_service.dart';
import 'package:interestnaut/services/sqlite_db.dart';
import 'package:interestnaut/services/model_constants.dart'; 
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
      debugPrint('Filling $mediaType queue with LLM generation');
      
      // Test LLM connection first
      final isLLMWorking = await _testLLMConnection();
      if (!isLLMWorking) {
        debugPrint('LLM not working, using fallback suggestions');
        final fallbackSuggestions = _generateFallbackSuggestions(mediaType);
        for (final suggestion in fallbackSuggestions) {
          await _db.saveMediaSuggestion(suggestion);
        }
        debugPrint('Added ${fallbackSuggestions.length} fallback $mediaType suggestions');
        return;
      }
      
      // Warm up the LLM for better performance
      final isWarmedUp = await _warmUpLLM();
      if (!isWarmedUp) {
        debugPrint('LLM warm-up failed, proceeding with caution...');
      }
      
      // Build context from user preferences
      final context = await _buildContextForMediaType(mediaType);
      
      // Generate multiple suggestions (3-5 per batch)
      final suggestions = <MediaSuggestion>[];
      int successfulGenerations = 0;
      
      for (int i = 0; i < 5; i++) { // Try up to 5 times
        try {
          final prompt = _buildSuggestionPrompt(mediaType, context);
          debugPrint('Generating $mediaType suggestion ${i + 1}/5 with prompt length: ${prompt.length}');
          
          final response = await _llamaService.generateStructuredJsonResponse(prompt);
          
          if (response.isNotEmpty) {
            final parsedSuggestions = _parseLlamaSuggestions(response, mediaType);
            
            // Only add valid suggestions
            final validSuggestions = parsedSuggestions.where((s) => s.isValid()).toList();
            suggestions.addAll(validSuggestions);
            
            if (validSuggestions.isNotEmpty) {
              successfulGenerations++;
              debugPrint('Successfully generated ${validSuggestions.length} valid suggestions');
            }
            
            // Stop if we have enough suggestions
            if (suggestions.length >= 3) {
              break;
            }
            
            // Add a small delay between generations to prevent overwhelming the model
            await Future.delayed(const Duration(milliseconds: 1000));
          }
        } catch (e) {
          debugPrint('Error generating suggestion ${i + 1} for $mediaType: $e');
          // Continue with other suggestions even if one fails
        }
      }
      
      // Save suggestions to database
      for (final suggestion in suggestions) {
        await _db.saveMediaSuggestion(suggestion);
      }
      
      debugPrint('Added ${suggestions.length} new $mediaType suggestions from LLM');
    } catch (e) {
      debugPrint('Error filling suggestion queue: $e');
      // Fallback to hardcoded suggestions on error
      try {
        final fallbackSuggestions = _generateFallbackSuggestions(mediaType);
        for (final suggestion in fallbackSuggestions) {
          await _db.saveMediaSuggestion(suggestion);
        }
        debugPrint('Added ${fallbackSuggestions.length} fallback $mediaType suggestions after error');
      } catch (fallbackError) {
        debugPrint('Error with fallback suggestions: $fallbackError');
      }
    } finally {
      _queueBeingFilled[mediaType] = false;
    }
  }
  
  Future<bool> _testLLMConnection() async {
    try {
      debugPrint('Testing LLM connection with music recommendation format...');
      const testPrompt = '''
<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are a music expert. Respond only with valid JSON.

<|eot_id|><|start_header_id|>user<|end_header_id|>

Generate exactly one song recommendation in this JSON format:
{
  "title": "actual song title",
  "artist": "actual artist name",
  "reasoning": "brief explanation"
}

Recommend one real song.

<|eot_id|><|start_header_id|>assistant<|end_header_id|>

''';
      
      final testResponse = await _llamaService.generateStructuredJsonResponse(testPrompt);
      debugPrint('LLM test response: $testResponse');
      
      // Check if response contains valid JSON with expected fields
      try {
        final json = jsonDecode(testResponse);
        final hasRequiredFields = json is Map && 
                                 json.containsKey('title') && 
                                 json.containsKey('artist') && 
                                 json.containsKey('reasoning') &&
                                 json['title'] is String && json['title'].toString().trim().isNotEmpty &&
                                 json['artist'] is String && json['artist'].toString().trim().isNotEmpty;
        if (hasRequiredFields) {
          debugPrint('LLM test successful - all required fields present and valid');
          return true;
        } else {
          debugPrint('LLM test failed - missing or invalid required fields: $testResponse');
          return false;
        }
      } catch (e) {
        debugPrint('LLM test failed - not valid JSON: $testResponse');
        return false;
      }
    } catch (e) {
      debugPrint('LLM connection test failed: $e');
      return false;
    }
  }
  
  Future<String> _buildContextForMediaType(String mediaType) async {
    try {
      final likedItems = await _db.getAllMediaSuggestions(
        mediaType: mediaType,
        statusFilter: SuggestionStatus.liked,
        limit: 10
      );
      
      if (likedItems.isEmpty) {
        return "No previous preferences found.";
      }
      
      String context = "User has liked the following $mediaType:\n";
      
      for (final item in likedItems) {
        final title = item.title ?? 'Unknown';
        
        if (mediaType == 'music') {
          final artist = item.artist ?? 'Unknown';
          final album = item.album ?? '';
          context += "- $title by $artist${album.isNotEmpty ? ' (Album: $album)' : ''}\n";
        } else {
          context += "- $title\n";
        }
      }
      
      return context;
    } catch (e) {
      debugPrint('Error building context: $e');
      return "Error retrieving preferences.";
    }
  }
  
  String _buildSuggestionPrompt(String mediaType, String context) {
    // Use the proper prompt templates from model_constants.dart
    try {
      var basePrompt = getPromptTemplateForMediaType(mediaType);
      
      // Add context-aware enhancement if we have user preferences
      if (context.isNotEmpty && context != "No previous preferences found.") {
        // Insert context before the instruction section
        basePrompt = basePrompt.replaceFirst(
          '### Instruction:',
          '''### User Context:
$context

### Instruction:'''
        );
      }
      
      return basePrompt;
    } catch (e) {
      // Fallback if mediaType is not supported
      return '''
Below is a JSON Schema. Produce exactly one JSON object that validates against it—no extra keys, no wrapping in text or markdown.

Schema:
{
  "type": "object",
  "properties": {
    "title":     { "type": "string", "maxLength": 80 },
    "reasoning": { "type": "string", "maxLength": 80 }
  },
  "required": ["title","reasoning"],
  "additionalProperties": false
}

### Instruction:
Generate one $mediaType recommendation that matches the schema.
ABSOLUTELY NO REASON STRING 80 CHARACTERS. STOP IMMEDIATELY IF SURPASSED.

### Response:
''';
    }
  }
  
  List<MediaSuggestion> _parseLlamaSuggestions(String response, String mediaType) {
    final List<MediaSuggestion> suggestions = [];
    
    try {
      // Try to parse as JSON first
      final Map<String, dynamic> json = jsonDecode(response);
      
      final title = json['title']?.toString().trim() ?? '';
      final reason = json['reasoning']?.toString().trim() ?? json['reason']?.toString().trim() ?? '';
      
      String? artist;
      String? album;
      
      if (mediaType == 'music') {
        artist = json['artist']?.toString().trim();
        album = json['album']?.toString().trim();
      } else if (mediaType == 'movie') {
        artist = json['director']?.toString().trim(); // Store director in artist field
      } else if (mediaType == 'book') {
        artist = json['author']?.toString().trim(); // Store author in artist field
      }
      
      if (title.isNotEmpty) {
        final suggestion = MediaSuggestion(
          query: title,
          mediaType: mediaType,
          title: title,
          artist: artist,
          album: album,
          botReasoning: reason,
          status: SuggestionStatus.pending,
        );
        
        suggestions.add(suggestion);
      }
    } catch (e) {
      debugPrint('JSON parsing failed, trying fallback parsing: $e');
      
      // Fallback to original parsing method
      try {
        final regex = RegExp(r'TITLE:\s*([^\n]+)(?:\s*\n|$)');
        final matches = regex.allMatches(response);
        
        for (final match in matches) {
          final startIndex = match.start;
          final endIndex = (startIndex < matches.length - 1) ? matches.elementAt(startIndex + 1).start : response.length;
          
          final suggestionText = response.substring(startIndex, endIndex).trim();
          
          final titleMatch = RegExp(r'TITLE:\s*([^\n]+)').firstMatch(suggestionText);
          final title = titleMatch?.group(1)?.trim() ?? '';
          
          String? artist;
          if (mediaType == 'music') {
            final artistMatch = RegExp(r'ARTIST:\s*([^\n]+)').firstMatch(suggestionText);
            artist = artistMatch?.group(1)?.trim();
          }
          
          String? album;
          if (mediaType == 'music') {
            final albumMatch = RegExp(r'ALBUM:\s*([^\n]+)').firstMatch(suggestionText);
            album = albumMatch?.group(1)?.trim();
          }
          
          final reasonMatch = RegExp(r'REASON:\s*([^\n]+(?:\n[^\n]+)*)').firstMatch(suggestionText);
          final reasoning = reasonMatch?.group(1)?.trim() ?? '';
          
          if (title.isNotEmpty) {
            final suggestion = MediaSuggestion(
              query: title,
              mediaType: mediaType,
              title: title,
              artist: artist,
              album: album,
              botReasoning: reasoning,
              status: SuggestionStatus.pending,
            );
            
            suggestions.add(suggestion);
          }
        }
      } catch (e2) {
        debugPrint('Error parsing LLM suggestions: $e2');
      }
    }
    
    return suggestions;
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
    debugPrint('Prefilling recommendation queues');
    
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
  
  // Generate fallback suggestions when LLM is not available
  List<MediaSuggestion> _generateFallbackSuggestions(String mediaType) {
    switch (mediaType) {
      case 'music':
        return [
          MediaSuggestion(
            query: 'Popular indie rock suggestion',
            mediaType: 'music',
            title: 'Bohemian Rhapsody',
            artist: 'Queen',
            album: 'A Night at the Opera',
            botReasoning: 'Classic rock masterpiece with complex arrangements and powerful vocals.',
            status: SuggestionStatus.pending,
          ),
          MediaSuggestion(
            query: 'Alternative rock suggestion',
            mediaType: 'music',
            title: 'Smells Like Teen Spirit',
            artist: 'Nirvana',
            album: 'Nevermind',
            botReasoning: 'Iconic grunge anthem that defined a generation.',
            status: SuggestionStatus.pending,
          ),
        ];
      case 'movie':
        return [
          MediaSuggestion(
            query: 'Sci-fi movie recommendation',
            mediaType: 'movie',
            title: 'The Matrix',
            artist: 'Wachowskis', // Director stored in artist field
            botReasoning: 'Groundbreaking sci-fi film that redefined action cinema.',
            status: SuggestionStatus.pending,
          ),
          MediaSuggestion(
            query: 'Drama film recommendation',
            mediaType: 'movie',
            title: 'The Shawshank Redemption',
            artist: 'Frank Darabont',
            botReasoning: 'Powerful drama about hope and friendship in prison.',
            status: SuggestionStatus.pending,
          ),
        ];
      case 'book':
        return [
          MediaSuggestion(
            query: 'Classic literature recommendation',
            mediaType: 'book',
            title: '1984',
            artist: 'George Orwell', // Author stored in artist field
            botReasoning: 'Dystopian masterpiece exploring themes of surveillance and control.',
            status: SuggestionStatus.pending,
          ),
          MediaSuggestion(
            query: 'Science fiction book',
            mediaType: 'book',
            title: 'Dune',
            artist: 'Frank Herbert',
            botReasoning: 'Epic space opera with complex world-building and political intrigue.',
            status: SuggestionStatus.pending,
          ),
        ];
      default:
        return [];
    }
  }
  
  // Warm up the LLM with a simple JSON generation task to improve performance
  Future<bool> _warmUpLLM() async {
    try {
      debugPrint('Warming up LLM for JSON generation...');
      const warmUpPrompt = '''
<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are a JSON response generator. Respond only with valid JSON.

<|eot_id|><|start_header_id|>user<|end_header_id|>

Generate this exact JSON response:
{"status":"ready"}

<|eot_id|><|start_header_id|>assistant<|end_header_id|>

''';
      
      final response = await _llamaService.generateStructuredJsonResponse(warmUpPrompt);
      
      // Check if response is valid JSON
      try {
        final json = jsonDecode(response);
        final isValid = json is Map && json.containsKey('status') && json['status'] == 'ready';
        debugPrint('LLM warm-up ${isValid ? 'successful' : 'failed'}: $response');
        return isValid;
      } catch (e) {
        debugPrint('LLM warm-up failed - invalid JSON: $response');
        return false;
      }
    } catch (e) {
      debugPrint('LLM warm-up failed with error: $e');
      return false;
    }
  }
  
  @override
  void dispose() {
    _queueTimer?.cancel();
    super.dispose();
  }
}

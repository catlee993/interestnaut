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
      debugPrint('Filling $mediaType queue with LLM suggestions');
      
      final context = await _buildContextForMediaType(mediaType);
      
      final prompt = _buildSuggestionPrompt(mediaType, context);
      
      final response = await _llamaService.generateStructuredJsonResponse(prompt);
      
      final suggestions = _parseLlamaSuggestions(response, mediaType);
      
      for (final suggestion in suggestions) {
        await _db.saveMediaSuggestion(suggestion);
      }
      
      debugPrint('Added ${suggestions.length} new $mediaType suggestions from LLM');
    } catch (e) {
      debugPrint('Error filling suggestion queue: $e');
    } finally {
      _queueBeingFilled[mediaType] = false;
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
    final displayType = _mapMediaTypeForDisplay(mediaType);
    
    return '''
You are a recommendation engine for $displayType.
Based on the user's preferences, suggest 5 $displayType that they might enjoy.

User's preferences:
$context

For each suggestion, provide:
1. Title
2. ${mediaType == 'music' ? 'Artist and Album' : mediaType == 'movie' ? 'Director and Year' : 'Author'}
3. A brief reason why you're recommending it

Format each suggestion as:
TITLE: [title]
${mediaType == 'music' ? 'ARTIST: [artist]\nALBUM: [album]' : mediaType == 'movie' ? 'DIRECTOR: [director]\nYEAR: [year]' : 'AUTHOR: [author]'}
REASON: [your reasoning]

Provide 5 diverse suggestions.
''';
  }
  
  List<MediaSuggestion> _parseLlamaSuggestions(String response, String mediaType) {
    final List<MediaSuggestion> suggestions = [];
    
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
    } catch (e) {
      debugPrint('Error parsing LLM suggestions: $e');
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
  
  @override
  void dispose() {
    _queueTimer?.cancel();
    super.dispose();
  }
}

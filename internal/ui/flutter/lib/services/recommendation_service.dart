import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:interestnaut/services/llama_service.dart';
import 'package:interestnaut/services/sqlite_db.dart';

// --- Data Models ---

enum SuggestionStatus {
  pending,
  skipped,
  liked,
  disliked,
  added, // Favorited
  archived, // User has removed/deleted it from view, kept for history
}

class MediaSuggestion {
  final int id; // Using INTEGER for ID instead of String
  final String query; // The original LLM query or bot's raw suggestion text
  final String mediaType; // e.g., "music", "movie", "book"
  final String? title; // Enriched title from Wikidata/Wikipedia
  final String? artist; // Specific for music, adapt as needed for other types
  final String? album;  // Specific for music
  final String? coverArtUrl; // URL for cover art
  final String? description; // Enriched description
  final String? wikiUrl;
  final String? wikidataId;
  final String? botReasoning; // LLM's reasoning for the suggestion, or Go's reasoning for match
  SuggestionStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MediaSuggestion({
    this.id = 0, // Default to 0 for new entries (will be set by autoincrement)
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

  String toPromptSummary() {
    String summary;
    
    // Format based on media type
    switch (mediaType) {
      case 'music':
        summary = '${artist ?? "Unknown Artist"} - "${title ?? query}" (Album: ${album ?? "Unknown"})';
        break;
      case 'movie':
        // Extract movie info from either structured fields or the raw query
        final year = query.contains('(') && query.contains(')') 
            ? RegExp(r'\((\d{4})\)').firstMatch(query)?.group(1) 
            : null;
        summary = '"${title ?? query}" ${year != null ? "($year)" : ""}';
        break;
      case 'book':
        summary = '"${title ?? query}" by ${query.contains('by') ? query.split('by').last.trim() : "Unknown Author"}';
        break;
      case 'tv_show':
        summary = 'TV Show: "${title ?? query}"';
        break;
      case 'video_game':
        summary = 'Game: "${title ?? query}"';
        break;
      default:
        summary = title ?? query;
    }
    
    // Add status information
    return '$summary [Status: ${status.toString().split('.').last}]';
  }
}

class RecommendationService extends ChangeNotifier {
  final LlamaService _llamaService;
  final SQLiteDatabase _db = SQLiteDatabase();
  final List<MediaSuggestion> _suggestions = [];
  String? _currentlyProcessingMediaType;
  bool _isLoading = false;
  String? _error;
  
  // Queue management
  static const int _targetPendingCount = 3;
  Timer? _queueCheckTimer;
  
  RecommendationService(this._llamaService);

  List<MediaSuggestion> get suggestions => _suggestions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentlyProcessingMediaType => _currentlyProcessingMediaType;

  // Initialize the service (should be called early in the app lifecycle)
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Initialize the SQLite database
      await _db.init();
      
      // Start the background queue monitoring
      _startBackgroundQueue();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = "Failed to initialize recommendation service: $e";
      debugPrint(_error);
      notifyListeners();
    }
  }

  // Initialize background queue monitoring
  void _startBackgroundQueue() {
    // Check queue status every 30 seconds
    _queueCheckTimer?.cancel();
    _queueCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAndFillQueuesIfNeeded();
    });
  }

  // Check and fill queues if needed
  Future<void> _checkAndFillQueuesIfNeeded() async {
    if (_isLoading || _currentlyProcessingMediaType != null) {
      return; // Don't check if already processing
    }
    
    // Media types to check
    final mediaTypes = ['music', 'movie', 'book', 'tv_show', 'video_game'];
    
    for (final mediaType in mediaTypes) {
      final pendingCount = await _getPendingSuggestionsCount(mediaType);
      
      if (pendingCount < _targetPendingCount) {
        // Need to fill the queue for this media type
        await _fillSuggestionQueue(mediaType);
        break; // Only process one media type at a time
      }
    }
  }

  // Get the count of pending suggestions for a specific media type
  Future<int> _getPendingSuggestionsCount(String mediaType) async {
    try {
      return await _db.countPendingMediaSuggestions(mediaType);
    } catch (e) {
      debugPrint('Error counting pending suggestions: $e');
      return 0;
    }
  }

  // Fill the suggestion queue for a specific media type
  Future<void> _fillSuggestionQueue(String mediaType) async {
    if (_currentlyProcessingMediaType != null) {
      return; // Already processing another media type
    }
    
    _currentlyProcessingMediaType = mediaType;
    notifyListeners();
    
    try {
      // Get existing suggestions to build prompt context
      final existingSuggestions = await _db.getAllMediaSuggestions(
        mediaType: mediaType,
        limit: 10, // Get recent suggestions for context
      );
      
      // Build a prompt with context of past suggestions
      final context = existingSuggestions.map((s) => s.toPromptSummary()).join('\n');
      final prompt = _buildSuggestionPrompt(mediaType, context);
      
      // Get a suggestion from LLama
      final suggestion = await _llamaService.generateFullResponse(prompt);
      
      if (suggestion.isEmpty) {
        throw Exception('Failed to generate suggestion');
      }
      
      // Create a preliminary suggestion
      final preliminarySuggestion = MediaSuggestion(
        query: suggestion,
        mediaType: mediaType,
        status: SuggestionStatus.pending,
      );
      
      // Enrich the suggestion with Wikidata/Wikipedia data
      final enrichedSuggestion = await _enrichSuggestion(preliminarySuggestion);
      
      // Save to SQLite
      await _db.saveMediaSuggestion(enrichedSuggestion);
      
      _currentlyProcessingMediaType = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error filling suggestion queue: $e';
      debugPrint(_error);
      _currentlyProcessingMediaType = null;
      notifyListeners();
    }
  }

  // Build a prompt for the LLM to generate a suggestion
  String _buildSuggestionPrompt(String mediaType, String context) {
    String humanReadableType = mediaType.replaceAll('_', ' ');
    
    // Base prompt
    String prompt = 'Suggest a $humanReadableType that you think I might enjoy.';
    
    // Add context of previous suggestions if available
    if (context.isNotEmpty) {
      prompt = '''
I've previously been suggested the following $humanReadableType:
$context

Based on these, $prompt Make sure to suggest something different than what I've seen before.
''';
    }
    
    return prompt;
  }

  // Enrich a suggestion with Wikidata/Wikipedia data
  Future<MediaSuggestion> _enrichSuggestion(MediaSuggestion suggestion) async {
    // First, search Wikidata for the best match
    final wikidataResult = await _searchWikidata(suggestion.query, suggestion.mediaType);
    
    if (wikidataResult == null) {
      // If no Wikidata match found, return the original suggestion
      return suggestion;
    }
    
    // Get more details from Wikipedia if we have a Wikidata ID
    final wikipediaResult = wikidataResult['wikidataId'] != null 
      ? await _getWikipediaDetails(wikidataResult['wikidataId'] as String)
      : null;
    
    // Build enriched suggestion
    return MediaSuggestion(
      id: suggestion.id,
      query: suggestion.query,
      mediaType: suggestion.mediaType,
      title: wikidataResult['title'] as String? ?? suggestion.title,
      artist: wikidataResult['artist'] as String? ?? suggestion.artist,
      album: wikidataResult['album'] as String? ?? suggestion.album,
      coverArtUrl: wikidataResult['imageUrl'] as String? ?? suggestion.coverArtUrl,
      description: wikipediaResult?['description'] as String? ?? suggestion.description,
      wikiUrl: wikipediaResult?['url'] as String? ?? suggestion.wikiUrl,
      wikidataId: wikidataResult['wikidataId'] as String? ?? suggestion.wikidataId,
      botReasoning: "Found match on Wikidata with confidence level: ${wikidataResult['confidence'] ?? 'unknown'}",
      status: suggestion.status,
      createdAt: suggestion.createdAt,
    );
  }

  // Search Wikidata for the best match
  Future<Map<String, dynamic>?> _searchWikidata(String query, String mediaType) async {
    try {
      // Convert media type to the format expected by Wikidata
      final wikidataType = _mapMediaTypeForWikidata(mediaType);
      
      // Build the SPARQL query to search Wikidata
      final sparqlQuery = _buildWikidataSparqlQuery(query, wikidataType);
      
      // Wikidata endpoint
      final endpoint = Uri.parse('https://query.wikidata.org/sparql');
      
      // Execute the query
      final queryParams = {'query': sparqlQuery, 'format': 'json'};
      final url = Uri(
        scheme: endpoint.scheme,
        host: endpoint.host,
        path: endpoint.path,
        queryParameters: queryParams,
      );
      
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode != 200) {
        debugPrint('Wikidata query failed with status: ${response.statusCode}');
        return null;
      }
      
      final data = json.decode(response.body);
      final results = data['results']['bindings'] as List<dynamic>;
      
      if (results.isEmpty) {
        return null;
      }
      
      // Process the first/best result
      final result = results.first;
      
      // Extract fields based on media type
      final Map<String, dynamic> extractedData = {
        'wikidataId': result['item']?['value']?.toString().split('/').last,
        'title': result['itemLabel']?['value'],
        'confidence': 'high', // Default confidence
      };
      
      // Add media-type specific fields
      switch (mediaType) {
        case 'music':
          if (result.containsKey('artist')) {
            extractedData['artist'] = result['artistLabel']?['value'];
          }
          if (result.containsKey('album')) {
            extractedData['album'] = result['albumLabel']?['value'];
          }
          break;
        case 'movie':
        case 'tv_show':
          if (result.containsKey('director')) {
            extractedData['director'] = result['directorLabel']?['value'];
          }
          break;
        case 'book':
          if (result.containsKey('author')) {
            extractedData['author'] = result['authorLabel']?['value'];
          }
          break;
        case 'video_game':
          if (result.containsKey('developer')) {
            extractedData['developer'] = result['developerLabel']?['value'];
          }
          break;
      }
      
      // Try to get an image URL if available
      if (result.containsKey('image')) {
        extractedData['imageUrl'] = result['image']?['value'];
      }
      
      return extractedData;
    } catch (e) {
      debugPrint('Error searching Wikidata: $e');
      return null;
    }
  }
  
  // Build a SPARQL query for Wikidata based on the media type
  String _buildWikidataSparqlQuery(String query, String mediaType) {
    // Escape the query for SPARQL
    final escapedQuery = query.replaceAll('"', '\\"');
    
    // Base query structure
    String sparqlQuery = '''
      SELECT ?item ?itemLabel 
      WHERE {
        SERVICE wikibase:mwapi {
          bd:serviceParam wikibase:endpoint "www.wikidata.org/w/api.php";
          wikibase:api "EntitySearch";
          wikibase:limit 5;
          mwapi:search "$escapedQuery";
          mwapi:language "en".
          ?item wikibase:apiOutputItem mwapi:item.
        }
    ''';
    
    // Add filters based on media type
    switch (mediaType) {
      case 'music':
        sparqlQuery += '''
          ?item wdt:P31/wdt:P279* wd:Q2188189. # instance of musical work or subclass
          OPTIONAL { ?item wdt:P175 ?artist. } # performer
          OPTIONAL { ?item wdt:P361 ?album. } # part of album
          OPTIONAL { ?item wdt:P18 ?image. } # image
        ''';
        break;
      case 'movie':
        sparqlQuery += '''
          ?item wdt:P31/wdt:P279* wd:Q11424. # instance of film or subclass
          OPTIONAL { ?item wdt:P57 ?director. } # director
          OPTIONAL { ?item wdt:P18 ?image. } # image
        ''';
        break;
      case 'book':
        sparqlQuery += '''
          ?item wdt:P31/wdt:P279* wd:Q571. # instance of book or subclass
          OPTIONAL { ?item wdt:P50 ?author. } # author
          OPTIONAL { ?item wdt:P18 ?image. } # image
        ''';
        break;
      case 'show':
        sparqlQuery += '''
          ?item wdt:P31/wdt:P279* wd:Q5398426. # instance of TV series or subclass
          OPTIONAL { ?item wdt:P57 ?director. } # director
          OPTIONAL { ?item wdt:P18 ?image. } # image
        ''';
        break;
      case 'game':
        sparqlQuery += '''
          ?item wdt:P31/wdt:P279* wd:Q7889. # instance of video game or subclass
          OPTIONAL { ?item wdt:P178 ?developer. } # developer
          OPTIONAL { ?item wdt:P18 ?image. } # image
        ''';
        break;
    }
    
    // Close the query and add service for labels
    sparqlQuery += '''
      SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
    }
    LIMIT 1
    ''';
    
    return sparqlQuery;
  }

  // Get additional details from Wikipedia using a Wikidata ID
  Future<Map<String, dynamic>?> _getWikipediaDetails(String wikidataId) async {
    try {
      // First, get the Wikipedia title from Wikidata
      final wikidataEndpoint = Uri.parse('https://www.wikidata.org/w/api.php');
      
      final wdQueryParams = {
        'action': 'wbgetentities',
        'ids': wikidataId,
        'props': 'sitelinks',
        'sitefilter': 'enwiki',
        'format': 'json',
      };
      
      final wdUrl = Uri(
        scheme: wikidataEndpoint.scheme,
        host: wikidataEndpoint.host,
        path: wikidataEndpoint.path,
        queryParameters: wdQueryParams,
      );
      
      final wikidataResponse = await http.get(wdUrl);
      
      if (wikidataResponse.statusCode != 200) {
        return null;
      }
      
      final wikidataData = json.decode(wikidataResponse.body);
      final entities = wikidataData['entities'] as Map<String, dynamic>;
      
      if (!entities.containsKey(wikidataId) || 
          !entities[wikidataId].containsKey('sitelinks') || 
          !entities[wikidataId]['sitelinks'].containsKey('enwiki')) {
        return null;
      }
      
      final wikipediaTitle = entities[wikidataId]['sitelinks']['enwiki']['title'];
      
      // Now get the Wikipedia page extract
      final wikipediaEndpoint = Uri.parse('https://en.wikipedia.org/w/api.php');
      
      final wpQueryParams = {
        'action': 'query',
        'prop': 'extracts|info',
        'exintro': 'true',
        'explaintext': 'true',
        'inprop': 'url',
        'titles': wikipediaTitle,
        'format': 'json',
      };
      
      final wpUrl = Uri(
        scheme: wikipediaEndpoint.scheme,
        host: wikipediaEndpoint.host,
        path: wikipediaEndpoint.path,
        queryParameters: wpQueryParams,
      );
      
      final wikipediaResponse = await http.get(wpUrl);
      
      if (wikipediaResponse.statusCode != 200) {
        return null;
      }
      
      final wikipediaData = json.decode(wikipediaResponse.body);
      final pages = wikipediaData['query']['pages'] as Map<String, dynamic>;
      final pageId = pages.keys.first;
      final page = pages[pageId];
      
      return {
        'description': page['extract'],
        'url': page['fullurl'],
      };
    } catch (e) {
      debugPrint('Error fetching Wikipedia details: $e');
      return null;
    }
  }

  // Helper method to convert media types for Wikidata
  String _mapMediaTypeForWikidata(String mediaType) {
    switch (mediaType) {
      case 'tv_show': return 'show';  // Map to the format expected by Wikidata
      case 'video_game': return 'game';  // Map to the format expected by Wikidata
      default: return mediaType;  // Keep others as is
    }
  }

  // --- Initialization and Proactive Queue Management ---

  Future<void> initializeAndPrefillQueues() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      await init();
      await _checkAndFillQueuesIfNeeded();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = "Failed to initialize and prefill queues: $e";
      notifyListeners();
    }
  }

  // Ensure there are enough suggestions in the queue for a media type
  Future<bool> ensureSuggestionQueue(String mediaType) async {
    if (_isLoading) return false;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final pendingCount = await _getPendingSuggestionsCount(mediaType);
      
      if (pendingCount < _targetPendingCount) {
        await _fillSuggestionQueue(mediaType);
      }
      
      // Get the pending suggestions to return
      final pendingSuggestions = await _db.getPendingMediaSuggestions(mediaType);
      _suggestions.clear();
      _suggestions.addAll(pendingSuggestions);
      
      _isLoading = false;
      notifyListeners();
      return pendingSuggestions.isNotEmpty;
    } catch (e) {
      _isLoading = false;
      _error = "Failed to ensure suggestion queue: $e";
      notifyListeners();
      return false;
    }
  }

  // Update the status of a suggestion
  Future<bool> updateSuggestionStatus(int suggestionId, SuggestionStatus newStatus) async {
    try {
      await _db.updateMediaSuggestionStatus(suggestionId, newStatus);
      
      // Update local cache if the suggestion is in memory
      final index = _suggestions.indexWhere((s) => s.id == suggestionId);
      if (index >= 0) {
        _suggestions[index].status = newStatus;
        notifyListeners();
      }
      
      // Check if we need to fill the queue again
      final mediaType = _suggestions.firstWhere((s) => s.id == suggestionId, orElse: () => 
          MediaSuggestion(id: 0, query: '', mediaType: '')).mediaType;
      
      if (mediaType.isNotEmpty) {
        _checkAndFillQueuesIfNeeded();
      }
      
      return true;
    } catch (e) {
      _error = "Failed to update suggestion status: $e";
      debugPrint(_error);
      return false;
    }
  }

  // Delete a suggestion
  Future<bool> deleteSuggestion(int suggestionId) async {
    try {
      final result = await _db.deleteMediaSuggestion(suggestionId);
      
      // Remove from local cache if present
      final index = _suggestions.indexWhere((s) => s.id == suggestionId);
      if (index >= 0) {
        _suggestions.removeAt(index);
        notifyListeners();
      }
      
      return result;
    } catch (e) {
      _error = "Failed to delete suggestion: $e";
      debugPrint(_error);
      return false;
    }
  }

  // Get suggestions for a specific media type
  Future<List<MediaSuggestion>> getSuggestions(String mediaType, {SuggestionStatus? status}) async {
    try {
      final suggestions = await _db.getAllMediaSuggestions(
        mediaType: mediaType,
        statusFilter: status,
      );
      
      return suggestions;
    } catch (e) {
      _error = "Failed to get suggestions: $e";
      debugPrint(_error);
      return [];
    }
  }
  
  // Clean up resources
  @override
  void dispose() {
    _queueCheckTimer?.cancel();
    super.dispose();
  }
}

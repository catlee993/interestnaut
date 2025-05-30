import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

/// A service for searching and retrieving information from Wikipedia
class WikipediaService {
  static const String _baseUrl = 'https://en.wikipedia.org/w/api.php';
  static const String _baseContentUrl = 'https://en.wikipedia.org/wiki/';
  
  /// Returns a list of search results from Wikipedia
  /// [query] - The search term
  /// [limit] - Maximum number of results to return
  Future<List<WikipediaSearchResult>> search(String query, {int limit = 10}) async {
    try {
      debugPrint('[WIKIPEDIA] Searching for: "$query" (limit: $limit)');
      
      // Add a user agent to avoid potential API blocks
      final headers = {
        'User-Agent': 'Interestnaut/1.0 (https://github.com/catlee993/interestnaut; catlee993@example.com)',
        'Accept': 'application/json',
      };
      
      final uri = Uri.parse('$_baseUrl').replace(
        queryParameters: {
          'action': 'opensearch',
          'search': query,
          'limit': limit.toString(),
          'namespace': '0',
          'format': 'json',
        },
      );
      
      debugPrint('[WIKIPEDIA] Request URL: $uri');
      final response = await http.get(uri, headers: headers);

      debugPrint('[WIKIPEDIA] Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // The OpenSearch API returns data in a specific format:
        // [0] = search term
        // [1] = list of titles
        // [2] = list of snippets/descriptions
        // [3] = list of URLs
        
        if (data.length >= 4) {
          final List<String> titles = List<String>.from(data[1]);
          final List<String> descriptions = List<String>.from(data[2]);
          final List<String> urls = List<String>.from(data[3]);
          
          final results = <WikipediaSearchResult>[];
          
          for (int i = 0; i < titles.length; i++) {
            results.add(
              WikipediaSearchResult(
                title: titles[i],
                description: descriptions[i],
                url: urls[i],
                // Extract the page ID from the URL for future API calls
                pageId: _extractPageIdFromUrl(urls[i]),
              ),
            );
          }
          
          debugPrint('[WIKIPEDIA] Found ${results.length} results');
          return results;
        }
      } else {
        debugPrint('[WIKIPEDIA] Error response: ${response.body}');
      }
      
      return [];
    } catch (e) {
      debugPrint('Error searching Wikipedia: $e');
      return [];
    }
  }
  
  /// Extracts a page ID from a Wikipedia URL
  String _extractPageIdFromUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path;
    // The path is typically /wiki/Title, so we extract the title
    if (path.startsWith('/wiki/')) {
      return path.substring('/wiki/'.length);
    }
    return '';
  }
  
  /// Finds the best match for a query from Wikipedia
  /// This is useful when you need to find the most relevant Wikipedia page
  /// for an artist, album, song, etc.
  Future<WikipediaSearchResult?> findBestMatch(String query) async {
    final results = await search(query, limit: 5);
    
    if (results.isEmpty) {
      return null;
    }
    
    // For simple cases, just return the first result
    // In a more advanced implementation, you could score the results
    // based on relevance to the query
    return results.first;
  }
  
  /// Gets detailed content for a Wikipedia page by its title
  Future<WikipediaContent?> getContent(String pageId) async {
    try {
      debugPrint('[WIKIPEDIA] Getting content for page ID: $pageId');
      
      // Add a user agent to avoid potential API blocks
      final headers = {
        'User-Agent': 'Interestnaut/1.0 (https://github.com/catlee993/interestnaut; catlee993@example.com)',
        'Accept': 'application/json',
      };
      
      final uri = Uri.parse('$_baseUrl').replace(
        queryParameters: {
          'action': 'query',
          'prop': 'extracts|pageimages',
          'exintro': '1',
          'explaintext': '1',
          'titles': pageId,
          'format': 'json',
          'pithumbsize': '500',
        },
      );
      
      debugPrint('[WIKIPEDIA] Request URL: $uri');
      final response = await http.get(uri, headers: headers);
      
      debugPrint('[WIKIPEDIA] Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (!data.containsKey('query') || !data['query'].containsKey('pages')) {
          debugPrint('[WIKIPEDIA] Invalid response format: ${response.body}');
          return null;
        }
        
        final pages = data['query']['pages'] as Map<String, dynamic>;
        
        // There's only one page in the response, but we don't know the page ID
        if (pages.isEmpty) {
          debugPrint('[WIKIPEDIA] No pages found in response');
          return null;
        }
        
        final pageData = pages.values.first;
        
        // Check if we got a missing page
        if (pageData.containsKey('missing')) {
          debugPrint('[WIKIPEDIA] Page not found: $pageId');
          return null;
        }
        
        String? imageUrl;
        if (pageData.containsKey('thumbnail') && pageData['thumbnail'] != null) {
          imageUrl = pageData['thumbnail']['source'];
        }
        
        return WikipediaContent(
          pageId: pageData['pageid'].toString(),
          title: pageData['title'],
          extract: pageData['extract'] ?? 'No description available',
          imageUrl: imageUrl,
          fullUrl: '$_baseContentUrl${Uri.encodeComponent(pageId)}',
        );
      } else {
        debugPrint('[WIKIPEDIA] Error response: ${response.body}');
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting Wikipedia content: $e');
      return null;
    }
  }
  
  /// Alternative method that uses the Wikipedia Search API to find the best match
  /// This is more accurate than the OpenSearch API for finding specific entities
  Future<WikipediaSearchResult?> searchEntity(String query) async {
    try {
      debugPrint('[WIKIPEDIA] Searching entity: "$query"');
      
      // Add a user agent to avoid potential API blocks
      final headers = {
        'User-Agent': 'Interestnaut/1.0 (https://github.com/catlee993/interestnaut; catlee993@example.com)',
        'Accept': 'application/json',
      };
      
      final uri = Uri.parse('$_baseUrl').replace(
        queryParameters: {
          'action': 'query',
          'list': 'search',
          'srsearch': query,
          'format': 'json',
        },
      );
      
      debugPrint('[WIKIPEDIA] Request URL: $uri');
      final response = await http.get(uri, headers: headers);
      
      debugPrint('[WIKIPEDIA] Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (!data.containsKey('query') || !data['query'].containsKey('search')) {
          debugPrint('[WIKIPEDIA] Invalid response format: ${response.body}');
          return null;
        }
        
        final searchResults = data['query']['search'] as List<dynamic>;
        
        if (searchResults.isNotEmpty) {
          final result = searchResults.first;
          
          // Extract plain text from HTML snippet
          String description = result['snippet'] ?? '';
          description = description.replaceAll(RegExp(r'<[^>]*>'), '');
          
          return WikipediaSearchResult(
            title: result['title'],
            description: description,
            url: '$_baseContentUrl${Uri.encodeComponent(result['title'])}',
            pageId: result['title'],
          );
        } else {
          debugPrint('[WIKIPEDIA] No search results found for: $query');
        }
      } else {
        debugPrint('[WIKIPEDIA] Error response: ${response.body}');
      }
      
      return null;
    } catch (e) {
      debugPrint('Error searching Wikipedia entity: $e');
      return null;
    }
  }
  
  /// Finds media information by title and media type
  /// [title] - The title of the media
  /// [mediaType] - The type of media (book, movie, album, etc.)
  /// Returns a MediaInfo object with details about the media
  Future<MediaInfo?> findMediaInfo(String title, MediaType mediaType) async {
    try {
      if (title.isEmpty) {
        debugPrint('[WIKIPEDIA] Cannot search with empty title');
        return null;
      }
      
      debugPrint('[WIKIPEDIA] Searching for $mediaType: "$title"');
      
      // Create a more specific search query based on media type
      String searchQuery = title;
      switch (mediaType) {
        case MediaType.book:
          searchQuery = '$title book novel';
          break;
        case MediaType.movie:
          searchQuery = '$title film movie';
          break;
        case MediaType.tvShow:
          searchQuery = '$title tv television series show';
          break;
        case MediaType.album:
          searchQuery = '$title music album';
          break;
        case MediaType.game:
          searchQuery = '$title video game';
          break;
        default:
          // Use the title as is
          break;
      }
      
      // Try the entity search first (more accurate for specific titles)
      debugPrint('[WIKIPEDIA] Trying entity search first');
      final entityResult = await searchEntity(searchQuery);
      
      if (entityResult != null) {
        debugPrint('[WIKIPEDIA] Found entity match: ${entityResult.title}');
        final content = await getContent(entityResult.pageId);
        
        if (content != null) {
          // Check if the content matches the media type
          if (_contentMatchesMediaType(content.extract, mediaType)) {
            debugPrint('[WIKIPEDIA] Entity content matches media type');
            return _extractMediaInfo(content, mediaType);
          } else {
            debugPrint('[WIKIPEDIA] Entity content does not match media type, falling back to regular search');
          }
        }
      }
      
      // Fall back to regular search
      debugPrint('[WIKIPEDIA] Falling back to regular search');
      final searchResults = await search(searchQuery, limit: 5);
      
      if (searchResults.isEmpty) {
        debugPrint('[WIKIPEDIA] No Wikipedia results found for: $searchQuery');
        return null;
      }
      
      // Find the best match by comparing titles and checking for media type keywords
      WikipediaSearchResult? bestMatch = _findBestMediaMatch(searchResults, title, mediaType);
      
      if (bestMatch == null) {
        debugPrint('[WIKIPEDIA] No suitable Wikipedia match found for: $title ($mediaType)');
        
        // Last resort: try with a simpler query
        debugPrint('[WIKIPEDIA] Trying simpler query as last resort');
        final simpleResults = await search(title, limit: 3);
        if (simpleResults.isNotEmpty) {
          bestMatch = simpleResults.first;
          debugPrint('[WIKIPEDIA] Using first result as fallback: ${bestMatch.title}');
        } else {
          return null;
        }
      }
      
      debugPrint('[WIKIPEDIA] Found potential Wikipedia match: ${bestMatch.title}');
      
      // Get the detailed content for the best match
      final content = await getContent(bestMatch.pageId);
      
      if (content == null) {
        debugPrint('[WIKIPEDIA] Failed to get Wikipedia content for: ${bestMatch.title}');
        return null;
      }
      
      // Extract media information from the content
      return _extractMediaInfo(content, mediaType);
    } catch (e) {
      debugPrint('[WIKIPEDIA] Error finding media info: $e');
      return null;
    }
  }
  
  /// Checks if content matches the expected media type
  bool _contentMatchesMediaType(String content, MediaType mediaType) {
    final lowerContent = content.toLowerCase();
    final keywords = _getMediaTypeKeywords(mediaType);
    
    // Check if any of the keywords appear in the content
    for (final keyword in keywords) {
      if (lowerContent.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Finds the best match for a media item from search results
  WikipediaSearchResult? _findBestMediaMatch(
    List<WikipediaSearchResult> results, 
    String originalTitle, 
    MediaType mediaType
  ) {
    // Keywords to look for in the description based on media type
    final mediaTypeKeywords = _getMediaTypeKeywords(mediaType);
    
    // First pass: Look for exact title match with media type keywords
    for (final result in results) {
      final String normalizedResultTitle = _normalizeTitle(result.title);
      final String normalizedOriginalTitle = _normalizeTitle(originalTitle);
      
      // Check if the title is similar and description contains media type keywords
      if (_isTitleSimilar(normalizedResultTitle, normalizedOriginalTitle)) {
        bool hasMediaTypeKeyword = false;
        for (final keyword in mediaTypeKeywords) {
          if (result.description.toLowerCase().contains(keyword)) {
            hasMediaTypeKeyword = true;
            break;
          }
        }
        
        if (hasMediaTypeKeyword) {
          return result;
        }
      }
    }
    
    // Second pass: Look for partial title match with media type keywords
    for (final result in results) {
      final String normalizedResultTitle = _normalizeTitle(result.title);
      final String normalizedOriginalTitle = _normalizeTitle(originalTitle);
      
      bool hasMediaTypeKeyword = false;
      for (final keyword in mediaTypeKeywords) {
        if (result.description.toLowerCase().contains(keyword)) {
          hasMediaTypeKeyword = true;
          break;
        }
      }
      
      if (hasMediaTypeKeyword && 
          (normalizedResultTitle.contains(normalizedOriginalTitle) || 
           normalizedOriginalTitle.contains(normalizedResultTitle))) {
        return result;
      }
    }
    
    // Third pass: Just return the first result if it has a somewhat similar title
    if (results.isNotEmpty) {
      final String normalizedResultTitle = _normalizeTitle(results.first.title);
      final String normalizedOriginalTitle = _normalizeTitle(originalTitle);
      
      if (_isTitleSimilar(normalizedResultTitle, normalizedOriginalTitle)) {
        return results.first;
      }
    }
    
    return null;
  }
  
  /// Checks if two titles are similar
  bool _isTitleSimilar(String title1, String title2) {
    // If either title contains the other, they're similar
    if (title1.contains(title2) || title2.contains(title1)) {
      return true;
    }
    
    // Split titles into words and check for significant word overlap
    final words1 = title1.split(' ');
    final words2 = title2.split(' ');
    
    // Count matching words
    int matchCount = 0;
    for (final word1 in words1) {
      if (word1.length <= 2) continue; // Skip short words
      
      for (final word2 in words2) {
        if (word2.length <= 2) continue; // Skip short words
        
        if (word1 == word2) {
          matchCount++;
          break;
        }
      }
    }
    
    // If more than half of the words match, consider it similar
    return matchCount >= (words1.length / 2).round() || matchCount >= (words2.length / 2).round();
  }
  
  /// Normalizes a title for comparison
  String _normalizeTitle(String title) {
    // Remove common prefixes like "The", "A", etc.
    String normalized = title.toLowerCase();
    
    // Remove anything in parentheses
    normalized = normalized.replaceAll(RegExp(r'\([^)]*\)'), '');
    
    // Remove common punctuation
    normalized = normalized.replaceAll(RegExp(r'[^\w\s]'), '');
    
    // Remove common words
    final commonWords = ['the', 'a', 'an', 'and', 'or', 'of', 'in', 'on', 'at', 'to'];
    final words = normalized.split(' ');
    final filteredWords = words.where((word) => !commonWords.contains(word) && word.isNotEmpty).toList();
    
    return filteredWords.join(' ').trim();
  }
  
  /// Gets keywords associated with a media type
  List<String> _getMediaTypeKeywords(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.book:
        return ['book', 'novel', 'fiction', 'author', 'published', 'literature'];
      case MediaType.movie:
        return ['film', 'movie', 'directed', 'director', 'cinema', 'starring'];
      case MediaType.tvShow:
        return ['television', 'tv', 'series', 'show', 'episode', 'season', 'aired'];
      case MediaType.album:
        return ['album', 'music', 'song', 'band', 'artist', 'record', 'track', 'released'];
      case MediaType.game:
        return ['game', 'video game', 'gameplay', 'developer', 'console', 'player'];
      default:
        return [];
    }
  }
  
  /// Extracts media information from Wikipedia content
  MediaInfo _extractMediaInfo(WikipediaContent content, MediaType mediaType) {
    // Extract creator information (author, director, developer, etc.)
    String? creator = _extractCreator(content.extract, mediaType);
    
    // Extract release date
    String? releaseDate = _extractReleaseDate(content.extract, mediaType);
    
    // Extract genre
    String? genre = _extractGenre(content.extract, mediaType);
    
    return MediaInfo(
      title: content.title,
      description: content.extract,
      imageUrl: content.imageUrl,
      creator: creator,
      releaseDate: releaseDate,
      genre: genre,
      mediaType: mediaType,
      sourceUrl: content.fullUrl,
    );
  }
  
  /// Extracts creator information from content
  String? _extractCreator(String content, MediaType mediaType) {
    final lowerContent = content.toLowerCase();
    
    // Different patterns based on media type
    RegExp? regex;
    switch (mediaType) {
      case MediaType.book:
        regex = RegExp(r'(?:by|author|written by)[^\.\n]*?([\w\s]+)', caseSensitive: false);
        break;
      case MediaType.movie:
        regex = RegExp(r'(?:directed by|director)[^\.\n]*?([\w\s]+)', caseSensitive: false);
        break;
      case MediaType.tvShow:
        regex = RegExp(r'(?:created by|creator|developed by)[^\.\n]*?([\w\s]+)', caseSensitive: false);
        break;
      case MediaType.album:
        regex = RegExp(r'(?:by|artist|band)[^\.\n]*?([\w\s]+)', caseSensitive: false);
        break;
      case MediaType.game:
        regex = RegExp(r'(?:developed by|developer)[^\.\n]*?([\w\s]+)', caseSensitive: false);
        break;
      default:
        return null;
    }
    
    final match = regex.firstMatch(lowerContent);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.trim();
    }
    
    return null;
  }
  
  /// Extracts release date from content
  String? _extractReleaseDate(String content, MediaType mediaType) {
    final lowerContent = content.toLowerCase();
    
    // Look for year patterns
    final yearRegex = RegExp(r'(?:released|published|aired|premiered|first released|launch|debut)(?:[^\.\n]*?)(\d{4})', caseSensitive: false);
    final yearMatch = yearRegex.firstMatch(lowerContent);
    
    if (yearMatch != null && yearMatch.groupCount >= 1) {
      return yearMatch.group(1);
    }
    
    // Fallback: just look for a year in the first paragraph
    final firstParagraphYearRegex = RegExp(r'\b(19\d{2}|20\d{2})\b');
    final paragraphs = content.split('\n\n');
    if (paragraphs.isNotEmpty) {
      final firstParagraphMatch = firstParagraphYearRegex.firstMatch(paragraphs[0]);
      if (firstParagraphMatch != null) {
        return firstParagraphMatch.group(0);
      }
    }
    
    return null;
  }
  
  /// Extracts genre information from content
  String? _extractGenre(String content, MediaType mediaType) {
    final lowerContent = content.toLowerCase();
    
    // Different patterns based on media type
    RegExp? regex;
    switch (mediaType) {
      case MediaType.book:
      case MediaType.movie:
      case MediaType.tvShow:
      case MediaType.album:
      case MediaType.game:
        regex = RegExp(r'(?:genre|genres)[^\.\n]*?([\w\s,]+)', caseSensitive: false);
        break;
      default:
        return null;
    }
    
    final match = regex.firstMatch(lowerContent);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.trim();
    }
    
    return null;
  }
}

/// Represents a Wikipedia search result
class WikipediaSearchResult {
  final String title;
  final String description;
  final String url;
  final String pageId;
  
  WikipediaSearchResult({
    required this.title,
    required this.description,
    required this.url,
    required this.pageId,
  });
  
  @override
  String toString() {
    return 'WikipediaSearchResult{title: $title, description: $description, url: $url}';
  }
}

/// Represents detailed Wikipedia content
class WikipediaContent {
  final String pageId;
  final String title;
  final String extract;
  final String? imageUrl;
  final String fullUrl;
  
  WikipediaContent({
    required this.pageId,
    required this.title,
    required this.extract,
    this.imageUrl,
    required this.fullUrl,
  });
  
  @override
  String toString() {
    return 'WikipediaContent{title: $title, extract: ${extract.substring(0, extract.length > 100 ? 100 : extract.length)}...}';
  }
}

/// Represents the type of media
enum MediaType {
  book,
  movie,
  tvShow,
  album,
  game,
  other
}

/// Represents media information extracted from Wikipedia
class MediaInfo {
  final String title;
  final String description;
  final String? imageUrl;
  final String? creator;
  final String? releaseDate;
  final String? genre;
  final MediaType mediaType;
  final String sourceUrl;
  
  MediaInfo({
    required this.title,
    required this.description,
    this.imageUrl,
    this.creator,
    this.releaseDate,
    this.genre,
    required this.mediaType,
    required this.sourceUrl,
  });
  
  @override
  String toString() {
    return 'MediaInfo{title: $title, creator: $creator, releaseDate: $releaseDate, genre: $genre, mediaType: $mediaType}';
  }
  
  /// Converts this MediaInfo to a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'creator': creator,
      'releaseDate': releaseDate,
      'genre': genre,
      'mediaType': mediaType.toString().split('.').last,
      'sourceUrl': sourceUrl,
    };
  }
  
  /// Creates a MediaInfo from a Map (for database retrieval)
  factory MediaInfo.fromMap(Map<String, dynamic> map) {
    return MediaInfo(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      creator: map['creator'],
      releaseDate: map['releaseDate'],
      genre: map['genre'],
      mediaType: _mediaTypeFromString(map['mediaType'] ?? 'other'),
      sourceUrl: map['sourceUrl'] ?? '',
    );
  }
  
  /// Converts a string to MediaType enum
  static MediaType _mediaTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'book':
        return MediaType.book;
      case 'movie':
        return MediaType.movie;
      case 'tvshow':
        return MediaType.tvShow;
      case 'album':
        return MediaType.album;
      case 'game':
        return MediaType.game;
      default:
        return MediaType.other;
    }
  }
}

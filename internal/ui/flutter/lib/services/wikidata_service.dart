import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Represents a search result from Wikipedia
class WikidataSearchResult {
  final String id;
  final String title;
  final String? artist; // Author, director, performer, etc.
  final String? description;
  final String? imageUrl;
  final String? releaseDate;
  final String? genre;
  final Map<String, dynamic>? additionalData;

  WikidataSearchResult({
    required this.id,
    required this.title,
    this.artist,
    this.description,
    this.imageUrl,
    this.releaseDate,
    this.genre,
    this.additionalData,
  });
}

class WikidataService {
  static const String _wikipediaEndpoint = 'https://en.wikipedia.org/w/api.php';
  static const Duration _timeout = Duration(seconds: 5);

  /// Search using Wikimedia Core API for better results with thumbnails
  Future<List<WikidataSearchResult>> search(String query, String mediaType, {int limit = 20}) async {
    try {
      // Create media-type specific search query
      String enhancedQuery;
      List<String> filterKeywords = [];
      List<String> excludePatterns = [];
      
      switch (mediaType.toLowerCase()) {
        case 'book':
        case 'books':
          enhancedQuery = '$query book';  // Simplified
          filterKeywords = ['book', 'novel', 'author', 'written', 'published'];
          break;
        case 'music':
        case 'song':
        case 'album':
          enhancedQuery = '$query music';  // Simplified
          filterKeywords = ['song', 'album', 'music', 'artist', 'band'];
          break;
        case 'movie':
        case 'movies':
        case 'film':
          enhancedQuery = '$query film';  // Simplified
          filterKeywords = ['film', 'movie', 'directed', 'cinema'];
          break;
        case 'tv':
        case 'television':
        case 'show':
          enhancedQuery = '$query television';  // Simplified
          filterKeywords = ['television', 'series', 'show', 'episode'];
          break;
        case 'game':
        case 'games':
        case 'videogame':
          enhancedQuery = '$query game';  // Simplified
          filterKeywords = ['game', 'video', 'developed'];
          break;
        default:
          enhancedQuery = query;
          filterKeywords = [];
      }

      // Use Wikipedia OpenSearch API which is more reliable
      final uri = Uri.parse('https://en.wikipedia.org/w/api.php').replace(queryParameters: {
        'action': 'opensearch',
        'search': enhancedQuery,
        'limit': '20',
        'namespace': '0',
        'format': 'json',
      });

      debugPrint('[WIKIPEDIA] ===== SEARCH DEBUG =====');
      debugPrint('[WIKIPEDIA] Original query: $query');
      debugPrint('[WIKIPEDIA] Media type: $mediaType');
      debugPrint('[WIKIPEDIA] Enhanced query: $enhancedQuery');
      debugPrint('[WIKIPEDIA] URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'InterestNaut/1.0 (https://github.com/interestnaut/interestnaut)',
        },
      ).timeout(_timeout);

      debugPrint('[WIKIPEDIA] Response status: ${response.statusCode}');
      debugPrint('[WIKIPEDIA] Response body length: ${response.body.length}');
      debugPrint('[WIKIPEDIA] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('[WIKIPEDIA] Parsed JSON structure: ${data.runtimeType}');
        
        // OpenSearch returns [query, [titles], [descriptions], [urls]]
        if (data is List && data.length >= 4) {
          final titles = data[1] as List<dynamic>?;
          final descriptions = data[2] as List<dynamic>?;
          final urls = data[3] as List<dynamic>?;
          
          if (titles == null || titles.isEmpty) {
            debugPrint('[WIKIPEDIA] ERROR: No titles found');
            return [];
          }

          debugPrint('[WIKIPEDIA] Found ${titles.length} raw results');
          final results = <WikidataSearchResult>[];
          
          for (int i = 0; i < titles.length && i < limit; i++) {
            final title = titles[i]?.toString() ?? '';
            final description = (descriptions != null && i < descriptions.length) 
                ? descriptions[i]?.toString() ?? '' 
                : '';
            final url = (urls != null && i < urls.length) 
                ? urls[i]?.toString() ?? '' 
                : '';
            
            debugPrint('[WIKIPEDIA] ===== PROCESSING RESULT $i =====');
            debugPrint('[WIKIPEDIA] Title: $title');
            debugPrint('[WIKIPEDIA] Description: $description');
            debugPrint('[WIKIPEDIA] URL: $url');
            
            // Skip disambiguation pages
            if (title.contains('disambiguation')) {
              debugPrint('[WIKIPEDIA] SKIPPING: disambiguation page');
              continue;
            }
            
            // Get image from Wikipedia page summary API
            String? imageUrl;
            try {
              final wikipediaTitle = title.replaceAll(' ', '_');
              final pageImageUrl = 'https://en.wikipedia.org/api/rest_v1/page/summary/$wikipediaTitle';
              debugPrint('[WIKIPEDIA] Fetching image from: $pageImageUrl');
              
              final imageResponse = await http.get(Uri.parse(pageImageUrl)).timeout(Duration(seconds: 5));
              if (imageResponse.statusCode == 200) {
                final imageData = json.decode(imageResponse.body);
                if (imageData['thumbnail'] != null && imageData['thumbnail']['source'] != null) {
                  imageUrl = imageData['thumbnail']['source'].toString();
                  debugPrint('[WIKIPEDIA] Found image: $imageUrl');
                } else {
                  debugPrint('[WIKIPEDIA] No thumbnail in summary API response');
                }
              } else {
                debugPrint('[WIKIPEDIA] Summary API returned ${imageResponse.statusCode}');
              }
            } catch (e) {
              debugPrint('[WIKIPEDIA] Image fetch failed: $e');
            }

            results.add(WikidataSearchResult(
              id: i.toString(),
              title: title,
              artist: null,
              description: description,
              imageUrl: imageUrl,
              releaseDate: null,
              genre: null,
              additionalData: {
                'source': 'wikipedia',
                'url': url.isNotEmpty ? url : 'https://en.wikipedia.org/wiki/${title.replaceAll(' ', '_')}',
              },
            ));

            debugPrint('[WIKIPEDIA] ✅ ADDED RESULT: $title');

            if (results.length >= limit) {
              break;
            }
          }

          debugPrint('[WIKIPEDIA] ===== FINAL SUMMARY =====');
          debugPrint('[WIKIPEDIA] Total results added: ${results.length}');
          for (int i = 0; i < results.length; i++) {
            debugPrint('[WIKIPEDIA] Result $i: ${results[i].title}');
          }
          return results;
        } else {
          debugPrint('[WIKIPEDIA] ERROR: Unexpected response format');
          debugPrint('[WIKIPEDIA] Response: $data');
          return [];
        }
      } else {
        debugPrint('[WIKIPEDIA] HTTP Error: ${response.statusCode}');
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('[WIKIPEDIA] Exception: $e');
      debugPrint('[WIKIPEDIA] Stack trace: $stackTrace');
      return [];
    }
  }

  /// Extract creator/artist information from Wikipedia text
  String? _extractCreatorFromText(String text, String mediaType) {
    if (text.isEmpty) return null;
    
    switch (mediaType.toLowerCase()) {
      case 'book':
      case 'books':
        // Look for author patterns
        final authorPatterns = [
          RegExp(r'written by ([^.]+)', caseSensitive: false),
          RegExp(r'authored by ([^.]+)', caseSensitive: false),
          RegExp(r'by ([^.]+)', caseSensitive: false),
          RegExp(r'author ([^.]+)', caseSensitive: false),
        ];
        for (final pattern in authorPatterns) {
          final match = pattern.firstMatch(text);
          if (match != null) {
            return match.group(1)?.trim();
          }
        }
        break;
        
      case 'movie':
      case 'movies':
      case 'film':
        // Look for director patterns
        final directorPatterns = [
          RegExp(r'directed by ([^.]+)', caseSensitive: false),
          RegExp(r'director ([^.]+)', caseSensitive: false),
        ];
        for (final pattern in directorPatterns) {
          final match = pattern.firstMatch(text);
          if (match != null) {
            return match.group(1)?.trim();
          }
        }
        break;
        
      case 'music':
      case 'song':
      case 'album':
        // Look for artist/performer patterns
        final artistPatterns = [
          RegExp(r'performed by ([^.]+)', caseSensitive: false),
          RegExp(r'by ([^.]+)', caseSensitive: false),
          RegExp(r'artist ([^.]+)', caseSensitive: false),
        ];
        for (final pattern in artistPatterns) {
          final match = pattern.firstMatch(text);
          if (match != null) {
            return match.group(1)?.trim();
          }
        }
        break;
        
      case 'tv':
      case 'television':
      case 'show':
        // Look for creator patterns
        final creatorPatterns = [
          RegExp(r'created by ([^.]+)', caseSensitive: false),
          RegExp(r'creator ([^.]+)', caseSensitive: false),
        ];
        for (final pattern in creatorPatterns) {
          final match = pattern.firstMatch(text);
          if (match != null) {
            return match.group(1)?.trim();
          }
        }
        break;
        
      case 'game':
      case 'games':
      case 'videogame':
        // Look for developer patterns
        final developerPatterns = [
          RegExp(r'developed by ([^.]+)', caseSensitive: false),
          RegExp(r'developer ([^.]+)', caseSensitive: false),
        ];
        for (final pattern in developerPatterns) {
          final match = pattern.firstMatch(text);
          if (match != null) {
            return match.group(1)?.trim();
          }
        }
        break;
    }
    
    return null;
  }
} 
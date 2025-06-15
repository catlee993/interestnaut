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

  /// Search using Wikipedia API
  Future<List<WikidataSearchResult>> search(String query, String mediaType, {int limit = 20}) async {
    try {
      // Create more specific search queries based on media type
      String enhancedQuery;
      List<String> filterKeywords = [];
      
      switch (mediaType.toLowerCase()) {
        case 'book':
        case 'books':
          enhancedQuery = '$query (book OR novel OR "written by")';
          filterKeywords = ['book', 'novel', 'author', 'written', 'published'];
          break;
        case 'music':
        case 'song':
        case 'album':
          enhancedQuery = '$query (song OR album OR music OR "performed by")';
          filterKeywords = ['song', 'album', 'music', 'artist', 'performed', 'singer'];
          break;
        case 'movie':
        case 'movies':
        case 'film':
          enhancedQuery = '$query (film OR movie OR "directed by")';
          filterKeywords = ['film', 'movie', 'director', 'directed', 'cinema'];
          break;
        case 'tv':
        case 'television':
        case 'show':
          enhancedQuery = '$query (television OR "TV series" OR "TV show" OR "created by")';
          filterKeywords = ['television', 'series', 'show', 'episode', 'created', 'network'];
          break;
        case 'game':
        case 'games':
        case 'videogame':
          enhancedQuery = '$query ("video game" OR game OR "developed by")';
          filterKeywords = ['game', 'video', 'developed', 'developer', 'gaming'];
          break;
        default:
          enhancedQuery = query;
          filterKeywords = [];
      }

      final uri = Uri.parse(_wikipediaEndpoint).replace(queryParameters: {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': enhancedQuery,
        'gsrprop': 'snippet',
        'prop': 'pageimages|extracts|info',
        'exintro': '1',
        'explaintext': '1',
        'piprop': 'thumbnail',
        'pithumbsize': '200',
        'inprop': 'url',
        'format': 'json',
        'origin': '*',
        'gsrlimit': (limit * 2).toString(), // Get more results to filter
      });

      debugPrint('[WIKIPEDIA] Searching: $enhancedQuery');

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'InterestNaut/1.0 (https://github.com/interestnaut/interestnaut)',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;
        
        if (pages == null) {
          debugPrint('[WIKIPEDIA] No pages found');
          return [];
        }

        final results = <WikidataSearchResult>[];
        
        for (final pageData in pages.values) {
          final pageId = pageData['pageid']?.toString() ?? '';
          final title = pageData['title']?.toString() ?? '';
          final extract = pageData['extract']?.toString() ?? '';
          final thumbnail = pageData['thumbnail']?['source']?.toString();
          final url = pageData['fullurl']?.toString() ?? '';

          // Skip disambiguation pages and other non-content pages
          if (title.contains('disambiguation') || 
              title.contains('(disambiguation)') ||
              title.contains('List of') ||
              title.contains('Category:') ||
              extract.isEmpty) {
            continue;
          }

          // Filter by media type relevance
          if (filterKeywords.isNotEmpty) {
            final lowerTitle = title.toLowerCase();
            final lowerExtract = extract.toLowerCase();
            final hasRelevantKeyword = filterKeywords.any((keyword) => 
              lowerTitle.contains(keyword) || lowerExtract.contains(keyword));
            
            if (!hasRelevantKeyword) {
              continue; // Skip irrelevant results
            }
          }

          // Try to extract creator/artist info from the extract
          String? artist = _extractCreatorFromText(extract, mediaType);

          results.add(WikidataSearchResult(
            id: pageId,
            title: title,
            artist: artist,
            description: extract.length > 200 ? '${extract.substring(0, 200)}...' : extract,
            imageUrl: thumbnail,
            releaseDate: null,
            genre: null,
            additionalData: {
              'source': 'wikipedia',
              'url': url,
              'full_extract': extract,
            },
          ));

          // Stop when we have enough results
          if (results.length >= limit) {
            break;
          }
        }

        debugPrint('[WIKIPEDIA] Found ${results.length} filtered results');
        return results;
      } else {
        debugPrint('[WIKIPEDIA] Error response: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[WIKIPEDIA] Error: $e');
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
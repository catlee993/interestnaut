import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'wikipedia_service.dart';

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
  final WikipediaService _wikipediaService = WikipediaService();
  static const Duration _timeout = Duration(seconds: 5);

  /// Search using our optimized Wikipedia service with query validation
  Future<List<WikidataSearchResult>> search(String query, String mediaType, {int limit = 20}) async {
    try {
      // Convert mediaType string to MediaType enum
      MediaType mediaTypeEnum;
      switch (mediaType.toLowerCase()) {
        case 'book':
        case 'books':
          mediaTypeEnum = MediaType.book;
          break;
        case 'movie':
        case 'movies':
        case 'film':
          mediaTypeEnum = MediaType.movie;
          break;
        case 'tv':
        case 'television':
        case 'show':
        case 'shows':
          mediaTypeEnum = MediaType.tvShow;
          break;
        case 'music':
        case 'song':
        case 'album':
          mediaTypeEnum = MediaType.album;
          break;
        case 'game':
        case 'games':
        case 'videogame':
          mediaTypeEnum = MediaType.game;
          break;
        default:
          mediaTypeEnum = MediaType.other;
      }
      
      debugPrint('[WIKIDATA] Using optimized Wikipedia search for: "$query" ($mediaType) with limit: $limit');
      
      // Use the optimized Wikipedia precision search which has proper category filtering
      final wikipediaResults = await _wikipediaService.precisionSearch(query, mediaTypeEnum);
      
      // Limit the results to the requested number
      final limitedResults = wikipediaResults.take(limit).toList();
      
      // Convert WikipediaSearchResult to WikidataSearchResult for UI compatibility
      final results = <WikidataSearchResult>[];
      
      for (int i = 0; i < limitedResults.length; i++) {
        final result = limitedResults[i];
        
        // Get enhanced content if this looks like a good match
        WikipediaContent? content;
        String? artist;
        String? imageUrl;
        
        try {
          // Try to get full content for better metadata
          content = await _wikipediaService.getContent(result.pageId);
          if (content != null) {
            imageUrl = content.imageUrl;
            
            // Extract artist/creator information based on media type
            artist = _extractCreatorFromContent(content.extract, mediaTypeEnum);
          }
        } catch (e) {
          debugPrint('[WIKIDATA] Failed to get enhanced content for ${result.title}: $e');
        }
        
        results.add(WikidataSearchResult(
          id: result.pageId,
          title: result.title,
          artist: artist,
          description: content?.extract ?? result.description,
          imageUrl: imageUrl,
          releaseDate: null, // Could be extracted from content if needed
          genre: null, // Could be extracted from content if needed
          additionalData: {
            'source': 'wikipedia_optimized',
            'url': result.url,
          },
        ));
      }
      
      debugPrint('[WIKIDATA] Returned ${results.length} optimized results');
      return results;
      
    } catch (e, stackTrace) {
      debugPrint('[WIKIDATA] Exception: $e');
      debugPrint('[WIKIDATA] Stack trace: $stackTrace');
      return [];
    }
  }

  /// Extract creator/artist information from Wikipedia content
  String? _extractCreatorFromContent(String content, MediaType mediaType) {
    if (content.isEmpty) return null;
    
    switch (mediaType) {
      case MediaType.book:
        // Look for author patterns
        final authorPatterns = [
          RegExp(r'written by ([^.]+)', caseSensitive: false),
          RegExp(r'authored by ([^.]+)', caseSensitive: false),
          RegExp(r'by ([^.]+)', caseSensitive: false),
          RegExp(r'author ([^.]+)', caseSensitive: false),
        ];
        for (final pattern in authorPatterns) {
          final match = pattern.firstMatch(content);
          if (match != null) {
            return match.group(1)?.trim();
          }
        }
        break;
        
      case MediaType.movie:
        // Look for director patterns
        final directorPatterns = [
          RegExp(r'directed by ([^.]+)', caseSensitive: false),
          RegExp(r'director ([^.]+)', caseSensitive: false),
        ];
        for (final pattern in directorPatterns) {
          final match = pattern.firstMatch(content);
          if (match != null) {
            return match.group(1)?.trim();
          }
        }
        break;
        
      case MediaType.album:
        // Look for artist/performer patterns
        final artistPatterns = [
          RegExp(r'performed by ([^.]+)', caseSensitive: false),
          RegExp(r'by ([^.]+)', caseSensitive: false),
          RegExp(r'artist ([^.]+)', caseSensitive: false),
        ];
        for (final pattern in artistPatterns) {
          final match = pattern.firstMatch(content);
          if (match != null) {
            return match.group(1)?.trim();
          }
        }
        break;
        
      case MediaType.tvShow:
        // Look for creator patterns
        final creatorPatterns = [
          RegExp(r'created by ([^.]+)', caseSensitive: false),
          RegExp(r'creator ([^.]+)', caseSensitive: false),
        ];
        for (final pattern in creatorPatterns) {
          final match = pattern.firstMatch(content);
          if (match != null) {
            return match.group(1)?.trim();
          }
        }
        break;
        
      case MediaType.game:
        // Look for developer patterns
        final developerPatterns = [
          RegExp(r'developed by ([^.]+)', caseSensitive: false),
          RegExp(r'developer ([^.]+)', caseSensitive: false),
        ];
        for (final pattern in developerPatterns) {
          final match = pattern.firstMatch(content);
          if (match != null) {
            return match.group(1)?.trim();
          }
        }
        break;
        
      default:
        break;
    }
    
    return null;
  }
} 
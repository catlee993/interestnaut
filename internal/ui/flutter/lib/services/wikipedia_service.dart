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
      final response = await http.get(
        Uri.parse('$_baseUrl?action=opensearch&search=${Uri.encodeComponent(query)}&limit=$limit&namespace=0&format=json'),
      );

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
          
          return results;
        }
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
      // Using the more detailed query to get page content
      final response = await http.get(
        Uri.parse(
          '$_baseUrl?action=query&prop=extracts|pageimages&exintro=1&explaintext=1&titles=${Uri.encodeComponent(pageId)}&format=json&pithumbsize=500'
        ),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final pages = data['query']['pages'] as Map<String, dynamic>;
        
        // There's only one page in the response, but we don't know the page ID
        final pageData = pages.values.first;
        
        String? imageUrl;
        if (pageData.containsKey('thumbnail') && pageData['thumbnail'] != null) {
          imageUrl = pageData['thumbnail']['source'];
        }
        
        return WikipediaContent(
          pageId: pageData['pageid'].toString(),
          title: pageData['title'],
          extract: pageData['extract'],
          imageUrl: imageUrl,
          fullUrl: '$_baseContentUrl${Uri.encodeComponent(pageId)}',
        );
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
      final response = await http.get(
        Uri.parse(
          '$_baseUrl?action=query&list=search&srsearch=${Uri.encodeComponent(query)}&format=json'
        ),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
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
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error searching Wikipedia entity: $e');
      return null;
    }
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

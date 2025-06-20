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
    // Validate query length and content
    if (query.trim().isEmpty) {
      debugPrint('[WIKIPEDIA] Query too short, skipping search: "$query"');
      return [];
    }
    
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
          'piprop': 'thumbnail|original',
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
        String? originalImageUrl;
        
        // Extract thumbnail URL (preferred for UI display)
        if (pageData.containsKey('thumbnail') && pageData['thumbnail'] != null) {
          imageUrl = pageData['thumbnail']['source'];
          debugPrint('[WIKIPEDIA] Thumbnail image found: $imageUrl');
        }
        
        // Extract original/full-size image URL
        if (pageData.containsKey('original') && pageData['original'] != null) {
          originalImageUrl = pageData['original']['source'];
          debugPrint('[WIKIPEDIA] Original image found: $originalImageUrl');
          
          // If we don't have a thumbnail, use the original
          if (imageUrl == null) {
            imageUrl = originalImageUrl;
          }
        }
        
        // Limit the extract to first few sentences to fit in UI cards
        String extract = pageData['extract'] ?? 'No description available';
        extract = _limitDescription(extract);
        
        final content = WikipediaContent(
          pageId: pageData['pageid'].toString(),
          title: pageData['title'],
          extract: extract,
          imageUrl: imageUrl,
          fullUrl: '$_baseContentUrl${Uri.encodeComponent(pageId)}',
        );
        
        return content;
      } else {
        debugPrint('[WIKIPEDIA] Error response: ${response.body}');
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting Wikipedia content: $e');
      return null;
    }
  }
  
  /// Limits description text to the first few sentences for UI display
  String _limitDescription(String description, {int maxSentences = 3, int maxChars = 400}) {
    if (description.isEmpty) return description;
    
    // First limit by character count
    if (description.length <= maxChars) {
      return description;
    }
    
    // Split into sentences and take the first few
    final sentences = description.split(RegExp(r'(?<=[.!?])\s+'));
    
    if (sentences.length <= maxSentences) {
      return description.length > maxChars 
        ? '${description.substring(0, maxChars)}...'
        : description;
    }
    
    // Take first maxSentences and check length
    String result = sentences.take(maxSentences).join(' ').trim();
    
    // If still too long, truncate and add ellipsis
    if (result.length > maxChars) {
      result = '${result.substring(0, maxChars)}...';
    }
    
    return result;
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
          'srnamespace': '0', // Only main namespace (articles)
          'srlimit': '5',
          'srinfo': 'size|wordcount|timestamp|snippet',
          'srprop': 'size|wordcount|timestamp|snippet|titlesnippet',
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
          
          final searchResult = WikipediaSearchResult(
            title: result['title'],
            description: description,
            url: '$_baseContentUrl${Uri.encodeComponent(result['title'])}',
            pageId: result['title'],
          );
          
          return searchResult;
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
  
  /// High-precision search using advanced MediaWiki search features
  Future<List<WikipediaSearchResult>> precisionSearch(String title, MediaType mediaType, {int maxResults = 20}) async {
    // Validate query
    final cleanTitle = _cleanTitleForSearch(title);
    if (cleanTitle.isEmpty) {
      debugPrint('[WIKIPEDIA] Query invalid for precision search: "$title" -> "$cleanTitle"');
      return [];
    }
    
    // Only reject truly generic terms, allow things like 'br' for prefix search
    if (cleanTitle.length < 3 && _isGenericTerm(cleanTitle)) {
      debugPrint('[WIKIPEDIA] Query too generic for precision search: "$title" -> "$cleanTitle"');
      return [];
    }

    debugPrint('[WIKIPEDIA] ===== PRECISION SEARCH DEBUG START =====');
    debugPrint('[WIKIPEDIA] Input: "$title" -> cleaned: "$cleanTitle"');
    debugPrint('[WIKIPEDIA] Media type: $mediaType');
    debugPrint('[WIKIPEDIA] Query length: ${cleanTitle.length}');
    debugPrint('[WIKIPEDIA] Max results: $maxResults');
    
    try {
      debugPrint('[WIKIPEDIA] Precision search for: "$title" ($mediaType)');
      
      // Build advanced search queries with increasing specificity
      final searchQueries = _buildAdvancedSearchQueries(title, mediaType);
      
      final headers = {
        'User-Agent': 'Interestnaut/1.0 (https://github.com/catlee993/interestnaut; catlee993@example.com)',
        'Accept': 'application/json',
      };
      
      final allResults = <WikipediaSearchResult>[];
      final seenTitles = <String>{};
      
      for (final searchQuery in searchQueries) {
        if (allResults.length >= maxResults) {
          debugPrint('[WIKIPEDIA] Reached max results limit ($maxResults), stopping search');
          break;
        }
        
        debugPrint('[WIKIPEDIA] Trying advanced query: "$searchQuery"');
        
        final uri = Uri.parse('$_baseUrl').replace(
          queryParameters: {
            'action': 'query',
            'list': 'search',
            'srsearch': searchQuery,
            'srnamespace': '0', // Only main namespace
            'srlimit': '20',
            'srinfo': 'size|wordcount|timestamp|snippet',
            'srprop': 'size|wordcount|timestamp|snippet|titlesnippet',
            'format': 'json',
          },
        );
        
        final response = await http.get(uri, headers: headers);
        
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          
          if (data.containsKey('query') && data['query'].containsKey('search')) {
            final searchResults = data['query']['search'] as List<dynamic>;
            
            debugPrint('[WIKIPEDIA] ===== RAW API RESPONSE =====');
            debugPrint('[WIKIPEDIA] Query returned ${searchResults.length} raw results');
            
            if (searchResults.isNotEmpty) {
              final queryResults = <WikipediaSearchResult>[];
              
              for (final result in searchResults) {
                // Skip duplicates
                if (seenTitles.contains(result['title'])) {
                  continue;
                }
                seenTitles.add(result['title']);
                
                String description = result['snippet'] ?? '';
                description = description.replaceAll(RegExp(r'<[^>]*>'), '');
                
                final wikiResult = WikipediaSearchResult(
                  title: result['title'],
                  description: description,
                  url: '$_baseContentUrl${Uri.encodeComponent(result['title'])}',
                  pageId: result['title'],
                );
                
                debugPrint('[WIKIPEDIA] Raw result: "${wikiResult.title}" - ${wikiResult.description}');
                queryResults.add(wikiResult);
              }
              
              // Apply post-processing filters to this batch
              final filteredResults = _applyPostProcessingFilters(queryResults, cleanTitle, mediaType);
              debugPrint('[WIKIPEDIA] After filtering: ${filteredResults.length}/${queryResults.length} results remain from this query');
              
              // Add filtered results to the main collection
              allResults.addAll(filteredResults);
              
              // If we have enough results, we can stop early (but still respect maxResults)
              if (allResults.length >= maxResults) {
                debugPrint('[WIKIPEDIA] Collected enough results (${allResults.length}), stopping early');
                break;
              }
            }
          }
        }
      }
      
      // Score and sort results by relevance and popularity
      if (allResults.isNotEmpty) {
        debugPrint('[WIKIPEDIA] ===== SCORING AND RANKING RESULTS =====');
        final scoredResults = _scoreAndRankResults(allResults, cleanTitle, mediaType);
        
        // Trim to exact limit after scoring
        final finalResults = scoredResults.take(maxResults).toList();
        
        debugPrint('[WIKIPEDIA] ===== FINAL FILTERED RESULTS =====');
        debugPrint('[WIKIPEDIA] Total results collected: ${finalResults.length}');
        for (int i = 0; i < finalResults.length; i++) {
          final result = finalResults[i];
          debugPrint('[WIKIPEDIA] Rank ${i + 1}: "${result.title}" - ${result.description}');
        }
        debugPrint('[WIKIPEDIA] ===== END RESULTS =====');
        
        return finalResults;
      }
      
      debugPrint('[WIKIPEDIA] No precision search results found');
      return [];
      
    } catch (e) {
      debugPrint('Error in precision search: $e');
      return [];
    }
  }
  
  /// Build advanced search queries using MediaWiki search syntax
  List<String> _buildAdvancedSearchQueries(String title, MediaType mediaType) {
    final queries = <String>[];
    final cleanTitle = _cleanTitleForSearch(title);
    
    debugPrint('[WIKIPEDIA] ===== BUILDING SEARCH QUERIES =====');
    debugPrint('[WIKIPEDIA] Original title: "$title"');
    debugPrint('[WIKIPEDIA] Clean title: "$cleanTitle"');
    debugPrint('[WIKIPEDIA] Media type: $mediaType');
    debugPrint('[WIKIPEDIA] Title length: ${cleanTitle.length}');
    
    // For very short queries (2-3 characters), use highly restrictive TV-specific searches
    if (cleanTitle.length <= 3) {
      debugPrint('[WIKIPEDIA] Using SHORT QUERY strategy for length ${cleanTitle.length}');
      
      switch (mediaType) {
        case MediaType.tvShow:
          debugPrint('[WIKIPEDIA] Building TV SHOW queries for short term');
          
          // Strategy 1: Target popular/mainstream shows first with prefix matching
          queries.add('intitle:$cleanTitle* AND (popular OR famous OR award) AND incategory:"Television series"');
          queries.add('intitle:$cleanTitle* AND (Emmy OR Golden Globe OR critics) AND incategory:"Television series"');
          
          // Strategy 2: English-language mainstream shows (most relevant for users)
          queries.add('intitle:$cleanTitle* AND incategory:"American television series" AND (network OR cable OR streaming)');
          queries.add('intitle:$cleanTitle* AND incategory:"British television series" AND (BBC OR ITV OR Channel)');
          
          // Strategy 3: Major network shows (high production value)
          queries.add('intitle:$cleanTitle* AND (Netflix OR HBO OR ABC OR CBS OR NBC OR Fox) AND incategory:"Television series"');
          
          // Strategy 4: Recent/current shows (more relevant to users)
          queries.add('intitle:$cleanTitle* AND (2020s OR 2010s OR current) AND incategory:"Television series"');
          
          // Strategy 5: Very strict category-based search for TV SERIES specifically
          queries.add('intitle:$cleanTitle* AND incategory:"Television series"');
          queries.add('intitle:$cleanTitle* AND incategory:"American television series"');
          queries.add('intitle:$cleanTitle* AND incategory:"British television series"');
          queries.add('intitle:$cleanTitle* AND incategory:"Drama television series"');
          queries.add('intitle:$cleanTitle* AND incategory:"Comedy television series"');
          
          // Strategy 6: Use Wikipedia's TV series infoboxes (most specific)
          queries.add('intitle:$cleanTitle* AND hastemplate:"Infobox television"');
          queries.add('intitle:$cleanTitle* AND hastemplate:"Infobox TV series"');
          
          // Strategy 7: Specific series terminology, excluding episodes and actors
          queries.add('intitle:$cleanTitle* AND ("television series" OR "TV series") NOT episode NOT actor NOT actress NOT character NOT cast');
          
          // Strategy 8: Series-specific terms with exclusions
          queries.add('intitle:$cleanTitle* AND (series OR show) AND (aired OR broadcast OR premiered) NOT episode NOT "List of" NOT cast NOT character');
          break;
          
        case MediaType.movie:
          queries.add('intitle:$cleanTitle* AND incategory:"Films"');
          queries.add('intitle:$cleanTitle* AND hastemplate:"Infobox film"');
          queries.add('intitle:$cleanTitle* AND (film OR movie OR cinema) NOT (city OR country OR place)');
          break;
          
        case MediaType.album:
          queries.add('intitle:$cleanTitle* AND incategory:"Albums"');
          queries.add('intitle:$cleanTitle* AND hastemplate:"Infobox album"');
          queries.add('intitle:$cleanTitle* AND (album OR music OR band) NOT (city OR country OR place)');
          break;
          
        case MediaType.book:
          queries.add('intitle:$cleanTitle* AND incategory:"Books"');
          queries.add('intitle:$cleanTitle* AND hastemplate:"Infobox book"');
          queries.add('intitle:$cleanTitle* AND (book OR novel OR author) NOT (city OR country OR place)');
          break;
          
        case MediaType.game:
          queries.add('intitle:$cleanTitle* AND incategory:"Video games"');
          queries.add('intitle:$cleanTitle* AND hastemplate:"Infobox video game"');
          queries.add('intitle:$cleanTitle* AND (video game OR game) NOT (city OR country OR place)');
          break;
          
        default:
          queries.add('intitle:$cleanTitle*');
      }
      
      return queries;
    }
    
    // For longer queries, build progressive search strategies
    final mediaConstraints = _getMediaConstraints(mediaType);
    
    // 1. Exact title search with strong media type constraint (highest precision)
    if (mediaConstraints.isNotEmpty) {
      queries.add('intitle:"$cleanTitle" AND (${mediaConstraints.join(' OR ')})');
    }
    
    // 2. Exact title search with category constraint
    final categoryConstraint = _getCategoryConstraint(mediaType);
    if (categoryConstraint.isNotEmpty) {
      queries.add('intitle:"$cleanTitle" AND $categoryConstraint');
    }
    
    // 3. Title words with media type (for multi-word titles)
    if (cleanTitle.contains(' ') && mediaConstraints.isNotEmpty) {
      final words = cleanTitle.split(' ').where((w) => w.length > 2).toList();
      if (words.length >= 2) {
        final wordQuery = words.map((w) => 'intitle:"$w"').join(' AND ');
        queries.add('($wordQuery) AND (${mediaConstraints.join(' OR ')})');
      }
    }
    
    // 4. Only for longer, specific titles - allow broader search
    if (cleanTitle.length > 5 && !_isGenericTerm(cleanTitle)) {
      queries.add('intitle:"$cleanTitle"');
    }
    
    debugPrint('[WIKIPEDIA] ===== FINAL QUERY LIST (${queries.length} queries) =====');
    for (int i = 0; i < queries.length; i++) {
      debugPrint('[WIKIPEDIA] Query ${i + 1}: ${queries[i]}');
    }
    debugPrint('[WIKIPEDIA] ===== END QUERY LIST =====');
    
    return queries;
  }
  
  /// Get media constraints for normal searching
  List<String> _getMediaConstraints(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.tvShow:
        return ['television series', 'TV series', 'television show', 'TV show', 'aired', 'episodes', 'season'];
      case MediaType.movie:
        return ['film', 'movie', 'directed by', 'starring', 'cinema', 'released'];
      case MediaType.album:
        return ['album', 'music album', 'artist', 'band', 'released', 'discography'];
      case MediaType.book:
        return ['book', 'novel', 'author', 'published', 'literature'];
      case MediaType.game:
        return ['video game', 'game', 'developer', 'gaming', 'console'];
      default:
        return [];
    }
  }
  
  /// Get category constraint for media type
  String _getCategoryConstraint(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.tvShow:
        return 'incategory:"Television series" OR incategory:"TV series"';
      case MediaType.movie:
        return 'incategory:"Films" OR incategory:"Movies"';
      case MediaType.album:
        return 'incategory:"Albums" OR incategory:"Music albums"';
      case MediaType.book:
        return 'incategory:"Books" OR incategory:"Novels"';
      case MediaType.game:
        return 'incategory:"Video games"';
      default:
        return '';
    }
  }
  
  /// Check if a term is too generic and should be avoided in broad searches
  bool _isGenericTerm(String term) {
    final genericTerms = [
      // Only truly meaningless single characters and stop words
      'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by',
      'is', 'are', 'was', 'were', 'be', 'been', 'have', 'has', 'had', 'do', 'does', 'did',
      // Generic media type words (when used alone)
      'tv', 'show', 'movie', 'film', 'book', 'game', 'music', 'album', 'series',
    ];
    
    // Allow 2+ character combinations like 'br', 'dr', etc. as they could be valid prefixes
    return genericTerms.contains(term.toLowerCase()) || 
           term.length < 2;  // Only reject single characters
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
      
      // Prevent searches for very short or generic terms
      final cleanTitle = _cleanTitleForSearch(title);
      if (cleanTitle.isEmpty) {
        debugPrint('[WIKIPEDIA] Query too short, skipping search: "$cleanTitle"');
        return null;
      }
      
      // For very short queries, only allow if they could be meaningful prefixes
      if (cleanTitle.length < 3 && _isGenericTerm(cleanTitle)) {
        debugPrint('[WIKIPEDIA] Query too generic, skipping search: "$cleanTitle"');
        return null;
      }
      
      debugPrint('[WIKIPEDIA] Searching for $mediaType: "$title"');
      
      // Strategy 0: Try precision search first (highest accuracy)
      debugPrint('[WIKIPEDIA] Trying precision search first');
      final precisionResults = await precisionSearch(title, mediaType);
      
      if (precisionResults.isNotEmpty) {
        final scoredResults = _scoreAndFilterResults(precisionResults, title, mediaType);
        
        for (final result in scoredResults) {
          debugPrint('[WIKIPEDIA] Trying precision result: "${result.title}"');
          final content = await getContent(result.pageId);
          
          if (content != null && _contentMatchesMediaType(content.extract, mediaType)) {
            debugPrint('[WIKIPEDIA] Found precise match: ${result.title}');
            final mediaInfo = _extractMediaInfo(content, mediaType);
            
            return mediaInfo;
          }
        }
      }
      
      // Fall back to existing multi-strategy approach
      debugPrint('[WIKIPEDIA] Precision search unsuccessful, trying fallback strategies');
      
      // Try multiple search strategies with progressively broader queries
      final searchStrategies = _buildSearchStrategies(title, mediaType);
      
      for (int i = 0; i < searchStrategies.length; i++) {
        final strategy = searchStrategies[i];
        debugPrint('[WIKIPEDIA] Trying search strategy ${i + 1}/${searchStrategies.length}: "${strategy.query}"');
        
        final searchResults = await search(strategy.query, limit: strategy.limit);
        
        if (searchResults.isNotEmpty) {
          // Score and rank results
          final scoredResults = _scoreAndFilterResults(searchResults, title, mediaType);
          
          // Try the best results in order
          for (final result in scoredResults) {
            debugPrint('[WIKIPEDIA] Trying result: "${result.title}"');
            final content = await getContent(result.pageId);
            
            if (content != null) {
              // Check if content matches media type
              if (_contentMatchesMediaType(content.extract, mediaType)) {
                debugPrint('[WIKIPEDIA] Found matching content for: ${result.title}');
                final mediaInfo = _extractMediaInfo(content, mediaType);
                
                return mediaInfo;
              } else {
                debugPrint('[WIKIPEDIA] Content does not match media type for: ${result.title}');
              }
            }
          }
        }
        
        debugPrint('[WIKIPEDIA] Strategy ${i + 1} yielded no valid results');
      }
      
      debugPrint('[WIKIPEDIA] No suitable Wikipedia match found for: $title ($mediaType)');
      
      return null;
    } catch (e) {
      debugPrint('[WIKIPEDIA] Error finding media info: $e');
      return null;
    }
  }
  
  /// Build search strategies with different query approaches
  List<SearchStrategy> _buildSearchStrategies(String title, MediaType mediaType) {
    final strategies = <SearchStrategy>[];
    
    // Strategy 1: Exact title (highest precision)
    strategies.add(SearchStrategy(
      query: title,
      limit: 3,
      minimumScore: 0.8,
      description: 'Exact title'
    ));
    
    // Strategy 2: Title with media type hint (balanced)
    final mediaHint = _getMediaTypeSearchHint(mediaType);
    if (mediaHint.isNotEmpty) {
      strategies.add(SearchStrategy(
        query: '$title $mediaHint',
        limit: 5,
        minimumScore: 0.6,
        description: 'Title with media hint'
      ));
    }
    
    // Strategy 3: Clean title (remove common words and punctuation)
    final cleanTitle = _cleanTitleForSearch(title);
    if (cleanTitle != title) {
      strategies.add(SearchStrategy(
        query: cleanTitle,
        limit: 5,
        minimumScore: 0.5,
        description: 'Cleaned title'
      ));
    }
    
    // Strategy 4: Broad search (lowest precision, highest recall)
    if (cleanTitle.contains(' ')) {
      final mainWords = cleanTitle.split(' ').where((w) => w.length > 3).take(2).join(' ');
      if (mainWords.isNotEmpty && mainWords != cleanTitle) {
        strategies.add(SearchStrategy(
          query: mainWords,
          limit: 8,
          minimumScore: 0.3,
          description: 'Main keywords only'
        ));
      }
    }
    
    return strategies;
  }
  
  /// Get a subtle search hint for media types
  String _getMediaTypeSearchHint(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.album:
        return 'album'; // Just "album", not "music album"
      case MediaType.movie:
        return 'film'; // "film" is more precise than "movie"  
      case MediaType.book:
        return ''; // Books often don't need hints
      case MediaType.tvShow:
        return 'series'; // "series" is more precise than "tv show"
      case MediaType.game:
        return 'video game';
      default:
        return '';
    }
  }
  
  /// Clean title for better search results
  String _cleanTitleForSearch(String title) {
    String cleaned = title;
    
    // Remove content in parentheses (often release years, versions, etc.)
    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    
    // Remove content in brackets
    cleaned = cleaned.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();
    
    // Remove common suffixes that might hurt search
    final suffixesToRemove = [
      RegExp(r'\s+(deluxe|remastered|expanded|special|limited|edition|version)$', caseSensitive: false),
      RegExp(r'\s+(soundtrack|ost)$', caseSensitive: false),
    ];
    
    for (final suffix in suffixesToRemove) {
      cleaned = cleaned.replaceAll(suffix, '').trim();
    }
    
    // Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned;
  }
  
  /// Score and filter search results based on relevance to the media type
  List<WikipediaSearchResult> _scoreAndFilterResults(
    List<WikipediaSearchResult> results, 
    String originalTitle, 
    MediaType mediaType
  ) {
    if (results.isEmpty) return results;
    
    final cleanTitle = _cleanTitleForSearch(originalTitle);
    final isShortQuery = cleanTitle.length <= 3;
    
    // For short queries, be much more aggressive about filtering
    if (isShortQuery && mediaType == MediaType.tvShow) {
      results = results.where((result) {
        final title = result.title.toLowerCase();
        final snippet = result.description.toLowerCase();
        
        // Remove obvious non-TV content
        if (_isGeographicalLocation(title, snippet)) return false;
        if (_isNonTVContent(title, snippet)) return false;
        
        // For very short queries, require strong TV indicators
        // This is more restrictive than before
        if (cleanTitle.length <= 2) {
          return _hasStrongTVIndicators(title, snippet);
        }
        
        // For 3-character queries, be slightly less restrictive
        return !_isPersonName(result.title) && 
               !_isObviousNonTV(title, snippet);
      }).toList();
    }
    
    // Score results based on multiple factors
    final scoredResults = results.map((result) {
      double score = 0.0;
      final title = result.title.toLowerCase();
      final snippet = result.description.toLowerCase();
      
      // Title similarity scoring
      if (title.startsWith(cleanTitle.toLowerCase())) {
        score += 50.0; // Strong boost for prefix match
      } else if (title.contains(cleanTitle.toLowerCase())) {
        score += 20.0;
      }
      
      // Exact match bonus
      if (title == cleanTitle.toLowerCase()) {
        score += 100.0;
      }
      
      // Media type relevance scoring
      score += _getMediaTypeScore(title, snippet, mediaType);
      
      // Penalize disambiguation pages and lists
      if (title.contains('disambiguation') || title.contains('list of')) {
        score -= 30.0;
      }
      
      // For short queries, heavily penalize geographical content
      if (isShortQuery) {
        if (_isGeographicalLocation(title, snippet)) {
          score -= 100.0;
        }
        if (_hasStrongTVIndicators(title, snippet)) {
          score += 30.0;
        }
      }
      
      return MapEntry(result, score);
    }).toList();
    
    // Sort by score and return top results
    scoredResults.sort((a, b) => b.value.compareTo(a.value));
    
    // Filter out very low scoring results
    final threshold = isShortQuery ? 10.0 : 0.0;
    return scoredResults
        .where((entry) => entry.value >= threshold)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Check if a result appears to be a geographical location
  bool _isGeographicalLocation(String title, String snippet) {
    final geoIndicators = [
      'city', 'town', 'state', 'country', 'province', 'county', 'district',
      'municipality', 'village', 'borough', 'capital', 'located in',
      'population', 'area', 'km²', 'square miles', 'geography', 'census',
      'coordinates', 'latitude', 'longitude', 'elevation'
    ];
    
    final text = '$title $snippet'.toLowerCase();
    return geoIndicators.any((indicator) => text.contains(indicator));
  }
  
  /// Check if content is clearly not TV-related
  bool _isNonTVContent(String title, String snippet) {
    final nonTVIndicators = [
      'singer', 'musician', 'artist', 'band', 'album', 'song',
      'athlete', 'sports', 'player', 'team', 'game',
      'politician', 'president', 'minister', 'senator',
      'company', 'corporation', 'business', 'brand',
      'book', 'novel', 'author', 'writer',
      // Add person indicators
      'born', 'died', 'actor', 'actress', 'director', 'producer',
      'screenwriter', 'composer', 'filmmaker', 'person',
      // Add location indicators
      'village', 'town', 'city', 'municipality', 'commune',
      'slovakia', 'czech', 'serbia', 'croatia', 'poland'
    ];
    
    final text = '$title $snippet'.toLowerCase();
    
    // Check for person name patterns (First Last name format)
    if (_isPersonName(title)) {
      return true;
    }
    
    // Check for episode or character pages
    if (_isEpisodeOrCharacterPage(title, snippet)) {
      return true;
    }
    
    return nonTVIndicators.any((indicator) => text.contains(indicator));
  }
  
  /// Check if content has strong TV show indicators
  bool _hasStrongTVIndicators(String title, String snippet) {
    final seriesIndicators = [
      'television series', 'tv series', 'drama series', 'comedy series',
      'sitcom', 'miniseries', 'web series', 'streaming series',
      'created by', 'developed by', 'showrunner', 'executive producer',
      'premiered on', 'aired on', 'broadcast on', 'original run',
      'seasons', 'series finale', 'pilot episode'
    ];
    
    final episodeIndicators = [
      'episode', 'episodes list', 'season', 'character', 'cast member',
      'actor', 'actress', 'played by', 'portrayed by', 'role of'
    ];
    
    final text = '$title $snippet'.toLowerCase();
    
    // Exclude if it's clearly about episodes, characters, or actors
    if (episodeIndicators.any((indicator) => text.contains(indicator))) {
      // Only allow if it also has very strong series indicators
      return seriesIndicators.any((indicator) => text.contains(indicator)) &&
             !title.toLowerCase().contains('episode') &&
             !title.toLowerCase().contains('character') &&
             !title.toLowerCase().contains('cast');
    }
    
    // Otherwise, check for series indicators
    return seriesIndicators.any((indicator) => text.contains(indicator));
  }

  /// Check if a title appears to be a person's name
  bool _isPersonName(String title) {
    // Check for typical person name patterns
    final words = title.trim().split(' ');
    
    // Two words with capital letters (First Last)
    if (words.length == 2) {
      final firstName = words[0];
      final lastName = words[1];
      
      // Both words start with capital and contain mostly letters
      if (firstName.isNotEmpty && lastName.isNotEmpty &&
          firstName[0].toUpperCase() == firstName[0] &&
          lastName[0].toUpperCase() == lastName[0] &&
          RegExp(r'^[A-Za-zÀ-ÿĀ-žА-я]+$').hasMatch(firstName) &&
          RegExp(r'^[A-Za-zÀ-ÿĀ-žА-я]+$').hasMatch(lastName)) {
        return true;
      }
    }
    
    // Three words might be "First Middle Last"
    if (words.length == 3) {
      return words.every((word) => 
        word.isNotEmpty && 
        word[0].toUpperCase() == word[0] &&
        RegExp(r'^[A-Za-zÀ-ÿĀ-žА-я]+$').hasMatch(word)
      );
    }
    
    return false;
  }
  
  /// Check if content is obviously not TV-related (less strict than _isNonTVContent)
  bool _isObviousNonTV(String title, String snippet) {
    final obviousNonTV = [
      'village', 'town', 'city', 'municipality', 'commune',
      'born', 'died', 'politician', 'singer', 'musician',
      'athlete', 'company', 'corporation'
    ];
    
    final text = '$title $snippet'.toLowerCase();
    return obviousNonTV.any((indicator) => text.contains(indicator));
  }
  
  /// Check if this is an episode or character page rather than a series page
  bool _isEpisodeOrCharacterPage(String title, String snippet) {
    final titleLower = title.toLowerCase();
    final snippetLower = snippet.toLowerCase();
    
    // Episode page indicators
    final episodePatterns = [
      RegExp(r'episode \d+'),
      RegExp(r'season \d+ episode'),
      RegExp(r'"[^"]*" episode'),
      RegExp(r'list of.*episodes'),
    ];
    
    for (final pattern in episodePatterns) {
      if (pattern.hasMatch(titleLower) || pattern.hasMatch(snippetLower)) {
        return true;
      }
    }
    
    // Character page indicators
    final characterIndicators = [
      'character', 'fictional character', 'main character',
      'recurring character', 'cast member', 'portrayed by',
      'played by', 'role of', 'character list',
      'cast and characters', 'list of characters'
    ];
    
    if (characterIndicators.any((indicator) => 
        titleLower.contains(indicator) || snippetLower.contains(indicator))) {
      return true;
    }
    
    // Actor/people pages in TV context
    if (_isPersonName(title) && (snippetLower.contains('actor') || 
        snippetLower.contains('actress') || snippetLower.contains('starred'))) {
      return true;
    }
    
    return false;
  }
  
  /// Check if content matches the expected media type
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
  
  /// Get media type specific score for a result
  double _getMediaTypeScore(String title, String snippet, MediaType mediaType) {
    double score = 0.0;
    final text = '$title $snippet'.toLowerCase();
    
    switch (mediaType) {
      case MediaType.tvShow:
        final tvTerms = ['television', 'tv series', 'show', 'episodes', 'seasons', 'aired', 'network'];
        for (final term in tvTerms) {
          if (text.contains(term)) score += 5.0;
        }
        break;
      case MediaType.movie:
        final movieTerms = ['film', 'movie', 'cinema', 'director', 'starring', 'released'];
        for (final term in movieTerms) {
          if (text.contains(term)) score += 5.0;
        }
        break;
      case MediaType.album:
        final albumTerms = ['album', 'music', 'band', 'artist', 'songs', 'tracks'];
        for (final term in albumTerms) {
          if (text.contains(term)) score += 5.0;
        }
        break;
      case MediaType.book:
        final bookTerms = ['book', 'novel', 'author', 'published', 'pages', 'chapter'];
        for (final term in bookTerms) {
          if (text.contains(term)) score += 5.0;
        }
        break;
      case MediaType.game:
        final gameTerms = ['game', 'video game', 'gameplay', 'developer', 'console', 'player'];
        for (final term in gameTerms) {
          if (text.contains(term)) score += 5.0;
        }
        break;
      default:
        break;
    }
    
    return score;
  }
  
  /// Extracts media information from Wikipedia content
  MediaInfo _extractMediaInfo(WikipediaContent content, MediaType mediaType) {
    // Extract creator information (author, director, developer, etc.)
    String? creator = _extractCreator(content.extract, mediaType);
    
    // Extract release date
    String? releaseDate = _extractReleaseDate(content.extract, mediaType);
    
    // Extract genre
    String? genre = _extractGenre(content.extract, mediaType);
    
    // Limit description length for UI display
    String limitedDescription = _limitDescription(content.extract);
    
    return MediaInfo(
      title: content.title,
      description: limitedDescription,
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
  
  /// Apply post-processing filters to remove irrelevant results
  List<WikipediaSearchResult> _applyPostProcessingFilters(
    List<WikipediaSearchResult> results, 
    String query, 
    MediaType mediaType
  ) {
    debugPrint('[WIKIPEDIA] ===== APPLYING POST-PROCESSING FILTERS =====');
    debugPrint('[WIKIPEDIA] Input: ${results.length} results for query "$query" (${mediaType})');
    
    final filtered = <WikipediaSearchResult>[];
    
    for (final result in results) {
      bool shouldKeep = true;
      final reasons = <String>[];
      
      // For TV shows, apply aggressive filtering for short queries
      if (mediaType == MediaType.tvShow && query.length <= 3) {
        // Check if it's a person name
        if (_isPersonName(result.title)) {
          shouldKeep = false;
          reasons.add('person name detected');
        }
        
        // Check if it's a geographical location
        if (_isGeographicalLocation(result.title, result.description)) {
          shouldKeep = false;
          reasons.add('geographical location');
        }
        
        // Check if it's an episode or character page
        if (_isEpisodeOrCharacterPage(result.title, result.description)) {
          shouldKeep = false;
          reasons.add('episode/character page');
        }
        
        // For very short queries, require strong TV indicators
        if (shouldKeep && !_hasStrongTVIndicators(result.title, result.description)) {
          shouldKeep = false;
          reasons.add('no strong TV indicators');
        }
      }
      
      if (shouldKeep) {
        filtered.add(result);
        debugPrint('[WIKIPEDIA] ✓ KEEPING: "${result.title}"');
      } else {
        debugPrint('[WIKIPEDIA] ✗ FILTERING OUT: "${result.title}" - ${reasons.join(', ')}');
      }
    }
    
    debugPrint('[WIKIPEDIA] ===== FILTERING COMPLETE: ${filtered.length}/${results.length} results kept =====');
    return filtered;
  }
  
  /// Score and rank results by relevance, popularity, and mainstream appeal
  List<WikipediaSearchResult> _scoreAndRankResults(
    List<WikipediaSearchResult> results, 
    String query, 
    MediaType mediaType
  ) {
    // Create scored results
    final scoredResults = results.map((result) {
      final score = _calculateRelevanceScore(result, query, mediaType);
      return _ScoredResult(result, score);
    }).toList();
    
    // Sort by score (highest first)
    scoredResults.sort((a, b) => b.score.compareTo(a.score));
    
    // Log scoring for debugging
    debugPrint('[WIKIPEDIA] ===== RESULT SCORING =====');
    for (int i = 0; i < scoredResults.length && i < 10; i++) {
      final scored = scoredResults[i];
      debugPrint('[WIKIPEDIA] Score ${scored.score.toStringAsFixed(2)}: "${scored.result.title}"');
    }
    debugPrint('[WIKIPEDIA] ===== END SCORING =====');
    
    // Return sorted results
    return scoredResults.map((scored) => scored.result).toList();
  }
  
  /// Calculate relevance score for a search result
  double _calculateRelevanceScore(WikipediaSearchResult result, String query, MediaType mediaType) {
    double score = 0.0;
    final title = result.title.toLowerCase();
    final description = result.description.toLowerCase();
    final queryLower = query.toLowerCase();
    
    // 1. Title relevance (most important factor)
    if (title.startsWith(queryLower)) {
      score += 100.0; // Perfect prefix match
    } else if (title.contains(queryLower)) {
      score += 50.0; // Contains query
    }
    
    // 2. Title length penalty (shorter titles often more popular)
    if (title.length <= 15) {
      score += 20.0; // Short, memorable titles
    } else if (title.length > 30) {
      score -= 10.0; // Very long titles tend to be obscure
    }
    
    // 3. Language and origin preference (English-speaking markets)
    if (_isMainstreamEnglishContent(title, description)) {
      score += 30.0;
    }
    
    // 4. Popularity indicators
    score += _getPopularityScore(title, description);
    
    // 5. Recency bonus (newer shows often more relevant)
    score += _getRecencyScore(description);
    
    // 6. Production quality indicators
    score += _getProductionQualityScore(description);
    
    // 7. Penalty for non-English characters (less mainstream)
    if (_hasNonEnglishCharacters(title)) {
      score -= 15.0;
    }
    
    return score;
  }
  
  /// Check if content is mainstream English-language content
  bool _isMainstreamEnglishContent(String title, String description) {
    final indicators = [
      'american', 'british', 'canadian', 'australian',
      'english', 'network', 'cable', 'streaming',
      'nbc', 'abc', 'cbs', 'fox', 'hbo', 'netflix',
      'bbc', 'itv', 'channel 4'
    ];
    
    for (final indicator in indicators) {
      if (title.contains(indicator) || description.contains(indicator)) {
        return true;
      }
    }
    return false;
  }
  
  /// Calculate popularity score based on content indicators
  double _getPopularityScore(String title, String description) {
    double score = 0.0;
    
    // Award indicators
    final awards = ['emmy', 'golden globe', 'critics choice', 'award', 'nominated'];
    for (final award in awards) {
      if (title.contains(award) || description.contains(award)) {
        score += 15.0;
      }
    }
    
    // Popularity indicators
    final popularity = ['popular', 'hit', 'successful', 'acclaimed', 'critically', 'rated'];
    for (final pop in popularity) {
      if (title.contains(pop) || description.contains(pop)) {
        score += 10.0;
      }
    }
    
    // Major network/platform indicators
    final platforms = ['netflix', 'hbo', 'amazon', 'disney', 'apple tv', 'hulu', 'bbc', 'nbc', 'abc', 'cbs', 'fox'];
    for (final platform in platforms) {
      if (title.contains(platform) || description.contains(platform)) {
        score += 12.0;
      }
    }
    
    return score;
  }
  
  /// Calculate recency score (newer shows get bonus)
  double _getRecencyScore(String description) {
    // Look for year indicators
    if (description.contains('2020') || description.contains('2021') || 
        description.contains('2022') || description.contains('2023') || 
        description.contains('2024')) {
      return 8.0;
    } else if (description.contains('2010') || description.contains('201')) {
      return 5.0; // 2010s shows
    }
    return 0.0;
  }
  
  /// Calculate production quality score
  double _getProductionQualityScore(String description) {
    double score = 0.0;
    
    final qualityIndicators = [
      'series', 'drama', 'comedy', 'thriller', 'documentary',
      'created by', 'directed by', 'starring', 'produced by'
    ];
    
    for (final indicator in qualityIndicators) {
      if (description.contains(indicator)) {
        score += 2.0;
      }
    }
    
    return score;
  }
  
  /// Check for non-English characters (indicates non-mainstream content)
  bool _hasNonEnglishCharacters(String text) {
    // Simple check for common non-English characters
    final nonEnglishPattern = RegExp(r'[áàâäčćěéêëíîïóôöúûüýÿñłšžđć]', caseSensitive: false);
    return nonEnglishPattern.hasMatch(text);
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

/// Represents a search strategy with specific parameters
class SearchStrategy {
  final String query;
  final int limit;
  final double minimumScore;
  final String description;
  
  SearchStrategy({
    required this.query,
    required this.limit,
    required this.minimumScore,
    required this.description,
  });
}

/// Represents a scored search result
class _ScoredResult {
  final WikipediaSearchResult result;
  final double score;
  
  _ScoredResult(this.result, this.score);
}

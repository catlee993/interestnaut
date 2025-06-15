import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WikidataSearchResult {
  final String id;
  final String title;
  final String? artist;
  final String? description;
  final String? imageUrl;
  final String? releaseDate;
  final String? genre;
  final Map<String, dynamic> additionalData;

  WikidataSearchResult({
    required this.id,
    required this.title,
    this.artist,
    this.description,
    this.imageUrl,
    this.releaseDate,
    this.genre,
    this.additionalData = const {},
  });

  factory WikidataSearchResult.fromJson(Map<String, dynamic> json) {
    return WikidataSearchResult(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString(),
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      releaseDate: json['releaseDate']?.toString(),
      genre: json['genre']?.toString(),
      additionalData: json,
    );
  }
}

class WikidataService {
  static const String _endpoint = 'https://query.wikidata.org/sparql';
  static const int _defaultLimit = 20;
  static const Duration _timeout = Duration(seconds: 10);

  /// Search for books using Wikidata SPARQL
  Future<List<WikidataSearchResult>> searchBooks(String query, {int limit = 20}) async {
    // For now, just search by title to avoid timeouts
    // We can add author search back later with better logic
    return await _searchBooksByTitle(query, limit: limit);
  }

  Future<List<WikidataSearchResult>> _searchBooksByTitle(String query, {int limit = 20}) async {
    final sparqlQuery = '''
      SELECT DISTINCT ?item ?itemLabel ?authorLabel ?publisherLabel ?genreLabel ?publicationDate ?description ?image WHERE {
        {
          ?item wdt:P31/wdt:P279* wd:Q571 .  # instance of book
        } UNION {
          ?item wdt:P31/wdt:P279* wd:Q7725634 .  # literary work
        } UNION {
          ?item wdt:P31/wdt:P279* wd:Q47461344 .  # written work
        }
        ?item rdfs:label ?itemLabel .
        FILTER(LANG(?itemLabel) = "en")
        FILTER(CONTAINS(LCASE(?itemLabel), LCASE("$query")))
        
        OPTIONAL { ?item wdt:P50 ?author . ?author rdfs:label ?authorLabel . FILTER(LANG(?authorLabel) = "en") }
        OPTIONAL { ?item wdt:P123 ?publisher . ?publisher rdfs:label ?publisherLabel . FILTER(LANG(?publisherLabel) = "en") }
        OPTIONAL { ?item wdt:P136 ?genre . ?genre rdfs:label ?genreLabel . FILTER(LANG(?genreLabel) = "en") }
        OPTIONAL { ?item wdt:P577 ?publicationDate }
        OPTIONAL { ?item schema:description ?description . FILTER(LANG(?description) = "en") }
        OPTIONAL { ?item wdt:P18 ?image }
      }
      ORDER BY ?itemLabel
      LIMIT $limit
    ''';

    return _executeSparqlQuery(sparqlQuery, 'book');
  }

  /// Search for music (songs/albums) using Wikidata SPARQL
  Future<List<WikidataSearchResult>> searchMusic(String query, {int limit = 20}) async {
    // Simplified to avoid timeouts - just search by title for now
    return await _searchMusicByTitle(query, limit: limit);
  }

  Future<List<WikidataSearchResult>> _searchMusicByTitle(String query, {int limit = 20}) async {
    final sparqlQuery = '''
      SELECT DISTINCT ?item ?itemLabel ?performerLabel ?recordLabelLabel ?genreLabel ?publicationDate ?description ?image WHERE {
        {
          ?item wdt:P31/wdt:P279* wd:Q7366 .  # song
        } UNION {
          ?item wdt:P31/wdt:P279* wd:Q482994 .  # album
        }
        ?item rdfs:label ?itemLabel .
        FILTER(LANG(?itemLabel) = "en")
        FILTER(CONTAINS(LCASE(?itemLabel), LCASE("$query")))
        
        OPTIONAL { ?item wdt:P175 ?performer . ?performer rdfs:label ?performerLabel . FILTER(LANG(?performerLabel) = "en") }
        OPTIONAL { ?item wdt:P264 ?recordLabel . ?recordLabel rdfs:label ?recordLabelLabel . FILTER(LANG(?recordLabelLabel) = "en") }
        OPTIONAL { ?item wdt:P136 ?genre . ?genre rdfs:label ?genreLabel . FILTER(LANG(?genreLabel) = "en") }
        OPTIONAL { ?item wdt:P577 ?publicationDate }
        OPTIONAL { ?item schema:description ?description . FILTER(LANG(?description) = "en") }
        OPTIONAL { ?item wdt:P18 ?image }
      }
      ORDER BY ?itemLabel
      LIMIT $limit
    ''';

    return _executeSparqlQuery(sparqlQuery, 'music');
  }

  /// Search for movies using Wikidata SPARQL
  Future<List<WikidataSearchResult>> searchMovies(String query, {int limit = 20}) async {
    // Simplified to avoid timeouts - just search by title for now
    return await _searchMoviesByTitle(query, limit: limit);
  }

  Future<List<WikidataSearchResult>> _searchMoviesByTitle(String query, {int limit = 20}) async {
    final sparqlQuery = '''
      SELECT DISTINCT ?item ?itemLabel ?directorLabel ?producerLabel ?distributorLabel ?genreLabel ?publicationDate ?description ?image WHERE {
        ?item wdt:P31/wdt:P279* wd:Q11424 .  # film
        ?item rdfs:label ?itemLabel .
        FILTER(LANG(?itemLabel) = "en")
        FILTER(CONTAINS(LCASE(?itemLabel), LCASE("$query")))
        
        OPTIONAL { ?item wdt:P57 ?director . ?director rdfs:label ?directorLabel . FILTER(LANG(?directorLabel) = "en") }
        OPTIONAL { ?item wdt:P162 ?producer . ?producer rdfs:label ?producerLabel . FILTER(LANG(?producerLabel) = "en") }
        OPTIONAL { ?item wdt:P750 ?distributor . ?distributor rdfs:label ?distributorLabel . FILTER(LANG(?distributorLabel) = "en") }
        OPTIONAL { ?item wdt:P136 ?genre . ?genre rdfs:label ?genreLabel . FILTER(LANG(?genreLabel) = "en") }
        OPTIONAL { ?item wdt:P577 ?publicationDate }
        OPTIONAL { ?item schema:description ?description . FILTER(LANG(?description) = "en") }
        OPTIONAL { ?item wdt:P18 ?image }
      }
      ORDER BY ?itemLabel
      LIMIT $limit
    ''';

    return _executeSparqlQuery(sparqlQuery, 'movie');
  }

  /// Search for TV shows using Wikidata SPARQL
  Future<List<WikidataSearchResult>> searchTVShows(String query, {int limit = 20}) async {
    // Simplified to avoid timeouts - just search by title for now
    return await _searchTVShowsByTitle(query, limit: limit);
  }

  Future<List<WikidataSearchResult>> _searchTVShowsByTitle(String query, {int limit = 20}) async {
    final sparqlQuery = '''
      SELECT DISTINCT ?item ?itemLabel ?creatorLabel ?producerLabel ?networkLabel ?genreLabel ?publicationDate ?description ?image WHERE {
        {
          ?item wdt:P31/wdt:P279* wd:Q5398426 .  # television series
        } UNION {
          ?item wdt:P31/wdt:P279* wd:Q15416 .  # television program
        }
        ?item rdfs:label ?itemLabel .
        FILTER(LANG(?itemLabel) = "en")
        FILTER(CONTAINS(LCASE(?itemLabel), LCASE("$query")))
        
        OPTIONAL { ?item wdt:P170 ?creator . ?creator rdfs:label ?creatorLabel . FILTER(LANG(?creatorLabel) = "en") }
        OPTIONAL { ?item wdt:P162 ?producer . ?producer rdfs:label ?producerLabel . FILTER(LANG(?producerLabel) = "en") }
        OPTIONAL { ?item wdt:P449 ?network . ?network rdfs:label ?networkLabel . FILTER(LANG(?networkLabel) = "en") }
        OPTIONAL { ?item wdt:P136 ?genre . ?genre rdfs:label ?genreLabel . FILTER(LANG(?genreLabel) = "en") }
        OPTIONAL { ?item wdt:P580 ?publicationDate }
        OPTIONAL { ?item schema:description ?description . FILTER(LANG(?description) = "en") }
        OPTIONAL { ?item wdt:P18 ?image }
      }
      ORDER BY ?itemLabel
      LIMIT $limit
    ''';

    return _executeSparqlQuery(sparqlQuery, 'tv');
  }

  /// Search for games using Wikidata SPARQL
  Future<List<WikidataSearchResult>> searchGames(String query, {int limit = 20}) async {
    // Simplified to avoid timeouts - just search by title for now
    return await _searchGamesByTitle(query, limit: limit);
  }

  Future<List<WikidataSearchResult>> _searchGamesByTitle(String query, {int limit = 20}) async {
    final sparqlQuery = '''
      SELECT DISTINCT ?item ?itemLabel ?developerLabel ?publisherLabel ?platformLabel ?genreLabel ?publicationDate ?description ?image WHERE {
        ?item wdt:P31/wdt:P279* wd:Q7889 .  # video game
        ?item rdfs:label ?itemLabel .
        FILTER(LANG(?itemLabel) = "en")
        FILTER(CONTAINS(LCASE(?itemLabel), LCASE("$query")))
        
        OPTIONAL { ?item wdt:P178 ?developer . ?developer rdfs:label ?developerLabel . FILTER(LANG(?developerLabel) = "en") }
        OPTIONAL { ?item wdt:P123 ?publisher . ?publisher rdfs:label ?publisherLabel . FILTER(LANG(?publisherLabel) = "en") }
        OPTIONAL { ?item wdt:P400 ?platform . ?platform rdfs:label ?platformLabel . FILTER(LANG(?platformLabel) = "en") }
        OPTIONAL { ?item wdt:P136 ?genre . ?genre rdfs:label ?genreLabel . FILTER(LANG(?genreLabel) = "en") }
        OPTIONAL { ?item wdt:P577 ?publicationDate }
        OPTIONAL { ?item schema:description ?description . FILTER(LANG(?description) = "en") }
        OPTIONAL { ?item wdt:P18 ?image }
      }
      ORDER BY ?itemLabel
      LIMIT $limit
    ''';

    return _executeSparqlQuery(sparqlQuery, 'game');
  }

  /// Execute a SPARQL query against Wikidata
  Future<List<WikidataSearchResult>> _executeSparqlQuery(String query, String mediaType) async {
    try {
      debugPrint('[WIKIDATA] Executing $mediaType search query');
      
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'query': query,
        'format': 'json',
      });

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/sparql-results+json',
          'User-Agent': 'InterestNaut/1.0 (https://github.com/interestnaut/interestnaut)',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bindings = data['results']['bindings'] as List<dynamic>;
        
        debugPrint('[WIKIDATA] Found ${bindings.length} results for $mediaType');
        
        return bindings.map((binding) => _parseBinding(binding, mediaType)).toList();
      } else {
        debugPrint('[WIKIDATA] Error response: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('[WIKIDATA] Error executing query: $e');
      return [];
    }
  }

  /// Parse a SPARQL binding result into a WikidataSearchResult
  WikidataSearchResult _parseBinding(Map<String, dynamic> binding, String mediaType) {
    String getValue(String key) {
      return binding[key]?['value']?.toString() ?? '';
    }

    final id = getValue('item').split('/').last;
    final title = getValue('itemLabel');
    
    String? artist;
    String? additionalInfo;
    
    switch (mediaType) {
      case 'book':
        artist = getValue('authorLabel');
        final publisher = getValue('publisherLabel');
        if (publisher.isNotEmpty) {
          additionalInfo = 'Published by $publisher';
        }
        break;
      case 'music':
        artist = getValue('performerLabel');
        final recordLabel = getValue('recordLabelLabel');
        if (recordLabel.isNotEmpty) {
          additionalInfo = 'Label: $recordLabel';
        }
        break;
      case 'movie':
        artist = getValue('directorLabel');
        final producer = getValue('producerLabel');
        final distributor = getValue('distributorLabel');
        if (producer.isNotEmpty && distributor.isNotEmpty) {
          additionalInfo = 'Produced by $producer, Distributed by $distributor';
        } else if (producer.isNotEmpty) {
          additionalInfo = 'Produced by $producer';
        } else if (distributor.isNotEmpty) {
          additionalInfo = 'Distributed by $distributor';
        }
        break;
      case 'tv':
        artist = getValue('creatorLabel');
        final producer = getValue('producerLabel');
        final network = getValue('networkLabel');
        if (network.isNotEmpty && producer.isNotEmpty) {
          additionalInfo = 'Network: $network, Produced by $producer';
        } else if (network.isNotEmpty) {
          additionalInfo = 'Network: $network';
        } else if (producer.isNotEmpty) {
          additionalInfo = 'Produced by $producer';
        }
        break;
      case 'game':
        artist = getValue('developerLabel');
        final publisher = getValue('publisherLabel');
        final platform = getValue('platformLabel');
        if (publisher.isNotEmpty && platform.isNotEmpty) {
          additionalInfo = 'Published by $publisher, Platform: $platform';
        } else if (publisher.isNotEmpty) {
          additionalInfo = 'Published by $publisher';
        } else if (platform.isNotEmpty) {
          additionalInfo = 'Platform: $platform';
        }
        break;
    }

    final description = getValue('description');
    final imageUrl = getValue('image');
    final releaseDate = getValue('publicationDate');
    final genre = getValue('genreLabel');

    // Combine description with additional info
    String? finalDescription = description.isNotEmpty ? description : null;
    if (additionalInfo != null) {
      if (finalDescription != null) {
        finalDescription = '$additionalInfo. $finalDescription';
      } else {
        finalDescription = additionalInfo;
      }
    }

    return WikidataSearchResult(
      id: id,
      title: title,
      artist: artist?.isNotEmpty == true ? artist : null,
      description: finalDescription,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
      releaseDate: releaseDate.isNotEmpty ? releaseDate : null,
      genre: genre.isNotEmpty ? genre : null,
      additionalData: binding,
    );
  }

  /// Generic search that tries to determine media type from query context
  Future<List<WikidataSearchResult>> search(String query, String mediaType, {int limit = 20}) async {
    switch (mediaType.toLowerCase()) {
      case 'book':
      case 'books':
        return searchBooks(query, limit: limit);
      case 'music':
      case 'song':
      case 'album':
        return searchMusic(query, limit: limit);
      case 'movie':
      case 'movies':
      case 'film':
        return searchMovies(query, limit: limit);
      case 'tv':
      case 'television':
      case 'show':
        return searchTVShows(query, limit: limit);
      case 'game':
      case 'games':
      case 'videogame':
        return searchGames(query, limit: limit);
      default:
        debugPrint('[WIKIDATA] Unknown media type: $mediaType, defaulting to general search');
        // For unknown types, try a general search across all media
        final results = <WikidataSearchResult>[];
        results.addAll(await searchBooks(query, limit: limit ~/ 4));
        results.addAll(await searchMusic(query, limit: limit ~/ 4));
        results.addAll(await searchMovies(query, limit: limit ~/ 4));
        results.addAll(await searchGames(query, limit: limit ~/ 4));
        return results;
    }
  }
} 
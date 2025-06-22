import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:path/path.dart' as pathLib;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// VectorDatabase
/// Read-only vector search database for media recommendations
/// Downloads pre-built vector databases from R2 storage based on user preferences
class VectorDatabase {
  static final VectorDatabase _instance = VectorDatabase._internal();
  factory VectorDatabase() => _instance;
  VectorDatabase._internal();

  // R2 base URL for vector database downloads
  static const String r2BaseUrl = 'https://interestnaut.com/vectors/';
  
  // Shard configuration
  static const Map<String, String> shardFiles = {
    'video_game': 'vectors_games.db',
    'movie': 'vectors_movies.db', 
    'tv_show': 'vectors_tv.db',
    'book': 'vectors_books.db',
    'music': 'vectors_music.db',
  };

  final Map<String, Database> _shards = {};
  bool _initialized = false;
  Set<String> _enabledMediaTypes = {};

  /// Initialize vector database (downloads enabled media types only)
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Load user preferences for enabled media types
      await _loadEnabledMediaTypes();
      
      final dbDir = await _getVectorDatabaseDir();
      
      // Only download and initialize enabled media types
      for (final mediaType in _enabledMediaTypes) {
        if (!shardFiles.containsKey(mediaType)) continue;
        
        final filename = shardFiles[mediaType]!;
        final localPath = pathLib.join(dbDir.path, filename);
        
        if (!await File(localPath).exists()) {
          debugPrint('Downloading vector database for $mediaType...');
          await _downloadShard(mediaType, filename, localPath);
        }
        
        // Open the shard database
        _shards[mediaType] = sqlite3.open(localPath);
        
        // Load sqlite-vec extension if available
        try {
          _shards[mediaType]!.execute('SELECT load_extension("sqlite_vec")');
        } catch (e) {
          debugPrint('sqlite-vec extension not available, using fallback');
        }
      }
      
      _initialized = true;
      debugPrint('Vector database initialized with ${_shards.length} shards: ${_shards.keys.join(', ')}');
    } catch (e) {
      debugPrint('Error initializing vector database: $e');
      rethrow;
    }
  }

  /// Load enabled media types from user preferences
  Future<void> _loadEnabledMediaTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final enabledTypes = prefs.getStringList('enabled_media_types');
    
    if (enabledTypes != null && enabledTypes.isNotEmpty) {
      _enabledMediaTypes = enabledTypes.toSet();
    } else {
      // Default to music only for initial setup
      _enabledMediaTypes = {'music'};
      await prefs.setStringList('enabled_media_types', ['music']);
    }
    
    debugPrint('Enabled media types: ${_enabledMediaTypes.join(', ')}');
  }

  /// Enable a media type (downloads database if needed)
  Future<bool> enableMediaType(String mediaType) async {
    if (!shardFiles.containsKey(mediaType)) {
      debugPrint('Unknown media type: $mediaType');
      return false;
    }
    
    if (_enabledMediaTypes.contains(mediaType)) {
      debugPrint('Media type $mediaType already enabled');
      return true;
    }

    try {
      final dbDir = await _getVectorDatabaseDir();
      final filename = shardFiles[mediaType]!;
      final localPath = pathLib.join(dbDir.path, filename);
      
      // Download if not exists
      if (!await File(localPath).exists()) {
        debugPrint('Downloading vector database for $mediaType...');
        await _downloadShard(mediaType, filename, localPath);
      }
      
      // Open the shard database
      _shards[mediaType] = sqlite3.open(localPath);
      
      // Load sqlite-vec extension if available
      try {
        _shards[mediaType]!.execute('SELECT load_extension("sqlite_vec")');
      } catch (e) {
        debugPrint('sqlite-vec extension not available for $mediaType');
      }
      
      // Update preferences
      _enabledMediaTypes.add(mediaType);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('enabled_media_types', _enabledMediaTypes.toList());
      
      debugPrint('Successfully enabled media type: $mediaType');
      return true;
    } catch (e) {
      debugPrint('Error enabling media type $mediaType: $e');
      return false;
    }
  }

  /// Disable a media type (keeps database file but closes connection)
  Future<void> disableMediaType(String mediaType) async {
    if (!_enabledMediaTypes.contains(mediaType)) return;
    
    // Close database connection
    _shards[mediaType]?.dispose();
    _shards.remove(mediaType);
    
    // Update preferences
    _enabledMediaTypes.remove(mediaType);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('enabled_media_types', _enabledMediaTypes.toList());
    
    debugPrint('Disabled media type: $mediaType');
  }

  /// Get vector database directory
  Future<Directory> _getVectorDatabaseDir() async {
    final appDir = await getApplicationSupportDirectory();
    final vectorDir = Directory(pathLib.join(appDir.path, 'vectors'));
    
    if (!await vectorDir.exists()) {
      await vectorDir.create(recursive: true);
    }
    
    return vectorDir;
  }

  /// Download a vector database shard from R2
  Future<void> _downloadShard(String mediaType, String filename, String localPath) async {
    final url = '$r2BaseUrl$filename';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        await File(localPath).writeAsBytes(response.bodyBytes);
        debugPrint('Downloaded $filename (${response.bodyBytes.length} bytes)');
      } else {
        throw Exception('Failed to download $filename: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading $filename: $e');
      rethrow;
    }
  }

  /// Get enabled media types
  Set<String> get enabledMediaTypes => Set.from(_enabledMediaTypes);

  /// Check if media type is enabled
  bool isMediaTypeEnabled(String mediaType) => _enabledMediaTypes.contains(mediaType);

  /// Get available media types for enabling
  Set<String> get availableMediaTypes => shardFiles.keys.toSet();

  /// Download all vector databases (for initial setup or bulk enhancement)
  Future<bool> downloadAllDatabases({Function(String, double)? onProgress}) async {
    try {
      final dbDir = await _getVectorDatabaseDir();
      final mediaTypes = shardFiles.keys.toList();
      
      debugPrint('Starting download of ${mediaTypes.length} vector databases...');
      
      for (int i = 0; i < mediaTypes.length; i++) {
        final mediaType = mediaTypes[i];
        final filename = shardFiles[mediaType]!;
        final localPath = pathLib.join(dbDir.path, filename);
        
        // Skip if already exists
        if (await File(localPath).exists()) {
          debugPrint('$filename already exists, skipping...');
          onProgress?.call(mediaType, (i + 1) / mediaTypes.length);
          continue;
        }
        
        try {
          debugPrint('Downloading $filename for $mediaType...');
          await _downloadShard(mediaType, filename, localPath);
          onProgress?.call(mediaType, (i + 1) / mediaTypes.length);
          debugPrint('Successfully downloaded $filename');
        } catch (e) {
          debugPrint('Failed to download $filename: $e');
          // Continue with other downloads even if one fails
          onProgress?.call(mediaType, (i + 1) / mediaTypes.length);
        }
      }
      
      debugPrint('Bulk download completed');
      return true;
    } catch (e) {
      debugPrint('Error in bulk download: $e');
      return false;
    }
  }

  /// Enable all downloaded media types
  Future<void> enableAllDownloadedMediaTypes() async {
    final dbDir = await _getVectorDatabaseDir();
    final downloadedTypes = <String>[];
    
    for (final entry in shardFiles.entries) {
      final mediaType = entry.key;
      final filename = entry.value;
      final file = File(pathLib.join(dbDir.path, filename));
      
      if (await file.exists()) {
        downloadedTypes.add(mediaType);
      }
    }
    
    if (downloadedTypes.isNotEmpty) {
      _enabledMediaTypes = downloadedTypes.toSet();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('enabled_media_types', downloadedTypes);
      debugPrint('Enabled all downloaded media types: ${downloadedTypes.join(', ')}');
    }
  }

  /// Get database size information
  Future<Map<String, int>> getDatabaseSizes() async {
    final sizes = <String, int>{};
    final dbDir = await _getVectorDatabaseDir();
    
    for (final entry in shardFiles.entries) {
      final mediaType = entry.key;
      final filename = entry.value;
      final file = File(pathLib.join(dbDir.path, filename));
      
      if (await file.exists()) {
        sizes[mediaType] = await file.length();
      }
    }
    
    return sizes;
  }

  /// Search for similar media items
  Future<List<MediaSearchResult>> searchSimilar({
    required List<double> queryEmbedding,
    required String mediaType,
    int limit = 20,
    double? minSimilarity,
  }) async {
    await _ensureInitialized();
    
    if (!_shards.containsKey(mediaType)) {
      throw Exception('Media type $mediaType not available');
    }

    try {
      final db = _shards[mediaType]!;
      final hasAlbum = mediaType == 'music';      
      // Use sqlite-vec if available, fallback to manual similarity
      final query = '''
        SELECT 
          media_id,
          title,
          artist,
          ${hasAlbum ? 'album,' : ''}
          description,
          themes,
          wiki_url,
          wikidata_id,
          image_url,
          distance
        FROM media_vectors 
        WHERE embedding MATCH ?
        ${minSimilarity != null ? 'AND distance <= ?' : ''}
        ORDER BY distance ASC
        LIMIT ?
      ''';
      
      final params = [
        jsonEncode(queryEmbedding),
        if (minSimilarity != null) minSimilarity,
        limit,
      ];
      
      final stmt = db.prepare(query);
      final result = stmt.select(params);
      
      final results = result.map((row) => MediaSearchResult(
        mediaId: row['media_id'] as String,
        title: row['title'] as String,
        artist: row['artist'] as String?,
        album: hasAlbum ? row['album'] as String? : null,
        description: row['description'] as String?,
        themes: row['themes'] as String?,
        wikiUrl: row['wiki_url'] as String?,
        wikidataId: row['wikidata_id'] as String?,
        coverArtUrl: row['image_url'] as String?,
        similarity: 1.0 - (row['distance'] as double), // Convert distance to similarity
        mediaType: mediaType,
      )).toList();
      
      stmt.dispose();
      return results;
    } catch (e) {
      debugPrint('Error searching similar media: $e');
      rethrow;
    }
  }

  /// Get media item by ID
  Future<MediaSearchResult?> getMediaById({
    required String mediaId,
    required String mediaType,
  }) async {
    await _ensureInitialized();
    
    if (!_shards.containsKey(mediaType)) {
      return null;
    }

    try {
      final db = _shards[mediaType]!;
      final hasAlbum = mediaType == 'music';      
      final query = '''
        SELECT 
          media_id,
          title,
          artist,
          ${hasAlbum ? 'album,' : ''}
          description,
          themes,
          wiki_url,
          wikidata_id,
          image_url
        FROM media_vectors 
        WHERE media_id = ?
        LIMIT 1
      ''';
      
      final stmt = db.prepare(query);
      final result = stmt.select([mediaId]);
      
      if (result.isEmpty) {
        stmt.dispose();
        return null;
      }
      
      final row = result.first;
      final mediaResult = MediaSearchResult(
        mediaId: row['media_id'] as String,
        title: row['title'] as String,
        artist: row['artist'] as String?,
        album: hasAlbum ? row['album'] as String? : null,
        description: row['description'] as String?,
        themes: row['themes'] as String?,
        wikiUrl: row['wiki_url'] as String?,
        wikidataId: row['wikidata_id'] as String?,
        coverArtUrl: row['image_url'] as String?,
        similarity: 1.0,
        mediaType: mediaType,
      );
      
      stmt.dispose();
      return mediaResult;
    } catch (e) {
      debugPrint('Error getting media by ID: $e');
      return null;
    }
  }

  /// Get random media items from a media type
  Future<List<MediaSearchResult>> getRandomMedia({
    required String mediaType,
    int limit = 10,
  }) async {
    await _ensureInitialized();
    
    if (!_shards.containsKey(mediaType)) {
      return [];
    }

    try {
      final db = _shards[mediaType]!;
      final hasAlbum = mediaType == 'music';      
      final query = '''
        SELECT 
          media_id,
          title,
          artist,
          ${hasAlbum ? 'album,' : ''}
          description,
          themes,
          wiki_url,
          wikidata_id,
          image_url
        FROM media_vectors 
        ORDER BY RANDOM()
        LIMIT ?
      ''';
      
      final stmt = db.prepare(query);
      final result = stmt.select([limit]);
      
      final results = result.map((row) => MediaSearchResult(
        mediaId: row['media_id'] as String,
        title: row['title'] as String,
        artist: row['artist'] as String?,
        album: hasAlbum ? row['album'] as String? : null,
        description: row['description'] as String?,
        themes: row['themes'] as String?,
        wikiUrl: row['wiki_url'] as String?,
        wikidataId: row['wikidata_id'] as String?,
        coverArtUrl: row['image_url'] as String?,
        similarity: 1.0,
        mediaType: mediaType,
      )).toList();
      
      stmt.dispose();
      return results;
    } catch (e) {
      debugPrint('Error getting random media: $e');
      return [];
    }
  }

  /// Search media using FTS5 full-text search (for music and movies)
  Future<List<MediaSearchResult>> searchByText({
    required String query,
    required String mediaType,
    int limit = 20,
  }) async {
    await _ensureInitialized();
    
    if (!_shards.containsKey(mediaType)) {
      return [];
    }

    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final db = _shards[mediaType]!;
      final hasAlbum = mediaType == 'music';      
      // Check if FTS5 table exists for this media type
      final tableCheckStmt = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='media_fts'");
      final tableCheckResult = tableCheckStmt.select([]);
      tableCheckStmt.dispose();
      
      if (tableCheckResult.isEmpty) {
        debugPrint('FTS5 table not available for $mediaType, falling back to basic search');
        return _fallbackTextSearch(query, mediaType, limit);
      }
      
      // Clean and prepare the search query for FTS5
      final cleanQuery = _prepareFTSQuery(query);
      
      final searchQuery = '''
        SELECT 
          v.media_id,
          v.title,
          v.artist,
          ${hasAlbum ? 'v.album,' : ''}
          v.description,
          v.themes,
          v.wiki_url,
          v.wikidata_id,
          v.image_url,
          fts.rank
        FROM media_fts fts
        JOIN media_vectors v ON v.rowid = fts.rowid
        WHERE media_fts MATCH ?
        ORDER BY rank
        LIMIT ?
      ''';
      
      final stmt = db.prepare(searchQuery);
      final result = stmt.select([cleanQuery, limit]);
      
      final results = result.map((row) {
        // Convert FTS5 rank to similarity score (higher rank = lower similarity)
        final rank = row['rank'] as double;
        final similarity = (1.0 / (1.0 + (-rank / 10.0))).clamp(0.0, 1.0);
        
        return MediaSearchResult(
          mediaId: row['media_id'] as String,
          title: row['title'] as String,
          artist: row['artist'] as String?,
          album: mediaType == 'music' ? row['album'] as String? : null,
          description: row['description'] as String?,
          themes: row['themes'] as String?,
          wikiUrl: row['wiki_url'] as String?,
          wikidataId: row['wikidata_id'] as String?,
          coverArtUrl: row['image_url'] as String?,
          similarity: similarity,
          mediaType: mediaType,
        );
      }).toList();
      
      stmt.dispose();
      
      debugPrint('🔍 FTS5 search for "$query" in $mediaType: found ${results.length} results');
      
      // If FTS5 returns no results for queries with short fragments, try LIKE-based search
      if (results.isEmpty && query.contains(' ') && query.split(' ').any((word) => word.length <= 2)) {
        debugPrint('🔄 FTS5 found no results for query with short fragments, trying LIKE search...');
        return _fallbackTextSearch(query, mediaType, limit);
      }
      
      return results;
    } catch (e) {
      debugPrint('Error in FTS5 search: $e');
      // Fallback to basic search if FTS5 fails
      return _fallbackTextSearch(query, mediaType, limit);
    }
  }

  /// Prepare query for FTS5 search
  String _prepareFTSQuery(String query) {
    // Clean the query and handle special characters
    final cleanQuery = query.trim().toLowerCase();
    
    // Always use prefix matching for flexible search
    return '$cleanQuery*';
  }

  /// Fallback text search using LIKE for databases without FTS5
  Future<List<MediaSearchResult>> _fallbackTextSearch(String query, String mediaType, int limit) async {
    final db = _shards[mediaType]!;
    
    // Build query based on media type (music has album, others don't)
    final hasAlbum = mediaType == 'music';
    
    final searchQuery = '''
      SELECT 
        media_id,
        title,
        artist,
        ${hasAlbum ? 'album,' : ''}
        description,
        themes,
        wiki_url,
        wikidata_id,
        image_url,
        (
          CASE WHEN LOWER(title) LIKE LOWER(?) || '%' THEN 100
          WHEN LOWER(title) LIKE '%' || LOWER(?) || '%' THEN 80
          WHEN LOWER(COALESCE(artist, '')) LIKE LOWER(?) || '%' THEN 70
          WHEN LOWER(COALESCE(artist, '')) LIKE '%' || LOWER(?) || '%' THEN 60
          WHEN LOWER(COALESCE(themes, '')) LIKE '%' || LOWER(?) || '%' THEN 40
          ELSE 20 END
        ) as relevance_score
      FROM media_vectors 
      WHERE (
        LOWER(title) LIKE '%' || LOWER(?) || '%' OR
        LOWER(COALESCE(artist, '')) LIKE '%' || LOWER(?) || '%' OR
        LOWER(COALESCE(themes, '')) LIKE '%' || LOWER(?) || '%'
      )
      ORDER BY relevance_score DESC, title ASC
      LIMIT ?
    ''';
    
    final params = [query, query, query, query, query, query, query, query, limit];
    
    final stmt = db.prepare(searchQuery);
    final result = stmt.select(params);
    
    final results = result.map((row) {
      final relevanceScore = row['relevance_score'] as int;
      final similarity = (relevanceScore / 100.0).clamp(0.0, 1.0);
      
      return MediaSearchResult(
        mediaId: row['media_id'] as String,
        title: row['title'] as String,
        artist: row['artist'] as String?,
        album: hasAlbum ? row['album'] as String? : null,
        description: row['description'] as String?,
        themes: row['themes'] as String?,
        wikiUrl: row['wiki_url'] as String?,
        wikidataId: row['wikidata_id'] as String?,
        coverArtUrl: row['image_url'] as String?,
        similarity: similarity,
        mediaType: mediaType,
      );
    }).toList();
    
    stmt.dispose();
    return results;
  }

  /// Check if a media type is available locally
  bool isMediaTypeAvailable(String mediaType) {
    return _shards.containsKey(mediaType);
  }

  /// Get available media types
  List<String> getAvailableMediaTypes() {
    return _shards.keys.toList();
  }

  /// Get shard statistics
  Future<Map<String, int>> getShardStats() async {
    await _ensureInitialized();
    
    final stats = <String, int>{};
    
    for (final entry in _shards.entries) {
      try {
        final db = entry.value;
        final stmt = db.prepare('SELECT COUNT(*) as count FROM media_vectors');
        final result = stmt.select([]);
        
        stats[entry.key] = result.isNotEmpty ? result.first['count'] as int : 0;
        stmt.dispose();
      } catch (e) {
        stats[entry.key] = 0;
      }
    }
    
    return stats;
  }

  /// Ensure database is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  /// Close all database connections
  Future<void> close() async {
    for (final db in _shards.values) {
      db.dispose();
    }
    _shards.clear();
    _initialized = false;
  }

  /// 🎯 NEW: Search for items similar to a reference item using embedding vectors
  /// This is the "More Like This" functionality using cosine similarity
  Future<List<MediaSearchResult>> searchBySimilarity({
    required String referenceMediaId,
    required String mediaType,
    int limit = 20,
    double minSimilarity = 0.6,
    List<String> excludeIds = const [],
  }) async {
    await _ensureInitialized();
    
    if (!_shards.containsKey(mediaType)) {
      throw Exception('Media type $mediaType not available');
    }

    try {
      final db = _shards[mediaType]!;
      
      // Step 1: Get reference embedding
      final refStmt = db.prepare('''
        SELECT embedding_blob FROM media_vectors 
        WHERE media_id = ?
      ''');
      
      final refResult = refStmt.select([referenceMediaId]);
      refStmt.dispose();
      
      if (refResult.isEmpty) {
        debugPrint('❌ Reference item not found: $referenceMediaId');
        return [];
      }
      
      final refBlob = refResult.first['embedding_blob'] as Uint8List;
      final refEmbedding = _blobToFloatList(refBlob);
      
      debugPrint('🎯 Found reference embedding: ${refEmbedding.length} dimensions');
      
      // Step 2: Get all items with embeddings (excluding reference and excludeIds)
      final hasAlbum = mediaType == 'music';
      String excludeClause = 'media_id != ?';
      List<dynamic> params = [referenceMediaId];
      
      if (excludeIds.isNotEmpty) {
        final placeholders = excludeIds.map((_) => '?').join(',');
        excludeClause += ' AND media_id NOT IN ($placeholders)';
        params.addAll(excludeIds);
      }
      
      final allStmt = db.prepare('''
        SELECT 
          media_id,
          title,
          artist,
          ${hasAlbum ? 'album,' : ''}
          description,
          themes,
          wiki_url,
          wikidata_id,
          image_url,
          embedding_blob
        FROM media_vectors 
        WHERE $excludeClause
      ''');
      
      final allResults = allStmt.select(params);
      allStmt.dispose();
      
      debugPrint('🔍 Comparing against ${allResults.length} items...');
      
      // Step 3: Calculate similarities
      final similarities = <Map<String, dynamic>>[];
      
      for (final row in allResults) {
        try {
          final itemBlob = row['embedding_blob'] as Uint8List;
          final itemEmbedding = _blobToFloatList(itemBlob);
          
          final similarity = _cosineSimilarity(refEmbedding, itemEmbedding);
          
          if (similarity >= minSimilarity) {
            similarities.add({
              'mediaId': row['media_id'] as String,
              'title': row['title'] as String,
              'artist': row['artist'] as String?,
              'album': hasAlbum ? row['album'] as String? : null,
              'description': row['description'] as String?,
              'themes': row['themes'] as String?,
              'wikiUrl': row['wiki_url'] as String?,
              'wikidataId': row['wikidata_id'] as String?,
              'coverArtUrl': row['image_url'] as String?,
              'similarity': similarity,
            });
          }
        } catch (e) {
          debugPrint('⚠️ Error processing embedding for ${row['media_id']}: $e');
          continue;
        }
      }
      
      // Step 4: Sort by similarity (highest first) and limit results
      similarities.sort((a, b) => (b['similarity'] as double).compareTo(a['similarity'] as double));
      final topResults = similarities.take(limit);
      
      debugPrint('✅ Found ${topResults.length} similar items (min similarity: $minSimilarity)');
      
      return topResults.map((item) => MediaSearchResult(
        mediaId: item['mediaId'] as String,
        title: item['title'] as String,
        artist: item['artist'] as String?,
        album: item['album'] as String?,
        description: item['description'] as String?,
        themes: item['themes'] as String?,
        wikiUrl: item['wikiUrl'] as String?,
        wikidataId: item['wikidataId'] as String?,
        coverArtUrl: item['coverArtUrl'] as String?,
        similarity: item['similarity'] as double,
        mediaType: mediaType,
      )).toList();
      
    } catch (e) {
      debugPrint('❌ Error in similarity search: $e');
      return [];
    }
  }

  /// 🧮 Convert binary blob to float list (384 dimensions)
  List<double> _blobToFloatList(Uint8List blob) {
    final buffer = blob.buffer;
    final floats = Float32List.view(buffer);
    return floats.cast<double>();
  }

  /// 🧮 Calculate cosine similarity between two vectors
  /// Returns value between -1 and 1 (1 = identical, 0 = unrelated, -1 = opposite)
  double _cosineSimilarity(List<double> vectorA, List<double> vectorB) {
    if (vectorA.length != vectorB.length) {
      throw ArgumentError('Vectors must have the same length');
    }
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      normA += vectorA[i] * vectorA[i];
      normB += vectorB[i] * vectorB[i];
    }
    
    // Avoid division by zero
    if (normA == 0.0 || normB == 0.0) {
      return 0.0;
    }
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// 🎯 Optimized version for large datasets (processes in batches)
  Future<List<MediaSearchResult>> searchBySimilarityOptimized({
    required String referenceMediaId,
    required String mediaType,
    int limit = 20,
    double minSimilarity = 0.6,
    List<String> excludeIds = const [],
    int batchSize = 1000,
  }) async {
    await _ensureInitialized();
    
    if (!_shards.containsKey(mediaType)) {
      throw Exception('Media type $mediaType not available');
    }

    try {
      final db = _shards[mediaType]!;
      
      // Get reference embedding (same as above)
      final refStmt = db.prepare('SELECT embedding_blob FROM media_vectors WHERE media_id = ?');
      final refResult = refStmt.select([referenceMediaId]);
      refStmt.dispose();
      
      if (refResult.isEmpty) {
        debugPrint('❌ Reference item not found: $referenceMediaId');
        return [];
      }
      
      final refBlob = refResult.first['embedding_blob'] as Uint8List;
      final refEmbedding = _blobToFloatList(refBlob);
      
      // Get total count for batching
      final countStmt = db.prepare('SELECT COUNT(*) as count FROM media_vectors WHERE media_id != ?');
      final countResult = countStmt.select([referenceMediaId]);
      countStmt.dispose();
      
      final totalCount = countResult.first['count'] as int;
      debugPrint('🔍 Processing $totalCount items in batches of $batchSize...');
      
      final similarities = <Map<String, dynamic>>[];
      final hasAlbum = mediaType == 'music';
      
      // Process in batches
      for (int offset = 0; offset < totalCount; offset += batchSize) {
        final batchStmt = db.prepare('''
          SELECT 
            media_id, title, artist, ${hasAlbum ? 'album,' : ''} description, themes, 
            wiki_url, wikidata_id, image_url, embedding_blob
          FROM media_vectors 
          WHERE media_id != ?
          LIMIT ? OFFSET ?
        ''');
        
        final batchResults = batchStmt.select([referenceMediaId, batchSize, offset]);
        batchStmt.dispose();
        
        for (final row in batchResults) {
          try {
            final itemBlob = row['embedding_blob'] as Uint8List;
            final itemEmbedding = _blobToFloatList(itemBlob);
            final similarity = _cosineSimilarity(refEmbedding, itemEmbedding);
            
            if (similarity >= minSimilarity && !excludeIds.contains(row['media_id'])) {
              similarities.add({
                'mediaId': row['media_id'] as String,
                'title': row['title'] as String,
                'artist': row['artist'] as String?,
                'album': hasAlbum ? row['album'] as String? : null,
                'description': row['description'] as String?,
                'themes': row['themes'] as String?,
                'wikiUrl': row['wiki_url'] as String?,
                'wikidataId': row['wikidata_id'] as String?,
                'coverArtUrl': row['image_url'] as String?,
                'similarity': similarity,
              });
            }
          } catch (e) {
            continue; // Skip problematic embeddings
          }
        }
        
        debugPrint('📊 Processed batch ${offset ~/ batchSize + 1}/${(totalCount / batchSize).ceil()}');
      }
      
      // Sort and return top results
      similarities.sort((a, b) => (b['similarity'] as double).compareTo(a['similarity'] as double));
      final topResults = similarities.take(limit);
      
      debugPrint('✅ Found ${topResults.length} similar items from $totalCount total');
      
      return topResults.map((item) => MediaSearchResult(
        mediaId: item['mediaId'] as String,
        title: item['title'] as String,
        artist: item['artist'] as String?,
        album: item['album'] as String?,
        description: item['description'] as String?,
        themes: item['themes'] as String?,
        wikiUrl: item['wikiUrl'] as String?,
        wikidataId: item['wikidataId'] as String?,
        coverArtUrl: item['coverArtUrl'] as String?,
        similarity: item['similarity'] as double,
        mediaType: mediaType,
      )).toList();
      
    } catch (e) {
      debugPrint('❌ Error in optimized similarity search: $e');
      return [];
    }
  }

  /// 🎯 Multi-criteria behavioral matching - THE main recommendation method
  /// Finds items that match user's behavioral patterns using multiple signals
  Future<List<MediaSearchResult>> searchByBehavioralMatch({
    required String mediaType,
    required List<String> likedItemIds,        // Max 3 liked items
    required List<String> dislikedItemIds,     // Max 3 disliked items
    String? favoriteItemId,                    // Single favorite item
    List<String> skippedItemIds = const [],    // Max 2-3 skipped items
    List<String> excludeIds = const [],        // Already recommended items
    int limit = 1,                             // Usually just need 1 suggestion
    int batchSize = 1000,
  }) async {
    await _ensureInitialized();
    
    if (!_shards.containsKey(mediaType)) {
      throw Exception('Media type $mediaType not available');
    }

    try {
      final db = _shards[mediaType]!;
      
      // Step 1: Get all behavioral embeddings
      final behavioralEmbeddings = await _getBehavioralEmbeddings(
        db, likedItemIds, dislikedItemIds, favoriteItemId, skippedItemIds
      );
      
      if (behavioralEmbeddings['liked'].isEmpty && behavioralEmbeddings['favorite'] == null) {
        debugPrint('⚠️ No positive behavioral signals found, falling back to random');
        return [];
      }
      
      debugPrint('🎯 Behavioral signals: ${behavioralEmbeddings['liked'].length} liked, '
          '${behavioralEmbeddings['disliked'].length} disliked, '
          '${behavioralEmbeddings['favorite'] != null ? 1 : 0} favorite, '
          '${behavioralEmbeddings['skipped'].length} skipped');
      
      // Step 2: Get total count and prepare for batch processing
      final countStmt = db.prepare('SELECT COUNT(*) as count FROM media_vectors');
      final countResult = countStmt.select([]);
      countStmt.dispose();
      
      final totalCount = countResult.first['count'] as int;
      debugPrint('🔍 Searching through $totalCount items in batches...');
      
      final candidates = <Map<String, dynamic>>[];
      final hasAlbum = mediaType == 'music';
      
      // Step 3: Process in batches to find matches
      for (int offset = 0; offset < totalCount; offset += batchSize) {
        final batchStmt = db.prepare('''
          SELECT 
            media_id, title, artist, ${hasAlbum ? 'album,' : ''} description, themes, 
            wiki_url, wikidata_id, image_url, embedding_blob
          FROM media_vectors 
          LIMIT ? OFFSET ?
        ''');
        
        final batchResults = batchStmt.select([batchSize, offset]);
        batchStmt.dispose();
        
        for (final row in batchResults) {
          final mediaId = row['media_id'] as String;
          
          // Skip excluded items
          if (excludeIds.contains(mediaId) || 
              likedItemIds.contains(mediaId) || 
              dislikedItemIds.contains(mediaId) ||
              mediaId == favoriteItemId ||
              skippedItemIds.contains(mediaId)) {
            continue;
          }
          
          try {
            final itemBlob = row['embedding_blob'] as Uint8List;
            final itemEmbedding = _blobToFloatList(itemBlob);
            
            // Step 4: Apply multi-criteria matching
            final matchResult = _evaluateBehavioralMatch(
              itemEmbedding, 
              behavioralEmbeddings
            );
            
            if (matchResult['isMatch']) {
              candidates.add({
                'mediaId': mediaId,
                'title': row['title'] as String,
                'artist': row['artist'] as String?,
                'album': hasAlbum ? row['album'] as String? : null,
                'description': row['description'] as String?,
                'themes': row['themes'] as String?,
                'wikiUrl': row['wiki_url'] as String?,
                'wikidataId': row['wikidata_id'] as String?,
                'coverArtUrl': row['image_url'] as String?,
                'matchScore': matchResult['score'],
                'matchDetails': matchResult['details'],
              });
            }
          } catch (e) {
            continue; // Skip problematic embeddings
          }
        }
        
        // Early exit if we have enough good candidates
        if (candidates.length >= limit * 3) {
          debugPrint('📊 Found ${candidates.length} candidates, stopping early');
          break;
        }
        
        debugPrint('📊 Processed batch ${offset ~/ batchSize + 1}/${(totalCount / batchSize).ceil()}, found ${candidates.length} candidates');
      }
      
      // Step 5: Sort by match score and return top results
      candidates.sort((a, b) => (b['matchScore'] as double).compareTo(a['matchScore'] as double));
      final topResults = candidates.take(limit);
      
      debugPrint('✅ Found ${topResults.length} behavioral matches from ${candidates.length} candidates');
      
      return topResults.map((item) => MediaSearchResult(
        mediaId: item['mediaId'] as String,
        title: item['title'] as String,
        artist: item['artist'] as String?,
        album: item['album'] as String?,
        description: item['description'] as String?,
        themes: item['themes'] as String?,
        wikiUrl: item['wikiUrl'] as String?,
        wikidataId: item['wikidataId'] as String?,
        coverArtUrl: item['coverArtUrl'] as String?,
        similarity: item['matchScore'] as double,
        mediaType: mediaType,
      )).toList();
      
    } catch (e) {
      debugPrint('❌ Error in behavioral matching: $e');
      return [];
    }
  }

  /// Get embeddings for all behavioral signals
  Future<Map<String, dynamic>> _getBehavioralEmbeddings(
    Database db,
    List<String> likedItemIds,
    List<String> dislikedItemIds,
    String? favoriteItemId,
    List<String> skippedItemIds,
  ) async {
    final result = {
      'liked': <List<double>>[],
      'disliked': <List<double>>[],
      'favorite': null as List<double>?,
      'skipped': <List<double>>[],
    };
    
    // Get liked embeddings
    for (final id in likedItemIds) {
      final embedding = await _getEmbeddingById(db, id);
      if (embedding != null) {
        (result['liked'] as List<List<double>>).add(embedding);
      }
    }
    
    // Get disliked embeddings
    for (final id in dislikedItemIds) {
      final embedding = await _getEmbeddingById(db, id);
      if (embedding != null) {
        (result['disliked'] as List<List<double>>).add(embedding);
      }
    }
    
    // Get favorite embedding (single embedding, not a list)
    if (favoriteItemId != null) {
      result['favorite'] = await _getEmbeddingById(db, favoriteItemId);
    }
    
    // Get skipped embeddings
    for (final id in skippedItemIds) {
      final embedding = await _getEmbeddingById(db, id);
      if (embedding != null) {
        (result['skipped'] as List<List<double>>).add(embedding);
      }
    }
    
    return result;
  }

  /// Get single embedding by media ID
  Future<List<double>?> _getEmbeddingById(Database db, String mediaId) async {
    try {
      final stmt = db.prepare('SELECT embedding_blob FROM media_vectors WHERE media_id = ?');
      final result = stmt.select([mediaId]);
      stmt.dispose();
      
      if (result.isNotEmpty) {
        final blob = result.first['embedding_blob'] as Uint8List;
        return _blobToFloatList(blob);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error getting embedding for $mediaId: $e');
      return null;
    }
  }

  /// Evaluate if an item matches behavioral criteria
  Map<String, dynamic> _evaluateBehavioralMatch(
    List<double> itemEmbedding,
    Map<String, dynamic> behavioralEmbeddings,
  ) {
    final likedEmbeddings = behavioralEmbeddings['liked'] as List<List<double>>;
    final dislikedEmbeddings = behavioralEmbeddings['disliked'] as List<List<double>>;
    final favoriteEmbedding = behavioralEmbeddings['favorite'] as List<double>?;
    final skippedEmbeddings = behavioralEmbeddings['skipped'] as List<List<double>>;
    
    // Calculate similarities
    double maxLikedSimilarity = 0.0;
    double favoriteSimilarity = 0.0;
    double maxDislikedSimilarity = 0.0;
    double maxSkippedSimilarity = 0.0;
    
    // Check against liked items
    for (final likedEmbedding in likedEmbeddings) {
      final similarity = _cosineSimilarity(itemEmbedding, likedEmbedding);
      if (similarity > maxLikedSimilarity) {
        maxLikedSimilarity = similarity;
      }
    }
    
    // Check against favorite
    if (favoriteEmbedding != null) {
      favoriteSimilarity = _cosineSimilarity(itemEmbedding, favoriteEmbedding);
    }
    
    // Check against disliked items
    for (final dislikedEmbedding in dislikedEmbeddings) {
      final similarity = _cosineSimilarity(itemEmbedding, dislikedEmbedding);
      if (similarity > maxDislikedSimilarity) {
        maxDislikedSimilarity = similarity;
      }
    }
    
    // Check against skipped items
    for (final skippedEmbedding in skippedEmbeddings) {
      final similarity = _cosineSimilarity(itemEmbedding, skippedEmbedding);
      if (similarity > maxSkippedSimilarity) {
        maxSkippedSimilarity = similarity;
      }
    }
    
    // Apply your criteria:
    // 1. Must be 0.7+ similar to liked items OR 0.5+ similar to favorite
    final hasPositiveMatch = maxLikedSimilarity >= 0.7 || favoriteSimilarity >= 0.5;
    
    // 2. Must be 0.3 or less similar to disliked items
    final passesDislikedFilter = maxDislikedSimilarity <= 0.3;
    
    // 3. Deprioritize if 0.85+ similar to skipped items
    final isLikelySkipped = maxSkippedSimilarity >= 0.85;
    
    final isMatch = hasPositiveMatch && passesDislikedFilter && !isLikelySkipped;
    
    // Calculate overall match score (higher = better)
    double score = 0.0;
    if (hasPositiveMatch) {
      score += max(maxLikedSimilarity * 0.7, favoriteSimilarity * 0.5);
    }
    if (passesDislikedFilter) {
      score += 0.2; // Bonus for passing dislike filter
    }
    if (isLikelySkipped) {
      score -= 0.3; // Penalty for being like skipped items
    }
    
    return {
      'isMatch': isMatch,
      'score': score,
      'details': {
        'maxLikedSimilarity': maxLikedSimilarity,
        'favoriteSimilarity': favoriteSimilarity,
        'maxDislikedSimilarity': maxDislikedSimilarity,
        'maxSkippedSimilarity': maxSkippedSimilarity,
      }
    };
  }
}

/// Media search result model
class MediaSearchResult {
  final String mediaId;
  final String title;
  final String? artist;
  final String? album;
  final String? description;
  final String? themes;
  final String? wikiUrl;
  final String? wikidataId;
  final String? coverArtUrl;
  final double similarity;
  final String mediaType;

  MediaSearchResult({
    required this.mediaId,
    required this.title,
    this.artist,
    this.album,
    this.description,
    this.themes,
    this.wikiUrl,
    this.wikidataId,
    this.coverArtUrl,
    required this.similarity,
    required this.mediaType,
  });

  Map<String, dynamic> toJson() => {
    'mediaId': mediaId,
    'title': title,
    'artist': artist,
    'album': album,
    'description': description,
    'themes': themes,
    'wikiUrl': wikiUrl,
    'wikidataId': wikidataId,
    'coverArtUrl': coverArtUrl,
    'similarity': similarity,
    'mediaType': mediaType,
  };
} 
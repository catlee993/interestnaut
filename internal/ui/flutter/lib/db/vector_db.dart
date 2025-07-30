import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// TFLite vector service removed - using gRPC backend
import '../models.dart';

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
  /// 🎯 OPTIMIZED: Can now specify which media types to initialize for performance
  Future<void> init({List<String>? specificMediaTypes}) async {
    if (_initialized) return;

    try {
      // Load user preferences for enabled media types
      await _loadEnabledMediaTypes();
      
      final dbDir = await _getVectorDatabaseDir();
      
      // 🎯 OPTIMIZATION: Only initialize specific media types if provided
      final typesToInitialize = specificMediaTypes ?? _enabledMediaTypes.toList();
      
      // REAL DATABASE INITIALIZATION LOGGING - NO MOCKING
      debugPrint('🔍 [REAL-VECTOR-DB] Initializing vector databases...');
      debugPrint('🔍 [REAL-VECTOR-DB]   - Enabled media types: ${_enabledMediaTypes.join(', ')}');
      debugPrint('🔍 [REAL-VECTOR-DB]   - Initializing: ${typesToInitialize.join(', ')}');
      
      // Only download and initialize requested media types
      for (final mediaType in typesToInitialize) {
        if (!shardFiles.containsKey(mediaType)) continue;
        
        final filename = shardFiles[mediaType]!;
        final localPath = path_lib.join(dbDir.path, filename);
        
        debugPrint('🔍 [REAL-VECTOR-DB] Processing $mediaType:');
        debugPrint('🔍 [REAL-VECTOR-DB]   - File: $filename');
        debugPrint('🔍 [REAL-VECTOR-DB]   - Path: $localPath');
        debugPrint('🔍 [REAL-VECTOR-DB]   - Exists: ${await File(localPath).exists()}');
        
        if (!await File(localPath).exists()) {
          debugPrint('🔍 [REAL-VECTOR-DB]   - Downloading vector database for $mediaType...');
          await _downloadShard(mediaType, filename, localPath);
        }
        
        // Open the shard database
        _shards[mediaType] = sqlite3.open(localPath);
        
        // Get actual database stats
        final db = _shards[mediaType]!;
        final stmt = db.prepare('SELECT COUNT(*) as count FROM media_vectors');
        final result = stmt.select([]);
        final count = result.isNotEmpty ? result.first['count'] as int : 0;
        stmt.dispose();
        
        debugPrint('🔍 [REAL-VECTOR-DB]   - Database opened successfully');
        debugPrint('🔍 [REAL-VECTOR-DB]   - Media items in database: $count');
        debugPrint('✅ [REAL-VECTOR-DB] Vector database initialized for $mediaType with $count items');
      }
      
      _initialized = true;
      debugPrint('✅ [REAL-VECTOR-DB] Vector database fully initialized with ${_shards.length} shards: ${_shards.keys.join(', ')}');
    } catch (e) {
      debugPrint('❌ [REAL-VECTOR-DB] Error initializing vector database: $e');
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
      final localPath = path_lib.join(dbDir.path, filename);
      
      // Download if not exists
      if (!await File(localPath).exists()) {
        debugPrint('Downloading vector database for $mediaType...');
        await _downloadShard(mediaType, filename, localPath);
      }
      
      // Open the shard database
      _shards[mediaType] = sqlite3.open(localPath);
      
      // sqlite-vec extension not needed - using TensorFlow Lite for vector operations
      debugPrint('✅ Vector database initialized for $mediaType (using TFLite backend)');
      
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
    final vectorDir = Directory(path_lib.join(appDir.path, 'vectors'));
    
    // REAL PATH LOGGING - NO MOCKING
    debugPrint('🔍 [REAL-VECTOR-DB] Vector database paths:');
    debugPrint('🔍 [REAL-VECTOR-DB]   - App support dir: ${appDir.path}');
    debugPrint('🔍 [REAL-VECTOR-DB]   - Vector dir: ${vectorDir.path}');
    debugPrint('🔍 [REAL-VECTOR-DB]   - Vector dir exists: ${await vectorDir.exists()}');
    
    if (!await vectorDir.exists()) {
      await vectorDir.create(recursive: true);
      debugPrint('🔍 [REAL-VECTOR-DB]   - Created vector directory');
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
        final localPath = path_lib.join(dbDir.path, filename);
        
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
      final file = File(path_lib.join(dbDir.path, filename));
      
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
      final file = File(path_lib.join(dbDir.path, filename));
      
      if (await file.exists()) {
        sizes[mediaType] = await file.length();
      }
    }
    
    return sizes;
  }

  /// Search for similar media items using TensorFlow Lite
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
      
      // Get all vectors from database for TensorFlow Lite processing
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
          embedding_blob
        FROM media_vectors 
        LIMIT 10000
      ''';
      
      final stmt = db.prepare(query);
      final result = stmt.select([]);
      
      // Convert to VectorWithMetadata for TensorFlow Lite processing
      final candidates = result.map((row) {
        final embedding = _blobToFloatList(row['embedding_blob'] as Uint8List);
        return MediaSearchResult(
          mediaId: row['media_id'] as String,
          title: row['title'] as String,
          artist: row['artist'] as String?,
          album: hasAlbum ? row['album'] as String? : null,
          similarity: 0.0, // Default similarity for this context
          mediaType: mediaType,
          description: row['description'] as String?,
          themes: row['themes'] as String?,
          wikiUrl: row['wiki_url'] as String?,
          wikidataId: row['wikidata_id'] as String?,
          coverArtUrl: row['image_url'] as String?,
        );
      }).toList();
      
      stmt.dispose();
      
      // TensorFlow Lite no longer used - using gRPC backend instead
      // Return empty results since this method should not be called with gRPC backend
      final tfliteResults = <MediaSearchResult>[];
      // final tfliteResults = await TFLiteVectorService.instance.findTopSimilar(
      //   queryVector: queryEmbedding,
      //   candidates: candidates,
      //   topK: limit,
      //   minSimilarity: minSimilarity ?? 0.0,
      // );
      
      // Since we're using gRPC backend, return empty results
      // This vector search method should not be called with gRPC backend
      final results = <MediaSearchResult>[];
      // Convert back to MediaSearchResult (disabled for gRPC backend)
      // final results = tfliteResults.map((result) => MediaSearchResult(
      //   mediaId: result.item.id,
      //   title: result.item.title,
      //   artist: result.item.artist,
      //   album: result.item.album,
      //   description: result.metadata['description'] as String?,
      //   themes: result.metadata['themes'] as String?,
      //   wikiUrl: result.metadata['wikiUrl'] as String?,
      //   wikidataId: result.metadata['wikidataId'] as String?,
      //   coverArtUrl: result.metadata['coverArtUrl'] as String?,
      //   similarity: result.similarity,
      //   mediaType: mediaType,
      // )).toList();
      
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
        title: row['title'] as String?,  // Allow null titles
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
    List<String> excludeIds = const [],
  }) async {
    await _ensureInitialized();
    
    if (!_shards.containsKey(mediaType)) {
      return [];
    }

    try {
      final db = _shards[mediaType]!;
      final hasAlbum = mediaType == 'music';      
      String query = '''
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
      ''';
      
      List<dynamic> params = [];
      
      // Add WHERE clause if we have IDs to exclude
      if (excludeIds.isNotEmpty) {
        final placeholders = excludeIds.map((_) => '?').join(',');
        query += ' WHERE media_id NOT IN ($placeholders)';
        params.addAll(excludeIds);
      }
      
      query += ' ORDER BY RANDOM() LIMIT ?';
      params.add(limit);
      
      final stmt = db.prepare(query);
      final result = stmt.select(params);
      
      final results = result.map((row) => MediaSearchResult(
        mediaId: row['media_id'] as String,
        title: row['title'] as String?,  // Allow null titles
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
      
      // REAL DATABASE LOGGING - NO MOCKING
      debugPrint('🔍 [REAL-VECTOR-DB] getRandomMedia for $mediaType:');
      debugPrint('🔍 [REAL-VECTOR-DB]   - Query executed successfully');
      debugPrint('🔍 [REAL-VECTOR-DB]   - Excluded IDs: ${excludeIds.length}');
      debugPrint('🔍 [REAL-VECTOR-DB]   - Results found: ${results.length}');
      if (results.isNotEmpty) {
        final first = results.first;
        debugPrint('🔍 [REAL-VECTOR-DB]   - First result: "${first.title}" by "${first.artist}"');
        debugPrint('🔍 [REAL-VECTOR-DB]   - Media ID: ${first.mediaId}');
        debugPrint('🔍 [REAL-VECTOR-DB]   - Cover URL: ${first.coverArtUrl?.isNotEmpty == true ? "✅ HAS IMAGE" : "❌ NO IMAGE"}');
        debugPrint('🔍 [REAL-VECTOR-DB]   - Themes: ${first.themes}');
      }
      
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
          title: row['title'] as String?,  // Allow null titles
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
    String cleanQuery = query.trim().toLowerCase();
    
    // Escape FTS5 special characters by quoting the entire query
    // FTS5 special characters: ( ) " * : ^ + - 
    if (cleanQuery.contains(RegExp(r'[()"\*:^+\-]'))) {
      // Quote the entire query to treat it as a literal phrase
      cleanQuery = '"${cleanQuery.replaceAll('"', '""')}"';
      return cleanQuery; // Don't add * to quoted phrases
    }
    
    // Split into words and add prefix matching to each word
    final words = cleanQuery.split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '$word*')
        .join(' ');
    
    return words.isNotEmpty ? words : '$cleanQuery*';
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

  /// 🎯 NEW: Search based on user-defined constraints (Include/Exclude)
  /// This is the missing constraint-based search that should be used when users have explicit preferences
  /// 🎯 OPTIMIZED: Uses paginated search with proper memory management to cover entire database
  Future<List<MediaSearchResult>> searchByConstraints({
    required String mediaType,
    required List<String> includeConstraints,  // Must match ALL of these
    required List<String> excludeConstraints,  // Must NOT match ANY of these
    required List<String> excludeIds,          // Already suggested items
    int limit = 1,
    double similarityThreshold = 0.5,          // From user settings (0.0-1.0)
    int batchSize = 1000,                      // Process in batches to manage memory
    int maxBatches = 400,                      // Maximum batches to process (400k items max)
    bool Function()? isCancelled,              // Function to check if operation is cancelled
  }) async {
    await _ensureInitialized();
    
    if (!_shards.containsKey(mediaType)) {
      throw Exception('Media type $mediaType not available');
    }

    if (includeConstraints.isEmpty) {
      debugPrint('[CONSTRAINT-SEARCH] No include constraints provided, falling back to behavioral matching');
      return [];
    }

    try {
      debugPrint('[CONSTRAINT-SEARCH] Starting paginated constraint-based search for $mediaType');
      debugPrint('[CONSTRAINT-SEARCH] Include constraints: ${includeConstraints.join(', ')}');
      debugPrint('[CONSTRAINT-SEARCH] Exclude constraints: ${excludeConstraints.join(', ')}');
      debugPrint('[CONSTRAINT-SEARCH] Similarity threshold: $similarityThreshold');
      
      final db = _shards[mediaType]!;
      final hasAlbum = mediaType == 'music';
      
      // Get total count for pagination
      final countStmt = db.prepare('SELECT COUNT(*) as count FROM media_vectors');
      final countResult = countStmt.select([]);
      countStmt.dispose();
      final totalCount = countResult.first['count'] as int;
      
      debugPrint('[CONSTRAINT-SEARCH] Total items: $totalCount, will process in batches of $batchSize');
      
      // Generate random offset to ensure we don't always start from the same place
      final random = Random();
      int startOffset = random.nextInt(max(1, totalCount ~/ 4)); // Random start within first 25%
      
      final candidates = <Map<String, dynamic>>[];
      int itemsProcessed = 0;
      int batchesProcessed = 0;
      
      // Process in randomized batches to cover different parts of the database
      while (batchesProcessed < maxBatches && candidates.length < (limit * 3)) {
        final currentOffset = (startOffset + (batchesProcessed * batchSize)) % totalCount;
        
        debugPrint('[CONSTRAINT-BATCH] Processing batch ${batchesProcessed + 1}/$maxBatches, offset: $currentOffset');
        
        // Check for cancellation
        if (isCancelled != null && isCancelled()) {
          debugPrint('[CONSTRAINT-CANCELLED] Search cancelled by user');
          return [];
        }
        
        // Build SQL WHERE clause for database-level filtering
        final whereConditions = <String>[];
        final params = <dynamic>[];
        
        // Add INCLUDE constraints using LIKE operators (must match ALL)
        for (final constraint in includeConstraints) {
          final likePattern = '%${constraint.toLowerCase()}%';
          whereConditions.add('''
            (LOWER(title) LIKE ? OR 
             LOWER(artist) LIKE ? OR 
             LOWER(description) LIKE ? OR 
             LOWER(themes) LIKE ?)
          ''');
          params.addAll([likePattern, likePattern, likePattern, likePattern]);
        }
        
        // Add EXCLUDE constraints using NOT LIKE operators (must NOT match ANY)
        for (final constraint in excludeConstraints) {
          final likePattern = '%${constraint.toLowerCase()}%';
          whereConditions.add('''
            NOT (LOWER(title) LIKE ? OR 
                 LOWER(artist) LIKE ? OR 
                 LOWER(description) LIKE ? OR 
                 LOWER(themes) LIKE ?)
          ''');
          params.addAll([likePattern, likePattern, likePattern, likePattern]);
        }
        
        // Add exclude IDs if provided
        if (excludeIds.isNotEmpty) {
          final placeholders = excludeIds.map((_) => '?').join(', ');
          whereConditions.add('media_id NOT IN ($placeholders)');
          params.addAll(excludeIds);
        }
        
        final whereClause = whereConditions.isNotEmpty ? 'WHERE ${whereConditions.join(' AND ')}' : '';
        
        // Execute the batch query
        final query = '''
          SELECT media_id, title, artist, ${hasAlbum ? 'album,' : ''} description, themes, 
                 wiki_url, wikidata_id, image_url
          FROM media_vectors 
          $whereClause
          LIMIT ? OFFSET ?
        ''';
        
        params.addAll([batchSize, currentOffset]);
        
        final stmt = db.prepare(query);
        final results = stmt.select(params);
        stmt.dispose();
        
        debugPrint('[CONSTRAINT-BATCH] Batch ${batchesProcessed + 1} returned ${results.length} candidates');
        
        // Log progress for UI (since we can't emit events from isolate)
        final progressPercent = (batchesProcessed / maxBatches * 100).toStringAsFixed(1);
        debugPrint('[CONSTRAINT-PROGRESS] ${progressPercent}% complete - processed ${batchesProcessed} batches, found ${candidates.length} matches');
        
        // Process this batch
        for (final row in results) {
          itemsProcessed++;
          
          final mediaId = row['media_id'] as String;
          
          // Get all searchable text fields
          final title = (row['title'] as String? ?? '').toLowerCase();
          final artist = (row['artist'] as String? ?? '').toLowerCase();
          final description = (row['description'] as String? ?? '').toLowerCase();
          final themes = (row['themes'] as String? ?? '').toLowerCase();
          
          final allText = '$title $artist $description $themes';
          
          // Double-check INCLUDE constraints (must match ALL) - more precise than SQL LIKE
          bool matchesAllIncludes = true;
          for (final constraint in includeConstraints) {
            final normalizedConstraint = constraint.toLowerCase();
            if (!allText.contains(normalizedConstraint)) {
              matchesAllIncludes = false;
              break;
            }
          }
          
          if (!matchesAllIncludes) {
            continue; // Doesn't match all required constraints
          }
          
          // Double-check EXCLUDE constraints (must NOT match ANY) - more precise than SQL LIKE
          bool matchesAnyExclude = false;
          for (final constraint in excludeConstraints) {
            final normalizedConstraint = constraint.toLowerCase();
            if (allText.contains(normalizedConstraint)) {
              matchesAnyExclude = true;
              break;
            }
          }
          
          if (matchesAnyExclude) {
            continue; // Contains excluded constraint
          }
          
          // Calculate match strength based on constraint relevance
          double matchStrength = 0.0;
          
          // Higher score for matches in title/artist vs description/themes
          for (final constraint in includeConstraints) {
            final normalizedConstraint = constraint.toLowerCase();
            if (title.contains(normalizedConstraint)) {
              matchStrength += 0.4; // Title match = highest relevance
            } else if (artist.contains(normalizedConstraint)) {
              matchStrength += 0.3; // Artist match = high relevance
            } else if (themes.contains(normalizedConstraint)) {
              matchStrength += 0.2; // Theme match = medium relevance
            } else if (description.contains(normalizedConstraint)) {
              matchStrength += 0.1; // Description match = lower relevance
            }
          }
          
          // Normalize match strength
          matchStrength = (matchStrength / includeConstraints.length).clamp(0.0, 1.0);
          
          // Apply similarity threshold
          if (matchStrength >= similarityThreshold) {
            candidates.add({
              'mediaId': mediaId,
              'title': row['title'] as String?,
              'artist': row['artist'] as String?,
              'album': hasAlbum ? row['album'] as String? : null,
              'description': row['description'] as String?,
              'themes': row['themes'] as String?,
              'wikiUrl': row['wiki_url'] as String?,
              'wikidataId': row['wikidata_id'] as String?,
              'coverArtUrl': row['image_url'] as String?,
              'matchStrength': matchStrength,
            });
            
            if (candidates.length <= 3) { // Only log first few matches to avoid spam
              debugPrint('[CONSTRAINT-MATCH] ✅ "${row['title']}" matched all constraints (strength: ${matchStrength.toStringAsFixed(3)})');
            }
          }
        }
        
        batchesProcessed++;
        
        // Early exit if we have enough good candidates
        if (candidates.length >= (limit * 3)) {
          debugPrint('[CONSTRAINT-EARLY-EXIT] Found sufficient candidates (${candidates.length}), stopping early');
          break;
        }
        
        // Yield control to prevent isolate blocking
        await Future.delayed(Duration.zero);
      }
      
      debugPrint('[CONSTRAINT-COMPLETE] Processed $itemsProcessed items across $batchesProcessed batches, found ${candidates.length} matches');
      
      // Sort by match strength (highest first) and return top results
      candidates.sort((a, b) => (b['matchStrength'] as double).compareTo(a['matchStrength'] as double));
      final topResults = candidates.take(limit).toList();
      
      if (topResults.isNotEmpty) {
        final winner = topResults.first;
        debugPrint('[CONSTRAINT-WINNER] Selected: "${winner['title']}" (Match strength: ${winner['matchStrength']})');
      } else {
        debugPrint('[CONSTRAINT-NO-MATCHES] No items matched all constraints with sufficient strength');
      }
      
      return topResults.map((item) => MediaSearchResult(
        mediaId: item['mediaId'] as String,
        title: item['title'] as String?,
        artist: item['artist'] as String?,
        album: item['album'] as String?,
        description: item['description'] as String?,
        themes: item['themes'] as String?,
        wikiUrl: item['wikiUrl'] as String?,
        wikidataId: item['wikidataId'] as String?,
        coverArtUrl: item['coverArtUrl'] as String?,
        similarity: item['matchStrength'] as double,
        mediaType: mediaType,
      )).toList();
      
    } catch (e) {
      debugPrint('❌ [CONSTRAINT-SEARCH] Error in constraint-based search: $e');
      return [];
    }
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
          
          if (similarity >= minSimilarity && !excludeIds.contains(row['media_id'])) {
            similarities.add({
              'mediaId': row['media_id'] as String,
              'title': row['title'] as String?,  // Allow null titles
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
        title: item['title'] as String?,  // Allow null titles
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

  /// 🎯 Get themes for a specific media ID
  Future<List<String>> _getThemesForMediaId(Database db, String mediaId) async {
    try {
      final stmt = db.prepare('SELECT themes FROM media_vectors WHERE media_id = ?');
      final result = stmt.select([mediaId]);
      stmt.dispose();
      
      if (result.isEmpty) {
        return [];
      }
      
      final themesString = result.first['themes'] as String? ?? '';
      if (themesString.trim().isEmpty) {
        return [];
      }
      
      // Split themes by comma and clean them up
      return themesString
          .split(',')
          .map((theme) => theme.trim().toLowerCase())
          .where((theme) => theme.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('⚠️ Error getting themes for $mediaId: $e');
      return [];
    }
  }

  /// 🎯 Get title and artist info for a specific media ID
  Future<Map<String, String>?> _getTitleInfoForMediaId(Database db, String mediaId) async {
    try {
      final stmt = db.prepare('SELECT title, artist FROM media_vectors WHERE media_id = ?');
      final result = stmt.select([mediaId]);
      stmt.dispose();
      
      if (result.isEmpty) {
        return null;
      }
      
      return {
        'title': result.first['title'] as String? ?? 'Unknown Title',
        'artist': result.first['artist'] as String? ?? '',
      };
    } catch (e) {
      debugPrint('⚠️ Error getting title info for $mediaId: $e');
      return null;
    }
  }

  /// 🎯 Get theme analysis for reasoning generation
  /// Returns the themes selected by the algorithm and which titles contributed to those themes
  Future<Map<String, dynamic>> getThemeAnalysisForReasoning({
    required String mediaType,
    required List<String> likedItemIds,
    required List<String> dislikedItemIds,
    List<String> favoriteItemIds = const [],
  }) async {
    try {
      await _ensureInitialized();
      
      if (!_shards.containsKey(mediaType)) {
        return {'selectedThemes': <String>[], 'themeTitles': <String, List<Map<String, String>>>{}};
      }

      final db = _shards[mediaType]!;
      final themeFrequency = <String, double>{};
      final themeToTitles = <String, List<Map<String, String>>>{};
      
      // Get themes from favorites (supreme weight = 3.0)
      for (final mediaId in favoriteItemIds) {
        final themes = await _getThemesForMediaId(db, mediaId);
        final titleInfo = await _getTitleInfoForMediaId(db, mediaId);
        if (titleInfo != null) {
          for (final theme in themes) {
            themeFrequency[theme] = (themeFrequency[theme] ?? 0.0) + 3.0;
            themeToTitles[theme] ??= [];
            if (!themeToTitles[theme]!.any((info) => info['mediaId'] == mediaId)) {
              themeToTitles[theme]!.add({
                'mediaId': mediaId,
                'title': titleInfo['title']!,
                'artist': titleInfo['artist'] ?? '',
                'type': 'favorite'
              });
            }
          }
        }
      }
      
      // Get themes from likes (great weight = 2.0)
      for (final mediaId in likedItemIds) {
        final themes = await _getThemesForMediaId(db, mediaId);
        final titleInfo = await _getTitleInfoForMediaId(db, mediaId);
        if (titleInfo != null) {
          for (final theme in themes) {
            themeFrequency[theme] = (themeFrequency[theme] ?? 0.0) + 2.0;
            themeToTitles[theme] ??= [];
            if (!themeToTitles[theme]!.any((info) => info['mediaId'] == mediaId)) {
              themeToTitles[theme]!.add({
                'mediaId': mediaId,
                'title': titleInfo['title']!,
                'artist': titleInfo['artist'] ?? '',
                'type': 'liked'
              });
            }
          }
        }
      }
      
      if (themeFrequency.isEmpty) {
        return {'selectedThemes': <String>[], 'themeTitles': <String, List<Map<String, String>>>{}};
      }
      
      // Select 2-3 positive themes (same logic as main algorithm)
      final sortedThemes = themeFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final selectedPositiveThemes = <String>[];
      final random = Random();
      
      // Always take top 2 themes
      if (sortedThemes.isNotEmpty) {
        selectedPositiveThemes.add(sortedThemes[0].key);
      }
      if (sortedThemes.length > 1) {
        selectedPositiveThemes.add(sortedThemes[1].key);
      }
      
      // Occasionally add a 3rd theme for variety (30% chance)
      if (sortedThemes.length > 2 && random.nextDouble() < 0.3) {
        selectedPositiveThemes.add(sortedThemes[2].key);
      }
      
      // Build the result with selected themes and their contributing titles
      final selectedThemeTitles = <String, List<Map<String, String>>>{};
      for (final theme in selectedPositiveThemes) {
        selectedThemeTitles[theme] = themeToTitles[theme] ?? [];
      }
      
      debugPrint('[THEME-ANALYSIS] Selected themes: ${selectedPositiveThemes.join(', ')}');
      
      return {
        'selectedThemes': selectedPositiveThemes,
        'themeTitles': selectedThemeTitles,
      };
      
    } catch (e) {
      debugPrint('⚠️ Error in theme analysis: $e');
      return {'selectedThemes': <String>[], 'themeTitles': <String, List<Map<String, String>>>{}};
    }
  }

  /// 🎯 Calculate theme-based match score (0.0 to 1.0) - optimized for 2-3 themes
  double _calculateThemeMatchScore(
    List<String> itemThemes,
    List<String> positiveThemes,
    List<String> negativeThemes,
  ) {
    if (itemThemes.isEmpty || positiveThemes.isEmpty) {
      return 0.0;
    }
    
    // Check for negative theme overlap (immediate rejection)
    final negativeOverlap = itemThemes.where((theme) => negativeThemes.contains(theme)).length;
    if (negativeOverlap > 0) {
      return 0.0; // Any negative theme overlap = reject (simple and effective)
    }
    
    // Calculate positive theme overlap
    final positiveOverlap = itemThemes.where((theme) => positiveThemes.contains(theme)).length;
    
    if (positiveOverlap == 0) {
      return 0.0; // No positive overlap
    }
    
    // Score based on overlap ratio
    // With 2 themes: 1 match = 0.5, 2 matches = 1.0
    // With 3 themes: 1 match = 0.33, 2 matches = 0.67, 3 matches = 1.0
    final positiveScore = positiveOverlap / positiveThemes.length;
    
    return positiveScore.clamp(0.0, 1.0);
  }

  /// 🎯 Optimized version for large datasets (processes in batches)
  Future<List<MediaSearchResult>> searchBySimilarityOptimized({
    required String referenceMediaId,
    required String mediaType,
    int limit = 20,
    double minSimilarity = 0.6,
    List<String> excludeIds = const [],
    int batchSize = 100,                       // Smaller batches for mobile isolates
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
        title: item['title'] as String?,  // Allow null titles
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
  /// Finds items that match user's behavioral patterns using theme-frequency matching
  Future<List<MediaSearchResult>> searchByBehavioralMatch({
    required String mediaType,
    required List<String> likedItemIds,        // Liked items (great weight)
    required List<String> dislikedItemIds,     // Disliked items (avoid themes)
    List<String> favoriteItemIds = const [],   // Favorite items (supreme weight)
    List<String> watchlistItemIds = const [],  // Watchlist items (ignored for now)
    List<String> skippedItemIds = const [],    // Skipped items (ignored - too noisy)
    List<String> excludeIds = const [],        // Already recommended items
    List<String> userConstraints = const [],   // User-defined constraints
    int limit = 1,                             // Usually just need 1 suggestion
    int batchSize = 100,                       // Smaller batches for mobile isolates
    double similarityThreshold = 0.5,          // From user settings
    int themesCount = 3,                       // From user settings
  }) async {
    try {
      debugPrint('[FUNCTION-START] Entering searchByBehavioralMatch for $mediaType');
      
      await _ensureInitialized();
      
      if (!_shards.containsKey(mediaType)) {
        throw Exception('Media type $mediaType not available');
      }

      debugPrint('[BEHAVIORAL-START] Beginning searchByBehavioralMatch for $mediaType with limit=$limit');
      debugPrint('[SETTINGS] Using similarity threshold: $similarityThreshold, themes count: $themesCount');
      final db = _shards[mediaType]!;
      
      // 🔍 LOG THE BEHAVIORAL INPUT DATA
      debugPrint('[THEME-BEHAVIORAL] === THEME-FREQUENCY MATCHING INPUT ===');
      debugPrint('[THEME-BEHAVIORAL] Media Type: $mediaType');
      debugPrint('[THEME-BEHAVIORAL] Liked IDs (${likedItemIds.length}): ${likedItemIds.map((id) => '"$id"').join(', ')}');
      debugPrint('[THEME-BEHAVIORAL] Disliked IDs (${dislikedItemIds.length}): ${dislikedItemIds.map((id) => '"$id"').join(', ')}');
      debugPrint('[THEME-BEHAVIORAL] Favorite IDs (${favoriteItemIds.length}): ${favoriteItemIds.map((id) => '"$id"').join(', ')}');
      debugPrint('[THEME-BEHAVIORAL] === END BEHAVIORAL INPUT ===');
      
      // Step 1: Extract and count themes from positive signals (favorites + likes)
      final themeFrequency = <String, double>{};
      final negativeThemes = <String>{};
      final themeToTitles = <String, List<Map<String, String>>>{}; // Track which titles contribute to each theme
      
      // Get themes from favorites (supreme weight = 3.0)
      for (final mediaId in favoriteItemIds) {
        final themes = await _getThemesForMediaId(db, mediaId);
        final titleInfo = await _getTitleInfoForMediaId(db, mediaId);
        if (titleInfo != null) {
          for (final theme in themes) {
            themeFrequency[theme] = (themeFrequency[theme] ?? 0.0) + 3.0;
            themeToTitles[theme] ??= [];
            if (!themeToTitles[theme]!.any((info) => info['mediaId'] == mediaId)) {
              themeToTitles[theme]!.add({
                'mediaId': mediaId,
                'title': titleInfo['title']!,
                'artist': titleInfo['artist'] ?? '',
                'type': 'favorite'
              });
            }
          }
        }
      }
      
      // Get themes from likes (great weight = 2.0)
      for (final mediaId in likedItemIds) {
        final themes = await _getThemesForMediaId(db, mediaId);
        final titleInfo = await _getTitleInfoForMediaId(db, mediaId);
        if (titleInfo != null) {
          for (final theme in themes) {
            themeFrequency[theme] = (themeFrequency[theme] ?? 0.0) + 2.0;
            themeToTitles[theme] ??= [];
            if (!themeToTitles[theme]!.any((info) => info['mediaId'] == mediaId)) {
              themeToTitles[theme]!.add({
                'mediaId': mediaId,
                'title': titleInfo['title']!,
                'artist': titleInfo['artist'] ?? '',
                'type': 'liked'
              });
            }
          }
        }
      }
      
      // Get negative themes from dislikes (to avoid)
      for (final mediaId in dislikedItemIds) {
        final themes = await _getThemesForMediaId(db, mediaId);
        negativeThemes.addAll(themes);
      }
      
      if (themeFrequency.isEmpty) {
        debugPrint('⚠️ No positive themes found, falling back to random');
        debugPrint('⚠️ [BEHAVIORAL-END] Returning empty list - no themes');
        return [];
      }
      
      // Step 2: Select themes based on user's themesCount setting
      final sortedThemes = themeFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final selectedPositiveThemes = <String>[];
      final random = Random();
      
      // Use the user's themesCount setting instead of hardcoded 2-3
      final targetThemeCount = themesCount.clamp(1, sortedThemes.length);
      
      // Select the top themes up to the user's preference
      for (int i = 0; i < targetThemeCount && i < sortedThemes.length; i++) {
        selectedPositiveThemes.add(sortedThemes[i].key);
      }
      
      // Step 3: Select 1 negative theme to avoid (keep it simple)
      final selectedNegativeThemes = negativeThemes.take(1).toList();
      
      debugPrint('[THEME-MATCHING] Selected Positive Themes (${selectedPositiveThemes.length}): ${selectedPositiveThemes.join(', ')}');
      debugPrint('[THEME-MATCHING] Selected Negative Themes (${selectedNegativeThemes.length}): ${selectedNegativeThemes.join(', ')}');
      
      // Store theme mapping data for reasoning generation
      final selectedThemeTitles = <String, List<Map<String, String>>>{};
      for (final theme in selectedPositiveThemes) {
        selectedThemeTitles[theme] = themeToTitles[theme] ?? [];
      }
      
      // Log user constraints if any
      if (userConstraints.isNotEmpty) {
        debugPrint('[USER-CONSTRAINTS] Active constraints:');
        for (final constraint in userConstraints) {
          debugPrint('   - $constraint');
        }
      } else {
        debugPrint('[USER-CONSTRAINTS] No active constraints');
      }
      
      // Step 4: Get total count and prepare for batch processing  
      final countStmt = db.prepare('SELECT COUNT(*) as count FROM media_vectors');
      final countResult = countStmt.select([]);
      countStmt.dispose();
      
      final totalCount = countResult.first['count'] as int;
      debugPrint('[THEME-SCAN] Processing $totalCount items in batches of $batchSize...');
      
      // Step 5: Filter excludeIds to only include those that exist in the vector database
      final validExcludeIds = <String>{};
      if (excludeIds.isNotEmpty) {
        debugPrint('[EXCLUSION-FILTER] Filtering exclusion IDs to only those in vector database...');
        debugPrint('[EXCLUSION-FILTER] Checking ${excludeIds.length} exclusion IDs against vector database...');
        
        // Check which exclude IDs actually exist in the database
        for (final excludeId in excludeIds) {
          final checkStmt = db.prepare('SELECT 1 FROM media_vectors WHERE media_id = ? LIMIT 1');
          final checkResult = checkStmt.select([excludeId]);
          checkStmt.dispose();
          
          if (checkResult.isNotEmpty) {
            validExcludeIds.add(excludeId);
            debugPrint('[EXCLUSION-FOUND] Valid exclusion ID: $excludeId');
          } else {
            debugPrint('[EXCLUSION-MISSING] ID not in vector DB: $excludeId');
          }
        }
      }
      
      // Step 6: Process items in batches to find matches
      final hasAlbum = mediaType == 'music';
      final candidates = <Map<String, dynamic>>[];
      
      int itemsProcessed = 0;
      int itemsMatched = 0;
      
      debugPrint('[THEME-SCAN] Starting batch processing...');
      
      for (int offset = 0; offset < totalCount; offset += batchSize) {
        final batchStmt = db.prepare('''
          SELECT media_id, title, artist, ${hasAlbum ? 'album,' : ''} description, themes, 
                 wiki_url, wikidata_id, image_url
          FROM media_vectors 
          LIMIT ? OFFSET ?
        ''');
        
        final batchResults = batchStmt.select([batchSize, offset]);
        batchStmt.dispose();
        
        for (final row in batchResults) {
          try {
            debugPrint('[ROW-START] Processing row ${itemsProcessed + 1}...');
            
            // Safe access to row data with detailed error reporting
            String mediaId;
            try {
              debugPrint('[ROW-ACCESS] Accessing media_id from row...');
              final rawMediaId = row['media_id'];
              debugPrint('[ROW-ACCESS] Raw media_id value: $rawMediaId (type: ${rawMediaId.runtimeType})');
              
              if (rawMediaId == null) {
                debugPrint('❌ [ROW-ERROR] media_id is null in row ${itemsProcessed + 1}');
                continue;
              }
              
              mediaId = rawMediaId as String;
              debugPrint('[ROW-ACCESS] Successfully cast media_id to String: $mediaId');
            } catch (e) {
              debugPrint('❌ [ROW-ACCESS-ERROR] Failed to access media_id from row ${itemsProcessed + 1}: $e');
              debugPrint('❌ [ROW-ACCESS-ERROR] Row keys: ${row.keys.toList()}');
              continue;
            }
            
            itemsProcessed++;
            debugPrint('[ROW-BASIC] Got mediaId: $mediaId');
            
            // Skip excluded items (only checking valid IDs that exist in vector DB)
            if (validExcludeIds.contains(mediaId)) {
              final title = row['title'] as String? ?? 'Unknown Title';
              debugPrint('[ROW-SKIPPED] Skipped excluded item: "$title" (ID: $mediaId)');
              continue;
            }
          
          // Step 6: Apply theme-based matching (much simpler!)
          debugPrint('[THEMES-PARSE] Parsing themes from row data for $mediaId...');
          
          // Declare variables outside try block for proper scope
          List<String> itemThemes;
          double matchScore;
          
          try {
            final themesString = row['themes'] as String? ?? '';
            debugPrint('[THEMES-RAW] Raw themes string: "${themesString.substring(0, min(50, themesString.length))}${themesString.length > 50 ? '...' : ''}"');
            
            itemThemes = themesString.trim().isEmpty ? <String>[] : 
              themesString.split(',').map((theme) => theme.trim().toLowerCase()).where((theme) => theme.isNotEmpty).toList();
            debugPrint('[THEMES-PARSE] Got themes: ${itemThemes.take(3).join(', ')}${itemThemes.length > 3 ? '...' : ''}');
            
            debugPrint('[SCORE-DEBUG] About to calculate match score...');
            matchScore = _calculateThemeMatchScore(
              itemThemes, 
              selectedPositiveThemes, 
              selectedNegativeThemes
            );
            debugPrint('[SCORE-DEBUG] Calculated score: $matchScore');
          } catch (e) {
            debugPrint('❌ [THEMES-ERROR] Error parsing themes for $mediaId: $e');
            debugPrint('[ROW-COMPLETE] Skipping problematic row ${itemsProcessed}: $mediaId due to theme parsing error');
            continue;
          }
          
          // Use the user's similarity threshold instead of hardcoded 0.25
          // Convert score to match threshold (0.33 = 1/3 themes match, 0.5 = 1/2 themes match, etc.)
          final minThreshold = (1.0 / targetThemeCount) * similarityThreshold;
          
          try {
            debugPrint('[POST-SCORE] Processing score: $matchScore for ${row['title']} (threshold: $minThreshold)');
            
            if (matchScore >= minThreshold) {
            itemsMatched++;
            
            final title = row['title'] as String? ?? 'Unknown Title';
            debugPrint('[THEME-MATCH] 📈 "$title" scored ${matchScore.toStringAsFixed(3)} - ACCEPTED (threshold: ${minThreshold.toStringAsFixed(3)})');
            debugPrint('[THEME-DETAILS]   - Media ID: $mediaId');
            debugPrint('[THEME-DETAILS]   - Item themes: ${itemThemes.join(', ')}');
            debugPrint('[THEME-OVERLAP]   - Positive overlap: ${itemThemes.where((t) => selectedPositiveThemes.contains(t)).toList()}');
            debugPrint('[THEME-AVOID]     - Negative overlap: ${itemThemes.where((t) => selectedNegativeThemes.contains(t)).toList()}');
            
            debugPrint('[CANDIDATE-ADD] About to add candidate to list (current count: ${candidates.length})');
            try {
              candidates.add({
                'mediaId': mediaId,
                'title': title,
                'artist': row['artist'] as String?,
                'album': hasAlbum ? row['album'] as String? : null,
                'description': row['description'] as String?,
                'themes': row['themes'] as String?,
                'wikiUrl': row['wiki_url'] as String?,
                'wikidataId': row['wikidata_id'] as String?,
                'coverArtUrl': row['image_url'] as String?,
                'matchScore': matchScore,
                'itemThemes': itemThemes,
              });
              debugPrint('[CANDIDATE-ADD] ✅ Successfully added candidate! New count: ${candidates.length}');
            } catch (e) {
              debugPrint('[CANDIDATE-ADD] ❌ ERROR adding candidate: $e');
            }
          } else {
            // Log close misses for debugging
            debugPrint('[THEME-MISSED] 📉 "${row['title']}" scored ${matchScore.toStringAsFixed(3)} - REJECTED (threshold: ${minThreshold.toStringAsFixed(3)})');
            debugPrint('[MISS-THEMES]   - Item themes: ${itemThemes.take(3).join(', ')}${itemThemes.length > 3 ? '...' : ''}');
          }
          
          debugPrint('[ROW-COMPLETE] Row completed');
          
          } catch (e, stackTrace) {
            debugPrint('❌ [SCORE-PROCESSING-ERROR] Critical error processing score for $mediaId: $e');
            debugPrint('❌ [SCORE-PROCESSING-STACK] Stack trace: $stackTrace');
            continue; // Skip problematic rows
          }
          } catch (e) {
            debugPrint('[ROW-ERROR] Error processing row $itemsProcessed: $e');
            continue; // Skip problematic rows
          }
        }
        
        debugPrint('[BATCH-COMPLETE] Finished processing batch at offset $offset, found ${candidates.length} total candidates');
        
        // Yield control to prevent isolate blocking
        await Future.delayed(Duration.zero);
        
        // 🚀 ENHANCED EARLY EXIT: Allow much more exploration for variety
        debugPrint('[EARLY-CHECK] Checking early exit: ${candidates.length} candidates found');
        
        // More permissive early exit - collect more candidates before stopping
        if (candidates.length >= (limit * 5)) {
          debugPrint('[EARLY-EXIT] Found sufficient candidates (${candidates.length}), stopping early');
          break;
        }
      }
      
      debugPrint('[SCAN-COMPLETE] Finished processing $itemsProcessed items, found ${candidates.length} candidates ($itemsMatched matched)');
      
      // Step 7: Sort and return top matches
      candidates.sort((a, b) => (b['matchScore'] as double).compareTo(a['matchScore'] as double));
      final topResults = candidates.take(limit).toList();
      
      debugPrint('[RESULTS] Selected top ${topResults.length} results from ${candidates.length} candidates');
      
      if (topResults.isNotEmpty) {
        final winner = topResults.first;
        debugPrint('[FINAL-MATCH] Selected: "${winner['title'] ?? 'NULL'}" (Score: ${winner['matchScore']})');
        debugPrint('[FINAL-MATCH] Selected media_id: ${winner['mediaId']}');
        debugPrint('[MATCH-THEMES] Item themes: ${(winner['itemThemes'] as List<String>).join(', ')}');
        debugPrint('[MATCH-REASONING] Selected positive themes: ${selectedPositiveThemes.join(', ')}');
        
        // 🔍 CRITICAL DEBUG: Verify this item wasn't supposed to be excluded
        final selectedMediaId = winner['mediaId'] as String;
        if (excludeIds.contains(selectedMediaId)) {
          debugPrint('🚨 [EXCLUSION-ERROR] CRITICAL BUG: Selected item "$selectedMediaId" was in exclusion list!');
          debugPrint('🚨 [EXCLUSION-ERROR] This indicates a serious bug in the exclusion logic');
        } else {
          debugPrint('✅ [EXCLUSION-CHECK] Selected item "$selectedMediaId" correctly not in exclusion list');
        }
      } else {
        debugPrint('[NO-MATCHES] No behavioral matches found despite scanning ${candidates.length} candidates');
      }
      
      try {
        debugPrint('[RESULT-MAPPING] Converting ${topResults.length} candidates to MediaSearchResult objects...');
        final results = topResults.map((item) => MediaSearchResult(
          mediaId: item['mediaId'] as String,
          title: (item['title'] as String?) ?? 'Unknown Title',
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
        debugPrint('[RESULT-MAPPING] Successfully converted ${results.length} results');
        debugPrint('[BEHAVIORAL-END] Returning ${results.length} results from searchByBehavioralMatch');
        return results;
      } catch (e) {
        debugPrint('❌ [RESULT-MAPPING] Error converting results: $e');
        debugPrint('❌ [BEHAVIORAL-END] Returning empty list due to mapping error');
        return [];
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error in behavioral matching: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('❌ [BEHAVIORAL-END] Returning empty list due to exception');
      return [];
    }
  }

  /// Get embeddings for all behavioral signals
  Future<Map<String, dynamic>> _getBehavioralEmbeddings(
    Database db,
    List<String> likedItemIds,
    List<String> dislikedItemIds,
    List<String> favoriteItemIds,
    List<String> watchlistItemIds,
    List<String> skippedItemIds,
  ) async {
    // 🔍 LOG EXACTLY WHAT WE'RE HASHING FOR
    debugPrint('[ISOLATE-THEMES] === BEHAVIORAL EMBEDDING LOOKUP ===');
    debugPrint('[ISOLATE-THEMES] About to look up embeddings for:');
    debugPrint('[ISOLATE-THEMES]   - Liked IDs: ${likedItemIds.map((id) => '"$id"').join(', ')}');
    debugPrint('[ISOLATE-THEMES]   - Disliked IDs: ${dislikedItemIds.map((id) => '"$id"').join(', ')}');
    debugPrint('[ISOLATE-THEMES]   - Favorite IDs: ${favoriteItemIds.map((id) => '"$id"').join(', ')}');
    debugPrint('[ISOLATE-THEMES]   - Watchlist IDs: ${watchlistItemIds.map((id) => '"$id"').join(', ')}');
    debugPrint('[ISOLATE-THEMES]   - Skipped IDs: ${skippedItemIds.map((id) => '"$id"').join(', ')}');
    debugPrint('[ISOLATE-THEMES] === END BEHAVIORAL EMBEDDING LOOKUP ===');
    final result = {
      'liked': <List<double>>[],
      'disliked': <List<double>>[],
      'favorites': <List<double>>[],
      'watchlist': <List<double>>[],
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
    
    // Get favorite embeddings (multiple favorites)
    for (final id in favoriteItemIds) {
      final embedding = await _getEmbeddingById(db, id);
      if (embedding != null) {
        (result['favorites'] as List<List<double>>).add(embedding);
      }
    }
    
    // Get watchlist embeddings
    for (final id in watchlistItemIds) {
      final embedding = await _getEmbeddingById(db, id);
      if (embedding != null) {
        (result['watchlist'] as List<List<double>>).add(embedding);
      }
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

  /// Get themes for all behavioral signals to log what's driving matching
  Future<Map<String, dynamic>> _getBehavioralThemes(
    Database db,
    List<String> likedItemIds,
    List<String> dislikedItemIds,
    List<String> favoriteItemIds,
    List<String> watchlistItemIds,
    List<String> skippedItemIds,
  ) async {
    final result = {
      'liked': <Map<String, String>>[],
      'disliked': <Map<String, String>>[],
      'favorites': <Map<String, String>>[],
      'watchlist': <Map<String, String>>[],
      'skipped': <Map<String, String>>[],
    };
    
    // Get liked themes
    for (final id in likedItemIds) {
      final themeData = await _getThemeDataById(db, id);
      if (themeData != null) {
        (result['liked'] as List<Map<String, String>>).add(themeData);
      }
    }
    
    // Get disliked themes
    for (final id in dislikedItemIds) {
      final themeData = await _getThemeDataById(db, id);
      if (themeData != null) {
        (result['disliked'] as List<Map<String, String>>).add(themeData);
      }
    }
    
    // Get favorite themes
    for (final id in favoriteItemIds) {
      final themeData = await _getThemeDataById(db, id);
      if (themeData != null) {
        (result['favorites'] as List<Map<String, String>>).add(themeData);
      }
    }
    
    // Get watchlist themes
    for (final id in watchlistItemIds) {
      final themeData = await _getThemeDataById(db, id);
      if (themeData != null) {
        (result['watchlist'] as List<Map<String, String>>).add(themeData);
      }
    }
    
    // Get skipped themes
    for (final id in skippedItemIds) {
      final themeData = await _getThemeDataById(db, id);
      if (themeData != null) {
        (result['skipped'] as List<Map<String, String>>).add(themeData);
      }
    }
    
    return result;
  }

  /// Get theme data by media ID for logging
  Future<Map<String, String>?> _getThemeDataById(Database db, String mediaId) async {
    try {
      final stmt = db.prepare('SELECT title, artist, themes FROM media_vectors WHERE media_id = ?');
      final result = stmt.select([mediaId]);
      stmt.dispose();
      
      if (result.isNotEmpty) {
        final row = result.first;
        return {
          'title': row['title'] as String,
          'artist': (row['artist'] as String?) ?? '',
          'themes': (row['themes'] as String?) ?? '',
        };
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error getting theme data for $mediaId: $e');
      return null;
    }
  }

  /// Log behavioral themes that are driving the matching
  void _logBehavioralThemes(Map<String, dynamic> behavioralThemes) {
    final likedThemes = behavioralThemes['liked'] as List<Map<String, String>>;
    final favoriteThemes = behavioralThemes['favorites'] as List<Map<String, String>>;
    final watchlistThemes = behavioralThemes['watchlist'] as List<Map<String, String>>;
    final dislikedThemes = behavioralThemes['disliked'] as List<Map<String, String>>;
    final skippedThemes = behavioralThemes['skipped'] as List<Map<String, String>>;
    
    debugPrint('[THEME-ANALYSIS] === BEHAVIORAL MATCHING DRIVERS ===');
    
    // Log favorite themes (strongest signal)
    if (favoriteThemes.isNotEmpty) {
      debugPrint('[FAVORITES] Seeking content similar to:');
      for (final item in favoriteThemes) {
        final themes = item['themes']?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).join(', ') ?? 'No themes';
        debugPrint('   - "${item['title']}" by ${item['artist']} -> Themes: $themes');
      }
    }
    
    // Log liked themes
    if (likedThemes.isNotEmpty) {
      debugPrint('[LIKED] Also considering:');
      for (final item in likedThemes) {
        final themes = item['themes']?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).join(', ') ?? 'No themes';
        debugPrint('   - "${item['title']}" by ${item['artist']} -> Themes: $themes');
      }
    }
    
    // Log watchlist themes
    if (watchlistThemes.isNotEmpty) {
      debugPrint('[WATCHLIST] Interested in:');
      for (final item in watchlistThemes) {
        final themes = item['themes']?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).join(', ') ?? 'No themes';
        debugPrint('   - "${item['title']}" by ${item['artist']} -> Themes: $themes');
      }
    }
    
    // Log what to avoid
    if (dislikedThemes.isNotEmpty) {
      debugPrint('[AVOIDING] Disliked themes:');
      for (final item in dislikedThemes) {
        final themes = item['themes']?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).join(', ') ?? 'No themes';
        debugPrint('   - "${item['title']}" by ${item['artist']} -> Avoid: $themes');
      }
    }
    
    if (skippedThemes.isNotEmpty) {
      debugPrint('[SKIPPED] Previously not interested:');
      for (final item in skippedThemes) {
        final themes = item['themes']?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).join(', ') ?? 'No themes';
        debugPrint('   - "${item['title']}" by ${item['artist']} -> Skipped: $themes');
      }
    }
    
    debugPrint('[THEME-ANALYSIS] === END BEHAVIORAL DRIVERS ===');
  }

  /// Evaluate if an item matches behavioral criteria
  Map<String, dynamic> _evaluateBehavioralMatch(
    List<double> itemEmbedding,
    Map<String, dynamic> behavioralEmbeddings, {
    String? mediaTitle,
    String? mediaArtist,
    String? mediaThemes,
  }) {
    final likedEmbeddings = behavioralEmbeddings['liked'] as List<List<double>>;
    final dislikedEmbeddings = behavioralEmbeddings['disliked'] as List<List<double>>;
    final favoriteEmbeddings = behavioralEmbeddings['favorites'] as List<List<double>>;
    final watchlistEmbeddings = behavioralEmbeddings['watchlist'] as List<List<double>>;
    final skippedEmbeddings = behavioralEmbeddings['skipped'] as List<List<double>>;
    
    // Calculate similarities
    double maxLikedSimilarity = 0.0;
    double maxFavoriteSimilarity = 0.0;
    double maxWatchlistSimilarity = 0.0;
    double maxDislikedSimilarity = 0.0;
    double maxSkippedSimilarity = 0.0;
    
    // Check against liked items
    for (final likedEmbedding in likedEmbeddings) {
      final similarity = _cosineSimilarity(itemEmbedding, likedEmbedding);
      if (similarity > maxLikedSimilarity) {
        maxLikedSimilarity = similarity;
      }
    }
    
    // Check against favorites
    for (final favoriteEmbedding in favoriteEmbeddings) {
      final similarity = _cosineSimilarity(itemEmbedding, favoriteEmbedding);
      if (similarity > maxFavoriteSimilarity) {
        maxFavoriteSimilarity = similarity;
      }
    }
    
    // Check against watchlist
    for (final watchlistEmbedding in watchlistEmbeddings) {
      final similarity = _cosineSimilarity(itemEmbedding, watchlistEmbedding);
      if (similarity > maxWatchlistSimilarity) {
        maxWatchlistSimilarity = similarity;
      }
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
    
    // 🎯 IMPROVED CRITERIA: Use behavioral data even with only negative signals
    // 1. Positive match criteria
    final hasPositiveMatch = maxLikedSimilarity >= 0.75 || 
                             maxFavoriteSimilarity >= 0.6 || 
                             maxWatchlistSimilarity >= 0.5;
    
    // 2. Negative filter criteria
    final passesDislikedFilter = maxDislikedSimilarity <= 0.25;
    final isLikelySkipped = maxSkippedSimilarity >= 0.75;
    
    // 3. Check if we have any positive signals at all
    final hasAnyPositiveSignals = likedEmbeddings.isNotEmpty || 
                                 favoriteEmbeddings.isNotEmpty || 
                                 watchlistEmbeddings.isNotEmpty;
    
    // 4. Final matching logic: 
    // - If we have positive signals: use normal criteria
    // - If only negative signals: just avoid bad stuff (find anything that passes filters)
    final isMatch = hasAnyPositiveSignals 
        ? (hasPositiveMatch && passesDislikedFilter && !isLikelySkipped)  // Normal criteria
        : (passesDislikedFilter && !isLikelySkipped);  // Only negative signals - just avoid bad stuff
    
    // Calculate overall match score (higher = better)
    double score = 0.0;
    
    if (hasAnyPositiveSignals) {
      // Normal scoring with positive signals
      if (hasPositiveMatch) {
        score += max(max(maxLikedSimilarity * 0.7, maxFavoriteSimilarity * 0.5), maxWatchlistSimilarity * 0.4);
      }
      if (passesDislikedFilter) {
        score += 0.2; // Bonus for passing dislike filter
      }
      if (isLikelySkipped) {
        score -= 0.3; // Penalty for being like skipped items
      }
    } else {
      // Only negative signals - score based on how well it avoids bad stuff
      score = 0.5; // Base score for passing negative filters
      score -= maxDislikedSimilarity * 0.5; // Penalty for similarity to disliked
      score -= maxSkippedSimilarity * 0.3; // Penalty for similarity to skipped
      if (passesDislikedFilter) {
        score += 0.3; // Higher bonus for avoiding disliked content
      }
      if (!isLikelySkipped) {
        score += 0.2; // Bonus for not being like skipped content
      }
    }
    
    // Log detailed similarity analysis for matches
    if (isMatch && mediaTitle != null) {
      final candidateThemes = mediaThemes?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).join(', ') ?? 'No themes';
      final artistInfo = mediaArtist?.isNotEmpty == true ? ' by $mediaArtist' : '';
      
      debugPrint('[VECTOR-MATCH] "$mediaTitle"$artistInfo - Score: ${score.toStringAsFixed(3)} | '
          'Liked: ${maxLikedSimilarity.toStringAsFixed(3)}, '
          'Favorites: ${maxFavoriteSimilarity.toStringAsFixed(3)}, '
          'Watchlist: ${maxWatchlistSimilarity.toStringAsFixed(3)}, '
          'Disliked: ${maxDislikedSimilarity.toStringAsFixed(3)}, '
          'Skipped: ${maxSkippedSimilarity.toStringAsFixed(3)}');
      debugPrint('[MATCHED-THEMES] "$mediaTitle" themes: $candidateThemes');
    } else if (mediaTitle != null && (maxFavoriteSimilarity > 0.3 || maxLikedSimilarity > 0.5)) {
      // Log near-misses for debugging
      final candidateThemes = mediaThemes?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).join(', ') ?? 'No themes';
      final artistInfo = mediaArtist?.isNotEmpty == true ? ' by $mediaArtist' : '';
      
      debugPrint('[VECTOR-NEAR] "$mediaTitle"$artistInfo - Score: ${score.toStringAsFixed(3)} | '
          'Liked: ${maxLikedSimilarity.toStringAsFixed(3)}, '
          'Favorites: ${maxFavoriteSimilarity.toStringAsFixed(3)}, '
          'Reason: ${!hasPositiveMatch ? "Low similarity" : !passesDislikedFilter ? "Too similar to disliked" : "Too similar to skipped"}');
      debugPrint('[NEAR-THEMES] "$mediaTitle" themes: $candidateThemes');
    }
    
    return {
      'isMatch': isMatch,
      'matchScore': score,  // Using matchScore key as expected by calling code
      'maxLikedSimilarity': maxLikedSimilarity,
      'maxFavoriteSimilarity': maxFavoriteSimilarity,
      'maxWatchlistSimilarity': maxWatchlistSimilarity,
      'maxDislikedSimilarity': maxDislikedSimilarity,
      'maxSkippedSimilarity': maxSkippedSimilarity,
    };
  }
}

/// Media search result model
class MediaSearchResult {
  final String mediaId;
  final String? title;  // Now nullable to handle data quality issues
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
    this.title,  // Now nullable
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

  /// Get smart display information that handles null titles gracefully
  MediaDisplayInfo get displayInfo => MediaDisplayHelper.resolveDisplayInfo(
    title: title,
    artist: artist,
    fallbackTitle: 'Unknown ${mediaType.replaceAll('_', ' ')}',
  );

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
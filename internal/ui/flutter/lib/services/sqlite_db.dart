import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'recommendation_service.dart';
import '../queries/queries.dart';

// Missing query constants
const String insertMediaTypesQuery = '''
  INSERT OR IGNORE INTO media_types (name) VALUES 
    ('music'), ('movie'), ('tv_show'), ('video_game'), ('book');
''';

const String insertRecommendationStatusQuery = '''
  INSERT OR IGNORE INTO recommendation_status (name) VALUES 
    ('pending'), ('liked'), ('disliked'), ('skipped'), ('added'), ('watchlist');
''';

/// SQLite database service for the normalized schema
class SQLiteDatabase {
  static Database? _db;
  static bool _initialized = false;

  /// Initialize the database
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Use the same directory as vector databases
      final appDir = await getApplicationSupportDirectory();
      final dbPath = path.join(appDir.path, 'interestnaut.db');
      
      // Check if database exists
      final dbExists = await File(dbPath).exists();
      
      _db = sqlite3.open(dbPath);
      
      if (dbExists) {
        debugPrint('✅ Existing database found, checking for schema updates...');
        await _migrateSchema();
      } else {
        debugPrint('✅ Creating new database with full schema...');
        await _createTables();
      }
      
      _initialized = true;
      debugPrint('✅ Database initialized successfully with new schema at: $dbPath');
    } catch (e) {
      debugPrint('❌ Error initializing database: $e');
      rethrow;
    }
  }

  /// Reset and reinitialize the database (for schema changes)
  Future<void> reset() async {
    try {
      _db?.dispose();
      _db = null;
      _initialized = false;
      await init();
      debugPrint('✅ Database reset and reinitialized with new schema');
    } catch (e) {
      debugPrint('❌ Error resetting database: $e');
      rethrow;
    }
  }

  /// Migrate existing database schema
  Future<void> _migrateSchema() async {
    try {
      debugPrint('🔄 Starting database schema migration...');
      
      // Drop deprecated tables first
      await _dropDeprecatedTables();
      
      // Check for missing tables and create them
      await _ensureAllTablesExist();
      
      // Migrate table columns if needed
      await _migrateTableColumns();
      
      // Ensure default data is present
      await _ensureDefaultData();
      
      debugPrint('✅ Database schema migration completed successfully');
    } catch (e) {
      debugPrint('❌ Error during schema migration: $e');
      rethrow;
    }
  }

  /// Drop deprecated tables
  Future<void> _dropDeprecatedTables() async {
    try {
      // Drop user_constraints table if it exists
      final userConstraintsExists = await _tableExists('user_constraints');
      if (userConstraintsExists) {
        _db!.execute('DROP TABLE user_constraints');
        debugPrint('✅ Dropped deprecated user_constraints table');
      }
      
      // Add other deprecated tables here if needed in the future
      // _db!.execute('DROP TABLE IF EXISTS other_deprecated_table');
      
    } catch (e) {
      debugPrint('❌ Error dropping deprecated tables: $e');
      rethrow;
    }
  }

  /// Ensure all required tables exist
  Future<void> _ensureAllTablesExist() async {
    try {
      final requiredTables = [
        {'name': 'media_types', 'query': createMediaTypesTableQuery},
        {'name': 'recommendation_status', 'query': createRecommendationStatusTableQuery},
        {'name': 'media_items', 'query': createMediaItemsTableQuery},
        {'name': 'recommendations', 'query': createRecommendationsTableQuery},
        {'name': 'favorites', 'query': createFavoritesTableQuery},
        {'name': 'watchlist', 'query': createWatchlistTableQuery},
        {'name': 'media_metadata', 'query': createMediaMetadataTableQuery},
        {'name': 'media_blends', 'query': createMediaBlendsTableQuery},
        {'name': 'media_matching', 'query': createMediaMatchingTableQuery},
        {'name': 'media_priority_titles', 'query': createMediaPriorityTitlesTableQuery},
        {'name': 'media_settings', 'query': createMediaSettingsTableQuery},
        {'name': 'general_settings', 'query': createGeneralSettingsTableQuery},
      ];
      
      for (final table in requiredTables) {
        final exists = await _tableExists(table['name']!);
        if (!exists) {
          debugPrint('🔄 Creating missing table: ${table['name']}');
          _db!.execute(table['query']!);
          debugPrint('✅ Created table: ${table['name']}');
        } else {
          debugPrint('✅ Table already exists: ${table['name']}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error ensuring tables exist: $e');
      rethrow;
    }
  }

  /// Migrate table columns for schema updates
  Future<void> _migrateTableColumns() async {
    try {
      // Add new columns to media_items table if they don't exist
      await _addColumnIfNotExists('media_items', 'youtube_id', 'TEXT');
      await _addColumnIfNotExists('media_items', 'spotify_id', 'TEXT');
      await _addColumnIfNotExists('media_items', 'genres', 'TEXT');
      
      debugPrint('✅ Column migration completed');
    } catch (e) {
      debugPrint('❌ Error migrating table columns: $e');
      rethrow;
    }
  }
  
  /// Add a column to a table if it doesn't already exist
  Future<void> _addColumnIfNotExists(String tableName, String columnName, String columnType) async {
    final exists = await _columnExists(tableName, columnName);
    if (!exists) {
      debugPrint('🔄 Adding column $columnName to table $tableName');
      _db!.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnType');
      debugPrint('✅ Added column $columnName to table $tableName');
    } else {
      debugPrint('✅ Column $columnName already exists in table $tableName');
    }
  }
  

  /// Check if a column exists in a table
  Future<bool> _columnExists(String tableName, String columnName) async {
    try {
      final result = _db!.select('PRAGMA table_info($tableName)');
      for (final row in result) {
        if (row['name'] == columnName) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking column existence: $e');
      return false;
    }
  }

  /// Ensure default data is present
  Future<void> _ensureDefaultData() async {
    try {
      // Insert default media types
      _db!.execute(insertMediaTypesQuery);
      
      // Insert default recommendation status
      _db!.execute(insertRecommendationStatusQuery);
      
      debugPrint('✅ Default data ensured');
    } catch (e) {
      debugPrint('❌ Error ensuring default data: $e');
      rethrow;
    }
  }

  /// Check if a table exists
  Future<bool> _tableExists(String tableName) async {
    try {
      final stmt = _db!.prepare('''
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name=?
      ''');
      final result = stmt.select([tableName]);
      stmt.dispose();
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking table existence: $e');
      return false;
    }
  }

  /// Create all tables (for new databases)
  Future<void> _createTables() async {
    try {
      _db!.execute(createMediaTypesTableQuery);
      _db!.execute(createRecommendationStatusTableQuery);
      _db!.execute(createMediaItemsTableQuery);
      _db!.execute(createRecommendationsTableQuery);
      _db!.execute(createFavoritesTableQuery);
      _db!.execute(createWatchlistTableQuery);
      _db!.execute(createMediaMetadataTableQuery); // Keep for now, will remove later
      
      // New tables for media-specific settings
      _db!.execute(createMediaBlendsTableQuery);
      _db!.execute(createMediaMatchingTableQuery);
      _db!.execute(createMediaPriorityTitlesTableQuery);
      _db!.execute(createMediaSettingsTableQuery);
      _db!.execute(createGeneralSettingsTableQuery);
      
      // Insert default data
      _db!.execute(insertMediaTypesQuery);
      _db!.execute(insertRecommendationStatusQuery);
      
      debugPrint('✅ All tables created successfully with new schema');
    } catch (e) {
      debugPrint('❌ Error creating tables: $e');
      rethrow;
    }
  }

  /// Ensure database is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  /// Close the database
  Future<void> close() async {
    if (_initialized && _db != null) {
      _db!.dispose();
      _initialized = false;
      _db = null;
    }
  }

  // ===== MEDIA ITEMS =====

  /// Create or get existing media item
  Future<int> createOrGetMediaItem({
    required String mediaType,
    required String vectorMediaId,
    required String title,
    String? primaryCreator,
    String? coverArtUrl,
    String? description,
    String? wikiUrl,
    String? wikidataId,
    String? themes,
    String? genres,
    String? youtubeId,
    String? spotifyId,
  }) async {
    await _ensureInitialized();

    try {

      final mediaTypeId = await getMediaTypeId(mediaType);
      if (mediaTypeId == null) {
        throw Exception('Invalid media type: $mediaType');
      }

      final now = DateTime.now().toIso8601String();

      // Try to find existing media item
      final existingStmt = _db!.prepare(getMediaItemByTitleCreatorQuery);
      final existingResult = existingStmt.select([title, primaryCreator ?? '', mediaType]);

      if (existingResult.isNotEmpty) {
        final id = existingResult.first['id'] as int;
        existingStmt.dispose();
        return id;
      }
      existingStmt.dispose();

      // Create new media item
      final insertStmt = _db!.prepare(insertOrGetMediaItemQuery);
      insertStmt.execute([
        mediaTypeId,
        vectorMediaId,
        title,
        primaryCreator,
        coverArtUrl,
        description,
        wikiUrl,
        wikidataId,
        themes,
        genres,
        youtubeId,
        spotifyId,
        now,
        now,
      ]);

      final id = _db!.lastInsertRowId;
      insertStmt.dispose();
      return id;
    } catch (e) {
      debugPrint('Error creating or getting media item: $e');
      rethrow;
    }
  }

  /// Get media type ID by name
  Future<int?> getMediaTypeId(String mediaTypeName) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getMediaTypeIdQuery);
      final result = stmt.select([mediaTypeName]);

      if (result.isEmpty) {
        // Debug: Print all available media types
        final allTypes = await getAllMediaTypes();
        debugPrint('❌ Media type "$mediaTypeName" not found. Available types: ${allTypes.map((t) => t['name']).join(', ')}');
        stmt.dispose();
        return null;
      }

      final id = result.first['id'] as int;
      stmt.dispose();
      debugPrint('✅ Found media type "$mediaTypeName" with ID: $id');
      return id;
    } catch (e) {
      debugPrint('Error getting media type ID: $e');
      return null;
    }
  }

  /// Get all media types
  Future<List<Map<String, dynamic>>> getAllMediaTypes() async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getAllMediaTypesQuery);
      final result = stmt.select([]);

      final mediaTypes = result.map((row) => {
        'id': row['id'] as int,
        'name': row['name'] as String,
      }).toList();

      stmt.dispose();
      return mediaTypes;
    } catch (e) {
      debugPrint('Error getting all media types: $e');
      return [];
    }
  }

  // ===== FAVORITES =====

  /// Add item to favorites
  Future<void> addToFavorites(int mediaItemId) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(addToFavoritesQuery);
      stmt.execute([mediaItemId, DateTime.now().toIso8601String()]);
      stmt.dispose();
      debugPrint('✅ Added to favorites (media_item_id: $mediaItemId)');
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
      rethrow;
    }
  }

  /// Remove from favorites
  Future<void> removeFromFavorites(int mediaItemId) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(removeFromFavoritesQuery);
      stmt.execute([mediaItemId]);
      stmt.dispose();
      debugPrint('✅ Removed from favorites (media_item_id: $mediaItemId)');
    } catch (e) {
      debugPrint('Error removing from favorites: $e');
      rethrow;
    }
  }

  /// Get the integer media_item_id from a vector_media_id string
  Future<int?> getMediaItemIdByVectorId(String vectorMediaId) async {
    await _ensureInitialized();

    try {
      const query = 'SELECT id FROM media_items WHERE vector_media_id = ?';
      final stmt = _db!.prepare(query);
      final result = stmt.select([vectorMediaId]);
      stmt.dispose();
      
      if (result.isNotEmpty) {
        return result.first['id'] as int;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting media_item_id for vector_media_id $vectorMediaId: $e');
      return null;
    }
  }

  /// Check if item is in favorites
  Future<bool> isInFavorites(int mediaItemId) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(isInFavoritesQuery);
      final result = stmt.select([mediaItemId]);

      final count = result.isNotEmpty ? result.first['count'] as int : 0;
      stmt.dispose();
      return count > 0;
    } catch (e) {
      debugPrint('Error checking if in favorites: $e');
      return false;
    }
  }

  /// Get favorites for a media type
  Future<List<MediaSuggestion>> getFavorites(String mediaType) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getFavoritesItemsQuery);
      final result = stmt.select([mediaType]);

      final suggestions = result.map((row) => _mapRowToMediaSuggestion(row)).toList();
      stmt.dispose();
      return suggestions;
    } catch (e) {
      debugPrint('Error getting favorites: $e');
      return [];
    }
  }

  /// Get all favorites for a media type (alias for getFavorites)
  Future<List<MediaSuggestion>> getAllFavorites(String mediaType) async {
    return getFavorites(mediaType);
  }

  // ===== WATCHLIST =====

  /// Add item to watchlist
  Future<void> addToWatchlist(int mediaItemId) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(addToWatchlistQuery);
      stmt.execute([mediaItemId, DateTime.now().toIso8601String()]);
      stmt.dispose();
      debugPrint('✅ Added to watchlist (media_item_id: $mediaItemId)');
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
      rethrow;
    }
  }

  /// Remove from watchlist
  Future<void> removeFromWatchlist(int mediaItemId) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(removeFromWatchlistQuery);
      stmt.execute([mediaItemId]);
      stmt.dispose();
      debugPrint('✅ Removed from watchlist (media_item_id: $mediaItemId)');
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
      rethrow;
    }
  }

  /// Check if item is in watchlist
  Future<bool> isInWatchlist(int mediaItemId) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(isInWatchlistQuery);
      final result = stmt.select([mediaItemId]);

      final count = result.isNotEmpty ? result.first['count'] as int : 0;
      stmt.dispose();
      return count > 0;
    } catch (e) {
      debugPrint('Error checking if in watchlist: $e');
      return false;
    }
  }

  /// Get watchlist for a media type
  Future<List<MediaSuggestion>> getWatchlist(String mediaType) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getWatchlistItemsQuery);
      final result = stmt.select([mediaType]);

      final suggestions = result.map((row) => _mapRowToMediaSuggestion(row)).toList();
      stmt.dispose();
      return suggestions;
    } catch (e) {
      debugPrint('Error getting watchlist: $e');
      return [];
    }
  }

  /// Move item from watchlist to favorites
  Future<void> moveFromWatchlistToFavorites(int mediaItemId) async {
    await _ensureInitialized();

    try {
      // Add to favorites
      await addToFavorites(mediaItemId);
      
      // Remove from watchlist
      await removeFromWatchlist(mediaItemId);
      
      // Update any existing recommendation status to 'added'
      await _updateRecommendationStatusForMediaItem(mediaItemId, 'added');
      
      debugPrint('✅ Moved from watchlist to favorites (media_item_id: $mediaItemId)');
    } catch (e) {
      debugPrint('Error moving from watchlist to favorites: $e');
      rethrow;
    }
  }

  // ===== SEARCH INTEGRATION =====

  /// Add item from search to favorites
  Future<void> addSearchItemToFavorites({
    required String mediaType,
    required String title,
    required String primaryCreator,
    String? vectorMediaId,
    String? coverArtUrl,
    String? description,
    String? wikiUrl,
    String? wikidataId,
    String? themes,
  }) async {
    await _ensureInitialized();

    try {
      // Create or get the media item
      final mediaItemId = await createOrGetMediaItem(
        mediaType: mediaType,
        vectorMediaId: vectorMediaId ?? 'user_added_${title.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        primaryCreator: primaryCreator,
        coverArtUrl: coverArtUrl,
        description: description,
        wikiUrl: wikiUrl,
        wikidataId: wikidataId,
        themes: themes,
        genres: null,
        youtubeId: null,
        spotifyId: null,
      );

      // Add to favorites
      await addToFavorites(mediaItemId);
      
      // Update any existing recommendation status to 'added'
      await _updateRecommendationStatusForMediaItem(mediaItemId, 'added');
    } catch (e) {
      debugPrint('Error adding search item to favorites: $e');
      rethrow;
    }
  }

  /// Add item from search to watchlist
  Future<void> addSearchItemToWatchlist({
    required String mediaType,
    required String title,
    required String primaryCreator,
    String? vectorMediaId,
    String? coverArtUrl,
    String? description,
    String? wikiUrl,
    String? wikidataId,
    String? themes,
  }) async {
    await _ensureInitialized();

    try {
      // Create or get the media item
      final mediaItemId = await createOrGetMediaItem(
        mediaType: mediaType,
        vectorMediaId: vectorMediaId ?? 'user_added_${title.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        primaryCreator: primaryCreator,
        coverArtUrl: coverArtUrl,
        description: description,
        wikiUrl: wikiUrl,
        wikidataId: wikidataId,
        themes: themes,
        genres: null,
        youtubeId: null,
        spotifyId: null,
      );

      // Add to watchlist
      await addToWatchlist(mediaItemId);
    } catch (e) {
      debugPrint('Error adding search item to watchlist: $e');
      rethrow;
    }
  }

  // ===== RECOMMENDATIONS =====

  /// Save a media suggestion
  Future<int> saveMediaSuggestion(MediaSuggestion suggestion) async {
    await _ensureInitialized();

    try {
      final isNew = suggestion.id <= 0;
      final now = DateTime.now().toIso8601String();

      // Get media type ID and status ID
      final mediaTypeId = await getMediaTypeId(suggestion.mediaType);
      final statusId = await _getStatusId(suggestion.status.toString().split('.').last);

      if (mediaTypeId == null) {
        throw Exception('Invalid media type: ${suggestion.mediaType}');
      }
      if (statusId == null) {
        throw Exception('Invalid status: ${suggestion.status}');
      }

      if (isNew) {
        // First, create or get the media item
        final mediaItemId = await createOrGetMediaItem(
          mediaType: suggestion.mediaType,
          vectorMediaId: suggestion.mediaId ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}',
          title: suggestion.title ?? '',
          primaryCreator: suggestion.artist,
          coverArtUrl: suggestion.coverArtUrl,
          description: suggestion.description,
          wikiUrl: suggestion.wikiUrl,
          wikidataId: suggestion.wikidataId,
          themes: suggestion.themes,
          genres: null, // TODO: Extract from suggestion if available
          youtubeId: null, // TODO: Extract from suggestion if available
          spotifyId: null, // TODO: Extract from suggestion if available
        );

        // Then create the recommendation that references the media item
        final stmt = _db!.prepare(insertRecommendationQuery);
        stmt.execute([
          mediaItemId,
          suggestion.query,
          suggestion.botReasoning,
          statusId,
          suggestion.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
          suggestion.updatedAt?.toIso8601String(),
        ]);

        final id = _db!.lastInsertRowId;
        stmt.dispose();
        return id;
      } else {
        // Update existing recommendation status
        final stmt = _db!.prepare(updateRecommendationStatusQuery);
        stmt.execute([
          suggestion.status.toString().split('.').last,
          now,
          suggestion.id,
        ]);
        stmt.dispose();
        return suggestion.id;
      }
    } catch (e) {
      debugPrint('Error saving media suggestion: $e');
      rethrow;
    }
  }

  /// Save a recommendation
  Future<int> saveRecommendation({
    required int mediaItemId,
    required String query,
    String? botReasoning,
    String status = 'pending',
  }) async {
    await _ensureInitialized();

    try {
      final statusId = await _getStatusId(status);
      if (statusId == null) {
        throw Exception('Invalid status: $status');
      }

      final now = DateTime.now().toIso8601String();
      final stmt = _db!.prepare(insertRecommendationQuery);
      stmt.execute([
        mediaItemId,
        query,
        botReasoning,
        statusId,
        now,
        now,
      ]);

      final id = _db!.lastInsertRowId;
      stmt.dispose();
      return id;
    } catch (e) {
      debugPrint('Error saving recommendation: $e');
      rethrow;
    }
  }

  /// Get pending suggestions not in watchlist
  Future<List<MediaSuggestion>> getPendingSuggestionsNotInWatchlist(String mediaType) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getPendingSuggestionsNotInWatchlistQuery);
      final result = stmt.select([mediaType]);

      final suggestions = result.map((row) => _mapRowToMediaSuggestion(row)).toList();
      stmt.dispose();
      return suggestions;
    } catch (e) {
      debugPrint('Error getting pending suggestions not in watchlist: $e');
      return [];
    }
  }

  /// Get all media suggestions for a media type
  Future<List<MediaSuggestion>> getAllMediaSuggestions(String mediaType, {String? status}) async {
    await _ensureInitialized();

    try {
      late String query;
      late List<dynamic> params;

      if (status != null) {
        query = getRecommendationsByStatusQuery;
        params = [mediaType, status];
      } else {
        // Get all recommendations for this media type
        query = '''
        SELECT r.id, r.media_item_id, r.query, r.bot_reasoning, rs.name as status,
               r.created_at, r.updated_at,
               mi.vector_media_id, mi.title, mi.primary_creator, mi.cover_art_url,
               mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
               mt.name as media_type
        FROM recommendations r
        JOIN media_items mi ON r.media_item_id = mi.id
        JOIN media_types mt ON mi.media_type_id = mt.id
        JOIN recommendation_status rs ON r.status_id = rs.id
        WHERE mt.name = ?
        ORDER BY r.created_at DESC;
        ''';
        params = [mediaType];
      }

      final stmt = _db!.prepare(query);
      final result = stmt.select(params);

      final suggestions = result.map((row) => _mapRowToMediaSuggestion(row)).toList();
      stmt.dispose();
      return suggestions;
    } catch (e) {
      debugPrint('Error getting all media suggestions: $e');
      return [];
    }
  }

  /// Count pending media suggestions
  Future<int> countPendingMediaSuggestions(String mediaType) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(countPendingMediaSuggestionsQuery);
      final result = stmt.select([mediaType]);

      final count = result.isNotEmpty ? result.first['count'] as int : 0;
      stmt.dispose();
      return count;
    } catch (e) {
      debugPrint('Error counting pending media suggestions: $e');
      return 0;
    }
  }

  /// Update media suggestion status
  Future<bool> updateMediaSuggestionStatus(int suggestionId, SuggestionStatus status) async {
    await _ensureInitialized();

    try {
      final now = DateTime.now().toIso8601String();
      final statusStr = status.toString().split('.').last;
      
      debugPrint('🔧 [STATUS-UPDATE] Updating suggestion $suggestionId to status "$statusStr"');
      
      // Debug: Check if the status exists in recommendation_status table
      final statusCheckStmt = _db!.prepare('SELECT id FROM recommendation_status WHERE name = ?');
      final statusCheckResult = statusCheckStmt.select([statusStr]);
      if (statusCheckResult.isEmpty) {
        debugPrint('❌ [STATUS-UPDATE] Status "$statusStr" not found in recommendation_status table!');
        statusCheckStmt.dispose();
        return false;
      }
      final statusId = statusCheckResult.first['id'] as int;
      debugPrint('✅ [STATUS-UPDATE] Status "$statusStr" found with ID: $statusId');
      statusCheckStmt.dispose();
      
      // Debug: Check if the suggestion exists
      final suggestionCheckStmt = _db!.prepare('SELECT id FROM recommendations WHERE id = ?');
      final suggestionCheckResult = suggestionCheckStmt.select([suggestionId]);
      if (suggestionCheckResult.isEmpty) {
        debugPrint('❌ [STATUS-UPDATE] Suggestion $suggestionId not found in recommendations table!');
        suggestionCheckStmt.dispose();
        return false;
      }
      debugPrint('✅ [STATUS-UPDATE] Suggestion $suggestionId exists in database');
      suggestionCheckStmt.dispose();

      final stmt = _db!.prepare(updateMediaSuggestionStatusQuery);
      stmt.execute([statusStr, now, suggestionId]);
      stmt.dispose();
      
      // Check if any rows were actually updated
      final changesStmt = _db!.prepare('SELECT changes()');
      final changesResult = changesStmt.select([]);
      final changes = changesResult.isNotEmpty ? changesResult.first['changes()'] as int : 0;
      changesStmt.dispose();
      
      debugPrint('🔧 [STATUS-UPDATE] Rows affected: $changes');

      if (changes == 0) {
        debugPrint('⚠️ [STATUS-UPDATE] No rows updated! SuggestionId $suggestionId might not exist or status "$statusStr" not found');
        return false;
      }
      
      debugPrint('✅ [STATUS-UPDATE] Successfully updated suggestion $suggestionId to "$statusStr"');
      return true;
    } catch (e) {
      debugPrint('Error updating media suggestion status: $e');
      return false;
    }
  }

  /// Delete media suggestion
  Future<bool> deleteMediaSuggestion(int suggestionId) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(deleteMediaSuggestionQuery);
      stmt.execute([suggestionId]);
      stmt.dispose();

      return true;
    } catch (e) {
      debugPrint('Error deleting media suggestion: $e');
      return false;
    }
  }

  /// Get liked recommendations for behavioral analysis
  Future<List<MediaSuggestion>> getLikedRecommendations(String mediaType) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getLikedRecommendationsQuery);
      final result = stmt.select([mediaType]);

      final suggestions = result.map((row) => _mapRowToMediaSuggestion(row)).toList();
      stmt.dispose();
      return suggestions;
    } catch (e) {
      debugPrint('Error getting liked recommendations: $e');
      return [];
    }
  }

  /// Get disliked recommendations for behavioral analysis
  Future<List<MediaSuggestion>> getDislikedRecommendations(String mediaType) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getDislikedRecommendationsQuery);
      final result = stmt.select([mediaType]);

      final suggestions = result.map((row) => _mapRowToMediaSuggestion(row)).toList();
      stmt.dispose();
      return suggestions;
    } catch (e) {
      debugPrint('Error getting disliked recommendations: $e');
      return [];
    }
  }

  // Note: getFavoritedRecommendations and getWatchlistedRecommendations have been removed
  // Use getAllFavorites() and getWatchlist() instead, which work with the normalized schema

  /// Get skipped recommendations for behavioral analysis
  Future<List<MediaSuggestion>> getSkippedRecommendations(String mediaType) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getSkippedRecommendationsQuery);
      final result = stmt.select([mediaType]);

      final suggestions = result.map((row) => _mapRowToMediaSuggestion(row)).toList();
      stmt.dispose();
      return suggestions;
    } catch (e) {
      debugPrint('Error getting skipped recommendations: $e');
      return [];
    }
  }

  /// Get a specific recommendation by ID
  Future<MediaSuggestion?> getRecommendationById(int recommendationId) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getRecommendationByIdQuery);
      final result = stmt.select([recommendationId]);

      if (result.isEmpty) {
        stmt.dispose();
        return null;
      }

      final suggestion = _mapRowToMediaSuggestion(result.first);
      stmt.dispose();
      return suggestion;
    } catch (e) {
      debugPrint('Error getting recommendation by ID: $e');
      return null;
    }
  }

  /// Get suggestion with current status (favorite/watchlist) determined by joins
  Future<SuggestionWithStatus?> getSuggestionWithStatus(int suggestionId) async {
    await _ensureInitialized();

    try {
      const query = '''
      SELECT r.id, r.media_item_id, r.query, r.bot_reasoning, rs.name as status,
             r.created_at, r.updated_at,
             mi.vector_media_id, mi.title, mi.primary_creator, mi.cover_art_url,
             mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
             mt.name as media_type,
             CASE WHEN f.media_item_id IS NOT NULL THEN 1 ELSE 0 END as is_favorited,
             CASE WHEN w.media_item_id IS NOT NULL THEN 1 ELSE 0 END as is_in_watchlist
      FROM recommendations r
      JOIN media_items mi ON r.media_item_id = mi.id
      JOIN media_types mt ON mi.media_type_id = mt.id
      JOIN recommendation_status rs ON r.status_id = rs.id
      LEFT JOIN favorites f ON mi.id = f.media_item_id
      LEFT JOIN watchlist w ON mi.id = w.media_item_id
      WHERE r.id = ?
      ''';

      final stmt = _db!.prepare(query);
      final result = stmt.select([suggestionId]);

      if (result.isEmpty) {
        stmt.dispose();
        return null;
      }

      final row = result.first;
      final suggestion = _mapRowToMediaSuggestion(row);
      final isFavorited = (row['is_favorited'] as int) == 1;
      final isInWatchlist = (row['is_in_watchlist'] as int) == 1;
      
      // Determine the effective status based on joins and current status
      bool hasLiked = false;
      bool hasFavorited = isFavorited;
      bool isInWatchlistStatus = isInWatchlist;
      
      // Show liked if not favorited and status is liked (can coexist with watchlist)
      // Priority: Favorite > Like > Watchlist > Pending > Disliked
      if (!isFavorited && suggestion.status == SuggestionStatus.liked) {
        hasLiked = true;
      }
      
      // If status is disliked, it means it was "unliked" - all flags should be false
      // If status is pending or skipped, no action has been taken - all flags should be false
      // The flags are already set correctly above based on the database joins

      stmt.dispose();
      return SuggestionWithStatus(
        suggestion: suggestion,
        isLiked: hasLiked,
        isFavorited: hasFavorited,
        isInWatchlist: isInWatchlistStatus,
      );
    } catch (e) {
      debugPrint('Error getting suggestion with status: $e');
      return null;
    }
  }

  /// Get comprehensive media item status by properties (title, artist, media type)
  /// This checks ALL tables - favorites, watchlist, recommendations - regardless of how the item was added
  Future<Map<String, dynamic>> getMediaItemStatusByProperties({
    required String title,
    required String mediaType,
    String? primaryCreator,
  }) async {
    await _ensureInitialized();

    try {
      debugPrint('🔍 [STATUS-LOOKUP] Looking up status for: "$title" by "$primaryCreator" ($mediaType)');
      
      // First, try to find the media item
      final findMediaQuery = '''
      SELECT mi.id, mi.title, mi.primary_creator, mi.cover_art_url, mi.description, 
             mi.wiki_url, mi.wikidata_id, mi.themes, mi.genres, mi.youtube_id, mi.spotify_id, mi.vector_media_id,
             CASE WHEN f.media_item_id IS NOT NULL THEN 1 ELSE 0 END as is_favorited,
             CASE WHEN w.media_item_id IS NOT NULL THEN 1 ELSE 0 END as is_in_watchlist
      FROM media_items mi
      JOIN media_types mt ON mi.media_type_id = mt.id
      LEFT JOIN favorites f ON mi.id = f.media_item_id
      LEFT JOIN watchlist w ON mi.id = w.media_item_id
      WHERE mt.name = ? 
        AND LOWER(mi.title) = LOWER(?)
        AND (? IS NULL OR LOWER(COALESCE(mi.primary_creator, '')) = LOWER(?))
      LIMIT 1
      ''';

      final stmt = _db!.prepare(findMediaQuery);
      final result = stmt.select([mediaType, title, primaryCreator, primaryCreator ?? '']);
      stmt.dispose();

      if (result.isEmpty) {
        debugPrint('🔍 [STATUS-LOOKUP] Media item not found in database');
        return {
          'found': false,
          'hasLiked': false,
          'hasFavorited': false,
          'hasDisliked': false,
          'isInWatchlist': false,
          'hasSkipped': false,
          'mediaItemId': null,
        };
      }

      final row = result.first;
      final mediaItemId = row['id'] as int;
      final isFavorited = (row['is_favorited'] as int) == 1;
      final isInWatchlist = (row['is_in_watchlist'] as int) == 1;

      debugPrint('🔍 [STATUS-LOOKUP] Found media item ID: $mediaItemId, Favorited: $isFavorited, Watchlist: $isInWatchlist');

      // Now check for any recommendations for this media item
      const recommendationQuery = '''
      SELECT r.id, rs.name as status
      FROM recommendations r
      JOIN recommendation_status rs ON r.status_id = rs.id
      WHERE r.media_item_id = ?
      ORDER BY r.created_at DESC
      LIMIT 1
      ''';

      final recStmt = _db!.prepare(recommendationQuery);
      final recResult = recStmt.select([mediaItemId]);
      recStmt.dispose();

      bool hasLiked = false;
      bool hasDisliked = false;
      bool hasSkipped = false;

      if (recResult.isNotEmpty) {
        final recStatus = recResult.first['status'] as String;
        debugPrint('🔍 [STATUS-LOOKUP] Found recommendation with status: $recStatus');
        
        switch (recStatus) {
          case 'liked':
            hasLiked = !isFavorited; // Only show liked if not favorited (favorite takes priority)
            break;
          case 'disliked':
            hasDisliked = true;
            break;
          case 'skipped':
            hasSkipped = true;
            break;
        }
      }

      final statusResult = {
        'found': true,
        'hasLiked': hasLiked,
        'hasFavorited': isFavorited,
        'hasDisliked': hasDisliked,
        'isInWatchlist': isInWatchlist,
        'hasSkipped': hasSkipped,
        'mediaItemId': mediaItemId,
        'title': row['title'] as String?,
        'primaryCreator': row['primary_creator'] as String?,
        'coverArtUrl': row['cover_art_url'] as String?,
        'description': row['description'] as String?,
        'wikiUrl': row['wiki_url'] as String?,
        'wikidataId': row['wikidata_id'] as String?,
        'themes': row['themes'] as String?,
        'genres': row['genres'] as String?,
        'youtubeId': row['youtube_id'] as String?,
        'spotifyId': row['spotify_id'] as String?,
        'vectorMediaId': row['vector_media_id'] as String?,
      };

      debugPrint('🔍 [STATUS-LOOKUP] Final status: Liked=$hasLiked, Favorited=$isFavorited, Disliked=$hasDisliked, Watchlist=$isInWatchlist, Skipped=$hasSkipped');
      
      return statusResult;
    } catch (e) {
      debugPrint('❌ [STATUS-LOOKUP] Error getting media item status: $e');
      return {
        'found': false,
        'hasLiked': false,
        'hasFavorited': false,
        'hasDisliked': false,
        'isInWatchlist': false,
        'hasSkipped': false,
        'mediaItemId': null,
      };
    }
  }

  /// Debug inspect recommendations table
  Future<void> debugInspectRecommendationsTable() async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare('''
        SELECT COUNT(*) as total_count FROM recommendations;
      ''');
      final result = stmt.select([]);

      if (result.isNotEmpty) {
        final count = result.first['total_count'] as int;
        debugPrint('🗄️ [DB] Total recommendations in database: $count');
      }

      stmt.dispose();
    } catch (e) {
      debugPrint('Error inspecting recommendations table: $e');
    }
  }

  /// Get status ID by name
  Future<int?> _getStatusId(String statusName) async {
    try {
      final stmt = _db!.prepare('SELECT id FROM recommendation_status WHERE name = ?');
      final result = stmt.select([statusName]);

      if (result.isEmpty) {
        stmt.dispose();
        return null;
      }

      final id = result.first['id'] as int;
      stmt.dispose();
      return id;
    } catch (e) {
      debugPrint('Error getting status ID: $e');
      return null;
    }
  }

  // ===== MEDIA SETTINGS =====

  /// Get media settings for a media type
  Future<Map<String, dynamic>?> getMediaSettings(String mediaType) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getMediaSettingsQuery);
      final result = stmt.select([mediaType]);

      if (result.isEmpty) {
        stmt.dispose();
        return null;
      }

      final row = result.first;
      final settings = {
        'similarity_matching': row['similarity_matching'] as double,
        'themes_matching': row['themes_matching'] as int,
        'created_at': row['created_at'] as String,
        'updated_at': row['updated_at'] as String,
      };

      stmt.dispose();
      return settings;
    } catch (e) {
      debugPrint('Error getting media settings: $e');
      return null;
    }
  }

  /// Save media settings
  Future<bool> saveMediaSettings(String mediaType, double similarityMatching, int themesMatching) async {
    await _ensureInitialized();

    try {
      final mediaTypeId = await getMediaTypeId(mediaType);
      if (mediaTypeId == null) {
        throw Exception('Invalid media type: $mediaType');
      }

      final now = DateTime.now().toIso8601String();
      final stmt = _db!.prepare(insertOrUpdateMediaSettingsQuery);
      stmt.execute([mediaTypeId, similarityMatching, themesMatching, now, now]);
      stmt.dispose();

      return true;
    } catch (e) {
      debugPrint('Error saving media settings: $e');
      return false;
    }
  }

  // ===== GENERAL SETTINGS =====

  /// Get general setting by key
  Future<String?> getGeneralSetting(String key) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getGeneralSettingQuery);
      final result = stmt.select([key]);

      if (result.isEmpty) {
        stmt.dispose();
        return null;
      }

      final value = result.first['value'] as String;
      stmt.dispose();
      return value;
    } catch (e) {
      debugPrint('Error getting general setting: $e');
      return null;
    }
  }

  /// Set general setting
  Future<bool> setGeneralSetting(String key, String value) async {
    await _ensureInitialized();

    try {
      final now = DateTime.now().toIso8601String();
      final stmt = _db!.prepare(insertOrUpdateGeneralSettingQuery);
      stmt.execute([key, value, now, now]);
      stmt.dispose();
      return true;
    } catch (e) {
      debugPrint('Error setting general setting: $e');
      return false;
    }
  }

  /// Get all general settings as a map
  Future<Map<String, String>> getAllGeneralSettings() async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getAllGeneralSettingsQuery);
      final result = stmt.select([]);

      final settings = <String, String>{};
      for (final row in result) {
        settings[row['key'] as String] = row['value'] as String;
      }

      stmt.dispose();
      return settings;
    } catch (e) {
      debugPrint('Error getting all general settings: $e');
      return {};
    }
  }

  /// Get continuous playback setting for music (uses general_settings)
  Future<bool> getContinuousPlaybackSetting() async {
    final value = await getGeneralSetting('continuous_playback_music');
    return value == 'true';
  }

  /// Set continuous playback setting for music (uses general_settings)
  Future<bool> setContinuousPlaybackSetting(bool enabled) async {
    return await setGeneralSetting('continuous_playback_music', enabled.toString());
  }

  /// Get YouTube previews setting (uses general_settings)  
  Future<bool> getYouTubePreviewsSetting() async {
    final value = await getGeneralSetting('youtube_previews');
    return value == 'true';
  }

  /// Set YouTube previews setting (uses general_settings)
  Future<bool> setYouTubePreviewsSetting(bool enabled) async {
    return await setGeneralSetting('youtube_previews', enabled.toString());
  }

  // ===== MEDIA MATCHING =====

  /// Get media matching constraints for a media type
  Future<Map<String, List<String>>> getMediaMatchingConstraints(String mediaType) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getMediaMatchingQuery);
      final result = stmt.select([mediaType]);

      final positive = <String>[];
      final negative = <String>[];

      for (final row in result) {
        final value = row['value'] as String;
        final isPositive = (row['is_positive'] as int) == 1;
        
        if (isPositive) {
          positive.add(value);
        } else {
          negative.add(value);
        }
      }

      stmt.dispose();
      return {
        'positive': positive,
        'negative': negative,
      };
    } catch (e) {
      debugPrint('Error getting media matching constraints: $e');
      return {'positive': [], 'negative': []};
    }
  }

  /// Add media matching constraint
  Future<bool> addMediaMatchingConstraint(String mediaType, String value, bool isPositive) async {
    await _ensureInitialized();

    try {
      final mediaTypeId = await getMediaTypeId(mediaType);
      if (mediaTypeId == null) {
        throw Exception('Invalid media type: $mediaType');
      }

      final now = DateTime.now().toIso8601String();
      final stmt = _db!.prepare(insertMediaMatchingQuery);
      stmt.execute([mediaTypeId, value, isPositive ? 1 : 0, now]);
      stmt.dispose();

      return true;
    } catch (e) {
      debugPrint('Error adding media matching constraint: $e');
      return false;
    }
  }

  /// Delete media matching constraint
  Future<bool> deleteMediaMatchingConstraint(String mediaType, String value) async {
    await _ensureInitialized();

    try {
      final mediaTypeId = await getMediaTypeId(mediaType);
      if (mediaTypeId == null) {
        throw Exception('Invalid media type: $mediaType');
      }

      final stmt = _db!.prepare(deleteMediaMatchingQuery);
      stmt.execute([mediaTypeId, value]);
      stmt.dispose();

      return true;
    } catch (e) {
      debugPrint('Error deleting media matching constraint: $e');
      return false;
    }
  }

  // ===== MEDIA PRIORITY TITLES =====

  /// Get media priority titles for a media type
  Future<Map<String, List<Map<String, dynamic>>>> getMediaPriorityTitles(String mediaType) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getMediaPriorityTitlesQuery);
      final result = stmt.select([mediaType]);

      final positive = <Map<String, dynamic>>[];
      final negative = <Map<String, dynamic>>[];

      for (final row in result) {
        final titleData = {
          'title': row['title'] as String,
          'creator': row['primary_creator'] as String?,
          'created_at': row['created_at'] as String,
        };
        
        final isPositive = (row['is_positive'] as int) == 1;
        if (isPositive) {
          positive.add(titleData);
        } else {
          negative.add(titleData);
        }
      }

      stmt.dispose();
      return {
        'positive': positive,
        'negative': negative,
      };
    } catch (e) {
      debugPrint('Error getting media priority titles: $e');
      return {'positive': [], 'negative': []};
    }
  }

  /// Add media priority title
  Future<bool> addMediaPriorityTitle(String mediaType, int mediaItemId, bool isPositive) async {
    await _ensureInitialized();

    try {
      final mediaTypeId = await getMediaTypeId(mediaType);
      if (mediaTypeId == null) {
        throw Exception('Invalid media type: $mediaType');
      }

      final now = DateTime.now().toIso8601String();
      final stmt = _db!.prepare(insertMediaPriorityTitleQuery);
      stmt.execute([mediaTypeId, mediaItemId, isPositive ? 1 : 0, now]);
      stmt.dispose();

      return true;
    } catch (e) {
      debugPrint('Error adding media priority title: $e');
      return false;
    }
  }

  /// Delete media priority title
  Future<bool> deleteMediaPriorityTitle(String mediaType, int mediaItemId) async {
    await _ensureInitialized();

    try {
      final mediaTypeId = await getMediaTypeId(mediaType);
      if (mediaTypeId == null) {
        throw Exception('Invalid media type: $mediaType');
      }

      final stmt = _db!.prepare(deleteMediaPriorityTitleQuery);
      stmt.execute([mediaTypeId, mediaItemId]);
      stmt.dispose();

      return true;
    } catch (e) {
      debugPrint('Error deleting media priority title: $e');
      return false;
    }
  }

  // ===== MEDIA BLENDS =====

  /// Get media blends for a media type
  Future<List<String>> getMediaBlends(String mediaType) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getMediaBlendsQuery);
      final result = stmt.select([mediaType]);

      final blends = <String>[];
      for (final row in result) {
        blends.add(row['blended_media_type'] as String);
      }

      stmt.dispose();
      return blends;
    } catch (e) {
      debugPrint('Error getting media blends: $e');
      return [];
    }
  }

  /// Add media blend
  Future<bool> addMediaBlend(String primaryMediaType, String blendedMediaType) async {
    await _ensureInitialized();

    try {
      final primaryMediaTypeId = await getMediaTypeId(primaryMediaType);
      final blendedMediaTypeId = await getMediaTypeId(blendedMediaType);
      
      if (primaryMediaTypeId == null || blendedMediaTypeId == null) {
        throw Exception('Invalid media type(s): $primaryMediaType, $blendedMediaType');
      }

      final now = DateTime.now().toIso8601String();
      final stmt = _db!.prepare(insertMediaBlendQuery);
      stmt.execute([primaryMediaTypeId, blendedMediaTypeId, now]);
      stmt.dispose();

      return true;
    } catch (e) {
      debugPrint('Error adding media blend: $e');
      return false;
    }
  }

  /// Delete media blend
  Future<bool> deleteMediaBlend(String primaryMediaType, String blendedMediaType) async {
    await _ensureInitialized();

    try {
      final primaryMediaTypeId = await getMediaTypeId(primaryMediaType);
      final blendedMediaTypeId = await getMediaTypeId(blendedMediaType);
      
      if (primaryMediaTypeId == null || blendedMediaTypeId == null) {
        throw Exception('Invalid media type(s): $primaryMediaType, $blendedMediaType');
      }

      final stmt = _db!.prepare(deleteMediaBlendQuery);
      stmt.execute([primaryMediaTypeId, blendedMediaTypeId]);
      stmt.dispose();

      return true;
    } catch (e) {
      debugPrint('Error deleting media blend: $e');
      return false;
    }
  }

  // ===== MEDIA METADATA =====

  /// Add metadata for a media item
  Future<void> addMediaMetadata(int mediaItemId, String key, String value) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(insertMediaMetadataQuery);
      stmt.execute([mediaItemId, key, value]);
      stmt.dispose();
    } catch (e) {
      debugPrint('Error adding media metadata: $e');
      rethrow;
    }
  }

  /// Get metadata for a media item
  Future<Map<String, String>> getMediaMetadata(int mediaItemId) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getMediaMetadataQuery);
      final result = stmt.select([mediaItemId]);

      final metadata = <String, String>{};
      for (final row in result) {
        metadata[row['key'] as String] = row['value'] as String;
      }

      stmt.dispose();
      return metadata;
    } catch (e) {
      debugPrint('Error getting media metadata: $e');
      return {};
    }
  }

  /// Get media item by ID (for direct lookup)
  Future<Map<String, dynamic>?> getMediaItemById(int mediaItemId) async {
    await _ensureInitialized();

    try {
      debugPrint('🔍 [GET-MEDIA-ITEM] Looking up media item by ID: $mediaItemId');
      
      final stmt = _db!.prepare(getMediaItemByIdQuery);
      final result = stmt.select([mediaItemId]);

      if (result.isEmpty) {
        stmt.dispose();
        debugPrint('❌ [GET-MEDIA-ITEM] No media item found with ID: $mediaItemId');
        return null;
      }

      final row = result.first;
      final mediaItem = {
        'id': row['id'] as int,
        'mediaTypeId': row['media_type_id'] as int,
        'vectorMediaId': row['vector_media_id'] as String,
        'title': row['title'] as String,
        'primaryCreator': row['primary_creator'] as String?,
        'coverArtUrl': row['cover_art_url'] as String?,
        'description': row['description'] as String?,
        'wikiUrl': row['wiki_url'] as String?,
        'wikidataId': row['wikidata_id'] as String?,
        'themes': row['themes'] as String?,
        'createdAt': row['created_at'] as String,
        'updatedAt': row['updated_at'] as String,
        'mediaType': row['media_type'] as String,
      };

      stmt.dispose();
      debugPrint('✅ [GET-MEDIA-ITEM] Found media item: "${mediaItem['title']}" by "${mediaItem['primaryCreator']}"');
      return mediaItem;
    } catch (e) {
      debugPrint('❌ [GET-MEDIA-ITEM] Error getting media item by ID: $e');
      return null;
    }
  }

  /// Get media item with status information by ID (optimized single query)
  /// This replaces the need for getMediaItemById + getMediaItemStatusByProperties
  Future<Map<String, dynamic>?> getMediaItemWithStatusById(int mediaItemId) async {
    await _ensureInitialized();

    try {
      debugPrint('🔍 [GET-MEDIA-ITEM-STATUS] Fast lookup for media item ID: $mediaItemId');
      
      // Single optimized query that gets media item + all status info using primary key
      const query = '''
      SELECT mi.id, mi.media_type_id, mi.vector_media_id, mi.title, mi.primary_creator,
             mi.cover_art_url, mi.description, mi.wiki_url, mi.wikidata_id, mi.themes, mi.genres,
             mi.youtube_id, mi.spotify_id, mi.created_at, mi.updated_at, mt.name as media_type,
             CASE WHEN f.media_item_id IS NOT NULL THEN 1 ELSE 0 END as is_favorited,
             CASE WHEN w.media_item_id IS NOT NULL THEN 1 ELSE 0 END as is_in_watchlist,
             rs.name as recommendation_status
      FROM media_items mi
      JOIN media_types mt ON mi.media_type_id = mt.id
      LEFT JOIN favorites f ON mi.id = f.media_item_id
      LEFT JOIN watchlist w ON mi.id = w.media_item_id
      LEFT JOIN recommendations r ON mi.id = r.media_item_id
      LEFT JOIN recommendation_status rs ON r.status_id = rs.id
      WHERE mi.id = ?;
      ''';
      
      final stmt = _db!.prepare(query);
      final result = stmt.select([mediaItemId]);

      if (result.isEmpty) {
        stmt.dispose();
        debugPrint('❌ [GET-MEDIA-ITEM-STATUS] No media item found with ID: $mediaItemId');
        return null;
      }

      final row = result.first;
      final isFavorited = (row['is_favorited'] as int) == 1;
      final isInWatchlist = (row['is_in_watchlist'] as int) == 1;
      
      // Handle recommendation status
      bool hasLiked = false;
      bool hasDisliked = false;
      bool hasSkipped = false;

      final recStatus = row['recommendation_status'] as String?;
      if (recStatus != null) {
        switch (recStatus) {
          case 'liked':
            hasLiked = !isFavorited; // Only show liked if not favorited (favorite takes priority)
            break;
          case 'disliked':
            hasDisliked = true;
            break;
          case 'skipped':
            hasSkipped = true;
            break;
        }
      }

      final statusResult = {
        'found': true,
        'hasLiked': hasLiked,
        'hasFavorited': isFavorited,
        'hasDisliked': hasDisliked,
        'isInWatchlist': isInWatchlist,
        'hasSkipped': hasSkipped,
        'mediaItemId': mediaItemId,
        'title': row['title'] as String?,
        'primaryCreator': row['primary_creator'] as String?,
        'coverArtUrl': row['cover_art_url'] as String?,
        'description': row['description'] as String?,
        'wikiUrl': row['wiki_url'] as String?,
        'wikidataId': row['wikidata_id'] as String?,
        'themes': row['themes'] as String?,
        'genres': row['genres'] as String?,
        'youtubeId': row['youtube_id'] as String?,
        'spotifyId': row['spotify_id'] as String?,
        'vectorMediaId': row['vector_media_id'] as String?,
      };

      stmt.dispose();
      debugPrint('✅ [GET-MEDIA-ITEM-STATUS] Fast lookup complete: Liked=$hasLiked, Favorited=$isFavorited, Disliked=$hasDisliked, Watchlist=$isInWatchlist, Skipped=$hasSkipped');
      return statusResult;
    } catch (e) {
      debugPrint('❌ [GET-MEDIA-ITEM-STATUS] Error in fast lookup: $e');
      return null;
    }
  }

  // ===== UTILITY METHODS =====

  /// Map database row to MediaSuggestion
  MediaSuggestion _mapRowToMediaSuggestion(Row row) {
    final statusFromDb = row['status'] as String?;
    final suggestionId = row['id'] as int;
    final title = row['title'] as String?;
    
    // Debug status mapping for problematic suggestions
    if (title?.contains('Beelzebub') == true) {
      debugPrint('🔍 [ROW-MAP] Beelzebub mapping: ID=$suggestionId, StatusFromDB="$statusFromDb"');
    }
    
    return MediaSuggestion(
      id: suggestionId,
      mediaId: (row['vector_media_id'] as String?) ?? 'db_legacy_${suggestionId}_${DateTime.now().millisecondsSinceEpoch}',
      query: (row['query'] as String?) ?? 'Unknown',
      mediaType: (row['media_type'] as String?) ?? 'unknown',
      title: title,
      artist: row['primary_creator'] as String?,
      coverArtUrl: row['cover_art_url'] as String?,
      description: row['description'] as String?,
      wikiUrl: row['wiki_url'] as String?,
      wikidataId: row['wikidata_id'] as String?,
      botReasoning: row['bot_reasoning'] as String?,
      themes: row['themes'] as String?,
      genres: (row['genres'] as String?)?.split(',').map((e) => e.trim()).toList(),
      youtubeId: row['youtube_id'] as String?,
      spotifyId: row['spotify_id'] as String?,
      status: SuggestionStatus.values.firstWhere(
        (s) => s.toString().split('.').last == (statusFromDb ?? 'pending'),
        orElse: () => SuggestionStatus.pending,
      ),
      createdAt: DateTime.parse((row['created_at'] as String?) ?? DateTime.now().toIso8601String()),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  /// Update recommendation status for a media item (used when items are favorited/watchlisted from search)
  Future<void> _updateRecommendationStatusForMediaItem(int mediaItemId, String statusName) async {
    await _ensureInitialized();

    try {
      // Find any existing recommendations for this media item
      final stmt = _db!.prepare('''
        UPDATE recommendations 
        SET status_id = (SELECT id FROM recommendation_status WHERE name = ?)
        WHERE media_item_id = ?
      ''');
      
      stmt.execute([statusName, mediaItemId]);
      stmt.dispose();
      
      debugPrint('✅ Updated recommendation status to "$statusName" for media_item_id: $mediaItemId');
    } catch (e) {
      debugPrint('⚠️ Error updating recommendation status for media_item_id $mediaItemId: $e');
      // Don't rethrow - this is a non-critical operation that shouldn't break the main flow
    }
  }
} 
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
      _db = sqlite3.open(dbPath);
      await _createTables();
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



  /// Create all tables
  Future<void> _createTables() async {
    try {
      _db!.execute(createMediaTypesTableQuery);
      _db!.execute(createRecommendationStatusTableQuery);
      _db!.execute(createMediaItemsTableQuery);
      _db!.execute(createRecommendationsTableQuery);
      _db!.execute(createFavoritesTableQuery);
      _db!.execute(createWatchlistTableQuery);
      _db!.execute(createMediaMetadataTableQuery);
      _db!.execute(createUserConstraintsTableQuery);
      
      // Insert default data
      _db!.execute(insertMediaTypesQuery);
      _db!.execute(insertRecommendationStatusQuery);
      
      debugPrint('✅ All tables created successfully');
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
      );

      // Add to favorites
      await addToFavorites(mediaItemId);
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
          vectorMediaId: suggestion.mediaId, // Already required and non-null
          title: suggestion.title ?? '',
          primaryCreator: suggestion.artist,
          coverArtUrl: suggestion.coverArtUrl,
          description: suggestion.description,
          wikiUrl: suggestion.wikiUrl,
          wikidataId: suggestion.wikidataId,
          themes: suggestion.themes,
        );

        // Then create the recommendation that references the media item
        final stmt = _db!.prepare(insertRecommendationQuery);
        stmt.execute([
          mediaItemId,
          suggestion.query,
          suggestion.botReasoning,
          statusId,
          suggestion.createdAt.toIso8601String(),
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
        hasLiked: hasLiked,
        hasFavorited: hasFavorited,
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
             mi.wiki_url, mi.wikidata_id, mi.themes, mi.vector_media_id,
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

  // ===== USER CONSTRAINTS =====

  /// Get user constraints for a media type
  Future<List<String>> getUserConstraints(String mediaType) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getUserConstraintsForMediaQuery);
      final result = stmt.select([mediaType]);

      final constraints = result.map((row) => row['value'] as String).toList();
      stmt.dispose();
      return constraints;
    } catch (e) {
      debugPrint('Error getting user constraints: $e');
      return [];
    }
  }

  /// Get all user constraints
  Future<List<Map<String, dynamic>>> getAllUserConstraints() async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(getAllUserConstraintsQuery);
      final result = stmt.select([]);

      final constraints = result.map((row) => {
        'id': row['id'] as int,
        'media_type': row['media_type'] as String,
        'value': row['value'] as String,
      }).toList();

      stmt.dispose();
      return constraints;
    } catch (e) {
      debugPrint('Error getting all user constraints: $e');
      return [];
    }
  }

  /// Add user constraint
  Future<bool> addUserConstraint(String mediaType, String constraint) async {
    await _ensureInitialized();

    try {
      final mediaTypeId = await getMediaTypeId(mediaType);
      if (mediaTypeId == null) {
        throw Exception('Invalid media type: $mediaType');
      }

      final stmt = _db!.prepare(insertUserConstraintQuery);
      stmt.execute([mediaTypeId, constraint]);
      stmt.dispose();

      return true;
    } catch (e) {
      debugPrint('Error adding user constraint: $e');
      return false;
    }
  }

  /// Delete user constraint
  Future<bool> deleteUserConstraint(int constraintId) async {
    await _ensureInitialized();

    try {
      final stmt = _db!.prepare(deleteUserConstraintQuery);
      stmt.execute([constraintId]);
      stmt.dispose();

      return true;
    } catch (e) {
      debugPrint('Error deleting user constraint: $e');
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
      mediaItemId: row['media_item_id'] as int?,
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
      mediaId: (row['vector_media_id'] as String?) ?? 'db_legacy_${suggestionId}_${DateTime.now().millisecondsSinceEpoch}',
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
} 
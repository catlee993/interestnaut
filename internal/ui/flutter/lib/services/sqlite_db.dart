import 'dart:io';
import 'package:path/path.dart' as pathLib;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import '../queries/queries.dart';
import 'recommendation_service.dart';

/// SQLiteDatabase
/// This class is responsible for all SQLite database operations.
/// It follows a singleton pattern to ensure only one instance is used.
class SQLiteDatabase {
  static final SQLiteDatabase _instance = SQLiteDatabase._internal();
  factory SQLiteDatabase() => _instance;
  SQLiteDatabase._internal();

  Database? _db;
  bool _initialized = false;

  /// Initialize the database
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Get the database file path
      final dbPath = await _getDatabasePath();
      
      // Open the database
      _db = sqlite3.open(dbPath);
      
      // Create tables if they don't exist
      await _createTables();
      
      _initialized = true;
      debugPrint('SQLite database initialized successfully at $dbPath');
    } catch (e) {
      debugPrint('Error initializing SQLite database: $e');
      rethrow;
    }
  }

  /// Get the database file path using proper OS-specific application support directory
  Future<String> _getDatabasePath() async {
    try {
      // Use the application support directory directly (it's already app-specific)
      final appSupportDir = await getApplicationSupportDirectory();
      
      // Create the directory if it doesn't exist
      if (!await appSupportDir.exists()) {
        await appSupportDir.create(recursive: true);
      }
      
      final dbPath = pathLib.join(appSupportDir.path, 'interestnaut.db');
      debugPrint('SQLite database path: $dbPath');
      return dbPath;
    } catch (e) {
      debugPrint('Error getting database path: $e');
      rethrow;
    }
  }

  /// Create tables if they don't exist
  Future<void> _createTables() async {
    try {
      // Create new schema tables
      _db!.execute(createMediaTypesTableQuery);
      _db!.execute(createRecommendationStatusTableQuery);
      _db!.execute(insertDefaultMediaTypesQuery);
      _db!.execute(insertDefaultRecommendationStatusQuery);
      _db!.execute(createRecommendationsTableQuery);
      _db!.execute(createRecommendationMetadataTableQuery);
      _db!.execute(createUserConstraintsTableQuery);
      _db!.execute(createUserAddedFavoritesTableQuery);
      _db!.execute(createWatchlistTableQuery);
      
      // Create indexes for performance
      _db!.execute('CREATE INDEX IF NOT EXISTS idx_recommendations_vector_media_id ON recommendations(vector_media_id);');
      _db!.execute('CREATE INDEX IF NOT EXISTS idx_recommendations_media_type_id ON recommendations(media_type_id);');
      _db!.execute('CREATE INDEX IF NOT EXISTS idx_recommendations_status_id ON recommendations(status_id);');
      
      // Run migrations for existing tables
      await _runMigrations();
    } catch (e) {
      debugPrint('Error creating tables: $e');
      rethrow;
    }
  }

  /// Run database migrations (for future schema changes)
  Future<void> _runMigrations() async {
    try {
      // Future migrations will go here
      debugPrint('Database migrations completed');
    } catch (e) {
      debugPrint('Error running migrations: $e');
    }
  }

  /// Ensure the database is initialized
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

  /// Save a media suggestion to the database
  /// Returns the ID of the saved suggestion
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
        // Insert new suggestion
        final stmt = _db!.prepare(insertMediaSuggestionQuery);
        stmt.execute([
          suggestion.query,
          mediaTypeId,
          suggestion.mediaId, // This is now vector_media_id
          suggestion.title,
          suggestion.artist, // This is now primary_creator
          suggestion.coverArtUrl,
          suggestion.description,
          suggestion.wikiUrl,
          suggestion.wikidataId,
          suggestion.botReasoning,
          statusId,
          suggestion.themes,
          suggestion.createdAt.toIso8601String(),
          suggestion.updatedAt?.toIso8601String(),
        ]);
        
        final id = _db!.lastInsertRowId;
        stmt.dispose();
        return id;
      } else {
        // Update existing suggestion - TODO: Need to create update query for new schema
        throw UnimplementedError('Update not implemented for new schema yet');
      }
    } catch (e) {
      debugPrint('Error saving media suggestion: $e');
      rethrow;
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

  /// Get a media suggestion by ID
  Future<MediaSuggestion?> getMediaSuggestionById(int id) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(getMediaSuggestionByIdQuery);
      final result = stmt.select([id]);
      
      if (result.isEmpty) {
        stmt.dispose();
        return null;
      }
      
      final row = result.first;
      final suggestion = _mapRowToMediaSuggestion(row);
      stmt.dispose();
      return suggestion;
    } catch (e) {
      debugPrint('Error getting media suggestion by ID: $e');
      rethrow;
    }
  }

  /// Get all media suggestions for a specific media type
  Future<List<MediaSuggestion>> getAllMediaSuggestions({
    required String mediaType,
    SuggestionStatus? statusFilter,
    int limit = 50,
  }) async {
    await _ensureInitialized();
    
    try {
      final List<MediaSuggestion> suggestions = [];
      ResultSet result;
      
      if (statusFilter != null) {
        final stmt = _db!.prepare(getAllMediaSuggestionsWithStatusQuery);
        final statusStr = statusFilter.toString().split('.').last;
        result = stmt.select([mediaType, statusStr, limit]);
        stmt.dispose();
      } else {
        final stmt = _db!.prepare(getAllMediaSuggestionsQuery);
        result = stmt.select([mediaType, limit]);
        stmt.dispose();
      }
      
      for (final row in result) {
        suggestions.add(_mapRowToMediaSuggestion(row));
      }
      
      return suggestions;
    } catch (e) {
      debugPrint('Error getting all media suggestions: $e');
      rethrow;
    }
  }

  /// Get pending media suggestions for a specific media type
  Future<List<MediaSuggestion>> getPendingMediaSuggestions(String mediaType) async {
    await _ensureInitialized();
    
    try {
      final List<MediaSuggestion> suggestions = [];
      final stmt = _db!.prepare(getPendingMediaSuggestionsQuery);
      final result = stmt.select([mediaType]);
      
      for (final row in result) {
        suggestions.add(_mapRowToMediaSuggestion(row));
      }
      
      stmt.dispose();
      return suggestions;
    } catch (e) {
      debugPrint('Error getting pending media suggestions: $e');
      rethrow;
    }
  }

  /// Update the status of a media suggestion
  Future<bool> updateMediaSuggestionStatus(int suggestionId, SuggestionStatus status) async {
    await _ensureInitialized();
    
    try {
      final now = DateTime.now().toIso8601String();
      final statusStr = status.toString().split('.').last;
      
      final stmt = _db!.prepare(updateMediaSuggestionStatusQuery);
      stmt.execute([statusStr, now, suggestionId]);
      stmt.dispose();
      
      return true;
    } catch (e) {
      debugPrint('Error updating media suggestion status: $e');
      return false;
    }
  }

  /// Delete a media suggestion by ID
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

  /// Count pending media suggestions for a specific media type and status
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
      rethrow;
    }
  }

  /// Add recommendation to watchlist
  Future<void> addToWatchlist(int recommendationId) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(addToWatchlistQuery);
      stmt.execute([
        recommendationId,
        DateTime.now().toIso8601String(),
      ]);
      stmt.dispose();
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
      rethrow;
    }
  }

  /// Remove recommendation from watchlist
  Future<void> removeFromWatchlist(int recommendationId) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(removeFromWatchlistQuery);
      stmt.execute([recommendationId]);
      stmt.dispose();
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
      rethrow;
    }
  }

  /// Get all watchlist items for a specific media type
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
      rethrow;
    }
  }

  /// Get pending suggestions that are NOT in watchlist (for main suggestions)
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
      rethrow;
    }
  }

  /// Check if recommendation is in watchlist
  Future<bool> isInWatchlist(int recommendationId) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(isInWatchlistQuery);
      final result = stmt.select([recommendationId]);
      
      final count = result.isNotEmpty ? result.first['count'] as int : 0;
      stmt.dispose();
      return count > 0;
    } catch (e) {
      debugPrint('Error checking if in watchlist: $e');
      rethrow;
    }
  }

  /// Map a database row to a MediaSuggestion object
  MediaSuggestion _mapRowToMediaSuggestion(Row row) {
    return MediaSuggestion(
      id: row['id'] as int,
      query: row['query'] as String,
      mediaType: row['media_type'] as String,
      title: row['title'] as String?,
      artist: row['primary_creator'] as String?, // Maps primary_creator to artist for backwards compatibility
      coverArtUrl: row['cover_art_url'] as String?,
      description: row['description'] as String?,
      wikiUrl: row['wiki_url'] as String?,
      wikidataId: row['wikidata_id'] as String?,
      botReasoning: row['bot_reasoning'] as String?,
      themes: row['themes'] as String?,
      mediaId: row['vector_media_id'] as String?, // Maps vector_media_id to mediaId
      status: SuggestionStatus.values.firstWhere(
        (s) => s.toString().split('.').last == (row['status'] as String),
        orElse: () => SuggestionStatus.pending,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  /// Clean up bad suggestions from the database
  Future<int> cleanupBadSuggestions() async {
    await _ensureInitialized();
    
    try {
      // Custom cleanup query for bad suggestions
      const cleanupQuery = '''
        DELETE FROM recommendations 
        WHERE title IS NULL 
           OR title = '' 
           OR title LIKE '%Why%' 
           OR title LIKE '%What%'
           OR title LIKE '%How%'
           OR title LIKE '%Because%'
           OR title LIKE 'http%'
           OR artist IS NULL 
           OR artist = ''
           OR artist LIKE '%Why%'
           OR artist LIKE '%What%'
           OR artist LIKE '%How%'
           OR artist LIKE '%Because%';
      ''';
      
      final stmt = _db!.prepare(cleanupQuery);
      final result = stmt.execute([]);
      stmt.dispose();
      
      // Get the number of rows affected
      final changesStmt = _db!.prepare('SELECT changes()');
      final changesResult = changesStmt.select([]);
      final deletedCount = changesResult.isNotEmpty ? changesResult.first['changes()'] as int : 0;
      changesStmt.dispose();
      
      debugPrint('Cleaned up $deletedCount bad suggestions from database');
      return deletedCount;
    } catch (e) {
      debugPrint('Error cleaning up bad suggestions: $e');
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
        stmt.dispose();
        return null;
      }
      
      final id = result.first['id'] as int;
      stmt.dispose();
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

  /// Add user constraint
  Future<bool> addUserConstraint(String mediaType, String constraint) async {
    await _ensureInitialized();
    
    try {
      final mediaTypeId = await getMediaTypeId(mediaType);
      if (mediaTypeId == null) {
        debugPrint('Media type not found: $mediaType');
        return false;
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

  /// Add user-added favorite
  Future<int?> addUserFavorite({
    required String title,
    required String mediaType,
    String? artist,
    String? coverArtUrl,
    String? themes,
  }) async {
    await _ensureInitialized();
    
    try {
      final mediaTypeId = await getMediaTypeId(mediaType);
      if (mediaTypeId == null) {
        debugPrint('Media type not found: $mediaType');
        return null;
      }
      
      final stmt = _db!.prepare(insertUserAddedFavoriteQuery);
      stmt.execute([title, mediaTypeId, artist, coverArtUrl, themes]);
      
      final id = _db!.lastInsertRowId;
      stmt.dispose();
      return id;
    } catch (e) {
      debugPrint('Error adding user favorite: $e');
      return null;
    }
  }

  /// Get user-added favorites for a media type
  Future<List<Map<String, dynamic>>> getUserFavorites(String mediaType) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(getUserAddedFavoritesForMediaQuery);
      final result = stmt.select([mediaType]);
      
      final favorites = result.map((row) => {
        'id': row['id'] as int,
        'title': row['title'] as String,
        'artist': row['artist'] as String?,
        'cover_art_url': row['cover_art_url'] as String?,
        'themes': row['themes'] as String?,
        'created_at': row['created_at'] as String,
      }).toList();
      
      stmt.dispose();
      return favorites;
    } catch (e) {
      debugPrint('Error getting user favorites: $e');
      return [];
    }
  }

  /// Get all user-added favorites
  Future<List<Map<String, dynamic>>> getAllUserFavorites() async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(getAllUserAddedFavoritesQuery);
      final result = stmt.select([]);
      
      final favorites = result.map((row) => {
        'id': row['id'] as int,
        'title': row['title'] as String,
        'artist': row['artist'] as String?,
        'cover_art_url': row['cover_art_url'] as String?,
        'themes': row['themes'] as String?,
        'created_at': row['created_at'] as String,
        'media_type': row['media_type'] as String,
      }).toList();
      
      stmt.dispose();
      return favorites;
    } catch (e) {
      debugPrint('Error getting all user favorites: $e');
      return [];
    }
  }

  /// Delete user-added favorite
  Future<bool> deleteUserFavorite(int favoriteId) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(deleteUserAddedFavoriteQuery);
      stmt.execute([favoriteId]);
      stmt.dispose();
      
      return true;
    } catch (e) {
      debugPrint('Error deleting user favorite: $e');
      return false;
    }
  }

  /// Add recommendation metadata
  Future<bool> addRecommendationMetadata(int recommendationId, String key, String value) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(insertRecommendationMetadataQuery);
      stmt.execute([recommendationId, key, value]);
      stmt.dispose();
      
      return true;
    } catch (e) {
      debugPrint('Error adding recommendation metadata: $e');
      return false;
    }
  }

  /// Get recommendation metadata
  Future<Map<String, String>> getRecommendationMetadata(int recommendationId) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(getRecommendationMetadataQuery);
      final result = stmt.select([recommendationId]);
      
      final metadata = <String, String>{};
      for (final row in result) {
        metadata[row['key'] as String] = row['value'] as String;
      }
      
      stmt.dispose();
      return metadata;
    } catch (e) {
      debugPrint('Error getting recommendation metadata: $e');
      return {};
    }
  }

  /// Get specific recommendation metadata value
  Future<String?> getRecommendationMetadataValue(int recommendationId, String key) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(getRecommendationMetadataValueQuery);
      final result = stmt.select([recommendationId, key]);
      
      if (result.isEmpty) {
        stmt.dispose();
        return null;
      }
      
      final value = result.first['value'] as String;
      stmt.dispose();
      return value;
    } catch (e) {
      debugPrint('Error getting recommendation metadata value: $e');
      return null;
    }
  }

  /// Delete recommendation metadata
  Future<bool> deleteRecommendationMetadata(int recommendationId) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(deleteRecommendationMetadataQuery);
      stmt.execute([recommendationId]);
      stmt.dispose();
      
      return true;
    } catch (e) {
      debugPrint('Error deleting recommendation metadata: $e');
      return false;
    }
  }

  /// Get liked recommendations for learning user preferences
  Future<List<MediaSuggestion>> getLikedRecommendations(String mediaType) async {
    await _ensureInitialized();
    
    try {
      debugPrint('🗄️ [DB] Executing getLikedRecommendations query for: $mediaType');
      final stmt = _db!.prepare(getLikedRecommendationsQuery);
      final result = stmt.select([mediaType]);
      
      debugPrint('🗄️ [DB] getLikedRecommendations returned ${result.length} rows');
      
      final suggestions = result.map((row) => _mapRowToMediaSuggestion(row)).toList();
      stmt.dispose();
      return suggestions;
    } catch (e) {
      debugPrint('Error getting liked recommendations: $e');
      return [];
    }
  }

  /// Get disliked recommendations for avoiding similar content
  Future<List<MediaSuggestion>> getDislikedRecommendations(String mediaType) async {
    await _ensureInitialized();
    
    try {
      debugPrint('🗄️ [DB] Executing getDislikedRecommendations query for: $mediaType');
      final stmt = _db!.prepare(getDislikedRecommendationsQuery);
      final result = stmt.select([mediaType]);
      
      debugPrint('🗄️ [DB] getDislikedRecommendations returned ${result.length} rows');
      
      final suggestions = result.map((row) => _mapRowToMediaSuggestion(row)).toList();
      stmt.dispose();
      return suggestions;
    } catch (e) {
      debugPrint('Error getting disliked recommendations: $e');
      return [];
    }
  }

  /// Get user preference summary for a media type
  Future<Map<String, dynamic>> getUserPreferenceSummary(String mediaType) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(getUserPreferenceSummaryQuery);
      final result = stmt.select([mediaType]);
      
      final summary = <String, dynamic>{};
      for (final row in result) {
        final status = row['status'] as String;
        summary[status] = {
          'count': row['count'] as int,
          'themes': (row['all_themes'] as String?)?.split(',').where((t) => t.trim().isNotEmpty).toList() ?? [],
          'artists': (row['all_artists'] as String?)?.split(',').where((a) => a.trim().isNotEmpty).toList() ?? [],
        };
      }
      
      stmt.dispose();
      return summary;
    } catch (e) {
      debugPrint('Error getting user preference summary: $e');
      return {};
    }
  }

  /// Debug method to inspect recommendations table
  Future<void> debugInspectRecommendationsTable() async {
    await _ensureInitialized();
    
    try {
      // Check total count
      final countStmt = _db!.prepare('SELECT COUNT(*) as count FROM recommendations');
      final countResult = countStmt.select([]);
      final totalCount = countResult.first['count'] as int;
      countStmt.dispose();
      
      debugPrint('🗄️ [DEBUG] Total recommendations in database: $totalCount');
      
      // Check by status
      final statusStmt = _db!.prepare('''
        SELECT rs.name as status, COUNT(*) as count 
        FROM recommendations r 
        JOIN recommendation_status rs ON r.status_id = rs.id 
        GROUP BY rs.name
      ''');
      final statusResult = statusStmt.select([]);
      
      debugPrint('🗄️ [DEBUG] Recommendations by status:');
      for (final row in statusResult) {
        debugPrint('🗄️ [DEBUG]   ${row['status']}: ${row['count']}');
      }
      statusStmt.dispose();
      
      // Check by media type
      final mediaStmt = _db!.prepare('''
        SELECT mt.name as media_type, rs.name as status, COUNT(*) as count 
        FROM recommendations r 
        JOIN media_types mt ON r.media_type_id = mt.id 
        JOIN recommendation_status rs ON r.status_id = rs.id 
        GROUP BY mt.name, rs.name
        ORDER BY mt.name, rs.name
      ''');
      final mediaResult = mediaStmt.select([]);
      
      debugPrint('🗄️ [DEBUG] Recommendations by media type and status:');
      for (final row in mediaResult) {
        debugPrint('🗄️ [DEBUG]   ${row['media_type']} - ${row['status']}: ${row['count']}');
      }
      mediaStmt.dispose();
      
    } catch (e) {
      debugPrint('🗄️ [DEBUG] Error inspecting recommendations table: $e');
    }
  }
}
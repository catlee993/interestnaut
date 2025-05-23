import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:interestnaut/queries/queries.dart';
import 'package:interestnaut/services/recommendation_service.dart';

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

  /// Get the database file path
  Future<String> _getDatabasePath() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'interestnaut.db');
      return path;
    } catch (e) {
      debugPrint('Error getting database path: $e');
      rethrow;
    }
  }

  /// Create tables if they don't exist
  Future<void> _createTables() async {
    try {
      _db!.execute(createRecommendationsTableQuery);
    } catch (e) {
      debugPrint('Error creating tables: $e');
      rethrow;
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
      
      if (isNew) {
        // Insert new suggestion
        final stmt = _db!.prepare(insertMediaSuggestionQuery);
        stmt.execute([
          suggestion.query,
          suggestion.mediaType,
          suggestion.title,
          suggestion.artist,
          suggestion.album,
          suggestion.coverArtUrl,
          suggestion.description,
          suggestion.wikiUrl,
          suggestion.wikidataId,
          suggestion.botReasoning,
          suggestion.status.toString().split('.').last,
          suggestion.createdAt.toIso8601String(),
          suggestion.updatedAt?.toIso8601String(),
        ]);
        
        final id = _db!.lastInsertRowId;
        stmt.dispose();
        return id;
      } else {
        // Update existing suggestion
        final stmt = _db!.prepare(updateMediaSuggestionQuery);
        stmt.execute([
          suggestion.query,
          suggestion.mediaType,
          suggestion.title,
          suggestion.artist,
          suggestion.album,
          suggestion.coverArtUrl,
          suggestion.description,
          suggestion.wikiUrl,
          suggestion.wikidataId,
          suggestion.botReasoning,
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

  /// Count pending media suggestions for a specific media type
  Future<int> countPendingMediaSuggestions(String mediaType) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(countPendingMediaSuggestionsQuery);
      final result = stmt.select([mediaType]);
      
      final count = result.first['count'] as int;
      stmt.dispose();
      
      return count;
    } catch (e) {
      debugPrint('Error counting pending media suggestions: $e');
      return 0;
    }
  }

  /// Map a database row to a MediaSuggestion object
  MediaSuggestion _mapRowToMediaSuggestion(Row row) {
    return MediaSuggestion(
      id: row['id'] as int,
      query: row['query'] as String,
      mediaType: row['media_type'] as String,
      title: row['title'] as String?,
      artist: row['artist'] as String?,
      album: row['album'] as String?,
      coverArtUrl: row['cover_art_url'] as String?,
      description: row['description'] as String?,
      wikiUrl: row['wiki_url'] as String?,
      wikidataId: row['wikidata_id'] as String?,
      botReasoning: row['bot_reasoning'] as String?,
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
}
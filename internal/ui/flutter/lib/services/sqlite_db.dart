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

  /// Get the database file path
  Future<String> _getDatabasePath() async {
    try {
      if (Platform.isWindows) {
        // On Windows, use the application support directory which is more appropriate
        // for database files than the documents directory
        final appDataDir = await getApplicationSupportDirectory();
        final dbDir = Directory(pathLib.join(appDataDir.path, 'Interestnaut'));
        
        // Create the directory if it doesn't exist
        if (!await dbDir.exists()) {
          await dbDir.create(recursive: true);
        }
        
        final path = pathLib.join(dbDir.path, 'interestnaut.db');
        debugPrint('Windows SQLite database path: $path');
        return path;
      } else {
        // For other platforms, use the documents directory as before
        final documentsDirectory = await getApplicationDocumentsDirectory();
        final path = pathLib.join(documentsDirectory.path, 'interestnaut.db');
        return path;
      }
    } catch (e) {
      debugPrint('Error getting database path: $e');
      rethrow;
    }
  }

  /// Create tables if they don't exist
  Future<void> _createTables() async {
    try {
      _db!.execute(createRecommendationsTableQuery);
      _db!.execute(createWatchlistTableQuery);
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

  /// Count pending media suggestions for a specific media type and status
  Future<int> countPendingMediaSuggestions(String mediaType) async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(countPendingMediaSuggestionsQuery);
      final result = stmt.select([mediaType, 'pending']);
      
      final count = result.isNotEmpty ? result.first['COUNT(*)'] as int : 0;
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
      final stmt = _db!.prepare(getWatchlistQuery);
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
      
      final count = result.isNotEmpty ? result.first['COUNT(*)'] as int : 0;
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

  /// Clean up bad suggestions from the database
  Future<int> cleanupBadSuggestions() async {
    await _ensureInitialized();
    
    try {
      final stmt = _db!.prepare(deleteBadSuggestionsQuery);
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
}
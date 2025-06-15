import 'package:flutter/foundation.dart';
import '../services/sqlite_db.dart';
import 'vector_db.dart';

/// DatabaseManager
/// Coordinates both user data (SQLite) and vector search (VectorDB)
/// Provides a unified interface for all database operations
class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  final SQLiteDatabase _userDb = SQLiteDatabase();
  final VectorDatabase _vectorDb = VectorDatabase();
  
  bool _initialized = false;

  /// Initialize both databases
  Future<void> init() async {
    if (_initialized) return;

    try {
      debugPrint('Initializing database manager...');
      
      // Initialize user database first (faster)
      await _userDb.init();
      debugPrint('User database initialized');
      
      // Initialize vector database (may download files)
      await _vectorDb.init();
      debugPrint('Vector database initialized');
      
      _initialized = true;
      debugPrint('Database manager initialization complete');
    } catch (e) {
      debugPrint('Error initializing database manager: $e');
      rethrow;
    }
  }

  /// Get user database instance
  SQLiteDatabase get userDb => _userDb;
  
  /// Get vector database instance
  VectorDatabase get vectorDb => _vectorDb;

  /// Check if both databases are ready
  bool get isReady => _initialized;

  /// Get available media types from vector database
  List<String> getAvailableMediaTypes() {
    return _vectorDb.getAvailableMediaTypes();
  }

  /// Check if a specific media type is available for vector search
  bool isMediaTypeAvailable(String mediaType) {
    return _vectorDb.isMediaTypeAvailable(mediaType);
  }

  /// Get statistics for both databases
  Future<Map<String, dynamic>> getDatabaseStats() async {
    if (!_initialized) {
      await init();
    }

    try {
      // Get vector database stats
      final vectorStats = await _vectorDb.getShardStats();
      
      // Get user database stats
      final userStats = <String, int>{};
      for (final mediaType in ['video_game', 'movie', 'tv_show', 'book', 'music']) {
        try {
          final count = await _userDb.countPendingMediaSuggestions(mediaType);
          userStats['${mediaType}_suggestions'] = count;
        } catch (e) {
          userStats['${mediaType}_suggestions'] = 0;
        }
      }

      return {
        'vector_database': vectorStats,
        'user_database': userStats,
        'total_vector_items': vectorStats.values.fold<int>(0, (sum, count) => sum + count),
        'initialized': _initialized,
      };
    } catch (e) {
      debugPrint('Error getting database stats: $e');
      return {
        'error': e.toString(),
        'initialized': _initialized,
      };
    }
  }

  /// Close both databases
  Future<void> close() async {
    try {
      await _userDb.close();
      await _vectorDb.close();
      _initialized = false;
      debugPrint('Database manager closed');
    } catch (e) {
      debugPrint('Error closing database manager: $e');
    }
  }

  /// Force re-initialization (useful for testing or recovery)
  Future<void> reinitialize() async {
    await close();
    _initialized = false;
    await init();
  }
} 
import 'package:flutter/foundation.dart';
import '../services/sqlite_db.dart';

/// DatabaseManager
/// Manages user data (SQLite) storage for local recommendations and metadata
/// Vector search is now handled by gRPC backend
class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  final SQLiteDatabase _userDb = SQLiteDatabase();
  
  bool _initialized = false;

  /// Initialize user database
  Future<void> init() async {
    if (_initialized) return;

    try {
      debugPrint('Initializing database manager...');
      
      // Initialize user database (interestnaut.db)
      await _userDb.init();
      debugPrint('User database initialized');
      
      _initialized = true;
      debugPrint('Database manager initialization complete');
    } catch (e) {
      debugPrint('Error initializing database manager: $e');
      rethrow;
    }
  }

  /// Get user database instance
  SQLiteDatabase get userDb => _userDb;

  /// Check if database is ready
  bool get isReady => _initialized;

  /// Get user database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    if (!_initialized) {
      await init();
    }

    try {
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
        'user_database': userStats,
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

  /// Close user database
  Future<void> close() async {
    try {
      await _userDb.close();
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
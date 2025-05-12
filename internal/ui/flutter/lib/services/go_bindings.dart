import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models.dart';
import 'ffi_bridge.dart' show FFIBindingBase, GoFFILibrary;
import 'ffi_init.dart';
import 'dart:convert';

// Import all FFI bindings
import 'auth_ffi.dart';
import 'books_ffi.dart';
import 'games_ffi.dart';
import 'movies_ffi.dart';
import 'music_ffi.dart';
import 'settings_ffi.dart';
import 'tv_ffi.dart';

/// GoBindings provides direct access to the Go backend functions
/// Similar to the Wails bindings in frontend/wailsjs/go/bindings
class GoBindings {
  static GoBindings? _instance;
  static bool _isInitialized = false;
  
  // Direct bindings to Go services
  late MusicBindings music;
  late MovieBindings movies;
  late TVShowBindings tvShows;
  late BookBindings books;
  late GameBindings games;
  late SettingsBindings settings;
  late AuthBindings auth;
  
  // Private constructor for singleton
  GoBindings._() {
    music = MusicBindings();
    movies = MovieBindings();
    tvShows = TVShowBindings();
    books = BookBindings();
    games = GameBindings();
    settings = SettingsBindings();
    auth = AuthBindings();
  }
  
  /// Returns the singleton instance
  static GoBindings get instance {
    if (_instance == null) {
      if (!FFIInitializer.isInitialized) {
        throw Exception("FFI not initialized. Call initialize() first.");
      }
      _instance = GoBindings._();
      _isInitialized = true;
    }
    
    // Double-check FFI is still valid
    if (!FFIInitializer.isInitialized) {
      _isInitialized = false;
      _instance = null;
      throw Exception("FFI library is no longer valid. Please reinitialize.");
    }
    
    return _instance!;
  }
  
  /// Initialize the bindings
  static Future<void> initialize() async {
    if (_isInitialized && _instance != null) {
      if (FFIInitializer.isInitialized) {
        debugPrint('GoBindings already initialized and FFI is valid, skipping');
        return;
      } else {
        debugPrint('GoBindings marked as initialized but FFI is invalid, reinitializing');
        _isInitialized = false;
        _instance = null;
      }
    }
    
    debugPrint('Initializing GoBindings...');
    
    if (!FFIInitializer.isInitialized) {
      debugPrint('FFI not initialized, initializing now...');
      await FFIInitializer.initialize();
      debugPrint('FFI initialized, FFI status: isInitialized=${FFIInitializer.isInitialized}');
    }
    
    if (!FFIInitializer.isInitialized) {
      throw Exception("FFI failed to initialize properly. Cannot create GoBindings.");
    }
    
    _instance = GoBindings._();
    _isInitialized = true;
    debugPrint('GoBindings initialized successfully');
  }
  
  /// Signal the Go app to shut down
  static void signalShutdown() {
    if (!FFIInitializer.isInitialized) {
      debugPrint('FFI not initialized, cannot signal shutdown');
      return;
    }
    
    try {
      final signalShutdown = GoFFILibrary.dylib
          .lookupFunction<Void Function(), void Function()>('SignalShutdown');
      signalShutdown();
      debugPrint('Signaled Go app to shut down');
    } catch (e) {
      debugPrint('Error signaling Go app shutdown: $e');
    }
  }
  
  /// Check if FFI is available
  static bool get ffiAvailable => FFIInitializer.isInitialized && _isInitialized;
}

/// MusicBindings provides direct access to the Go Music functions
class MusicBindings {
  final _ffi = MusicFFI();
  
  /// Ensure FFI is initialized before making a call
  Future<void> _ensureInitialized() async {
    if (!GoBindings.ffiAvailable) {
      debugPrint("FFI not initialized or valid in MusicBindings, attempting initialization...");
      
      // Log FFI status for diagnosis
      debugPrint('FFI status before init: ${FFIInitializer.isInitialized}');
      
      try {
        // First ensure FFI is initialized
        if (!FFIInitializer.isInitialized) {
          await FFIInitializer.initialize();
          debugPrint('FFI initialized successfully');
        }
        
        // Then ensure GoBindings is initialized
        await GoBindings.initialize();
        debugPrint('GoBindings initialized successfully');
        
        // Verify initialization was successful
        if (!GoBindings.ffiAvailable) {
          final paths = FFIInitializer.searchPaths.join(', ');
          throw Exception('FFI initialization completed but verification failed. Searched paths: $paths');
        }
        
        debugPrint('FFI and GoBindings successfully initialized');
      } catch (e) {
        debugPrint('Error during initialization: $e');
        throw Exception('Failed to initialize FFI: $e');
      }
    }
  }
  
  /// Get authentication status
  Future<Map<String, dynamic>> getAuthStatus() async {
    try {
      await _ensureInitialized();
      return await _ffi.getAuthStatus();
    } catch (e) {
      debugPrint('Error getting auth status: $e');
      debugPrint('FFI status: initialized=${FFIInitializer.isInitialized}');
      return {'isAuthenticated': false, 'error': e.toString()};
    }
  }
  
  /// Get user's saved tracks
  Future<Map<String, dynamic>> getSavedTracks(int limit, int offset) async {
    try {
      await _ensureInitialized();
      return await _ffi.getSavedTracks(limit, offset);
    } catch (e) {
      debugPrint('Error getting saved tracks: $e');
      return {'items': [], 'total': 0, 'error': e.toString()};
    }
  }
  
  /// Save a track to the user's library
  Future<void> saveTrack(String trackId) async {
    try {
      await _ensureInitialized();
      await _ffi.saveTrack(trackId);
    } catch (e) {
      debugPrint('Error saving track: $e');
      rethrow;
    }
  }
  
  /// Remove a track from the user's library
  Future<void> removeTrack(String trackId) async {
    try {
      await _ensureInitialized();
      await _ffi.removeTrack(trackId);
    } catch (e) {
      debugPrint('Error removing track: $e');
      rethrow;
    }
  }
  
  /// Get current user profile
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      await _ensureInitialized();
      return await _ffi.getCurrentUser();
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return {'display_name': 'User', 'error': e.toString()};
    }
  }
  
  /// Request a new suggestion
  Future<Map<String, dynamic>> requestNewSuggestion() async {
    try {
      await _ensureInitialized();
      return await _ffi.requestNewSuggestion();
    } catch (e) {
      debugPrint('Error getting music suggestion: $e');
      return {
        'id': 'error',
        'title': 'Error',
        'overview': 'Could not get suggestion',
        'mediaType': 'music',
      };
    }
  }
  
  /// Provide feedback for a suggestion
  Future<void> provideSuggestionFeedback(String outcome, String title, String artist, String album) async {
    try {
      await _ensureInitialized();
      await _ffi.provideSuggestionFeedback(outcome, title, artist, album);
    } catch (e) {
      debugPrint('Error providing feedback: $e');
      rethrow;
    }
  }
  
  /// Get a valid Spotify token
  Future<String> getValidToken() async {
    try {
      await _ensureInitialized();
      return await _ffi.getValidToken();
    } catch (e) {
      debugPrint('Error getting valid token: $e');
      rethrow;
    }
  }
  
  /// Clear Spotify credentials
  Future<void> clearSpotifyCredentials() async {
    try {
      await _ensureInitialized();
      await _ffi.clearSpotifyCredentials();
    } catch (e) {
      debugPrint('Error clearing Spotify credentials: $e');
      rethrow;
    }
  }
  
  /// Explicitly initiate Spotify authentication
  /// This is now non-blocking and returns immediately while auth happens in background.
  /// Status updates are communicated via the event bus, not through the return value.
  Future<void> initiateSpotifyAuth() async {
    try {
      debugPrint('Initiating Spotify auth in MusicBindings...');
      await _ensureInitialized();
      debugPrint('FFI initialized, calling _ffi.initiateSpotifyAuth()');
      // The Go function will now return immediately, and the auth status
      // will be communicated via the event bus
      await _ffi.initiateSpotifyAuth();
      debugPrint('Spotify auth initiated - waiting for event bus updates');
    } catch (e) {
      debugPrint('Error initiating Spotify auth: $e');
      debugPrint('FFI status: initialized=${FFIInitializer.isInitialized}');
      // Don't rethrow - the UI should be listening to the event bus for auth status
    }
  }
  
  /// Search for tracks
  Future<List<dynamic>> searchTracks(String query, int limit) async {
    try {
      await _ensureInitialized();
      return await _ffi.searchTracks(query, limit);
    } catch (e) {
      debugPrint('Error searching tracks: $e');
      return [];
    }
  }
}

/// MovieBindings provides direct access to the Go Movie functions
class MovieBindings {
  final _ffi = MoviesFFI();
  
  /// Get movie suggestions
  Future<Map<String, dynamic>> getMovieSuggestion() async {
    try {
      return await _ffi.getMovieSuggestion();
    } catch (e) {
      debugPrint('Error getting movie suggestion: $e');
      return {
        'id': 'error',
        'title': 'Error',
        'overview': 'Could not get suggestion',
        'mediaType': 'movie',
      };
    }
  }
  
  /// Provide feedback for a movie suggestion
  Future<void> provideSuggestionFeedback(String outcome, int movieId) async {
    try {
      await _ffi.provideSuggestionFeedback(outcome, movieId);
    } catch (e) {
      debugPrint('Error providing movie feedback: $e');
    }
  }
  
  /// Search for movies
  Future<List<dynamic>> searchMovies(String query) async {
    try {
      return await _ffi.searchMovies(query);
    } catch (e) {
      debugPrint('Error searching movies: $e');
      return [];
    }
  }
  
  /// Get movie details
  Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    try {
      return await _ffi.getMovieDetails(movieId);
    } catch (e) {
      debugPrint('Error getting movie details: $e');
      return {'title': 'Error', 'overview': 'Could not get movie details'};
    }
  }
  
  /// Get favorite movies
  Future<List<dynamic>> getFavoriteMovies() async {
    try {
      return await _ffi.getFavoriteMovies();
    } catch (e) {
      debugPrint('Error getting favorite movies: $e');
      return [];
    }
  }
  
  /// Get movie watchlist
  Future<List<dynamic>> getWatchlist() async {
    try {
      return await _ffi.getWatchlist();
    } catch (e) {
      debugPrint('Error getting movie watchlist: $e');
      return [];
    }
  }
}

/// TVShowBindings provides direct access to the Go TVShow functions
class TVShowBindings {
  /// Get TV show suggestions
  Future<Map<String, dynamic>> requestNewSuggestion() async {
    // This will be implemented similarly to MovieBindings
    return {
      'id': 'tv0',
      'title': 'Example TV Show',
      'mediaType': 'tv',
    };
  }
}

/// BookBindings provides direct access to the Go Book functions
class BookBindings {
  /// Get book suggestions
  Future<Map<String, dynamic>> requestNewSuggestion() async {
    // This will be implemented similarly to MovieBindings
    return {
      'id': 'book0',
      'title': 'Example Book',
      'mediaType': 'book',
    };
  }
}

/// GameBindings provides direct access to the Go Game functions
class GameBindings {
  /// Get game suggestions
  Future<Map<String, dynamic>> requestNewSuggestion() async {
    // This will be implemented similarly to MovieBindings
    return {
      'id': 'game0',
      'title': 'Example Game',
      'mediaType': 'game',
    };
  }
}

/// SettingsBindings provides direct access to the Go Settings functions
class SettingsBindings {
  /// Get LLM provider setting
  Future<String> getLLMProvider() async {
    // This will be implemented with FFI
    return 'openai';
  }
  
  /// Set LLM provider setting
  Future<void> setLLMProvider(String provider) async {
    // This will be implemented with FFI
  }
}

/// AuthBindings provides direct access to the Go Auth functions
class AuthBindings {
  final _ffi = AuthFFI();
  
  /// Ensure FFI is initialized before making a call
  Future<void> _ensureInitialized() async {
    if (!GoBindings.ffiAvailable) {
      debugPrint("FFI not initialized or valid in AuthBindings, attempting initialization...");
      
      // Log FFI status for diagnosis
      debugPrint('FFI status before init: ${FFIInitializer.isInitialized}');
      
      try {
        // First ensure FFI is initialized
        if (!FFIInitializer.isInitialized) {
          await FFIInitializer.initialize();
          debugPrint('FFI initialized successfully');
        }
        
        // Then ensure GoBindings is initialized
        await GoBindings.initialize();
        debugPrint('GoBindings initialized successfully');
        
        // Verify initialization was successful
        if (!GoBindings.ffiAvailable) {
          final paths = FFIInitializer.searchPaths.join(', ');
          throw Exception('FFI initialization completed but verification failed. Searched paths: $paths');
        }
        
        debugPrint('FFI and GoBindings successfully initialized');
      } catch (e) {
        debugPrint('Error during initialization: $e');
        throw Exception('Failed to initialize FFI: $e');
      }
    }
  }
}
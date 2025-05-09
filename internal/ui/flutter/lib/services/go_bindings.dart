import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models.dart';
import 'ffi_bridge.dart';
import 'ffi_init.dart';
import 'dart:convert';

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
  
  // Private constructor for singleton
  GoBindings._() {
    music = MusicBindings();
    movies = MovieBindings();
    tvShows = TVShowBindings();
    books = BookBindings();
    games = GameBindings();
    settings = SettingsBindings();
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
      debugPrint('FFI status before init: [32m${FFIInitializer.isInitialized}[0m');
      
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
  Future<MediaItem> requestNewSuggestion() async {
    try {
      await _ensureInitialized();
      final Map<String, dynamic> response = await _ffi.requestNewSuggestion();
      
      // Parse the response into a MediaItem
      return MediaItem(
        id: response['id'] ?? '',
        title: response['name'] ?? 'Unknown Track',
        overview: response['artist'] ?? 'Unknown Artist',
        posterPath: response['album_art_url'] ?? '',
        mediaType: 'music',
        reason: response['reason'] ?? '',
      );
    } catch (e) {
      debugPrint('Error getting music suggestion: $e');
      return MediaItem(
        id: 'error',
        title: 'Error',
        overview: 'Could not get suggestion',
        mediaType: 'music',
      );
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
  Future<void> initiateSpotifyAuth() async {
    try {
      debugPrint('Initiating Spotify auth in MusicBindings...');
      await _ensureInitialized();
      debugPrint('FFI initialized, calling _ffi.initiateSpotifyAuth()');
      await _ffi.initiateSpotifyAuth();
      debugPrint('Spotify auth initiated successfully');
    } catch (e) {
      debugPrint('Error initiating Spotify auth: $e');
      debugPrint('FFI status: initialized=${FFIInitializer.isInitialized}');
      rethrow;
    }
  }
  
  /// Search for tracks
  Future<List<MediaItem>> searchTracks(String query, int limit) async {
    try {
      await _ensureInitialized();
      final List<dynamic> results = await _ffi.searchTracks(query, limit);
      return results.map((track) {
        return MediaItem(
          id: track['id'] ?? '',
          title: track['name'] ?? 'Unknown Track',
          overview: track['artist'] ?? 'Unknown Artist',
          posterPath: track['album_art_url'] ?? '',
          mediaType: 'music',
        );
      }).toList().cast<MediaItem>();
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
  Future<MediaItem> requestNewSuggestion() async {
    try {
      final Map<String, dynamic> response = await _ffi.getMovieSuggestion();
      final movie = response['movie'];
      
      if (movie == null) {
        throw Exception('Movie suggestion not found in response');
      }
      
      return MediaItem(
        id: movie['id'] ?? 0,
        title: movie['title'] ?? movie['name'] ?? 'Unknown Movie',
        overview: movie['overview'] ?? response['reason'] ?? '',
        posterPath: movie['poster_path'] ?? '',
        mediaType: 'movie',
        reason: response['reason'],
      );
    } catch (e) {
      debugPrint('Error getting movie suggestion: $e');
      return MediaItem(
        id: 0,
        title: 'Error',
        overview: 'Could not get suggestion',
        mediaType: 'movie',
      );
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
  Future<List<MediaItem>> searchMovies(String query) async {
    try {
      final List<dynamic> results = await _ffi.searchMovies(query);
      return results.map((movie) {
        return MediaItem(
          id: movie['id'] ?? 0,
          title: movie['title'] ?? movie['name'] ?? 'Unknown Movie',
          overview: movie['overview'] ?? '',
          posterPath: movie['poster_path'] ?? '',
          mediaType: 'movie',
        );
      }).toList().cast<MediaItem>();
    } catch (e) {
      debugPrint('Error searching movies: $e');
      return [];
    }
  }
  
  /// Get movie details
  Future<MediaItem> getMovieDetails(int movieId) async {
    try {
      final Map<String, dynamic> movie = await _ffi.getMovieDetails(movieId);
      
      return MediaItem(
        id: movie['id'] ?? 0,
        title: movie['title'] ?? movie['name'] ?? 'Unknown Movie',
        overview: movie['overview'] ?? '',
        posterPath: movie['poster_path'] ?? '',
        mediaType: 'movie',
      );
    } catch (e) {
      debugPrint('Error getting movie details: $e');
      return MediaItem(
        id: movieId,
        title: 'Error',
        overview: 'Could not get movie details',
        mediaType: 'movie',
      );
    }
  }
  
  /// Get favorite movies
  Future<List<MediaItem>> getFavoriteMovies() async {
    try {
      final List<dynamic> favorites = await _ffi.getFavoriteMovies();
      return favorites.map((movie) {
        return MediaItem(
          id: 0, // Favorites might not have IDs
          title: movie['title'] ?? 'Unknown Movie',
          overview: movie['director'] ?? '',
          posterPath: movie['poster_path'] ?? '',
          mediaType: 'movie',
          director: movie['director'],
        );
      }).toList().cast<MediaItem>();
    } catch (e) {
      debugPrint('Error getting favorite movies: $e');
      return [];
    }
  }
  
  /// Get movie watchlist
  Future<List<MediaItem>> getWatchlist() async {
    try {
      final List<dynamic> watchlist = await _ffi.getWatchlist();
      return watchlist.map((movie) {
        return MediaItem(
          id: 0, // Watchlist items might not have IDs
          title: movie['title'] ?? 'Unknown Movie',
          overview: movie['director'] ?? '',
          posterPath: movie['poster_path'] ?? '',
          mediaType: 'movie',
          director: movie['director'],
        );
      }).toList().cast<MediaItem>();
    } catch (e) {
      debugPrint('Error getting movie watchlist: $e');
      return [];
    }
  }
}

/// TVShowBindings provides direct access to the Go TVShow functions
class TVShowBindings {
  /// Get TV show suggestions
  Future<MediaItem> requestNewSuggestion() async {
    // This will be implemented similarly to MovieBindings
    return MediaItem(
      id: 0,
      title: 'Example TV Show',
      mediaType: 'tv',
    );
  }
}

/// BookBindings provides direct access to the Go Book functions
class BookBindings {
  /// Get book suggestions
  Future<MediaItem> requestNewSuggestion() async {
    // This will be implemented similarly to MovieBindings
    return MediaItem(
      id: 'book0',
      title: 'Example Book',
      mediaType: 'book',
    );
  }
}

/// GameBindings provides direct access to the Go Game functions
class GameBindings {
  /// Get game suggestions
  Future<MediaItem> requestNewSuggestion() async {
    // This will be implemented similarly to MovieBindings
    return MediaItem(
      id: 'game0',
      title: 'Example Game',
      mediaType: 'game',
    );
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
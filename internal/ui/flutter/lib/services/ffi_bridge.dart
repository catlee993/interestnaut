import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'ffi_init.dart';

/// The DynamicLibrary that holds our Go FFI functions
class GoFFILibrary {
  /// Get the dynamic library from the initializer
  static DynamicLibrary get dylib => FFIInitializer.dylib;
}

/// Base class for FFI bindings to make it easier to handle common patterns
abstract class FFIBindingBase {
  /// Helper to free a string allocated by Go
  final _freeString = GoFFILibrary.dylib
    .lookupFunction<
      Void Function(Pointer<Char>),
      void Function(Pointer<Char>)
    >('FreeString');
    
  /// Helper to convert a C string to a Dart string and free the memory
  String _fromCString(Pointer<Char> cString) {
    final result = cString.cast<Utf8>().toDartString();
    _freeString(cString);
    return result;
  }
  
  /// Helper to parse a JSON response from a C string and free the memory
  dynamic _parseJsonResponse(Pointer<Char> cString) {
    final jsonStr = _fromCString(cString);
    try {
      return jsonDecode(jsonStr);
    } catch (e) {
      debugPrint('Error parsing JSON response: $e');
      debugPrint('Raw response: $jsonStr');
      return {'error': 'Failed to parse JSON response: $e'};
    }
  }
  
  /// Helper to convert a Dart string to a C string
  Pointer<Char> _toCString(String string) {
    return string.toNativeUtf8().cast<Char>();
  }
  
  /// Helper to check for errors in JSON responses
  void _checkForError(dynamic json) {
    if (json is Map && json.containsKey('error')) {
      throw Exception(json['error']);
    }
  }
}

/// The FFI bindings for Music-related functions
class MusicFFI extends FFIBindingBase {
  /// Singleton instance
  static final MusicFFI _instance = MusicFFI._();
  factory MusicFFI() => _instance;
  MusicFFI._();
  
  // Verify FFI initialization
  void _verifyFFI() {
    if (!FFIInitializer.isInitialized) {
      throw Exception("FFI library not initialized. Call initialize() first.");
    }
  }
  
  // Function pointers for all Music FFI functions
  late final _getAuthStatus = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(),
      Pointer<Char> Function()
    >('Music_GetAuthStatus');
    
  late final _getSavedTracks = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(Int, Int),
      Pointer<Char> Function(int, int)
    >('Music_GetSavedTracks');
    
  late final _saveTrack = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(Pointer<Char>),
      Pointer<Char> Function(Pointer<Char>)
    >('Music_SaveTrack');
    
  late final _removeTrack = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(Pointer<Char>),
      Pointer<Char> Function(Pointer<Char>)
    >('Music_RemoveTrack');
    
  late final _getCurrentUser = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(),
      Pointer<Char> Function()
    >('Music_GetCurrentUser');
    
  late final _requestNewSuggestion = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(),
      Pointer<Char> Function()
    >('Music_RequestNewSuggestion');
    
  late final _provideSuggestionFeedback = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(Pointer<Char>, Pointer<Char>, Pointer<Char>, Pointer<Char>),
      Pointer<Char> Function(Pointer<Char>, Pointer<Char>, Pointer<Char>, Pointer<Char>)
    >('Music_ProvideSuggestionFeedback');
    
  late final _getValidToken = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(),
      Pointer<Char> Function()
    >('Music_GetValidToken');
    
  late final _clearSpotifyCredentials = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(),
      Pointer<Char> Function()
    >('Music_ClearSpotifyCredentials');
    
  late final _searchTracks = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(Pointer<Char>, Int),
      Pointer<Char> Function(Pointer<Char>, int)
    >('Music_SearchTracks');
    
  late final _initiateSpotifyAuth = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(),
      Pointer<Char> Function()
    >('Music_InitiateSpotifyAuth');
  
  // Public API methods that match the Go API
  
  /// Get authentication status
  Future<Map<String, dynamic>> getAuthStatus() async {
    _verifyFFI();
    final response = _getAuthStatus();
    return _parseJsonResponse(response);
  }
  
  /// Get saved tracks
  Future<Map<String, dynamic>> getSavedTracks(int limit, int offset) async {
    _verifyFFI();
    final response = _getSavedTracks(limit, offset);
    return _parseJsonResponse(response);
  }
  
  /// Save a track
  Future<void> saveTrack(String trackId) async {
    _verifyFFI();
    final trackIdPtr = _toCString(trackId);
    final response = _saveTrack(trackIdPtr);
    _parseJsonResponse(response);
  }
  
  /// Remove a track
  Future<void> removeTrack(String trackId) async {
    _verifyFFI();
    final trackIdPtr = _toCString(trackId);
    final response = _removeTrack(trackIdPtr);
    _parseJsonResponse(response);
  }
  
  /// Get current user profile
  Future<Map<String, dynamic>> getCurrentUser() async {
    _verifyFFI();
    final response = _getCurrentUser();
    return _parseJsonResponse(response);
  }
  
  /// Request a new suggestion
  Future<Map<String, dynamic>> requestNewSuggestion() async {
    _verifyFFI();
    final response = _requestNewSuggestion();
    return _parseJsonResponse(response);
  }
  
  /// Provide feedback for a suggestion
  Future<void> provideSuggestionFeedback(
    String outcome, 
    String title, 
    String artist, 
    String album
  ) async {
    _verifyFFI();
    final outcomePtr = _toCString(outcome);
    final titlePtr = _toCString(title);
    final artistPtr = _toCString(artist);
    final albumPtr = _toCString(album);
    final response = _provideSuggestionFeedback(
      outcomePtr, 
      titlePtr, 
      artistPtr, 
      albumPtr
    );
    _parseJsonResponse(response);
  }
  
  /// Get a valid Spotify token
  Future<String> getValidToken() async {
    _verifyFFI();
    final response = _getValidToken();
    return _fromCString(response);
  }
  
  /// Clear Spotify credentials
  Future<void> clearSpotifyCredentials() async {
    _verifyFFI();
    final response = _clearSpotifyCredentials();
    _parseJsonResponse(response);
  }
  
  /// Search for tracks
  Future<List<dynamic>> searchTracks(String query, int limit) async {
    _verifyFFI();
    final queryPtr = _toCString(query);
    final response = _searchTracks(queryPtr, limit);
    final result = _parseJsonResponse(response);
    if (result is List) {
      return result;
    }
    return [];
  }
  
  /// Initiate Spotify authentication flow
  Future<void> initiateSpotifyAuth() async {
    _verifyFFI();
    final response = _initiateSpotifyAuth();
    _parseJsonResponse(response);
  }
}

/// The FFI bindings for Movie-related functions
class MoviesFFI extends FFIBindingBase {
  /// Singleton instance
  static final MoviesFFI _instance = MoviesFFI._();
  factory MoviesFFI() => _instance;
  MoviesFFI._();
  
  // Function pointers for Movie FFI functions
  late final _hasValidCredentials = GoFFILibrary.dylib
    .lookupFunction<
      Int Function(),
      int Function()
    >('Movies_HasValidCredentials');
    
  late final _refreshCredentials = GoFFILibrary.dylib
    .lookupFunction<
      Int Function(),
      int Function()
    >('Movies_RefreshCredentials');
    
  late final _searchMovies = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(Pointer<Char>),
      Pointer<Char> Function(Pointer<Char>)
    >('Movies_SearchMovies');
    
  late final _getMovieDetails = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(Int),
      Pointer<Char> Function(int)
    >('Movies_GetMovieDetails');
    
  late final _getMovieSuggestion = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(),
      Pointer<Char> Function()
    >('Movies_GetMovieSuggestion');
    
  late final _provideSuggestionFeedback = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(Pointer<Char>, Int),
      Pointer<Char> Function(Pointer<Char>, int)
    >('Movies_ProvideSuggestionFeedback');
    
  late final _getFavoriteMovies = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(),
      Pointer<Char> Function()
    >('Movies_GetFavoriteMovies');
    
  late final _setFavoriteMovies = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(Pointer<Char>),
      Pointer<Char> Function(Pointer<Char>)
    >('Movies_SetFavoriteMovies');
    
  late final _addToWatchlist = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(Pointer<Char>),
      Pointer<Char> Function(Pointer<Char>)
    >('Movies_AddToWatchlist');
    
  late final _removeFromWatchlist = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(Pointer<Char>),
      Pointer<Char> Function(Pointer<Char>)
    >('Movies_RemoveFromWatchlist');
    
  late final _getWatchlist = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(),
      Pointer<Char> Function()
    >('Movies_GetWatchlist');
  
  // Public API methods
  
  /// Check if the movie service has valid credentials
  Future<bool> hasValidCredentials() async {
    return await compute(
      _computeHasValidCredentials, 
      null
    );
  }
  
  /// Compute function to run in isolate
  static bool _computeHasValidCredentials(Object? _) {
    final instance = MoviesFFI();
    return instance._hasValidCredentials() == 1;
  }
  
  /// Refresh credentials
  Future<bool> refreshCredentials() async {
    return await compute(
      _computeRefreshCredentials, 
      null
    );
  }
  
  /// Compute function to run in isolate
  static bool _computeRefreshCredentials(Object? _) {
    final instance = MoviesFFI();
    return instance._refreshCredentials() == 1;
  }
  
  /// Search for movies
  Future<List<dynamic>> searchMovies(String query) async {
    final result = await compute(
      _computeSearchMovies, 
      query
    );
    _checkForError(result);
    if (result is List) {
      return result;
    } else {
      return [];
    }
  }
  
  /// Compute function to run in isolate
  static dynamic _computeSearchMovies(String query) {
    final instance = MoviesFFI();
    final queryPtr = instance._toCString(query);
    final response = instance._searchMovies(queryPtr);
    return instance._parseJsonResponse(response);
  }
  
  /// Get movie details
  Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    final result = await compute(
      _computeGetMovieDetails, 
      movieId
    );
    _checkForError(result);
    return result as Map<String, dynamic>;
  }
  
  /// Compute function to run in isolate
  static dynamic _computeGetMovieDetails(int movieId) {
    final instance = MoviesFFI();
    final response = instance._getMovieDetails(movieId);
    return instance._parseJsonResponse(response);
  }
  
  /// Get a movie suggestion
  Future<Map<String, dynamic>> getMovieSuggestion() async {
    final result = await compute(
      _computeGetMovieSuggestion, 
      null
    );
    _checkForError(result);
    return result as Map<String, dynamic>;
  }
  
  /// Compute function to run in isolate
  static dynamic _computeGetMovieSuggestion(Object? _) {
    final instance = MoviesFFI();
    final response = instance._getMovieSuggestion();
    return instance._parseJsonResponse(response);
  }
  
  /// Provide feedback for a movie suggestion
  Future<void> provideSuggestionFeedback(String outcome, int movieId) async {
    final result = await compute(
      _computeProvideSuggestionFeedback, 
      [outcome, movieId]
    );
    _checkForError(result);
  }
  
  /// Compute function to run in isolate
  static dynamic _computeProvideSuggestionFeedback(List<Object> params) {
    final instance = MoviesFFI();
    final outcomePtr = instance._toCString(params[0] as String);
    final movieId = params[1] as int;
    final response = instance._provideSuggestionFeedback(outcomePtr, movieId);
    return instance._parseJsonResponse(response);
  }
  
  /// Get favorite movies
  Future<List<dynamic>> getFavoriteMovies() async {
    final result = await compute(
      _computeGetFavoriteMovies, 
      null
    );
    _checkForError(result);
    if (result is List) {
      return result;
    } else {
      return [];
    }
  }
  
  /// Compute function to run in isolate
  static dynamic _computeGetFavoriteMovies(Object? _) {
    final instance = MoviesFFI();
    final response = instance._getFavoriteMovies();
    return instance._parseJsonResponse(response);
  }
  
  /// Set favorite movies
  Future<void> setFavoriteMovies(List<dynamic> movies) async {
    final result = await compute(
      _computeSetFavoriteMovies, 
      jsonEncode(movies)
    );
    _checkForError(result);
  }
  
  /// Compute function to run in isolate
  static dynamic _computeSetFavoriteMovies(String moviesJson) {
    final instance = MoviesFFI();
    final moviesJsonPtr = instance._toCString(moviesJson);
    final response = instance._setFavoriteMovies(moviesJsonPtr);
    return instance._parseJsonResponse(response);
  }
  
  /// Add movie to watchlist
  Future<void> addToWatchlist(Map<String, dynamic> movie) async {
    final result = await compute(
      _computeAddToWatchlist, 
      jsonEncode(movie)
    );
    _checkForError(result);
  }
  
  /// Compute function to run in isolate
  static dynamic _computeAddToWatchlist(String movieJson) {
    final instance = MoviesFFI();
    final movieJsonPtr = instance._toCString(movieJson);
    final response = instance._addToWatchlist(movieJsonPtr);
    return instance._parseJsonResponse(response);
  }
  
  /// Remove movie from watchlist
  Future<void> removeFromWatchlist(String title) async {
    final result = await compute(
      _computeRemoveFromWatchlist, 
      title
    );
    _checkForError(result);
  }
  
  /// Compute function to run in isolate
  static dynamic _computeRemoveFromWatchlist(String title) {
    final instance = MoviesFFI();
    final titlePtr = instance._toCString(title);
    final response = instance._removeFromWatchlist(titlePtr);
    return instance._parseJsonResponse(response);
  }
  
  /// Get watchlist
  Future<List<dynamic>> getWatchlist() async {
    final result = await compute(
      _computeGetWatchlist, 
      null
    );
    _checkForError(result);
    if (result is List) {
      return result;
    } else {
      return [];
    }
  }
  
  /// Compute function to run in isolate
  static dynamic _computeGetWatchlist(Object? _) {
    final instance = MoviesFFI();
    final response = instance._getWatchlist();
    return instance._parseJsonResponse(response);
  }
} 
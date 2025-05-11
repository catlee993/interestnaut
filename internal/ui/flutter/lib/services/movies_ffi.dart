import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'ffi_bridge.dart';
import 'ffi_init.dart';

/// The FFI bindings for Movies-related functions
class MoviesFFI {
  /// Singleton instance
  static final MoviesFFI _instance = MoviesFFI._();
  factory MoviesFFI() => _instance;
  
  // Function pointers for all Movies FFI functions
  final ffi.Pointer<ffi.Char> Function() _getMovieSuggestionPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, int) _provideSuggestionFeedbackPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _searchMoviesPtr;
  final ffi.Pointer<ffi.Char> Function(int) _getMovieDetailsPtr;
  final ffi.Pointer<ffi.Char> Function() _getFavoriteMoviesPtr;
  final ffi.Pointer<ffi.Char> Function() _getWatchlistPtr;
  
  // Private constructor - initialize all function pointers eagerly
  MoviesFFI._() : 
    _getMovieSuggestionPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Movies_GetMovieSuggestion'),
    _provideSuggestionFeedbackPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, ffi.Int32),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, int)>('Movies_ProvideSuggestionFeedback'),
    _searchMoviesPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('Movies_SearchMovies'),
    _getMovieDetailsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Int32),
        ffi.Pointer<ffi.Char> Function(int)>('Movies_GetMovieDetails'),
    _getFavoriteMoviesPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Movies_GetFavoriteMovies'),
    _getWatchlistPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Movies_GetWatchlist') {
    debugPrint('MoviesFFI initialized with eager function pointer loading');
  }
  
  /// Get movie suggestions
  Future<Map<String, dynamic>> getMovieSuggestion() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getMovieSuggestionPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return {
        'id': 'error',
        'title': 'Error',
        'overview': 'Could not get suggestion',
        'mediaType': 'movie',
      };
    }
    
    return result;
  }
  
  /// Provide feedback for a movie suggestion
  Future<void> provideSuggestionFeedback(String outcome, int movieId) async {
    FFIBindingBase.checkInitialized();
    
    final outcomeUtf8 = outcome.toNativeUtf8();
    _provideSuggestionFeedbackPtr(outcomeUtf8, movieId);
    calloc.free(outcomeUtf8);
  }
  
  /// Search for movies
  Future<List<dynamic>> searchMovies(String query) async {
    FFIBindingBase.checkInitialized();
    
    final queryUtf8 = query.toNativeUtf8();
    final resultPtr = _searchMoviesPtr(queryUtf8);
    calloc.free(queryUtf8);
    
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return [];
    }
    
    return result;
  }
  
  /// Get movie details
  Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getMovieDetailsPtr(movieId);
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return {'title': 'Error', 'overview': 'Could not get movie details'};
    }
    
    return result;
  }
  
  /// Get favorite movies
  Future<List<dynamic>> getFavoriteMovies() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getFavoriteMoviesPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return [];
    }
    
    return result;
  }
  
  /// Get movie watchlist
  Future<List<dynamic>> getWatchlist() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getWatchlistPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return [];
    }
    
    return result;
  }
}

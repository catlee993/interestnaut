import 'dart:ffi' as ffi;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ffi/ffi.dart';
import 'ffi_bridge.dart';
import 'ffi_init.dart';

/// The FFI bindings for TV Shows-related functions
class TVShowsFFI {
  /// Singleton instance
  static final TVShowsFFI _instance = TVShowsFFI._();
  factory TVShowsFFI() => _instance;
  
  // Function pointers for TV Shows FFI functions
  final ffi.Pointer<ffi.Char> Function() _hasValidCredentialsPtr;
  final ffi.Pointer<ffi.Char> Function() _refreshCredentialsPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _searchTVShowsPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _getTVShowDetailsPtr;
  final ffi.Pointer<ffi.Char> Function() _getTVShowSuggestionPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>) _provideSuggestionFeedbackPtr;
  final ffi.Pointer<ffi.Char> Function() _getFavoriteTVShowsPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _setFavoriteTVShowsPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _addToWatchlistPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _removeFromWatchlistPtr;
  final ffi.Pointer<ffi.Char> Function() _getWatchlistPtr;
  final ffi.Pointer<ffi.Char> Function() _refreshLLMClientsPtr;
  
  // Private constructor - initialize all function pointers eagerly
  TVShowsFFI._() : 
    _hasValidCredentialsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('TV_HasValidCredentials'),
    _refreshCredentialsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('TV_RefreshCredentials'),
    _searchTVShowsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('TV_SearchTVShows'),
    _getTVShowDetailsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('TV_GetTVShowDetails'),
    _getTVShowSuggestionPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('TV_GetTVShowSuggestion'),
    _provideSuggestionFeedbackPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>)>('TV_ProvideSuggestionFeedback'),
    _getFavoriteTVShowsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('TV_GetFavoriteTVShows'),
    _setFavoriteTVShowsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('TV_SetFavoriteTVShows'),
    _addToWatchlistPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('TV_AddToWatchlist'),
    _removeFromWatchlistPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('TV_RemoveFromWatchlist'),
    _getWatchlistPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('TV_GetWatchlist'),
    _refreshLLMClientsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('TV_RefreshLLMClients') {
    debugPrint('TVShowsFFI initialized with eager function pointer loading');
  }
  
  /// Check if we have valid credentials
  Future<bool> hasValidCredentials() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _hasValidCredentialsPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null || result is! Map) {
      return false;
    }
    
    return result['valid'] == true;
  }
  
  /// Refresh credentials
  Future<bool> refreshCredentials() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _refreshCredentialsPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null || result is! Map) {
      return false;
    }
    
    return result['success'] == true;
  }
  
  /// Search for TV shows
  Future<List<dynamic>> searchTVShows(String query) async {
    FFIBindingBase.checkInitialized();
    
    final queryUtf8 = query.toNativeUtf8();
    final resultPtr = _searchTVShowsPtr(queryUtf8);
    calloc.free(queryUtf8);
    
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return [];
    }
    
    return result;
  }
  
  /// Get TV show details
  Future<Map<String, dynamic>> getTVShowDetails(String tvShowId) async {
    FFIBindingBase.checkInitialized();
    
    final tvShowIdUtf8 = tvShowId.toNativeUtf8();
    final resultPtr = _getTVShowDetailsPtr(tvShowIdUtf8);
    calloc.free(tvShowIdUtf8);
    
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return {'title': 'Error', 'overview': 'Could not get TV show details'};
    }
    
    return result;
  }
  
  /// Get TV show suggestion
  Future<Map<String, dynamic>> getTVShowSuggestion() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getTVShowSuggestionPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return {
        'id': 'error',
        'title': 'Error',
        'overview': 'Could not get suggestion',
        'mediaType': 'tv',
      };
    }
    
    return result;
  }
  
  /// Provide feedback for a TV show suggestion
  Future<void> provideSuggestionFeedback(String outcome, String tvShowId) async {
    FFIBindingBase.checkInitialized();
    
    final outcomeUtf8 = outcome.toNativeUtf8();
    final tvShowIdUtf8 = tvShowId.toNativeUtf8();
    _provideSuggestionFeedbackPtr(outcomeUtf8, tvShowIdUtf8);
    calloc.free(outcomeUtf8);
    calloc.free(tvShowIdUtf8);
  }
  
  /// Get favorite TV shows
  Future<List<dynamic>> getFavoriteTVShows() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getFavoriteTVShowsPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return [];
    }
    
    return result;
  }
  
  /// Set favorite TV shows
  Future<void> setFavoriteTVShows(List<dynamic> tvShows) async {
    FFIBindingBase.checkInitialized();
    
    final tvShowsJson = jsonEncode(tvShows);
    final tvShowsJsonUtf8 = tvShowsJson.toNativeUtf8();
    
    _setFavoriteTVShowsPtr(tvShowsJsonUtf8);
    calloc.free(tvShowsJsonUtf8);
  }
  
  /// Add TV show to watchlist
  Future<void> addToWatchlist(Map<String, dynamic> tvShow) async {
    FFIBindingBase.checkInitialized();
    
    final tvShowJson = jsonEncode(tvShow);
    final tvShowJsonUtf8 = tvShowJson.toNativeUtf8();
    
    _addToWatchlistPtr(tvShowJsonUtf8);
    calloc.free(tvShowJsonUtf8);
  }
  
  /// Remove TV show from watchlist
  Future<void> removeFromWatchlist(String title) async {
    FFIBindingBase.checkInitialized();
    
    final titleUtf8 = title.toNativeUtf8();
    _removeFromWatchlistPtr(titleUtf8);
    calloc.free(titleUtf8);
  }
  
  /// Get watchlist
  Future<List<dynamic>> getWatchlist() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getWatchlistPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return [];
    }
    
    return result;
  }
  
  /// Refresh LLM clients
  Future<void> refreshLLMClients() async {
    FFIBindingBase.checkInitialized();
    
    _refreshLLMClientsPtr();
  }
}

/// The FFI bindings for TV-related functions
class TVFFI {
  /// Singleton instance
  static final TVFFI _instance = TVFFI._();
  factory TVFFI() => _instance;
  
  // Function pointers for TV FFI functions
  final ffi.Pointer<ffi.Char> Function() _getTVShowSuggestionPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, int) _provideSuggestionFeedbackPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _searchTVShowsPtr;
  final ffi.Pointer<ffi.Char> Function(int) _getTVShowDetailsPtr;
  final ffi.Pointer<ffi.Char> Function() _getFavoriteTVShowsPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _setFavoriteTVShowsPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _addToWatchlistPtr;
  final ffi.Pointer<ffi.Char> Function() _getWatchlistPtr;
  
  // Private constructor - initialize all function pointers eagerly
  TVFFI._() :
    _getTVShowSuggestionPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('GetTVShowSuggestion'),
    _provideSuggestionFeedbackPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, ffi.Int32),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, int)>('ProvideTVShowFeedback'),
    _searchTVShowsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('SearchTVShows'),
    _getTVShowDetailsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Int32),
        ffi.Pointer<ffi.Char> Function(int)>('GetTVShowDetails'),
    _getFavoriteTVShowsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('GetFavoriteTVShows'),
    _setFavoriteTVShowsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('SetFavoriteTVShows'),
    _addToWatchlistPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('AddTVShowToWatchlist'),
    _getWatchlistPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('GetTVShowWatchlist') {
    debugPrint('TVFFI initialized with eager function pointer loading');
  }
  
  /// Get TV show suggestion
  Future<Map<String, dynamic>> getTVShowSuggestion() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getTVShowSuggestionPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return {
        'id': 'error',
        'title': 'Error',
        'overview': 'Could not get suggestion',
        'mediaType': 'tv',
      };
    }
    
    return result;
  }
  
  /// Provide feedback for a TV show suggestion
  Future<void> provideSuggestionFeedback(String outcome, int tvShowId) async {
    FFIBindingBase.checkInitialized();
    
    final outcomeUtf8 = outcome.toNativeUtf8();
    _provideSuggestionFeedbackPtr(outcomeUtf8, tvShowId);
    calloc.free(outcomeUtf8);
  }
  
  /// Search for TV shows
  Future<List<dynamic>> searchTVShows(String query) async {
    FFIBindingBase.checkInitialized();
    
    final queryUtf8 = query.toNativeUtf8();
    final resultPtr = _searchTVShowsPtr(queryUtf8);
    calloc.free(queryUtf8);
    
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return [];
    }
    
    return result;
  }
  
  /// Get TV show details
  Future<Map<String, dynamic>> getTVShowDetails(int tvShowId) async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getTVShowDetailsPtr(tvShowId);
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return {'title': 'Error', 'overview': 'Could not get TV show details'};
    }
    
    return result;
  }
  
  /// Get favorite TV shows
  Future<List<dynamic>> getFavoriteTVShows() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getFavoriteTVShowsPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return [];
    }
    
    return result;
  }
  
  /// Set favorite TV shows
  Future<void> setFavoriteTVShows(List<dynamic> tvShows) async {
    FFIBindingBase.checkInitialized();
    
    final tvShowsJson = jsonEncode(tvShows);
    final tvShowsJsonUtf8 = tvShowsJson.toNativeUtf8();
    
    _setFavoriteTVShowsPtr(tvShowsJsonUtf8);
    calloc.free(tvShowsJsonUtf8);
  }
  
  /// Add TV show to watchlist
  Future<void> addToWatchlist(Map<String, dynamic> tvShow) async {
    FFIBindingBase.checkInitialized();
    
    final tvShowJson = jsonEncode(tvShow);
    final tvShowJsonUtf8 = tvShowJson.toNativeUtf8();
    
    _addToWatchlistPtr(tvShowJsonUtf8);
    calloc.free(tvShowJsonUtf8);
  }
  
  /// Get watchlist
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

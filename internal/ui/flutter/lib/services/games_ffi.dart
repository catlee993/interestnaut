import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ffi_bridge.dart';
import 'ffi_init.dart';

/// The FFI bindings for Games-related functions
class GamesFFI extends FFIBindingBase {
  /// Singleton instance
  static final GamesFFI _instance = GamesFFI._();
  factory GamesFFI() => _instance;
  
  // Function pointers for all Games FFI functions - declared as final for eager initialization
  final Pointer<Char> Function() _getGameSuggestion;
  final Pointer<Char> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>) _provideSuggestionFeedback;
  final Pointer<Char> Function(Pointer<Utf8>) _searchGames;
  final Pointer<Char> Function(Pointer<Utf8>) _getGameDetails;
  final Pointer<Char> Function() _getFavoriteGames;
  final Pointer<Char> Function(Pointer<Utf8>) _setFavoriteGames;
  final Pointer<Char> Function(Pointer<Utf8>) _addToGameList;
  final Pointer<Char> Function(Pointer<Utf8>, Pointer<Utf8>) _removeFromGameList;
  final Pointer<Char> Function() _getGameList;
  final Pointer<Char> Function() _refreshLLMClients;
  
  // Private constructor - initialize all function pointers eagerly
  GamesFFI._() : 
    _getGameSuggestion = GoFFILibrary.dylib.lookupFunction<
        Pointer<Char> Function(),
        Pointer<Char> Function()>('Games_GetSuggestion'),
    _provideSuggestionFeedback = GoFFILibrary.dylib.lookupFunction<
        Pointer<Char> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>),
        Pointer<Char> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>('Games_ProvideSuggestionFeedback'),
    _searchGames = GoFFILibrary.dylib.lookupFunction<
        Pointer<Char> Function(Pointer<Utf8>),
        Pointer<Char> Function(Pointer<Utf8>)>('Games_Search'),
    _getGameDetails = GoFFILibrary.dylib.lookupFunction<
        Pointer<Char> Function(Pointer<Utf8>),
        Pointer<Char> Function(Pointer<Utf8>)>('Games_GetDetails'),
    _getFavoriteGames = GoFFILibrary.dylib.lookupFunction<
        Pointer<Char> Function(),
        Pointer<Char> Function()>('Games_GetFavorites'),
    _setFavoriteGames = GoFFILibrary.dylib.lookupFunction<
        Pointer<Char> Function(Pointer<Utf8>),
        Pointer<Char> Function(Pointer<Utf8>)>('Games_SetFavorites'),
    _addToGameList = GoFFILibrary.dylib.lookupFunction<
        Pointer<Char> Function(Pointer<Utf8>),
        Pointer<Char> Function(Pointer<Utf8>)>('Games_AddToPlayList'),
    _removeFromGameList = GoFFILibrary.dylib.lookupFunction<
        Pointer<Char> Function(Pointer<Utf8>, Pointer<Utf8>),
        Pointer<Char> Function(Pointer<Utf8>, Pointer<Utf8>)>('Games_RemoveFromPlayList'),
    _getGameList = GoFFILibrary.dylib.lookupFunction<
        Pointer<Char> Function(),
        Pointer<Char> Function()>('Games_GetPlayList'),
    _refreshLLMClients = GoFFILibrary.dylib.lookupFunction<
        Pointer<Char> Function(),
        Pointer<Char> Function()>('Games_RefreshLLMClients') {
    debugPrint('GamesFFI: Successfully initialized all function pointers eagerly');
  }
  
  /// Verify the FFI is initialized
  void _verifyFFI() {
    FFIBindingBase.checkInitialized();
  }
  
  /// Get game suggestion
  Future<Map<String, dynamic>> getGameSuggestion() async {
    _verifyFFI();
    
    try {
      final resultPtr = _getGameSuggestion();
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
      
      if (result == null) {
        return {'error': 'Failed to get game suggestion'};
      }
      
      return result;
    } catch (e) {
      debugPrint('Error getting game suggestion: $e');
      return {
        'id': 'error',
        'title': 'Error',
        'overview': 'Could not get suggestion: $e',
        'mediaType': 'game',
      };
    }
  }
  
  /// Provide feedback for a game suggestion
  Future<void> provideSuggestionFeedback(String outcome, String title, String platform) async {
    _verifyFFI();
    
    try {
      final outcomeUtf8 = outcome.toNativeUtf8();
      final titleUtf8 = title.toNativeUtf8();
      final platformUtf8 = platform.toNativeUtf8();
      
      final resultPtr = _provideSuggestionFeedback(outcomeUtf8, titleUtf8, platformUtf8);
      
      calloc.free(outcomeUtf8);
      calloc.free(titleUtf8);
      calloc.free(platformUtf8);
      
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
      if (result != null && result['error'] != null) {
        debugPrint('Error providing game feedback: ${result['error']}');
      }
    } catch (e) {
      debugPrint('Error providing game feedback: $e');
    }
  }
  
  /// Search for games matching the query
  Future<List<dynamic>> searchGames(String query) async {
    _verifyFFI();
    
    try {
      final queryUtf8 = query.toNativeUtf8();
      final resultPtr = _searchGames(queryUtf8);
      calloc.free(queryUtf8);
      
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
      
      if (result == null) {
        return [];
      }
      
      return result;
    } catch (e) {
      debugPrint('Error searching games: $e');
      return [];
    }
  }
  
  /// Get detailed information about a specific game
  Future<Map<String, dynamic>> getGameDetails(String gameId) async {
    _verifyFFI();
    
    try {
      final gameIdUtf8 = gameId.toNativeUtf8();
      final resultPtr = _getGameDetails(gameIdUtf8);
      calloc.free(gameIdUtf8);
      
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
      
      if (result == null) {
        return {'error': 'Failed to get game details'};
      }
      
      return result;
    } catch (e) {
      debugPrint('Error getting game details: $e');
      return {'error': 'Failed to get game details: $e'};
    }
  }
  
  /// Get the user's favorite games
  Future<List<dynamic>> getFavoriteGames() async {
    _verifyFFI();
    
    try {
      final resultPtr = _getFavoriteGames();
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
      
      if (result == null) {
        return [];
      }
      
      return result;
    } catch (e) {
      debugPrint('Error getting favorite games: $e');
      return [];
    }
  }
  
  /// Set the user's favorite games
  Future<void> setFavoriteGames(List<dynamic> games) async {
    _verifyFFI();
    
    try {
      final gamesJson = jsonEncode(games);
      final gamesUtf8 = gamesJson.toNativeUtf8();
      
      final resultPtr = _setFavoriteGames(gamesUtf8);
      calloc.free(gamesUtf8);
      
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
      if (result != null && result['error'] != null) {
        debugPrint('Error setting favorite games: ${result['error']}');
      }
    } catch (e) {
      debugPrint('Error setting favorite games: $e');
    }
  }
  
  /// Add a game to the user's game list
  Future<void> addToGameList(String gameId) async {
    _verifyFFI();
    
    try {
      final gameIdUtf8 = gameId.toNativeUtf8();
      final resultPtr = _addToGameList(gameIdUtf8);
      calloc.free(gameIdUtf8);
      
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
      if (result != null && result['error'] != null) {
        debugPrint('Error adding game to list: ${result['error']}');
      }
    } catch (e) {
      debugPrint('Error adding game to list: $e');
    }
  }
  
  /// Remove a game from the user's game list
  Future<void> removeFromGameList(String gameId, String listId) async {
    _verifyFFI();
    
    try {
      final gameIdUtf8 = gameId.toNativeUtf8();
      final listIdUtf8 = listId.toNativeUtf8();
      
      final resultPtr = _removeFromGameList(gameIdUtf8, listIdUtf8);
      
      calloc.free(gameIdUtf8);
      calloc.free(listIdUtf8);
      
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
      if (result != null && result['error'] != null) {
        debugPrint('Error removing game from list: ${result['error']}');
      }
    } catch (e) {
      debugPrint('Error removing game from list: $e');
    }
  }
  
  /// Get the user's game list
  Future<List<dynamic>> getGameList() async {
    _verifyFFI();
    
    try {
      final resultPtr = _getGameList();
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
      
      if (result == null) {
        return [];
      }
      
      return result;
    } catch (e) {
      debugPrint('Error getting game list: $e');
      return [];
    }
  }
  
  /// Refresh LLM clients
  Future<void> refreshLLMClients() async {
    _verifyFFI();
    
    try {
      final resultPtr = _refreshLLMClients();
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
      if (result != null && result['error'] != null) {
        debugPrint('Error refreshing LLM clients: ${result['error']}');
      }
    } catch (e) {
      debugPrint('Error refreshing LLM clients: $e');
    }
  }
}

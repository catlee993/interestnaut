import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ffi_bridge.dart';
import 'ffi_init.dart';

/// The FFI bindings for Books-related functions
class BooksFFI extends FFIBindingBase {
  /// Singleton instance
  static final BooksFFI _instance = BooksFFI._();
  factory BooksFFI() => _instance;
  
  // Function pointers for all Books FFI functions
  Pointer<Char> Function()? _getBookSuggestion;
  Pointer<Char> Function(Pointer<Char>, Pointer<Char>, Pointer<Char>)? _provideSuggestionFeedback;
  Pointer<Char> Function(Pointer<Char>)? _searchBooks;
  Pointer<Char> Function(Pointer<Char>)? _getBookDetails;
  Pointer<Char> Function()? _getFavoriteBooks;
  Pointer<Char> Function(Pointer<Char>)? _setFavoriteBooks;
  Pointer<Char> Function(Pointer<Char>)? _addToReadList;
  Pointer<Char> Function(Pointer<Char>, Pointer<Char>)? _removeFromReadList;
  Pointer<Char> Function()? _getReadList;
  Pointer<Char> Function()? _refreshLLMClients;
  bool _initialized = false;
  
  // Private constructor - initialize all function pointers eagerly
  BooksFFI._() {
    try {
      // Initialize all function pointers with try-catch for each one
      try {
        _getBookSuggestion = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(),
            Pointer<Char> Function()
          >('Books_GetSuggestion');
        debugPrint('BooksFFI: Successfully loaded Books_GetSuggestion');
      } catch (e) {
        debugPrint('BooksFFI: Error loading Books_GetSuggestion: $e');
      }
      
      try {
        _provideSuggestionFeedback = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(Pointer<Char>, Pointer<Char>, Pointer<Char>),
            Pointer<Char> Function(Pointer<Char>, Pointer<Char>, Pointer<Char>)
          >('Books_ProvideSuggestionFeedback');
        debugPrint('BooksFFI: Successfully loaded Books_ProvideSuggestionFeedback');
      } catch (e) {
        debugPrint('BooksFFI: Error loading Books_ProvideSuggestionFeedback: $e');
      }
      
      try {
        _searchBooks = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(Pointer<Char>),
            Pointer<Char> Function(Pointer<Char>)
          >('Books_Search');
        debugPrint('BooksFFI: Successfully loaded Books_Search');
      } catch (e) {
        debugPrint('BooksFFI: Error loading Books_Search: $e');
      }
      
      try {
        _getBookDetails = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(Pointer<Char>),
            Pointer<Char> Function(Pointer<Char>)
          >('Books_GetDetails');
        debugPrint('BooksFFI: Successfully loaded Books_GetDetails');
      } catch (e) {
        debugPrint('BooksFFI: Error loading Books_GetDetails: $e');
      }
      
      try {
        _getFavoriteBooks = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(),
            Pointer<Char> Function()
          >('Books_GetFavorites');
        debugPrint('BooksFFI: Successfully loaded Books_GetFavorites');
      } catch (e) {
        debugPrint('BooksFFI: Error loading Books_GetFavorites: $e');
      }
      
      try {
        _setFavoriteBooks = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(Pointer<Char>),
            Pointer<Char> Function(Pointer<Char>)
          >('Books_SetFavorites');
        debugPrint('BooksFFI: Successfully loaded Books_SetFavorites');
      } catch (e) {
        debugPrint('BooksFFI: Error loading Books_SetFavorites: $e');
      }
      
      try {
        _addToReadList = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(Pointer<Char>),
            Pointer<Char> Function(Pointer<Char>)
          >('Books_AddToReadList');
        debugPrint('BooksFFI: Successfully loaded Books_AddToReadList');
      } catch (e) {
        debugPrint('BooksFFI: Error loading Books_AddToReadList: $e');
      }
      
      try {
        _removeFromReadList = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(Pointer<Char>, Pointer<Char>),
            Pointer<Char> Function(Pointer<Char>, Pointer<Char>)
          >('Books_RemoveFromReadList');
        debugPrint('BooksFFI: Successfully loaded Books_RemoveFromReadList');
      } catch (e) {
        debugPrint('BooksFFI: Error loading Books_RemoveFromReadList: $e');
      }
      
      try {
        _getReadList = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(),
            Pointer<Char> Function()
          >('Books_GetReadList');
        debugPrint('BooksFFI: Successfully loaded Books_GetReadList');
      } catch (e) {
        debugPrint('BooksFFI: Error loading Books_GetReadList: $e');
      }
      
      try {
        _refreshLLMClients = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(),
            Pointer<Char> Function()
          >('Books_RefreshLLMClients');
        debugPrint('BooksFFI: Successfully loaded Books_RefreshLLMClients');
      } catch (e) {
        debugPrint('BooksFFI: Error loading Books_RefreshLLMClients: $e');
      }
      
      // If we have at least the critical functions, consider BooksFFI initialized
      // For now, just check if we have at least one function
      if (_getBookSuggestion != null || _searchBooks != null) {
        _initialized = true;
        debugPrint('BooksFFI: Critical functions loaded, BooksFFI is considered initialized');
      } else {
        debugPrint('BooksFFI: Critical functions not loaded, BooksFFI is NOT initialized');
      }
      
    } catch (e) {
      debugPrint('BooksFFI: Error during initialization: $e');
      _initialized = false;
    }
  }
  
  /// Check if BooksFFI was initialized correctly
  bool get isInitialized => _initialized;
  
  /// Verify the FFI is initialized
  void _verifyFFI() {
    // In the main isolate, check FFIInitializer.isInitialized
    // In other isolates, check if dylib is accessible
    if (!FFIInitializer.isInitialized && !FFIBindingBase.isInitializedInIsolate) {
      throw Exception("FFI library not initialized. Call initialize() first.");
    }
    
    if (!_initialized) {
      throw Exception("BooksFFI is not properly initialized. Required functions may be missing.");
    }
  }
  
  /// Get book suggestion
  Future<Map<String, dynamic>> getBookSuggestion() async {
    _verifyFFI();
    
    if (_getBookSuggestion == null) {
      throw Exception("Books_GetSuggestion function is not available");
    }
    
    final result = await compute(_computeGetBookSuggestion, null);
    return result;
  }
  
  /// Compute function to run in isolate
  static dynamic _computeGetBookSuggestion(Object? _) {
    final instance = BooksFFI();
    instance._verifyFFI();
    if (instance._getBookSuggestion == null) {
      return {'error': 'Books_GetSuggestion function is not available'};
    }
    final response = instance._getBookSuggestion!();
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Provide feedback for a book suggestion
  Future<void> provideSuggestionFeedback(String outcome, String title, String author) async {
    _verifyFFI();
    
    if (_provideSuggestionFeedback == null) {
      throw Exception("Books_ProvideSuggestionFeedback function is not available");
    }
    
    await compute(_computeProvideSuggestionFeedback, [outcome, title, author]);
  }
  
  /// Compute function to run in isolate
  static dynamic _computeProvideSuggestionFeedback(List<String> params) {
    final instance = BooksFFI();
    instance._verifyFFI();
    if (instance._provideSuggestionFeedback == null) {
      return {'error': 'Books_ProvideSuggestionFeedback function is not available'};
    }
    final outcomePtr = FFIBindingBase.toCString(params[0]);
    final titlePtr = FFIBindingBase.toCString(params[1]);
    final authorPtr = FFIBindingBase.toCString(params[2]);
    final response = instance._provideSuggestionFeedback!(outcomePtr, titlePtr, authorPtr);
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Search for books
  Future<List<dynamic>> searchBooks(String query) async {
    _verifyFFI();
    
    if (_searchBooks == null) {
      throw Exception("Books_Search function is not available");
    }
    
    final result = await compute(_computeSearchBooks, query);
    FFIBindingBase.checkForError(result);
    if (result is List) {
      return result;
    } else {
      return [];
    }
  }
  
  /// Compute function to run in isolate
  static dynamic _computeSearchBooks(String query) {
    final instance = BooksFFI();
    instance._verifyFFI();
    if (instance._searchBooks == null) {
      return {'error': 'Books_Search function is not available'};
    }
    final queryPtr = FFIBindingBase.toCString(query);
    final response = instance._searchBooks!(queryPtr);
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Get book details
  Future<Map<String, dynamic>> getBookDetails(String workKey) async {
    _verifyFFI();
    
    if (_getBookDetails == null) {
      throw Exception("Books_GetDetails function is not available");
    }
    
    final result = await compute(_computeGetBookDetails, workKey);
    FFIBindingBase.checkForError(result);
    return result as Map<String, dynamic>;
  }
  
  /// Compute function to run in isolate
  static dynamic _computeGetBookDetails(String workKey) {
    final instance = BooksFFI();
    instance._verifyFFI();
    if (instance._getBookDetails == null) {
      return {'error': 'Books_GetDetails function is not available'};
    }
    final workKeyPtr = FFIBindingBase.toCString(workKey);
    final response = instance._getBookDetails!(workKeyPtr);
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Get favorite books
  Future<List<dynamic>> getFavoriteBooks() async {
    _verifyFFI();
    
    if (_getFavoriteBooks == null) {
      throw Exception("Books_GetFavorites function is not available");
    }
    
    final result = await compute(_computeGetFavoriteBooks, null);
    FFIBindingBase.checkForError(result);
    if (result is List) {
      return result;
    } else {
      return [];
    }
  }
  
  /// Compute function to run in isolate
  static dynamic _computeGetFavoriteBooks(Object? _) {
    final instance = BooksFFI();
    instance._verifyFFI();
    if (instance._getFavoriteBooks == null) {
      return {'error': 'Books_GetFavorites function is not available'};
    }
    final response = instance._getFavoriteBooks!();
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Set favorite books
  Future<void> setFavoriteBooks(List<dynamic> books) async {
    _verifyFFI();
    
    if (_setFavoriteBooks == null) {
      throw Exception("Books_SetFavorites function is not available");
    }
    
    await compute(_computeSetFavoriteBooks, jsonEncode(books));
  }
  
  /// Compute function to run in isolate
  static dynamic _computeSetFavoriteBooks(String booksJson) {
    final instance = BooksFFI();
    instance._verifyFFI();
    if (instance._setFavoriteBooks == null) {
      return {'error': 'Books_SetFavorites function is not available'};
    }
    final booksJsonPtr = FFIBindingBase.toCString(booksJson);
    final response = instance._setFavoriteBooks!(booksJsonPtr);
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Add book to read list
  Future<void> addToReadList(Map<String, dynamic> book) async {
    _verifyFFI();
    
    if (_addToReadList == null) {
      throw Exception("Books_AddToReadList function is not available");
    }
    
    await compute(_computeAddToReadList, jsonEncode(book));
  }
  
  /// Compute function to run in isolate
  static dynamic _computeAddToReadList(String bookJson) {
    final instance = BooksFFI();
    instance._verifyFFI();
    if (instance._addToReadList == null) {
      return {'error': 'Books_AddToReadList function is not available'};
    }
    final bookJsonPtr = FFIBindingBase.toCString(bookJson);
    final response = instance._addToReadList!(bookJsonPtr);
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Remove book from read list
  Future<void> removeFromReadList(String title, String author) async {
    _verifyFFI();
    
    if (_removeFromReadList == null) {
      throw Exception("Books_RemoveFromReadList function is not available");
    }
    
    await compute(_computeRemoveFromReadList, [title, author]);
  }
  
  /// Compute function to run in isolate
  static dynamic _computeRemoveFromReadList(List<String> params) {
    final instance = BooksFFI();
    instance._verifyFFI();
    if (instance._removeFromReadList == null) {
      return {'error': 'Books_RemoveFromReadList function is not available'};
    }
    final titlePtr = FFIBindingBase.toCString(params[0]);
    final authorPtr = FFIBindingBase.toCString(params[1]);
    final response = instance._removeFromReadList!(titlePtr, authorPtr);
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Get read list
  Future<List<dynamic>> getReadList() async {
    _verifyFFI();
    
    if (_getReadList == null) {
      throw Exception("Books_GetReadList function is not available");
    }
    
    final result = await compute(_computeGetReadList, null);
    FFIBindingBase.checkForError(result);
    if (result is List) {
      return result;
    } else {
      return [];
    }
  }
  
  /// Compute function to run in isolate
  static dynamic _computeGetReadList(Object? _) {
    final instance = BooksFFI();
    instance._verifyFFI();
    if (instance._getReadList == null) {
      return {'error': 'Books_GetReadList function is not available'};
    }
    final response = instance._getReadList!();
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Refresh LLM clients
  Future<void> refreshLLMClients() async {
    _verifyFFI();
    
    if (_refreshLLMClients == null) {
      throw Exception("Books_RefreshLLMClients function is not available");
    }
    
    await compute(_computeRefreshLLMClients, null);
  }
  
  /// Compute function to run in isolate
  static dynamic _computeRefreshLLMClients(Object? _) {
    final instance = BooksFFI();
    instance._verifyFFI();
    if (instance._refreshLLMClients == null) {
      return {'error': 'Books_RefreshLLMClients function is not available'};
    }
    final response = instance._refreshLLMClients!();
    return FFIBindingBase.parseJsonResponse(response);
  }
}

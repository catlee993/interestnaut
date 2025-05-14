import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ffi_init.dart';

/// Simple wrapper class for isolate payloads
class _IsolatePayload<T> {
  final Future<Map<String, dynamic>> Function(T param) operation;
  final T param;
  
  _IsolatePayload(this.operation, this.param);
}

/// Implementation of the authentication-specific FFI functionality
class AuthFFI {
  // Eagerly initialize all function pointers in constructor to avoid race conditions
  final ffi.Pointer<ffi.Char> Function() _getAuthConfigPtr;
  final ffi.Pointer<ffi.Char> Function(int) _authenticatePtr;
  final ffi.Pointer<ffi.Char> Function() _getUserProfilePtr;
  final ffi.Pointer<ffi.Char> Function() _logoutPtr;
  final ffi.Pointer<ffi.Char> Function() _getOpenAITokenPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _saveOpenAITokenPtr;
  final ffi.Pointer<ffi.Char> Function() _clearOpenAITokenPtr;
  final ffi.Pointer<ffi.Char> Function() _getTMBDAccessTokenPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _saveTMBDAccessTokenPtr;
  final ffi.Pointer<ffi.Char> Function() _clearTMBDAccessTokenPtr;
  final ffi.Pointer<ffi.Char> Function() _getGeminiTokenPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _saveGeminiTokenPtr;
  final ffi.Pointer<ffi.Char> Function() _clearGeminiTokenPtr;
  final ffi.Pointer<ffi.Char> Function() _getRAWGAPIKeyPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _saveRAWGAPIKeyPtr;
  final ffi.Pointer<ffi.Char> Function() _clearRAWGAPIKeyPtr;
  
  // Track initialization state
  bool get isInitialized => FFIInitializer.isInitialized;
  
  /// Constructor eagerly initializes all function pointers
  /// This prevents race conditions when FFI is accessed from different isolates
  AuthFFI()
    : _getAuthConfigPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Music_GetAuthStatus'),
    _authenticatePtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Int32),
        ffi.Pointer<ffi.Char> Function(int)>('Music_InitiateSpotifyAuth'),
    _getUserProfilePtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Music_GetCurrentUser'),
    _logoutPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Music_ClearSpotifyCredentials'),
    _getOpenAITokenPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Auth_GetOpenAIToken'),
    _saveOpenAITokenPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('Auth_SaveOpenAIToken'),
    _clearOpenAITokenPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Auth_ClearOpenAIToken'),
    _getTMBDAccessTokenPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Auth_GetTMBDAccessToken'),
    _saveTMBDAccessTokenPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('Auth_SaveTMBDAccessToken'),
    _clearTMBDAccessTokenPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Auth_ClearTMBDAccessToken'),
    _getGeminiTokenPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Auth_GetGeminiToken'),
    _saveGeminiTokenPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('Auth_SaveGeminiToken'),
    _clearGeminiTokenPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Auth_ClearGeminiToken'),
    _getRAWGAPIKeyPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Auth_GetRAWGAPIKey'),
    _saveRAWGAPIKeyPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('Auth_SaveRAWGAPIKey'),
    _clearRAWGAPIKeyPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Auth_ClearRAWGAPIKey');

  /// Check if FFI is initialized
  void _checkInitialized() {
    if (!FFIInitializer.isInitialized) {
      throw Exception('FFI not initialized. Call FFIInitializer.initialize() first.');
    }
  }
  
  /// Execute operations in an isolate safely
  Future<Map<String, dynamic>> _executeInIsolate<T>(
      Future<Map<String, dynamic>> Function(T) operation,
      T param) async {
    _checkInitialized();
    
    try {
      return compute<_IsolatePayload<T>, Map<String, dynamic>>(
          _isolateHandler,
          _IsolatePayload<T>(operation, param));
    } catch (e) {
      debugPrint('Error executing in isolate: $e');
      return _errorResult('Failed to execute in isolate: $e');
    }
  }

  /// Get auth configuration for various providers
  Future<Map<String, dynamic>> getAuthConfig() async {
    _checkInitialized();
    
    return await _executeInIsolate<void>(
      (_) async {
        final instance = AuthFFI();
        
        final resultPtr = instance._getAuthConfigPtr();
        final parsed = _parseJsonResponse(_fromCString(resultPtr));
        return parsed ?? {'error': 'Failed to parse auth config'};
      },
      null
    );
  }

  /// Authenticate with a specific provider
  Future<Map<String, dynamic>> authenticate({
    String code = '',
    String provider = 'spotify',
    int port = 0
  }) async {
    _checkInitialized();
    
    try {
      // For Spotify, we use Music_InitiateSpotifyAuth
      final resultPtr = _authenticatePtr(port);
      final resultStr = _fromCString(resultPtr);
      if (resultStr == null) {
        return {'error': 'Failed to initiate authentication'};
      }
      
      try {
        return json.decode(resultStr) as Map<String, dynamic>;
      } catch (e) {
        // If not valid JSON, return success with the raw result
        return {'status': 'initiated', 'result': resultStr};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  /// Get the current authentication provider
  Future<String> getAuthProvider() async {
    return 'spotify';
  }
  
  /// Get the user profile information
  Future<Map<String, dynamic>> getUserProfile() async {
    _checkInitialized();
    
    return await _executeInIsolate<void>(
      (_) async {
        final instance = AuthFFI();
        
        final resultPtr = instance._getUserProfilePtr();
        final parsed = _parseJsonResponse(_fromCString(resultPtr));
        return parsed ?? {'error': 'Failed to get user profile'};
      },
      null
    );
  }
  
  /// Logout from the current provider
  Future<void> logout() async {
    _checkInitialized();
    
    try {
      final resultPtr = _logoutPtr();
      _fromCString(resultPtr); // Process the response but we don't need to return it
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }
  
  /// Handle authentication callback from redirect
  /// Note: We keep this method for API compatibility, but the Go backend
  /// doesn't seem to have a direct callback handler function.
  Future<void> handleAuthCallback(String callbackUrl) async {
    _checkInitialized();
    
    // Log the callback URL for debugging
    debugPrint('Auth callback received: $callbackUrl');
    
    // The Spotify authentication flow is likely handled internally by the Go backend
    // We don't need to explicitly handle the callback here
  }
  
  /// Get the OpenAI token if available
  Future<String> getOpenAIToken() async {
    _checkInitialized();
    
    final result = await _executeInIsolate<void>(
      (_) async {
        final instance = AuthFFI();
        
        final resultPtr = instance._getOpenAITokenPtr();
        final result = _parseJsonResponse(_fromCString(resultPtr));
        
        if (result == null || result['token'] == null) {
          return {'token': ''};
        }
        
        return {'token': result['token']};
      },
      null
    );
    
    return result['token'] as String;
  }
  
  /// Save an OpenAI token
  Future<bool> saveOpenAIToken(String token) async {
    _checkInitialized();
    
    final result = await _executeInIsolate<String>(
      (token) async {
        final instance = AuthFFI();
        
        final tokenUtf8 = token.toNativeUtf8();
        final resultPtr = instance._saveOpenAITokenPtr(tokenUtf8);
        calloc.free(tokenUtf8);
        
        final result = _parseJsonResponse(_fromCString(resultPtr));
        return {'success': result != null && result['success'] == true};
      },
      token
    );
    
    return result['success'] as bool;
  }
  
  /// Clear the OpenAI token
  Future<bool> clearOpenAIToken() async {
    _checkInitialized();
    
    final result = await _executeInIsolate<void>(
      (_) async {
        final instance = AuthFFI();
        
        final resultPtr = instance._clearOpenAITokenPtr();
        final result = _parseJsonResponse(_fromCString(resultPtr));
        return {'success': result != null && result['success'] == true};
      },
      null
    );
    
    return result['success'] as bool;
  }
  
  /// Get the TMBD access token if available
  Future<String> getTMBDAccessToken() async {
    _checkInitialized();
    
    final result = await _executeInIsolate<void>(
      (_) async {
        final instance = AuthFFI();
        
        final resultPtr = instance._getTMBDAccessTokenPtr();
        final result = _parseJsonResponse(_fromCString(resultPtr));
        
        if (result == null || result['token'] == null) {
          return {'token': ''};
        }
        
        return {'token': result['token']};
      },
      null
    );
    
    return result['token'] as String;
  }
  
  /// Save a TMBD access token
  Future<bool> saveTMBDAccessToken(String token) async {
    _checkInitialized();
    
    final result = await _executeInIsolate<String>(
      (token) async {
        final instance = AuthFFI();
        
        final tokenUtf8 = token.toNativeUtf8();
        final resultPtr = instance._saveTMBDAccessTokenPtr(tokenUtf8);
        calloc.free(tokenUtf8);
        
        final result = _parseJsonResponse(_fromCString(resultPtr));
        return {'success': result != null && result['success'] == true};
      },
      token
    );
    
    return result['success'] as bool;
  }
  
  /// Clear the TMBD access token
  Future<bool> clearTMBDAccessToken() async {
    _checkInitialized();
    
    final result = await _executeInIsolate<void>(
      (_) async {
        final instance = AuthFFI();
        
        final resultPtr = instance._clearTMBDAccessTokenPtr();
        final result = _parseJsonResponse(_fromCString(resultPtr));
        return {'success': result != null && result['success'] == true};
      },
      null
    );
    
    return result['success'] as bool;
  }
  
  /// Get the Gemini token if available
  Future<String> getGeminiToken() async {
    _checkInitialized();
    
    final result = await _executeInIsolate<void>(
      (_) async {
        final instance = AuthFFI();
        
        final resultPtr = instance._getGeminiTokenPtr();
        final result = _parseJsonResponse(_fromCString(resultPtr));
        
        if (result == null || result['token'] == null) {
          return {'token': ''};
        }
        
        return {'token': result['token']};
      },
      null
    );
    
    return result['token'] as String;
  }
  
  /// Save a Gemini token
  Future<bool> saveGeminiToken(String token) async {
    _checkInitialized();
    
    final result = await _executeInIsolate<String>(
      (token) async {
        final instance = AuthFFI();
        
        final tokenUtf8 = token.toNativeUtf8();
        final resultPtr = instance._saveGeminiTokenPtr(tokenUtf8);
        calloc.free(tokenUtf8);
        
        final result = _parseJsonResponse(_fromCString(resultPtr));
        return {'success': result != null && result['success'] == true};
      },
      token
    );
    
    return result['success'] as bool;
  }
  
  /// Clear the Gemini token
  Future<bool> clearGeminiToken() async {
    _checkInitialized();
    
    final result = await _executeInIsolate<void>(
      (_) async {
        final instance = AuthFFI();
        
        final resultPtr = instance._clearGeminiTokenPtr();
        final result = _parseJsonResponse(_fromCString(resultPtr));
        return {'success': result != null && result['success'] == true};
      },
      null
    );
    
    return result['success'] as bool;
  }
  
  /// Get the RAWG API Key if available
  Future<String> getRAWGAPIKey() async {
    _checkInitialized();
    
    final result = await _executeInIsolate<void>(
      (_) async {
        final instance = AuthFFI();
        
        final resultPtr = instance._getRAWGAPIKeyPtr();
        final result = _parseJsonResponse(_fromCString(resultPtr));
        
        if (result == null || result['key'] == null) {
          return {'key': ''};
        }
        
        return {'key': result['key']};
      },
      null
    );
    
    return result['key'] as String;
  }
  
  /// Save a RAWG API Key
  Future<bool> saveRAWGAPIKey(String key) async {
    _checkInitialized();
    
    final result = await _executeInIsolate<String>(
      (key) async {
        final instance = AuthFFI();
        
        final keyUtf8 = key.toNativeUtf8();
        final resultPtr = instance._saveRAWGAPIKeyPtr(keyUtf8);
        calloc.free(keyUtf8);
        
        final result = _parseJsonResponse(_fromCString(resultPtr));
        return {'success': result != null && result['success'] == true};
      },
      key
    );
    
    return result['success'] as bool;
  }
  
  /// Clear the RAWG API Key
  Future<bool> clearRAWGAPIKey() async {
    _checkInitialized();
    
    final result = await _executeInIsolate<void>(
      (_) async {
        final instance = AuthFFI();
        
        final resultPtr = instance._clearRAWGAPIKeyPtr();
        final result = _parseJsonResponse(_fromCString(resultPtr));
        return {'success': result != null && result['success'] == true};
      },
      null
    );
    
    return result['success'] as bool;
  }
  
  // Standard isolate handler
  static Future<Map<String, dynamic>> _isolateHandler<T>(_IsolatePayload<T> payload) async {
    // Ensure FFI is initialized in the isolate
    if (!FFIInitializer.isInitialized) {
      await FFIInitializer.initialize();
    }
    return payload.operation(payload.param);
  }
  
  // Parse a JSON string into a Map<String, dynamic>
  Map<String, dynamic>? _parseJsonResponse(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    
    try {
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
      return null;
    }
  }
  
  // Helper for returning error results
  Map<String, dynamic> _errorResult(String message) {
    return {'error': message};
  }
  
  // Helper method to clean up C strings
  void _freeCString(ffi.Pointer<ffi.Char> cString) {
    try {
      final freeStringFn = FFIInitializer.dylib.lookupFunction<
          ffi.Void Function(ffi.Pointer<ffi.Char>),
          void Function(ffi.Pointer<ffi.Char>)>('FreeString');
      freeStringFn(cString);
    } catch (e) {
      debugPrint('Warning: Could not free string: $e');
    }
  }
  
  // Convert C string to Dart string
  String? _fromCString(ffi.Pointer<ffi.Char> cString) {
    if (cString.address == 0) {
      return null;
    }
    
    final result = cString.cast<Utf8>().toDartString();
    
    // Free the string
    _freeCString(cString);
    
    return result;
  }
}

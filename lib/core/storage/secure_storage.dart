import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage service for managing credentials across platforms
/// 
/// This provides a unified interface for securely storing sensitive information
/// such as API keys and OAuth tokens across all platforms:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences
/// - macOS: Keychain (falls back to shared preferences in development mode)
/// - Windows: Data Protection API
/// - Linux: libsecret
class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static SharedPreferences? _prefs;
  static bool? _useSecureStorage;
  static final _initCompleter = Completer<bool>();
  static bool _isInitializing = false;
  static const String _devModePrefix = 'dev_';
  
  // Keys for all services
  static const _spotifyAccessToken = 'spotify_access_token';
  static const _spotifyRefreshToken = 'spotify_refresh_token';
  static const _spotifyTokenExpiry = 'spotify_token_expiry';
  static const _spotifyCodeVerifier = 'spotify_code_verifier';
  static const _openaiKey = 'openai_key';
  static const _tmdbToken = 'tmdb_token';
  static const _geminiKey = 'gemini_key';
  static const _rawgApiKey = 'rawg_api_key';

  /// Initialize the secure storage system
  /// Tests if secure storage is working, if not (like on macOS in dev mode),
  /// falls back to SharedPreferences
  static Future<bool> initialize() async {
    // If already initialized, return the result
    if (_useSecureStorage != null) return _useSecureStorage!;
    
    // If initialization is in progress, wait for it to complete
    if (_isInitializing) {
      return _initCompleter.future;
    }
    
    _isInitializing = true;
    
    try {
      // Initialize shared preferences for potential fallback
      _prefs = await SharedPreferences.getInstance();
      
      // Test if secure storage works
      // Only test on macOS since other platforms shouldn't have issues
      if (Platform.isMacOS) {
        const testKey = 'secure_storage_test_key';
        const testValue = 'test_value';
        
        try {
          // Try to write and read a test value
          await _storage.write(key: testKey, value: testValue);
          final readValue = await _storage.read(key: testKey);
          await _storage.delete(key: testKey);
          
          _useSecureStorage = readValue == testValue;
        } catch (e) {
          debugPrint('Secure storage test failed with error: $e');
          _useSecureStorage = false;
        }
      } else {
        // For other platforms, assume secure storage works
        _useSecureStorage = true;
      }
      
      debugPrint('Using secure storage: $_useSecureStorage');
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete(_useSecureStorage);
      }
      return _useSecureStorage!;
    } catch (e) {
      debugPrint('Error initializing secure storage: $e');
      _useSecureStorage = false;
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete(false);
      }
      return false;
    }
  }
  
  // Generic read/write methods that handle the fallback to SharedPreferences
  static Future<void> _write({required String key, required String? value}) async {
    await initialize();
    
    try {
      if (_useSecureStorage!) {
        if (value == null) {
          await _storage.delete(key: key);
        } else {
          await _storage.write(key: key, value: value);
        }
      } else {
        // Use shared preferences with a prefix to avoid conflicts
        final prefKey = _devModePrefix + key;
        if (value == null) {
          await _prefs!.remove(prefKey);
        } else {
          await _prefs!.setString(prefKey, value);
        }
      }
    } catch (e) {
      debugPrint('Error writing to storage for key $key: $e');
      // If secure storage fails, try to fall back to shared preferences
      if (_useSecureStorage!) {
        _useSecureStorage = false;
        // Retry with shared preferences
        return _write(key: key, value: value);
      }
    }
  }
  
  static Future<String?> _read({required String key}) async {
    await initialize();
    
    try {
      if (_useSecureStorage!) {
        return await _storage.read(key: key);
      } else {
        // Use shared preferences with a prefix
        final prefKey = _devModePrefix + key;
        return _prefs!.getString(prefKey);
      }
    } catch (e) {
      debugPrint('Error reading from storage for key $key: $e');
      // If secure storage fails, try to fall back to shared preferences
      if (_useSecureStorage!) {
        _useSecureStorage = false;
        // Retry with shared preferences
        return _read(key: key);
      }
      return null;
    }
  }

  static Future<void> _delete({required String key}) async {
    await initialize();
    
    try {
      if (_useSecureStorage!) {
        await _storage.delete(key: key);
      } else {
        final prefKey = _devModePrefix + key;
        await _prefs!.remove(prefKey);
      }
    } catch (e) {
      debugPrint('Error deleting from storage for key $key: $e');
      // If secure storage fails, try to fall back to shared preferences
      if (_useSecureStorage!) {
        _useSecureStorage = false;
        // Retry with shared preferences
        return _delete(key: key);
      }
    }
  }

  // Spotify token methods
  static Future<void> saveSpotifyTokens({
    required String accessToken,
    String? refreshToken,
    required int expiryMillis,
  }) async {
    await _write(key: _spotifyAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _write(key: _spotifyRefreshToken, value: refreshToken);
    }
    await _write(key: _spotifyTokenExpiry, value: expiryMillis.toString());
  }

  static Future<String?> getSpotifyAccessToken() async {
    return await _read(key: _spotifyAccessToken);
  }

  static Future<String?> getSpotifyRefreshToken() async {
    return await _read(key: _spotifyRefreshToken);
  }

  static Future<DateTime?> getSpotifyTokenExpiry() async {
    final expiryStr = await _read(key: _spotifyTokenExpiry);
    if (expiryStr == null) return null;
    
    return DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
  }

  static Future<bool> hasValidSpotifyToken() async {
    final token = await getSpotifyAccessToken();
    final expiry = await getSpotifyTokenExpiry();
    
    if (token == null || expiry == null) return false;
    return expiry.isAfter(DateTime.now());
  }

  static Future<void> clearSpotifyCredentials() async {
    await _delete(key: _spotifyAccessToken);
    await _delete(key: _spotifyRefreshToken);
    await _delete(key: _spotifyTokenExpiry);
  }

  static Future<Map<String, dynamic>?> getSpotifyTokens() async {
    final accessToken = await getSpotifyAccessToken();
    if (accessToken == null) return null;
    
    final refreshToken = await getSpotifyRefreshToken();
    final expiryStr = await _read(key: _spotifyTokenExpiry);
    
    if (expiryStr == null) return null;
    
    try {
      final expiryMillis = int.parse(expiryStr);
      return {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiryMillis': expiryMillis,
      };
    } catch (e) {
      debugPrint('Error parsing token expiry: $e');
      return null;
    }
  }

  // --- SPOTIFY CODE VERIFIER METHODS ---
  static Future<void> saveSpotifyCodeVerifier(String verifier) async {
    await _write(key: _spotifyCodeVerifier, value: verifier);
  }

  static Future<String?> getSpotifyCodeVerifier() async {
    return await _read(key: _spotifyCodeVerifier);
  }

  // OpenAI methods
  static Future<String?> getOpenAIKey() async {
    return await _read(key: _openaiKey);
  }

  static Future<void> saveOpenAIKey(String key) async {
    await _write(key: _openaiKey, value: key);
  }

  static Future<void> clearOpenAIKey() async {
    await _delete(key: _openaiKey);
  }

  // TMDB methods
  static Future<String?> getTMDBAccessToken() async {
    return await _read(key: _tmdbToken);
  }

  static Future<void> saveTMDBAccessToken(String token) async {
    await _write(key: _tmdbToken, value: token);
  }

  static Future<void> clearTMDBAccessToken() async {
    await _delete(key: _tmdbToken);
  }

  // Gemini methods
  static Future<String?> getGeminiKey() async {
    return await _read(key: _geminiKey);
  }

  static Future<void> saveGeminiKey(String key) async {
    await _write(key: _geminiKey, value: key);
  }

  static Future<void> clearGeminiKey() async {
    await _delete(key: _geminiKey);
  }

  // RAWG methods
  static Future<String?> getRAWGAPIKey() async {
    return await _read(key: _rawgApiKey);
  }

  static Future<void> saveRAWGAPIKey(String key) async {
    await _write(key: _rawgApiKey, value: key);
  }

  static Future<void> clearRAWGAPIKey() async {
    await _delete(key: _rawgApiKey);
  }
}

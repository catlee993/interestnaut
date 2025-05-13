import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for managing credentials across platforms
/// 
/// This provides a unified interface for securely storing sensitive information
/// such as API keys and OAuth tokens across all platforms:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences
/// - macOS: Keychain
/// - Windows: Data Protection API
/// - Linux: libsecret
class SecureStorage {
  static const _storage = FlutterSecureStorage();
  
  // Keys for all services
  static const _spotifyAccessToken = 'spotify_access_token';
  static const _spotifyRefreshToken = 'spotify_refresh_token';
  static const _spotifyTokenExpiry = 'spotify_token_expiry';
  static const _spotifyCodeVerifier = 'spotify_code_verifier';
  static const _openaiKey = 'openai_key';
  static const _tmdbToken = 'tmdb_token';
  static const _geminiKey = 'gemini_key';
  static const _rawgApiKey = 'rawg_api_key';

  // Spotify token methods
  static Future<void> saveSpotifyTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiry,
  }) async {
    await _storage.write(key: _spotifyAccessToken, value: accessToken);
    await _storage.write(key: _spotifyRefreshToken, value: refreshToken);
    await _storage.write(key: _spotifyTokenExpiry, value: expiry.millisecondsSinceEpoch.toString());
  }

  static Future<String?> getSpotifyAccessToken() async {
    return await _storage.read(key: _spotifyAccessToken);
  }

  static Future<String?> getSpotifyRefreshToken() async {
    return await _storage.read(key: _spotifyRefreshToken);
  }

  static Future<DateTime?> getSpotifyTokenExpiry() async {
    final expiryStr = await _storage.read(key: _spotifyTokenExpiry);
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
    await _storage.delete(key: _spotifyAccessToken);
    await _storage.delete(key: _spotifyRefreshToken);
    await _storage.delete(key: _spotifyTokenExpiry);
  }

  // --- SPOTIFY CODE VERIFIER METHODS ---
  static Future<void> saveSpotifyCodeVerifier(String verifier) async {
    await _storage.write(key: _spotifyCodeVerifier, value: verifier);
  }

  static Future<String?> getSpotifyCodeVerifier() async {
    return await _storage.read(key: _spotifyCodeVerifier);
  }

  // OpenAI methods
  static Future<String?> getOpenAIKey() async {
    return await _storage.read(key: _openaiKey);
  }

  static Future<void> saveOpenAIKey(String key) async {
    await _storage.write(key: _openaiKey, value: key);
  }

  static Future<void> clearOpenAIKey() async {
    await _storage.delete(key: _openaiKey);
  }

  // TMDB methods
  static Future<String?> getTMDBAccessToken() async {
    return await _storage.read(key: _tmdbToken);
  }

  static Future<void> saveTMDBAccessToken(String token) async {
    await _storage.write(key: _tmdbToken, value: token);
  }

  static Future<void> clearTMDBAccessToken() async {
    await _storage.delete(key: _tmdbToken);
  }

  // Gemini methods
  static Future<String?> getGeminiKey() async {
    return await _storage.read(key: _geminiKey);
  }

  static Future<void> saveGeminiKey(String key) async {
    await _storage.write(key: _geminiKey, value: key);
  }

  static Future<void> clearGeminiKey() async {
    await _storage.delete(key: _geminiKey);
  }

  // RAWG methods
  static Future<String?> getRAWGAPIKey() async {
    return await _storage.read(key: _rawgApiKey);
  }

  static Future<void> saveRAWGAPIKey(String key) async {
    await _storage.write(key: _rawgApiKey, value: key);
  }

  static Future<void> clearRAWGAPIKey() async {
    await _storage.delete(key: _rawgApiKey);
  }
}

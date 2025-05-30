import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models.dart';
import '../../services/secure_storage.dart';

/// SpotifyClient handles all API requests to the Spotify Web API.
/// It manages token validation and automatic refreshing before each request.
class SpotifyClient {
  // Constants
  static const String _baseUrl = 'api.spotify.com';
  static const String _apiVersion = 'v1';
  static const String _tokenEndpoint = 'https://accounts.spotify.com/api/token';
  static const String _clientId = '3bb48a30577342869a9ffcb176dee7d2';
  
  // Token management
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  
  // In-memory backup storage for tokens
  String? _accessTokenInMemory;
  String? _refreshTokenInMemory;
  DateTime? _tokenExpiryInMemory;
  
  /// Private singleton constructor
  SpotifyClient._();
  
  /// Singleton instance
  static final SpotifyClient _instance = SpotifyClient._();
  
  /// Factory constructor to return the singleton instance
  factory SpotifyClient() => _instance;
  
  /// Set credentials from a token response
  void setCredentials({required String accessToken, String? refreshToken, DateTime? expiry}) {
    _accessToken = accessToken;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
    if (expiry != null) {
      // Add a small buffer to ensure we refresh before expiration
      _tokenExpiry = expiry.subtract(const Duration(minutes: 5));
    }
    
    // Also save to memory backup
    _accessTokenInMemory = _accessToken;
    _refreshTokenInMemory = _refreshToken;
    _tokenExpiryInMemory = _tokenExpiry;
  }
  
  /// Get a valid access token, refreshing if necessary
  Future<String?> getValidToken() async {
    try {
      // Check if we have a valid token in memory
      if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
        return _accessToken;
      }
      
      // If not, try to load from storage
      if (_accessToken == null || _tokenExpiry == null) {
        await _loadTokens();
        
        // Check again after loading
        if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
          return _accessToken;
        }
      }
      
      // If still no valid token, try to refresh
      if (_refreshToken != null) {
        await _refreshTokenToken();
        if (_accessToken != null) {
          return _accessToken;
        }
      }
      
      // If we still don't have a token, return null (not authenticated)
      return null;
    } catch (e) {
      debugPrint('Error getting valid token: $e');
      return null;
    }
  }
  
  /// Load tokens from secure storage or memory backup
  Future<void> _loadTokens() async {
    try {
      // Try enhanced secure storage first
      final tokenData = await SecureStorage.getSpotifyTokens();
      if (tokenData != null) {
        _accessToken = tokenData['accessToken'] as String?;
        _refreshToken = tokenData['refreshToken'] as String?;
        final expiryMillis = tokenData['expiryMillis'] as int?;
        if (expiryMillis != null) {
          _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
        }
        debugPrint('Tokens loaded from enhanced secure storage');
        return;
      }
      
      // If that fails, try direct secure storage
      try {
        const storage = FlutterSecureStorage();
        _accessToken = await storage.read(key: 'spotify_access_token');
        _refreshToken = await storage.read(key: 'spotify_refresh_token');
        final expiryStr = await storage.read(key: 'spotify_token_expiry');
        if (expiryStr != null) {
          _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
        }
        debugPrint('Tokens loaded from direct secure storage');
      } catch (e) {
        debugPrint('Error loading tokens from direct secure storage: $e');
      }
      
      // Finally, check memory backups
      if (_accessToken == null && _accessTokenInMemory != null) {
        _accessToken = _accessTokenInMemory;
        _refreshToken = _refreshTokenInMemory;
        _tokenExpiry = _tokenExpiryInMemory;
        debugPrint('Using memory backup tokens');
      }
    } catch (e) {
      debugPrint('Error loading tokens: $e');
    }
  }
  
  /// Refresh the access token using the refresh token
  Future<bool> _refreshTokenToken() async {
    try {
      debugPrint('Refreshing access token...');
      
      // Try to get refresh token from secure storage
      String? refreshToken;
      try {
        // First try our enhanced secure storage
        final tokenData = await SecureStorage.getSpotifyTokens();
        if (tokenData != null) {
          refreshToken = tokenData['refreshToken'] as String?;
          debugPrint('Got refresh token from enhanced secure storage');
        }
        
        // If not found, try direct secure storage
        if (refreshToken == null) {
          const storage = FlutterSecureStorage();
          refreshToken = await storage.read(key: 'spotify_refresh_token');
          debugPrint('Got refresh token from direct secure storage');
        }
      } catch (e) {
        debugPrint('Error retrieving refresh token from secure storage: $e');
      }
      
      // If not found in secure storage, check memory backup
      if (refreshToken == null) {
        refreshToken = _refreshTokenInMemory;
        debugPrint('Using in-memory refresh token: ${refreshToken != null}');
      }
      
      if (refreshToken == null) {
        debugPrint('No refresh token available, cannot refresh access token');
        return false;
      }
      
      // Use HTTP directly instead of the oauth2 package to have more control
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': _clientId,
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final accessToken = data['access_token'] as String;
        final expiresIn = data['expires_in'] as int? ?? 3600;
        final newRefreshToken = data['refresh_token'] as String?;
        
        // Set expiry time with buffer
        final expiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        
        // Update in memory immediately
        _accessToken = accessToken;
        _tokenExpiry = expiry;
        _accessTokenInMemory = accessToken;
        _tokenExpiryInMemory = expiry;
        if (newRefreshToken != null) {
          _refreshToken = newRefreshToken;
          _refreshTokenInMemory = newRefreshToken;
        }
        
        // Save to secure storage
        await _saveTokens(
          accessToken, 
          newRefreshToken ?? refreshToken, 
          expiry
        );
        
        debugPrint('Successfully refreshed access token, valid until ${expiry.toString()}');
        return true;
      } else {
        debugPrint('Failed to refresh token: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      return false;
    }
  }
  
  /// Save access token, refresh token, and expiry to secure storage
  Future<void> _saveTokens(String accessToken, String refreshToken, DateTime expiry) async {
    debugPrint('Saving tokens to secure storage...');
    
    // Always store tokens in memory as a fallback
    _accessTokenInMemory = accessToken;
    _refreshTokenInMemory = refreshToken;
    _tokenExpiryInMemory = expiry;
    
    // Try to save in secure storage
    try {
      // First try our enhanced secure storage
      await SecureStorage.saveSpotifyTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiryMillis: expiry.millisecondsSinceEpoch,
      );
      debugPrint('Tokens saved successfully in enhanced secure storage');
    } catch (e1) {
      debugPrint('Error saving to enhanced secure storage: $e1');
      // Fall back to direct secure storage
      try {
        const storage = FlutterSecureStorage();
        await storage.write(key: 'spotify_access_token', value: accessToken);
        await storage.write(key: 'spotify_refresh_token', value: refreshToken);
        await storage.write(
          key: 'spotify_token_expiry',
          value: expiry.millisecondsSinceEpoch.toString(),
        );
        debugPrint('Tokens saved successfully in direct secure storage');
      } catch (e2) {
        debugPrint('Error saving to direct secure storage, using memory backup: $e2');
        // Continue with memory backup only (already set above)
      }
    }
    
    // Update instance variables
    _accessToken = accessToken;
    _tokenExpiry = expiry;
  }
  
  /// Make an API request to Spotify, automatically handling token refreshing
  Future<http.Response> _apiRequest(
    String method,
    String path, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    // Get a valid token if we need authentication
    String? token;
    if (requiresAuth) {
      token = await getValidToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }
    }
    
    // Construct URI
    final uri = Uri.https(_baseUrl, '/$_apiVersion/$path', queryParams);
    
    // Prepare headers
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (requiresAuth && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    http.Response response;
    
    // Make request based on method
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
    
    // Handle 401 (token expired) by refreshing token and retrying once
    if (response.statusCode == 401 && requiresAuth) {
      debugPrint('Access token expired, attempting to refresh...');
      if (await _refreshTokenToken()) {
        // Update auth header with new token
        headers['Authorization'] = 'Bearer $_accessToken';
        
        // Retry the request
        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(uri, headers: headers);
            break;
          case 'POST':
            response = await http.post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'PUT':
            response = await http.put(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'DELETE':
            response = await http.delete(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          default:
            throw Exception('Unsupported HTTP method: $method');
        }
      }
    }
    
    return response;
  }
  
  /// Get recommendations based on seed tracks, artists, or genres
  Future<List<SimpleTrack>> getRecommendations({
    List<String> seedTracks = const [],
    List<String> seedArtists = const [],
    List<String> seedGenres = const [],
    int limit = 10,
  }) async {
    try {
      // Build parameters for the API request
      final params = <String, String>{
        'limit': limit.toString(),
      };
      
      if (seedTracks.isNotEmpty) {
        params['seed_tracks'] = seedTracks.join(',');
      }
      
      if (seedArtists.isNotEmpty) {
        params['seed_artists'] = seedArtists.join(',');
      }
      
      if (seedGenres.isNotEmpty) {
        params['seed_genres'] = seedGenres.join(',');
      }
      
      // Make the API request
      final response = await _apiRequest(
        'GET',
        'recommendations',
        queryParams: params,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['tracks'] as List<dynamic>;
        
        return items.map((item) {
          // Extract artist information
          final artists = (item['artists'] as List<dynamic>?)
              ?.map((a) => a['name'] as String)
              .toList() ?? [];
          final artistName = artists.isNotEmpty ? artists.first : '';
          
          // Extract album information
          final albumName = item['album']?['name'] as String? ?? '';
          
          // Extract album art
          final images = item['album']?['images'] as List<dynamic>?;
          String imageUrl = '';
          if (images != null && images.isNotEmpty) {
            imageUrl = images.first['url'] as String? ?? '';
          }
          
          // Extract preview URL
          final previewUrl = item['preview_url'] as String? ?? '';
          
          return SimpleTrack(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            artist: artistName,
            album: albumName,
            albumArtUrl: imageUrl,
            uri: item['uri'] as String? ?? '',
            previewUrl: previewUrl,
          );
        }).toList();
      } else {
        debugPrint('Failed to get recommendations: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting recommendations: $e');
      return [];
    }
  }
  
  /// Search for tracks on Spotify
  Future<List<SimpleTrack>> searchTracks(String query, {int limit = 20}) async {
    try {
      // Add log for search query
      debugPrint('Starting search for tracks with query: "$query"');
      
      // Remove the minimum length check to allow single character searches
      if (query.isEmpty) {
        debugPrint('Empty query, skipping API call');
        return [];
      }
      
      final params = <String, String>{
        'q': query,
        'type': 'track',
        'limit': limit.toString(),
      };
      
      debugPrint('Calling Spotify search API with params: $params');
      final response = await _apiRequest(
        'GET',
        'search',
        queryParams: params,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['tracks']['items'] as List<dynamic>;
        debugPrint('Search successful, found ${items.length} tracks');
        
        return items.map((item) {
          // Extract artist information
          final artists = (item['artists'] as List<dynamic>?)
              ?.map((a) => a['name'] as String)
              .toList() ?? [];
          final artistName = artists.isNotEmpty ? artists.first : '';
          
          // Extract album information
          final albumName = item['album']?['name'] as String? ?? '';
          
          // Extract album art
          final images = item['album']?['images'] as List<dynamic>?;
          String imageUrl = '';
          if (images != null && images.isNotEmpty) {
            imageUrl = images.first['url'] as String? ?? '';
          }
          
          // Extract preview URL
          final previewUrl = item['preview_url'] as String? ?? '';
          
          return SimpleTrack(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            artist: artistName,
            album: albumName,
            albumArtUrl: imageUrl,
            uri: item['uri'] as String? ?? '',
            previewUrl: previewUrl,
          );
        }).toList();
      } else {
        debugPrint('Search failed: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error searching tracks: $e');
      return [];
    }
  }
  
  /// Get user's saved/liked tracks
  Future<List<SimpleTrack>> getLikedTracks({int limit = 20, int offset = 0}) async {
    try {
      final params = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      final response = await _apiRequest(
        'GET',
        'me/tracks',
        queryParams: params,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>;
        
        return items.map((item) {
          final track = item['track'] as Map<String, dynamic>;
          
          // Extract artist information
          final artists = (track['artists'] as List<dynamic>?)
              ?.map((a) => a['name'] as String)
              .toList() ?? [];
          final artistName = artists.isNotEmpty ? artists.first : '';
          
          // Extract album information
          final albumName = track['album']?['name'] as String? ?? '';
          
          // Extract album art
          final images = track['album']?['images'] as List<dynamic>?;
          String imageUrl = '';
          if (images != null && images.isNotEmpty) {
            imageUrl = images.first['url'] as String? ?? '';
          }
          
          // Extract preview URL
          final previewUrl = track['preview_url'] as String? ?? '';
          
          return SimpleTrack(
            id: track['id'] as String? ?? '',
            name: track['name'] as String? ?? '',
            artist: artistName,
            album: albumName,
            albumArtUrl: imageUrl,
            uri: track['uri'] as String? ?? '',
            previewUrl: previewUrl,
          );
        }).toList();
      } else {
        debugPrint('Failed to get liked tracks: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting liked tracks: $e');
      return [];
    }
  }
  
  /// Get user's playlists
  Future<List<Map<String, dynamic>>> getUserPlaylists({int limit = 20, int offset = 0}) async {
    final result = await getUserPlaylistsMap(limit: limit, offset: offset);
    if (result == null) return [];
    
    try {
      final items = result['items'] as List<dynamic>;
      return items.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error parsing user playlists: $e');
      return [];
    }
  }
  
  /// Get user's playlists
  /// [limit] - The maximum number of playlists to return (default: 20)
  /// [offset] - The index of the first playlist to return (default: 0)
  Future<Map<String, dynamic>?> getUserPlaylistsMap({int limit = 20, int offset = 0}) async {
    final token = await getValidToken();
    if (token == null) return null;
    
    try {
      final uri = Uri.https(_baseUrl, '$_apiVersion/me/playlists', {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        if (await _refreshTokenToken()) {
          // Try again with new token
          return getUserPlaylistsMap(limit: limit, offset: offset);
        }
      }
      
      debugPrint('Failed to get user playlists: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error getting user playlists: $e');
      return null;
    }
  }
  
  /// Get user's top tracks
  Future<List<SimpleTrack>> getTopTracks({int limit = 10, String timeRange = 'medium_term'}) async {
    try {
      final params = <String, String>{
        'limit': limit.toString(),
        'time_range': timeRange, // short_term, medium_term, or long_term
      };
      
      final response = await _apiRequest(
        'GET',
        'me/top/tracks',
        queryParams: params,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>;
        
        return items.map((item) {
          // Extract artist information
          final artists = (item['artists'] as List<dynamic>?)
              ?.map((a) => a['name'] as String)
              .toList() ?? [];
          final artistName = artists.isNotEmpty ? artists.first : '';
          
          // Extract album information
          final albumName = item['album']?['name'] as String? ?? '';
          
          // Extract album art
          final images = item['album']?['images'] as List<dynamic>?;
          String imageUrl = '';
          if (images != null && images.isNotEmpty) {
            imageUrl = images.first['url'] as String? ?? '';
          }
          
          // Extract preview URL
          final previewUrl = item['preview_url'] as String? ?? '';
          
          return SimpleTrack(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            artist: artistName,
            album: albumName,
            albumArtUrl: imageUrl,
            uri: item['uri'] as String? ?? '',
            previewUrl: previewUrl,
          );
        }).toList();
      } else {
        debugPrint('Failed to get top tracks: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting top tracks: $e');
      return [];
    }
  }
  
  /// Save a track to the user's library
  Future<bool> saveTrack(String trackId) async {
    try {
      final response = await _apiRequest(
        'PUT',
        'me/tracks',
        queryParams: {'ids': trackId},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error saving track: $e');
      return false;
    }
  }
  
  /// Remove a track from the user's library
  Future<bool> removeTrack(String trackId) async {
    try {
      final response = await _apiRequest(
        'DELETE',
        'me/tracks',
        queryParams: {'ids': trackId},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error removing track: $e');
      return false;
    }
  }
  
  /// Play a track on an active Spotify device
  Future<bool> playTrack(String trackUri, {String? deviceId}) async {
    try {
      final body = <String, dynamic>{
        'uris': [trackUri],
      };
      
      final queryParams = deviceId != null ? {'device_id': deviceId} : null;
      
      final response = await _apiRequest(
        'PUT',
        'me/player/play',
        queryParams: queryParams,
        body: body,
      );
      
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Error playing track: $e');
      return false;
    }
  }
  
  /// Pause playback on an active Spotify device
  Future<bool> pausePlayback({String? deviceId}) async {
    try {
      final queryParams = deviceId != null ? {'device_id': deviceId} : null;
      
      final response = await _apiRequest(
        'PUT',
        'me/player/pause',
        queryParams: queryParams,
      );
      
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Error pausing playback: $e');
      return false;
    }
  }
  
  /// Get the current playback state
  Future<Map<String, dynamic>?> getPlaybackState() async {
    try {
      final response = await _apiRequest(
        'GET',
        'me/player',
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error getting playback state: $e');
      return null;
    }
  }
  
  /// Set tokens directly - useful when auth is handled externally
  void setTokens(String accessToken, String refreshToken, DateTime expiry) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _tokenExpiry = expiry;
    
    // Also store in memory backup
    _accessTokenInMemory = accessToken;
    _refreshTokenInMemory = refreshToken;
    _tokenExpiryInMemory = expiry;
    
    // Save to storage
    _saveTokens(accessToken, refreshToken, expiry);
  }
  
  /// Get the current user profile
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final response = await _apiRequest(
        'GET',
        'me',
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Failed to get user profile: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }
  
  /// Clear saved tokens
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _accessTokenInMemory = null;
    _refreshTokenInMemory = null;
    _tokenExpiryInMemory = null;
    
    try {
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'spotify_access_token');
      await storage.delete(key: 'spotify_refresh_token');
      await storage.delete(key: 'spotify_token_expiry');
    } catch (e) {
      debugPrint('Error clearing tokens from direct secure storage: $e');
    }
  }
  
  /// Get a playlist by ID
  Future<Map<String, dynamic>?> getPlaylist(String playlistId) async {
    final token = await getValidToken();
    if (token == null) return null;
    
    try {
      final uri = Uri.https(_baseUrl, '$_apiVersion/playlists/$playlistId');
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        if (await _refreshTokenToken()) {
          // Try again with new token
          return getPlaylist(playlistId);
        }
        return null;
      }
      
      debugPrint('Error getting playlist: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error getting playlist: $e');
      return null;
    }
  }
  
  /// Get tracks from a playlist
  Future<List<Map<String, dynamic>>> getPlaylistTracks(String playlistId, {int limit = 50, int offset = 0}) async {
    final token = await getValidToken();
    if (token == null) return [];
    
    try {
      final uri = Uri.https(_baseUrl, '$_apiVersion/playlists/$playlistId/tracks', {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>;
        return items.map((item) => item as Map<String, dynamic>).toList();
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        if (await _refreshTokenToken()) {
          // Try again with new token
          return getPlaylistTracks(playlistId, limit: limit, offset: offset);
        }
        return [];
      }
      
      debugPrint('Error getting playlist tracks: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      debugPrint('Error getting playlist tracks: $e');
      return [];
    }
  }
}

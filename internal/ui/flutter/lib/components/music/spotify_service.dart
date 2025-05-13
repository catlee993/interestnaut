import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models.dart';
import '../../services/secure_storage.dart' as secure_storage;
import 'spotify_client.dart';

// Event classes for state management
class AuthStatusEvent {
  final bool isAuthenticated;
  AuthStatusEvent(this.isAuthenticated);
}

class UserProfileEvent {
  final String id;
  final String displayName;
  final String imageUrl;
  UserProfileEvent(this.id, this.displayName, this.imageUrl);
}

class TrackChangeEvent {
  final MediaItem item;
  TrackChangeEvent(this.item);
}

/// A cross-platform Spotify service that handles authentication and playback
///
/// This service provides three layers of functionality:
/// 1. Native auth & playback through spotify_sdk where available (iOS, Android)
/// 2. WebView-based auth with WebAPI playback for desktop platforms
/// 3. Fallback to Go backend when available
class SpotifyService {
  // Singleton pattern
  static final SpotifyService _instance = SpotifyService._internal(
    clientId: '3bb48a30577342869a9ffcb176dee7d2',
    redirectUri: 'interestnaut://spotify-callback',
    authEndpoint: 'https://accounts.spotify.com/authorize',
    tokenEndpoint: 'https://accounts.spotify.com/api/token',
    callbackServerUri: 'http://localhost:8080',
  );
  static SpotifyService get instance => _instance;
  factory SpotifyService() => _instance;

  // Stream controllers for events
  final _authStatusController = StreamController<AuthStatusEvent>.broadcast();
  final _userProfileController = StreamController<UserProfileEvent>.broadcast();
  final _trackChangeController = StreamController<TrackChangeEvent>.broadcast();
  final _playbackStateController = StreamController<bool>.broadcast();
  
  // Public streams that UI components can listen to
  Stream<AuthStatusEvent> get onAuthStatusChange => _authStatusController.stream;
  Stream<UserProfileEvent> get onUserProfileChange => _userProfileController.stream;
  Stream<TrackChangeEvent> get onTrackChange => _trackChangeController.stream;
  Stream<bool> get onPlaybackStateChange => _playbackStateController.stream;
  
  // Authentication state
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;
  
  // Token management
  String? _accessToken;
  DateTime _tokenExpiry = DateTime.now();
  Timer? _refreshTimer;
  bool _authenticating = false;
  
  // Backup token storage in memory
  String? _accessTokenInMemory;
  
  // Code verifier for PKCE
  String _codeVerifier = '';
  
  // API information
  final String clientId;
  final String redirectUri;
  final String authEndpoint;
  final String tokenEndpoint;
  final String callbackServerUri;
  
  // Whether we're using the callback server
  HttpServer? _callbackServer;
  
  // Spotify Web API client
  final SpotifyClient _spotifyClient = SpotifyClient();
  
  /// Internal constructor for the singleton pattern
  SpotifyService._internal({
    required this.clientId,
    required this.redirectUri,
    required this.authEndpoint,
    required this.tokenEndpoint,
    required this.callbackServerUri,
  });
  
  /// Initialize the Spotify service
  /// This should be called during app startup
  Future<void> initialize() async {
    if (_isAuthenticated) return;

    // Load tokens from storage
    final hasToken = await _loadTokens();
    
    if (hasToken) {
      _isAuthenticated = true;

      // Initialize Spotify API wrapper with existing token
      _initializeApi();

      // Schedule a token refresh if needed
      _setupTokenRefresh(_tokenExpiry);
      
      // Emit authentication event
      _emitAuthEvent(true);

      // Fetch user details to make sure token is valid
      _fetchUserDetails();
      
      // Also fetch playlists to ensure we have library access
      _fetchUserPlaylists();
    } else {
      _emitAuthEvent(false);
    }
    
    // Set up URI handling for auth callbacks
    if (Platform.isIOS || Platform.isAndroid) {
      // Mobile platforms use uni_links
      uriLinkStream.listen((Uri? uri) {
        if (uri != null && uri.toString().startsWith(redirectUri)) {
          _handleAuthCallback(uri);
        }
      }, onError: (err) {
        debugPrint('URI link error: $err');
      });
      
      // Check for initial link
      try {
        final initialLink = await getInitialLink();
        if (initialLink != null) {
          final uri = Uri.parse(initialLink);
          if (uri.toString().startsWith(redirectUri)) {
            _handleAuthCallback(uri);
          }
        }
      } catch (e) {
        debugPrint('Error getting initial link: $e');
      }
    } else {
      // Desktop platforms use a local callback server
      _setUpCallbackServer();
    }
    
    // Initialize platform-specific bindings
    await _initializeBindings();

    _isAuthenticated = true;
  }

  /// Initialize platform-specific bindings
  Future<void> _initializeBindings() async {
    // This now only registers Go/Rust FFI callbacks if needed
    // We don't depend on any platform-specific bindings anymore
  }

  /// Set up a local HTTP server to listen for the Spotify callback
  Future<String?> _setUpCallbackServer() async {
    try {
      final completer = Completer<String?>();
      
      _callbackServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
      _callbackServer!.listen((HttpRequest request) async {
        debugPrint('Received callback: ${request.uri}');
        
        // Extract the authorization code
        final code = request.uri.queryParameters['code'];
        
        // Send a response to the browser
        request.response.headers.set('Content-Type', 'text/html');
        request.response.write('''
          <html>
            <head><title>Authentication Successful</title></head>
            <body>
              <h1>Authentication Successful</h1>
              <p>You can now close this window and return to the app.</p>
              <script>window.close();</script>
            </body>
          </html>
        ''');
        await request.response.close();
        
        // Complete the future with the code
        completer.complete(code);
        
        // Clean up server
        await _callbackServer?.close();
        _callbackServer = null;
      });
      
      return completer.future;
    } catch (e) {
      debugPrint('Error setting up callback server: $e');
      return null;
    }
  }

  /// Handle the authentication callback from the browser
  void _handleAuthCallback(Uri uri) async {
    debugPrint('Handling auth callback: ${uri.toString()}');
    
    // Extract the authorization code from the URI
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      debugPrint('No code found in callback URI');
      return;
    }
    
    // Exchange the code for an access token
    await _exchangeCodeForToken(code);
  }
  
  /// Generate a random code verifier for PKCE
  String _generateCodeVerifier() {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(128, (_) => charset[random.nextInt(charset.length)]).join();
  }
  
  /// Generate a code challenge from the code verifier
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Authenticate with Spotify using appropriate method for the current platform
  /// Returns true if the authentication process was initiated successfully
  Future<bool> authenticate(BuildContext context) async {
    if (_authenticating) return false;
    
    _authenticating = true;
    bool success = false;
    
    try {
      debugPrint('Starting Spotify authentication...');
      
      // Generate a PKCE code verifier and challenge
      _codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(_codeVerifier);
      
      // Save the code verifier to secure storage for later use
      try {
        await secure_storage.SecureStorage.saveSpotifyCodeVerifier(_codeVerifier);
      } catch (e) {
        debugPrint('Error saving code verifier to secure storage: $e');
      }
      
      // Build the authorization URL
      final authUrl = Uri.parse(authEndpoint).replace(
        queryParameters: {
          'client_id': clientId,
          'response_type': 'code',
          'redirect_uri': redirectUri,
          'code_challenge_method': 'S256',
          'code_challenge': codeChallenge,
          'scope': 'user-read-private user-read-email user-library-read user-library-modify user-read-playback-state user-modify-playback-state user-top-read streaming',
        },
      );
      
      // Open the URL in the browser
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(
          authUrl,
          mode: LaunchMode.externalApplication,
        );
        
        // For platforms like macOS with entitlement issues, we might need manual entry
        if (Platform.isMacOS) {
          if (context.mounted) {
            _handleAuthTextField(context);
          }
        }
        
        // Subscribe to incoming links (for mobile platforms and desktop apps registered with URL schemes)
        _subscribeToAuthLinks();
        
        // Set up a callback server if needed (desktop platforms)
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          final code = await _setUpCallbackServer();
          if (code != null) {
            await _exchangeCodeForToken(code);
          }
        }
        
        success = true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to launch browser for authentication'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error during authentication: $e');
      
      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _authenticating = false;
    }
    
    return success;
  }
  
  /// This method handles the authentication callback by extracting the auth code from a TextField
  void _handleAuthTextField(BuildContext context) async {
    // Show dialog for manual entry
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter Authorization Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter the authorization code from the Spotify authentication page:',
              ),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Authorization Code',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(null);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              child: const Text('Submit'),
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text);
              },
            ),
          ],
        );
      },
    );
    
    if (code != null && code.isNotEmpty) {
      await _exchangeCodeForToken(code);
    }
  }
  
  /// Subscribe to incoming deep links
  void _subscribeToAuthLinks() {
    try {
      uriLinkStream.listen((Uri? uri) {
        if (uri != null) {
          _handleAuthCallback(uri);
        }
      }, onError: (err) {
        debugPrint('Error with URI links: $err');
      });
      debugPrint('Listening for auth links');
    } catch (e) {
      debugPrint('Error setting up URI link listener: $e');
    }
  }

  /// Exchange the authorization code for an access token using PKCE
  Future<bool> _exchangeCodeForToken(String code) async {
    try {
      debugPrint('Exchanging code for token with PKCE...');
      // Exchange the authorization code for tokens using PKCE
      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': _codeVerifier,
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 3600;
        
        // Calculate expiry time
        final expiry = DateTime.now().add(Duration(seconds: expiresIn - 60)); // Subtract 60s for buffer
        
        // Save tokens
        await _saveTokens(
          accessToken,
          refreshToken ?? '',
          expiry,
        );
        
        // Set as authenticated
        _isAuthenticated = true;
        
        // Emit auth event
        _emitAuthEvent(true);

        // Initialize the API
        _initializeApi();
        
        // Set up auto refresh
        _setupTokenRefresh(expiry);
        
        // Save tokens to the platform-specific secure storage as backup
        await secure_storage.SecureStorage.saveSpotifyTokens(
          accessToken: accessToken,
          refreshToken: refreshToken ?? '',
          expiryMillis: expiry.millisecondsSinceEpoch,
        );
        
        // Also save to in-memory backup
        _accessTokenInMemory = accessToken;
        
        debugPrint('Authentication successful, token expires at $expiry');
        
        // Fetch user profile
        _fetchAndEmitUserProfile();
        
        return true;
      } else {
        debugPrint('Token exchange failed with status ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error exchanging code for token: $e');
      return false;
    }
  }

  /// Refresh the access token using the refresh token
  Future<bool> _refreshAccessToken() async {
    debugPrint('Refreshing access token...');
    
    if (_accessToken == null) {
      debugPrint('No access token available');
      return false;
    }
    
    try {
      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': clientId,
          'grant_type': 'refresh_token',
          'refresh_token': _accessToken!,
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 3600;
        
        // Calculate expiry time
        final expiry = DateTime.now().add(Duration(seconds: expiresIn - 60)); // Subtract 60s for buffer
        
        // Save tokens
        await _saveTokens(
          accessToken,
          refreshToken ?? '',
          expiry,
        );
        
        // Update in-memory backup
        _accessTokenInMemory = accessToken;
        
        // Set up next refresh
        _setupTokenRefresh(expiry);
        
        // Initialize API with new token
        _initializeApi();
        
        debugPrint('Token refreshed successfully, expires at $expiry');
        return true;
      } else {
        debugPrint('Token refresh failed: ${response.statusCode} ${response.body}');
        
        // Token refresh failed, may need to reauthenticate
        _emitAuthEvent(false);
        return false;
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      
      // Token refresh failed, may need to reauthenticate
      _emitAuthEvent(false);
      return false;
    }
  }

  /// Save tokens to internal state
  Future<void> _saveTokens(String accessToken, String refreshToken, DateTime expiry) async {
    // Update instance variables
    _accessToken = accessToken;
    _tokenExpiry = expiry;
    
    // Try to save to secure storage
    try {
      await secure_storage.SecureStorage.saveSpotifyTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiryMillis: expiry.millisecondsSinceEpoch,
      );
      debugPrint('Tokens saved to secure storage');
    } catch (e) {
      debugPrint('Error saving tokens to secure storage: $e');
    }
  }

  /// Initialize the Spotify API with the current access token
  void _initializeApi() {
    if (_accessToken != null) {
      try {
        debugPrint('Initializing Spotify API with token: ${_accessToken!.substring(0, 5)}...');
        
        // Pass the credentials to the client
        _spotifyClient.setCredentials(
          accessToken: _accessToken!,
          expiry: _tokenExpiry,
        );
        
        debugPrint('Spotify API initialized successfully');
      } catch (e) {
        debugPrint('Error initializing Spotify API: $e');
      }
    } else {
      debugPrint('Cannot initialize Spotify API: No access token available');
    }
  }

  /// Fetch user profile and emit event
  Future<void> _fetchAndEmitUserProfile() async {
    await _fetchUserDetails();
  }

  /// Fetch the user's profile details
  Future<void> _fetchUserDetails() async {
    debugPrint('Fetching user details...');
    try {
      // Make sure we have a valid access token
      if (_accessToken == null) {
        try {
          // First try to load from our enhanced storage
          final tokenData = await secure_storage.SecureStorage.getSpotifyTokens();
          if (tokenData != null && tokenData['accessToken'] != null) {
            _accessToken = tokenData['accessToken'] as String?;
            final expiryMillis = tokenData['expiryMillis'] as int?;
            if (expiryMillis != null) {
              _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
            }
            
            debugPrint('Tokens loaded from enhanced secure storage');
          } else {
            // Fall back to direct secure storage
            const storage = FlutterSecureStorage();
            _accessToken = await storage.read(key: 'spotify_access_token');
            debugPrint('Loaded access token from direct secure storage');
          }
          
          // If we still don't have a token, check memory backup
          if (_accessToken == null) {
            _accessToken = _accessTokenInMemory;
            debugPrint('Using in-memory access token');
          }
        } catch (e) {
          debugPrint('Error loading access token: $e');
          // Check memory backup
          if (_accessTokenInMemory != null) {
            _accessToken = _accessTokenInMemory;
            debugPrint('Using in-memory access token after error');
          }
        }
        
        // If still null, we don't have authentication
        if (_accessToken == null) {
          debugPrint('Cannot get user: not authenticated or no access token');
          return;
        }
        
        // Re-initialize API since we just loaded the token
        _initializeApi();
      }
      
      // Make direct API call instead of using the Spotify SDK wrapper
      // This is more reliable and gives us better error handling
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic>? images = data['images'] as List<dynamic>?;
        final String imageUrl = images != null && images.isNotEmpty 
            ? (images.first['url'] as String? ?? '') 
            : '';
            
        _userProfileController.add(UserProfileEvent(
          data['id'] as String? ?? '',
          data['display_name'] as String? ?? '',
          imageUrl,
        ));
        
        // Also try to fetch the user's playlists since we know the token is working
        _fetchUserPlaylists();
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        debugPrint('Access token expired, attempting to refresh...');
        await _refreshAccessToken();
      } else {
        debugPrint('Error fetching user profile: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  /// Fetch user playlists to ensure we have access to the user's library
  Future<void> _fetchUserPlaylists() async {
    try {
      if (_accessToken == null) return;
      
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/playlists?limit=5'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('Successfully retrieved user playlists - API connection is working');
      } else {
        debugPrint('Error fetching playlists: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching playlists: $e');
    }
  }

  /// Load tokens from secure storage or memory backup
  Future<bool> _loadTokens() async {
    try {
      debugPrint('Loading tokens from secure storage');
      
      // Load from secure storage
      final tokenData = await secure_storage.SecureStorage.getSpotifyTokens();
      if (tokenData != null && tokenData['accessToken'] != null) {
        _accessToken = tokenData['accessToken'] as String?;
        final expiryMillis = tokenData['expiryMillis'] as int?;
        if (expiryMillis != null) {
          _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
        }
        
        debugPrint('Tokens loaded from enhanced secure storage');
        return true;
      }
    } catch (e) {
      debugPrint('Error loading tokens from secure storage: $e');
    }
    
    // Fall back to memory if all else fails
    if (_accessTokenInMemory != null) {
      _accessToken = _accessTokenInMemory;
      debugPrint('Tokens loaded from memory backup');
      return true;
    }
    
    return false;
  }

  /// Logout from Spotify
  Future<void> logout() async {
    try {
      // Clear tokens from secure storage
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'spotify_access_token');
      await storage.delete(key: 'spotify_refresh_token');
      await storage.delete(key: 'spotify_token_expiry');
      await storage.delete(key: 'spotify_code_verifier');
      
      // Reset state
      _accessToken = null;
      _tokenExpiry = DateTime.now();
      _isAuthenticated = false;
      
      // Cancel any scheduled refreshes
      _refreshTimer?.cancel();
      
      // Emit event
      _emitAuthEvent(false);
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  /// Get recommendations based on seed tracks, artists, or genres
  Future<List<SimpleTrack>> getRecommendations({
    List<String> seedTracks = const [],
    List<String> seedArtists = const [],
    List<String> seedGenres = const [],
    int limit = 10,
  }) async {
    if (!_isAuthenticated) {
      debugPrint('Cannot get recommendations: not authenticated');
      return [];
    }
    
    try {
      return await _spotifyClient.getRecommendations(
        seedTracks: seedTracks,
        seedArtists: seedArtists,
        seedGenres: seedGenres,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error getting recommendations: $e');
      return [];
    }
  }

  /// Search for tracks, albums, artists, or playlists on Spotify
  Future<List<SimpleTrack>> searchTracks(String query, {int limit = 20}) async {
    if (!_isAuthenticated) {
      debugPrint('Cannot search tracks: not authenticated');
      return [];
    }
    
    try {
      return await _spotifyClient.searchTracks(query, limit: limit);
    } catch (e) {
      debugPrint('Error searching tracks: $e');
      return [];
    }
  }

  /// Get user's saved/liked tracks
  Future<List<SimpleTrack>> getLikedTracks({int limit = 20, int offset = 0}) async {
    if (!_isAuthenticated) {
      debugPrint('Cannot get liked tracks: not authenticated');
      return [];
    }
    
    try {
      return await _spotifyClient.getLikedTracks(limit: limit, offset: offset);
    } catch (e) {
      debugPrint('Error getting liked tracks: $e');
      return [];
    }
  }

  /// Get user's playlists
  Future<List<Map<String, dynamic>>> getUserPlaylists({int limit = 20, int offset = 0}) async {
    if (!_isAuthenticated) {
      debugPrint('Cannot get user playlists: not authenticated');
      return [];
    }
    
    try {
      return await _spotifyClient.getUserPlaylists(limit: limit, offset: offset);
    } catch (e) {
      debugPrint('Error getting user playlists: $e');
      return [];
    }
  }

  /// Get user's top tracks
  Future<List<SimpleTrack>> getTopTracks({int limit = 10, String timeRange = 'medium_term'}) async {
    if (!_isAuthenticated) {
      debugPrint('Cannot get top tracks: not authenticated');
      return [];
    }
    
    try {
      return await _spotifyClient.getTopTracks(limit: limit, timeRange: timeRange);
    } catch (e) {
      debugPrint('Error getting top tracks: $e');
      return [];
    }
  }

  /// Save a track to the user's library
  Future<bool> saveTrack(String trackId) async {
    if (!_isAuthenticated) {
      debugPrint('Cannot save track: not authenticated');
      return false;
    }
    
    try {
      return await _spotifyClient.saveTrack(trackId);
    } catch (e) {
      debugPrint('Error saving track: $e');
      return false;
    }
  }

  /// Remove a track from the user's library
  Future<bool> removeTrack(String trackId) async {
    if (!_isAuthenticated) {
      debugPrint('Cannot remove track: not authenticated');
      return false;
    }
    
    try {
      return await _spotifyClient.removeTrack(trackId);
    } catch (e) {
      debugPrint('Error removing track: $e');
      return false;
    }
  }

  /// Play a track on an active Spotify device
  Future<bool> playTrack(String trackUri, {String? deviceId}) async {
    if (!_isAuthenticated) {
      debugPrint('Cannot play track: not authenticated');
      return false;
    }
    
    try {
      // Use Web API
      return await _spotifyClient.playTrack(trackUri, deviceId: deviceId);
    } catch (e) {
      debugPrint('Error playing track: $e');
      return false;
    }
  }

  /// Pause playback on an active Spotify device
  Future<bool> pausePlayback({String? deviceId}) async {
    if (!_isAuthenticated) {
      debugPrint('Cannot pause playback: not authenticated');
      return false;
    }
    
    try {
      // Use Web API
      return await _spotifyClient.pausePlayback(deviceId: deviceId);
    } catch (e) {
      debugPrint('Error pausing playback: $e');
      return false;
    }
  }

  /// Get the current playback state
  Future<Map<String, dynamic>?> getPlaybackState() async {
    if (!_isAuthenticated) {
      debugPrint('Cannot get playback state: not authenticated');
      return null;
    }
    
    try {
      return await _spotifyClient.getPlaybackState();
    } catch (e) {
      debugPrint('Error getting playback state: $e');
      return null;
    }
  }

  /// Fetch the current user's profile from Spotify API
  /// Returns null if user is not authenticated or if there was an error
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (!_isAuthenticated) {
      debugPrint('Cannot get user: not authenticated or no access token');
      return null;
    }
    
    try {
      return await _spotifyClient.getCurrentUserProfile();
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return {'error': 'Error getting user profile: $e'};
    }
  }

  /// Emit an authentication event
  void _emitAuthEvent(bool isAuthenticated) {
    _authStatusController.add(AuthStatusEvent(isAuthenticated));
  }

  /// Schedule a token refresh before the current token expires
  void _setupTokenRefresh(DateTime expiry) {
    // Cancel any existing refresh timer
    _refreshTimer?.cancel();
    
    // Calculate when to refresh (5 minutes before expiry)
    final now = DateTime.now();
    final refreshTime = expiry.subtract(const Duration(minutes: 5));
    
    // If the token is already expired or will expire in less than 5 minutes,
    // refresh immediately
    if (now.isAfter(refreshTime)) {
      // Call directly without using Timer
      _refreshAccessToken();
      return;
    }
    
    // Schedule the refresh
    final refreshDelay = refreshTime.difference(now);
    _refreshTimer = Timer(refreshDelay, () {
      // Use a closure to avoid the null safety issue
      _refreshAccessToken();
    });
    
    debugPrint('Token refresh scheduled for $refreshTime (in ${refreshDelay.inMinutes} minutes)');
  }
}

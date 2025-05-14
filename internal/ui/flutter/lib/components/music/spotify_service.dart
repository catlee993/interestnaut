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
    callbackServerUri: 'http://localhost',
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
  Completer<String?>? _callbackCompleter;
  Future<String?>? _callbackServerFuture;
  
  // Registered callback ports - these must be registered in the Spotify Developer Dashboard
  static const List<int> _registeredCallbackPorts = [8080, 6789, 7575, 8821, 9432, 5723];
  
  // Property to store current callback port
  int _callbackPort = -1;
  
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
  /// Returns the authorization code if successful, null otherwise
  Future<String?> _setUpCallbackServer() async {
    // Make sure any previous server is properly closed
    await _closeCallbackServer();
    
    try {
      _callbackCompleter = Completer<String?>();
      
      // Try each registered port in sequence
      bool serverStarted = false;
      for (final port in _registeredCallbackPorts) {
        try {
          _callbackServer = await HttpServer.bind(InternetAddress.loopbackIPv4, port, shared: true);
          _callbackPort = port;
          serverStarted = true;
          debugPrint('Callback server started on port $_callbackPort');
          break;
        } catch (e) {
          debugPrint('Port $port is not available: $e');
        }
      }
      
      if (!serverStarted) {
        debugPrint('Failed to bind to any registered callback port');
        return null;
      }
      
      _callbackServer!.listen((HttpRequest request) async {
        debugPrint('Received callback: ${request.uri}');
        
        // Parse the URI
        final uri = request.uri;
        
        // Write a friendly HTML response
        request.response.headers.set('Content-Type', 'text/html');
        request.response.write('''
          <!DOCTYPE html>
          <html>
            <head>
              <title>Authentication Successful</title>
              <style>
                body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
                h1 { color: #1DB954; }
              </style>
            </head>
            <body>
              <h1>Authentication Successful</h1>
              <p>You can close this window and return to the app.</p>
            </body>
          </html>
        ''');
        await request.response.close();
        
        // Extract the code
        final code = uri.queryParameters['code'];
        if (code != null && !_callbackCompleter!.isCompleted) {
          _callbackCompleter!.complete(code);
          
          // Close the server after a delay to ensure the response has been sent
          Timer(const Duration(seconds: 1), () {
            _closeCallbackServer();
          });
        } else if (uri.queryParameters['error'] != null && !_callbackCompleter!.isCompleted) {
          debugPrint('Error during auth: ${uri.queryParameters['error']}');
          _callbackCompleter!.complete(null);
          
          // Close the server after a delay
          Timer(const Duration(seconds: 1), () {
            _closeCallbackServer();
          });
        }
      }, onError: (e) {
        debugPrint('Error in callback server: $e');
        if (_callbackCompleter != null && !_callbackCompleter!.isCompleted) {
          _callbackCompleter!.complete(null);
        }
      });
      
      // Set the future that will complete when the callback is received
      _callbackServerFuture = _callbackCompleter!.future;
      return _callbackServerFuture;
    } catch (e) {
      debugPrint('Error starting callback server: $e');
      return null;
    }
  }

  /// Close the callback server if it's running
  Future<void> _closeCallbackServer() async {
    try {
      if (_callbackServer != null) {
        debugPrint('Closing callback server');
        await _callbackServer!.close();
        _callbackServer = null;
      }
    } catch (e) {
      debugPrint('Error closing callback server: $e');
    }
  }
  
  /// Try to find an available registered callback port
  Future<int> _findAvailableCallbackPort() async {
    for (final port in _registeredCallbackPorts) {
      try {
        // Just try to bind to check availability, then close immediately
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port, shared: true);
        debugPrint('Successfully bound to port $port');
        await server.close();
        return port;
      } catch (e) {
        debugPrint('Port $port is not available: $e');
      }
    }
    return -1;
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
    if (_authenticating) {
      debugPrint('Authentication already in progress');
      return false;
    }
    
    _authenticating = true;
    bool success = false;
    
    try {
      // First find an available registered port
      final port = await _findAvailableCallbackPort();
      
      if (port <= 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to find an available port for authentication. Try restarting the app.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }
      
      // Now start the callback server with our known-available port
      _callbackPort = port;
      await _closeCallbackServer(); // Make sure any previous server is closed
      await _startCallbackServer();
      
      // Generate PKCE code verifier and challenge
      _codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(_codeVerifier);
      
      // Use the dynamic redirect URI with the port we found
      final dynamicRedirectUri = '$callbackServerUri:$_callbackPort/callback';
      debugPrint('Using dynamic redirect URI: $dynamicRedirectUri');
      
      // Build the authorization URL with the dynamic redirect URI
      final authUrl = Uri.parse(authEndpoint).replace(
        queryParameters: {
          'client_id': clientId,
          'response_type': 'code',
          'redirect_uri': dynamicRedirectUri,
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
        
        // Subscribe to incoming links (for mobile platforms and desktop apps registered with URL schemes)
        _subscribeToAuthLinks();
        
        // Wait for the callback server to get a code
        final code = await _callbackServerFuture;
        if (code != null) {
          success = await _exchangeCodeForToken(code, dynamicRedirectUri);
        }
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
      
      // Ensure the callback server is closed
      await _closeCallbackServer();
    }
    
    return success;
  }

  /// Start the callback server
  Future<bool> _startCallbackServer() async {
    try {
      _callbackCompleter = Completer<String?>();
      
      // Attempt to bind to the port we found available
      try {
        _callbackServer = await HttpServer.bind(InternetAddress.loopbackIPv4, _callbackPort, shared: true);
        debugPrint('Callback server started on port $_callbackPort');
      } catch (e) {
        debugPrint('Failed to bind to port $_callbackPort: $e');
        return false;
      }
      
      _callbackServer!.listen((HttpRequest request) async {
        debugPrint('Received callback: ${request.uri}');
        
        // Parse the URI
        final uri = request.uri;
        
        // Write a friendly HTML response
        request.response.headers.set('Content-Type', 'text/html');
        request.response.write('''
          <!DOCTYPE html>
          <html>
            <head>
              <title>Authentication Successful</title>
              <style>
                body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
                h1 { color: #1DB954; }
              </style>
            </head>
            <body>
              <h1>Authentication Successful</h1>
              <p>You can close this window and return to the app.</p>
            </body>
          </html>
        ''');
        await request.response.close();
        
        // Extract the code
        final code = uri.queryParameters['code'];
        if (code != null && _callbackCompleter != null && !_callbackCompleter!.isCompleted) {
          _callbackCompleter!.complete(code);
          
          // Close the server after a delay to ensure the response has been sent
          Timer(const Duration(seconds: 1), () {
            _closeCallbackServer();
          });
        } else if (uri.queryParameters['error'] != null && _callbackCompleter != null && !_callbackCompleter!.isCompleted) {
          debugPrint('Error during auth: ${uri.queryParameters['error']}');
          _callbackCompleter!.complete(null);
          
          // Close the server after a delay
          Timer(const Duration(seconds: 1), () {
            _closeCallbackServer();
          });
        }
      }, onError: (e) {
        debugPrint('Error in callback server: $e');
        if (_callbackCompleter != null && !_callbackCompleter!.isCompleted) {
          _callbackCompleter!.complete(null);
        }
      });
      
      // Set the future that will complete when the callback is received
      _callbackServerFuture = _callbackCompleter!.future;
      return true;
    } catch (e) {
      debugPrint('Error starting callback server: $e');
      return false;
    }
  }

  /// Exchange the authorization code for an access token using PKCE
  Future<bool> _exchangeCodeForToken(String code, [String? dynamicRedirectUri]) async {
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
          'redirect_uri': dynamicRedirectUri ?? '$callbackServerUri:$_callbackPort/callback',
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

  /// Subscribe to incoming deep links
  void _subscribeToAuthLinks() {
    try {
      uriLinkStream.listen((Uri? uri) {
        if (uri != null) {
          debugPrint('Received URI: $uri');
          
          // Check if this is a callback URI with a code parameter
          if (uri.toString().contains('/callback') && uri.queryParameters.containsKey('code')) {
            final code = uri.queryParameters['code'];
            if (code != null) {
              debugPrint('Extracted code from URI: ${code.substring(0, min(10, code.length))}...');
              
              // Complete the callback completer if it exists and hasn't been completed yet
              if (_callbackCompleter != null && !_callbackCompleter!.isCompleted) {
                _callbackCompleter!.complete(code);
              }
            }
          }
        }
      }, onError: (err) {
        debugPrint('Error with URI links: $err');
      });
      debugPrint('Listening for auth links');
    } catch (e) {
      debugPrint('Error setting up URI link listener: $e');
    }
  }
}

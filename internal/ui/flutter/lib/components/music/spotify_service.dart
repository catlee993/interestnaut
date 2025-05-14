import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models.dart';
import '../../services/secure_storage.dart' as secure_storage;
import 'spotify_client.dart';
import 'package:path_provider/path_provider.dart';

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
  final MediaItem? item;
  TrackChangeEvent(this.item);
}

// Singleton implementation for SpotifyService
class SpotifyService {
  // Singleton instance
  static final SpotifyService _instance = SpotifyService._internal(
    clientId: '3bb48a30577342869a9ffcb176dee7d2',
    redirectUri: 'interestnaut://spotify-callback',
    authEndpoint: 'https://accounts.spotify.com/authorize',
    tokenEndpoint: 'https://accounts.spotify.com/api/token',
    callbackServerUri: 'http://localhost',
  );
  
  // Factory constructor to return the same instance
  factory SpotifyService() {
    return _instance;
  }
  
  // Private constructor
  SpotifyService._internal({
    required this.clientId,
    required this.redirectUri,
    required this.authEndpoint,
    required this.tokenEndpoint,
    required this.callbackServerUri,
  });
  
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
  String? _refreshToken;
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
  
  /// Initialize the Spotify service
  /// This should be called during app startup
  Future<void> initialize() async {
    debugPrint('Initializing Spotify service...');
    
    // Set initial state to not authenticated
    _isAuthenticated = false;
    
    // Load tokens from storage first
    final hasToken = await _loadTokens();
    
    if (hasToken) {
      debugPrint('Found existing tokens, verifying with API...');
      // Initialize Spotify API wrapper with loaded token
      _initializeApi();
      
      // Verify token by attempting to fetch user profile
      final userProfile = await _verifyTokenWithUserProfile();
      
      if (userProfile != null) {
        // Token is valid, set authenticated state
        debugPrint('Token verification successful, user is authenticated');
        _isAuthenticated = true;
        _emitAuthEvent(true);
        
        // Schedule token refresh
        _setupTokenRefresh();
      } else {
        // Token is invalid, clear it
        debugPrint('Token verification failed, clearing tokens');
        await _clearTokens();
        _emitAuthEvent(false);
      }
    } else {
      debugPrint('No tokens found, user is not authenticated');
      _emitAuthEvent(false);
    }
    
    // Set up URI handling for auth callbacks on mobile
    if (Platform.isIOS || Platform.isAndroid) {
      uriLinkStream.listen((Uri? uri) {
        if (uri != null && uri.toString().contains('/callback')) {
          _handleAuthCallback(uri);
        }
      }, onError: (err) {
        debugPrint('URI link error: $err');
      });
    }
  }

  /// Verify token validity by fetching user profile
  /// Returns user profile if successful, null if token is invalid
  Future<Map<String, dynamic>?> _verifyTokenWithUserProfile() async {
    if (_accessToken == null) return null;
    
    try {
      // Make direct API call to verify token
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      
      if (response.statusCode == 200) {
        // Token is valid, parse user profile
        final data = jsonDecode(response.body);
        
        // Extract user info
        final List<dynamic>? images = data['images'] as List<dynamic>?;
        final String imageUrl = images != null && images.isNotEmpty 
            ? (images.first['url'] as String? ?? '') 
            : '';
        
        // Emit user profile event
        _userProfileController.add(UserProfileEvent(
          data['id'] as String? ?? '',
          data['display_name'] as String? ?? '',
          imageUrl,
        ));
        
        // Also fetch playlists since we know token works
        _fetchUserPlaylists();
        
        return data;
      } else if (response.statusCode == 401) {
        // Token is expired, try to refresh
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          // Try again with new token
          return _verifyTokenWithUserProfile();
        }
      }
    } catch (e) {
      debugPrint('Error verifying token: $e');
    }
    
    return null;
  }

  /// Logout from Spotify
  Future<void> logout() async {
    try {
      // Try to pause any playback first
      try {
        await _spotifyClient.pausePlayback();
      } catch (e) {
        // Ignore errors if not playing
        debugPrint('Note: Could not pause playback during logout: $e');
      }
      
      // Clear tokens and state
      await _clearTokens();
      
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  /// Manually get a new access token
  Future<bool> refreshToken() async {
    return await _refreshAccessToken();
  }

  /// Clear all tokens from storage and memory
  Future<void> _clearTokens() async {
    try {
      // Clear from secure storage using the proper methods
      try {
        // Use the correct method name: clearSpotifyCredentials
        await secure_storage.SecureStorage.clearSpotifyCredentials();
        debugPrint('Tokens cleared from secure storage');
      } catch (e) {
        debugPrint('Error clearing tokens from secure storage: $e');
      }
      
      // Also clear from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('spotify_access_token');
        await prefs.remove('spotify_refresh_token');
        await prefs.remove('spotify_token_expiry');
        debugPrint('Tokens cleared from SharedPreferences');
      } catch (e) {
        debugPrint('Error clearing tokens from SharedPreferences: $e');
      }
      
      // Clear memory
      _accessToken = null;
      _refreshToken = null;
      _accessTokenInMemory = null;
      _isAuthenticated = false;
      
      // Notify listeners about auth state change
      _emitAuthEvent(false);
      
      debugPrint('All tokens cleared from storage and memory');
    } catch (e) {
      debugPrint('Error clearing tokens: $e');
    }
  }

  /// Get the current playback state
  Future<Map<String, dynamic>?> getPlaybackState() async {
    if (!_isAuthenticated || _accessToken == null) {
      debugPrint('Cannot get playback state: not authenticated');
      return null;
    }
    
    try {
      // Make direct API call
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );
      
      if (response.statusCode == 200) {
        // Success - parse and return the playback state
        return jsonDecode(response.body);
      } else if (response.statusCode == 204) {
        // No active device - this is a normal state
        return {'is_playing': false, 'no_active_device': true};
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshed = await _refreshAccessToken();
        if (!refreshed) {
          _isAuthenticated = false;
          _emitAuthEvent(false);
        }
        return null;
      } else {
        debugPrint('Error getting playback state: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting playback state: $e');
      return null;
    }
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
    final random = math.Random.secure();
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
      final dynamicRedirectUri = _dynamicRedirectUri;
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
      
      // Use dynamic redirect URI if provided, otherwise use the default
      final redirectUriToUse = dynamicRedirectUri ?? _dynamicRedirectUri;
      
      // Prepare the token request
      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUriToUse,
          'code_verifier': _codeVerifier,
        },
      );
      
      // Check response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;
        final expiresIn = data['expires_in'] as int;
        
        // Calculate token expiry time
        final expiry = DateTime.now().add(Duration(seconds: expiresIn));
        
        // Save tokens
        await _saveTokens(accessToken, refreshToken, expiry);
        
        debugPrint('Tokens saved to secure storage');
        
        // Initialize the API
        _initializeApi();
        
        // Emit auth event
        _isAuthenticated = true;
        _emitAuthEvent(true);
        
        // Schedule token refresh
        _setupTokenRefresh();
        
        debugPrint('Authentication successful, token expires at $_tokenExpiry');
        
        // Fetch user details
        _fetchUserDetails();
        
        return true;
      } else {
        debugPrint('Token exchange failed: ${response.statusCode} - ${response.body}');
        
        _isAuthenticated = false;
        _emitAuthEvent(false);
        return false;
      }
    } catch (e) {
      debugPrint('Error exchanging code for token: $e');
      
      _isAuthenticated = false;
      _emitAuthEvent(false);
      return false;
    }
  }

  /// Refresh the access token using the refresh token
  Future<bool> _refreshAccessToken() async {
    debugPrint('Refreshing access token...');
    
    if (_refreshToken == null) {
      debugPrint('Cannot refresh token: No refresh token available');
      return false;
    }
    
    try {
      // Prepare the refresh token request
      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': clientId,
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
        },
      );
      
      // Check response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String;
        final expiresIn = data['expires_in'] as int;
        
        // Note: Spotify may not always return a new refresh token
        // If it does, we should update our stored refresh token
        String refreshTokenToSave = _refreshToken!;
        if (data['refresh_token'] != null) {
          refreshTokenToSave = data['refresh_token'] as String;
        }
        
        // Calculate token expiry time
        final expiry = DateTime.now().add(Duration(seconds: expiresIn));
        
        // Save tokens
        await _saveTokens(accessToken, refreshTokenToSave, expiry);
        
        debugPrint('Token refreshed successfully');
        
        // Re-initialize the API with the new token
        _initializeApi();
        
        // Update authenticated state
        _isAuthenticated = true;
        _emitAuthEvent(true);
        
        // Schedule next refresh
        _setupTokenRefresh();
        
        return true;
      } else {
        debugPrint('Token refresh failed: ${response.statusCode} - ${response.body}');
        
        // Clear tokens if refresh fails with 400 (likely invalid refresh token)
        if (response.statusCode == 400) {
          await _clearTokens();
        }
        
        return false;
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      return false;
    }
  }

  /// Save tokens to internal state and storage
  Future<void> _saveTokens(String accessToken, String? refreshToken, DateTime expiry) async {
    // Update instance variables
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _tokenExpiry = expiry;
    _accessTokenInMemory = accessToken;
    _isAuthenticated = true;
    
    try {
      // Save tokens using the available SecureStorage method
      await secure_storage.SecureStorage.saveSpotifyTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiryMillis: expiry.millisecondsSinceEpoch,
      );
      
      debugPrint('Tokens saved to secure storage');
    } catch (e) {
      debugPrint('Error saving tokens to secure storage: $e');
      
      // Use SharedPreferences as fallback in dev mode
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('spotify_access_token', accessToken);
        if (refreshToken != null) {
          await prefs.setString('spotify_refresh_token', refreshToken);
        }
        await prefs.setInt('spotify_token_expiry', expiry.millisecondsSinceEpoch);
        
        debugPrint('Tokens saved to SharedPreferences as fallback');
      } catch (prefError) {
        debugPrint('Error saving tokens to SharedPreferences: $prefError');
      }
    }
  }

  /// Load tokens from secure storage, SharedPreferences, or memory
  Future<bool> _loadTokens() async {
    // Try loading from secure storage first
    bool loaded = await _loadTokensFromSecureStorage();
    if (loaded) return true;
    
    // Try loading from SharedPreferences
    loaded = await _loadTokensFromSharedPreferences();
    if (loaded) return true;
    
    // Finally, check memory backup
    if (_accessTokenInMemory != null) {
      _accessToken = _accessTokenInMemory;
      debugPrint('Tokens loaded from memory backup');
      return true;
    }
    
    debugPrint('No tokens found in any storage');
    return false;
  }

  /// Load tokens from secure storage
  Future<bool> _loadTokensFromSecureStorage() async {
    try {
      debugPrint('Trying to load tokens from secure storage');
      
      // First try using the getSpotifyTokens method
      final tokenData = await secure_storage.SecureStorage.getSpotifyTokens();
      if (tokenData != null && tokenData['accessToken'] != null) {
        _accessToken = tokenData['accessToken'] as String?;
        _refreshToken = tokenData['refreshToken'] as String?;
        final expiryMillis = tokenData['expiryMillis'] as int?;
        
        if (expiryMillis != null) {
          _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
          debugPrint('Token expiry: $_tokenExpiry');
        } else {
          _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
          debugPrint('No expiry in token data, defaulting to 1 hour from now');
        }
        
        // Also save to in-memory backup
        _accessTokenInMemory = _accessToken;
        
        debugPrint('Tokens loaded from secure storage (combined method)');
        return true;
      }
      
      // If combined method fails, try individual token methods as fallback
      debugPrint('Combined token retrieval failed, trying individual methods');
      
      // Since there are no individual getters like getSpotifyAccessToken in SecureStorage,
      // we need to use the _read method directly - but that's protected, so we'll use
      // SharedPreferences as a fallback instead
      return false;
    } catch (e) {
      debugPrint('Error loading tokens from secure storage: $e');
    }
    return false;
  }

  /// Load tokens from SharedPreferences
  Future<bool> _loadTokensFromSharedPreferences() async {
    try {
      debugPrint('Trying to load tokens from SharedPreferences');
      
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('spotify_access_token');
      final refreshToken = prefs.getString('spotify_refresh_token');
      final expiryMillis = prefs.getInt('spotify_token_expiry');
      
      if (accessToken != null && accessToken.isNotEmpty) {
        debugPrint('Found valid access token in SharedPreferences');
        _accessToken = accessToken;
        _refreshToken = refreshToken;
        
        if (expiryMillis != null) {
          _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
          debugPrint('Token expiry from SharedPreferences: $_tokenExpiry');
        } else {
          _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
          debugPrint('No expiry in SharedPreferences, defaulting to 1 hour from now');
        }
        
        // Also save to in-memory backup
        _accessTokenInMemory = accessToken;
        
        return true;
      }
    } catch (e) {
      debugPrint('Error loading tokens from SharedPreferences: $e');
    }
    return false;
  }

  /// Initialize the Spotify API with the current access token
  void _initializeApi() {
    if (_accessToken != null) {
      try {
        debugPrint('Initializing Spotify API with token: ${_accessToken!.substring(0, math.min(5, _accessToken!.length))}...');
        
        // Pass the credentials to the client
        _spotifyClient.setCredentials(
          accessToken: _accessToken!,
          expiry: _tokenExpiry,
          refreshToken: _refreshToken,
        );
        
        debugPrint('Spotify API initialized successfully');
      } catch (e) {
        debugPrint('Error initializing Spotify API: $e');
      }
    } else {
      debugPrint('Cannot initialize API: No access token available');
    }
  }

  /// Fetch the user's profile details
  /// Returns a Map with the user profile data if successful, null otherwise
  Future<Map<String, dynamic>?> _fetchUserDetails() async {
    debugPrint('Fetching user details...');
    try {
      // Make sure we have a valid access token
      if (_accessToken == null) {
        try {
          // Try to load tokens from the storage
          final tokenData = await secure_storage.SecureStorage.getSpotifyTokens();
          if (tokenData != null && tokenData['accessToken'] != null) {
            _accessToken = tokenData['accessToken'] as String?;
            debugPrint('Loaded access token from secure storage');
          } else {
            // If no tokens in secure storage, we don't have auth
            debugPrint('No token found in secure storage');
          }
          
          // If we still don't have a token, check memory backup
          if (_accessToken == null) {
            _accessToken = _accessTokenInMemory;
            debugPrint('Using in-memory access token');
          }
        } catch (e) {
          debugPrint('Error loading access token: $e');
        }
        
        // If still null, we don't have authentication
        if (_accessToken == null) {
          debugPrint('Cannot get user: not authenticated or no access token');
          return null;
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
        final data = jsonDecode(response.body) as Map<String, dynamic>;
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
        
        return data;
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        debugPrint('Access token expired, attempting to refresh...');
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          // Try again with the new token
          return _fetchUserDetails();
        }
        return null;
      } else {
        debugPrint('Error fetching user profile: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
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

  /// Fetch the current user's profile from Spotify API
  /// Returns null if user is not authenticated or if there was an error
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (!_isAuthenticated || _accessToken == null) {
      debugPrint('Cannot get user: not authenticated');
      return null;
    }
    
    try {
      // Make direct API call
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          // Try again with new token
          return getCurrentUser();
        } else {
          _isAuthenticated = false;
          _emitAuthEvent(false);
          return null;
        }
      } else {
        debugPrint('Error getting user profile: ${response.statusCode}');
        return null;
      }
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
  void _setupTokenRefresh() {
    // Cancel any existing refresh timer
    _refreshTimer?.cancel();
    
    // Calculate when to refresh the token (5 minutes before expiry)
    final now = DateTime.now();
    final refreshTime = _tokenExpiry.subtract(const Duration(minutes: 5));
    
    // If the token is already expired or will expire in less than 5 minutes,
    // refresh immediately
    if (refreshTime.isBefore(now)) {
      debugPrint('Token already expired or about to expire, refreshing now...');
      _refreshAccessToken();
      return;
    }
    
    // Calculate the delay until refresh time
    final refreshDelay = refreshTime.difference(now);
    
    // Schedule the refresh
    _refreshTimer = Timer(refreshDelay, () {
      debugPrint('Refresh timer fired, refreshing token...');
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
              debugPrint('Extracted code from URI: ${code.substring(0, math.min(10, code.length))}...');
              
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

  /// Get the dynamic redirect URI based on current port
  String get _dynamicRedirectUri => '$callbackServerUri:$_callbackPort/callback';

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

  /// Check if the user is authenticated
  /// This loads tokens if they exist and verifies them if necessary
  Future<bool> checkAuthentication() async {
    if (_isAuthenticated && _accessToken != null) {
      return true;
    }
    
    // Try to load tokens if we don't have them
    await _loadTokens();
    
    // If we still don't have tokens, we're not authenticated
    if (_accessToken == null) {
      return false;
    }
    
    // We have tokens, but we need to verify they're valid
    // We'll do a simple verification by attempting to get the user profile
    try {
      final userProfile = await _fetchUserDetails();
      _isAuthenticated = userProfile != null;
      return _isAuthenticated;
    } catch (e) {
      debugPrint('Error verifying authentication: $e');
      return false;
    }
  }
}

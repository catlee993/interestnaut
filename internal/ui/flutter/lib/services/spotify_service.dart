import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:ffi/ffi.dart';
import 'package:interestnaut/services/ffi_bridge.dart';
import 'package:interestnaut/services/secure_storage.dart' as secure_storage;
import 'package:interestnaut/services/ffi_init.dart' as ffi_initializer;
import 'package:interestnaut/services/event_bus.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify/spotify.dart' as s;
import 'package:interestnaut/models.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static final SpotifyService _instance = SpotifyService._internal();
  static SpotifyService get instance => _instance;
  factory SpotifyService() => _instance;
  SpotifyService._internal();

  // Constants
  static const String clientId = '3bb48a30577342869a9ffcb176dee7d2';
  static const String clientSecret = 'your_client_secret_here';
  static const String redirectUri = 'http://localhost:8080/callback';
  static const String authEndpoint = 'https://accounts.spotify.com/authorize';
  static const String tokenEndpoint = 'https://accounts.spotify.com/api/token';
  static const String scope = 'user-read-private user-read-email user-library-read user-library-modify user-read-playback-state user-modify-playback-state streaming';

  // State variables
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  String? _accessToken;
  DateTime? _tokenExpiry;
  s.SpotifyApi? _spotifyApi;
  bool _useSdk = false;
  Timer? _refreshTimer;
  dynamic _musicBindings;
  final bool _fetchUserProfile = true; // Whether to fetch user profile after auth
  String? _tempCodeVerifier;
  String? _refreshTokenString;
  String? _accessTokenInMemory;
  String? _refreshTokenInMemory;
  DateTime? _tokenExpiryInMemory;

  // Event streams for player updates
  final StreamController<dynamic> _trackChangeController = StreamController<dynamic>.broadcast();
  final StreamController<bool> _playbackStateController = StreamController<bool>.broadcast();
  final EventBus _eventBus = EventBus();

  // Getters for event streams
  Stream<dynamic> get onTrackChange => _trackChangeController.stream;
  Stream<bool> get onPlaybackStateChange => _playbackStateController.stream;

  // Getter for authentication status
  bool get isAuthenticated => _isAuthenticated;

  /// Initialize the Spotify service
  /// This should be called during app startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Determine if we can use the Spotify SDK (iOS/Android)
    _useSdk = Platform.isAndroid || Platform.isIOS;

    // Initialize secure storage and ensure it works (either natively or with fallback)
    final secureStorageInitialized = await secure_storage.SecureStorage.initialize();
    debugPrint('Secure storage initialized: $secureStorageInitialized');
    
    // Check if we have a valid token in secure storage
    final hasToken = await _loadTokens();
    if (hasToken) {
      _isAuthenticated = true;

      // Initialize Spotify API with existing token
      _initializeApi();

      // Schedule a token refresh if needed
      _scheduleTokenRefresh();

      // Emit auth event to keep the app updated
      _emitAuthEvent(true);

      // Try to get user profile and emit event
      _fetchAndEmitUserProfile();
    }

    // Try initializing the SDK if we're on a supported platform
    if (_useSdk) {
      try {
        final bool connected = await SpotifySdk.connectToSpotifyRemote(
          clientId: clientId,
          redirectUrl: redirectUri,
        );
        debugPrint('Spotify SDK connected: $connected');
      } catch (e) {
        debugPrint('Failed to connect to Spotify SDK: $e');
        // Fall back to web API only
        _useSdk = false;
      }
    }

    // Initialize platform-specific bindings
    await _initializeBindings();

    _isInitialized = true;
  }

  /// Initialize platform-specific bindings
  Future<void> _initializeBindings() async {
    try {
      // Initialize FFI bindings for desktop platforms
      if (_musicBindings == null) {
        _musicBindings = MusicFFI();
      }
      // MusicFFI already initializes itself in its constructor
    } catch (e) {
      debugPrint('Error initializing bindings: $e');
    }
  }

  /// Set up a local HTTP server to listen for the Spotify callback
  Future<String?> _setUpCallbackServer() async {
    try {
      // Create an HTTP server
      final server = await HttpServer.bind('localhost', 8080, shared: true);
      debugPrint('Callback server listening on http://localhost:8080');
      
      // Completer to return the code once received
      final completer = Completer<String?>();
      
      // Listen for requests
      server.listen((HttpRequest request) async {
        debugPrint('Received request: ${request.uri.path}');
        
        // Check if this is the callback request
        if (request.uri.path == '/callback') {
          // Extract the code from the query parameters
          final code = request.uri.queryParameters['code'];
          
          if (code != null && code.isNotEmpty) {
            debugPrint('Received auth code');
            
            // Send a response to close the browser window
            request.response.headers.contentType = ContentType.html;
            request.response.write('''
            <!DOCTYPE html>
            <html>
              <head>
                <title>Authentication Successful</title>
                <style>
                  body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    text-align: center;
                    padding: 40px;
                    background-color: #f5f5f7;
                    color: #1d1d1f;
                  }
                  .container {
                    background-color: white;
                    border-radius: 8px;
                    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                    padding: 20px;
                    max-width: 500px;
                    margin: 0 auto;
                  }
                  h1 {
                    color: #1DB954;
                  }
                </style>
              </head>
              <body>
                <div class="container">
                  <h1>Authentication Successful</h1>
                  <p>You've successfully authenticated with Spotify.</p>
                  <p>You can now close this window and return to the app.</p>
                </div>
                <script>
                  // Close the window automatically after 3 seconds
                  setTimeout(() => window.close(), 3000);
                </script>
              </body>
            </html>
            ''');
            await request.response.close();
            
            // Complete with the code
            if (!completer.isCompleted) {
              completer.complete(code);
            }
            
            // Close server after a short delay
            Timer(const Duration(seconds: 1), () {
              server.close(force: true);
            });
          } else {
            // Handle error - no code in the callback
            request.response.statusCode = HttpStatus.badRequest;
            request.response.headers.contentType = ContentType.html;
            request.response.write('<html><body><h1>Authentication Error</h1><p>No authorization code received from Spotify.</p></body></html>');
            await request.response.close();
            
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          }
        } else {
          // Not a callback path we recognize
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });
      
      // Close the server if no request received after timeout
      Timer(const Duration(minutes: 5), () {
        if (!completer.isCompleted) {
          debugPrint('Timeout waiting for callback - closing server');
          completer.complete(null);
          server.close(force: true);
        }
      });
      
      return completer.future;
    } catch (e) {
      debugPrint('Error setting up callback server: $e');
      return null;
    }
  }

  /// Authenticate with Spotify
  /// Returns true if successful, false otherwise
  Future<bool> authenticate(BuildContext context) async {
    if (_musicBindings == null) {
      _musicBindings = MusicFFI();
    }

    try {
      // Store scaffold messenger to avoid BuildContext across async gaps
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      
      // Set up a local HTTP server to handle the callback
      final codeCompleter = Completer<String?>();
      _setUpCallbackServer().then((code) {
        if (code != null) {
          codeCompleter.complete(code);
        }
      });

      // Now initiate authentication through FFI - this just opens the browser
      final result = await _musicBindings!.initiateSpotifyAuth();
      debugPrint('Spotify auth initiated with FFI: $result');
      
      // Extract and store the code verifier from the response
      if (result is Map && result.containsKey('codeVerifier')) {
        final verifier = result['codeVerifier'] as String;
        debugPrint('Got code verifier from FFI: ${verifier.substring(0, 10)}...');
        
        // Store in memory immediately for backup
        _tempCodeVerifier = verifier;
        
        // Try to store it in secure storage
        try {
          // First try our enhanced SecureStorage
          await secure_storage.SecureStorage.saveSpotifyCodeVerifier(verifier);
          debugPrint('Stored code verifier in enhanced secure storage');
        } catch (e1) {
          debugPrint('Error storing in enhanced secure storage: $e1');
          // Fall back to direct secure storage
          try {
            const secureStorage = FlutterSecureStorage();
            await secureStorage.write(key: 'spotify_code_verifier', value: verifier);
            debugPrint('Stored code verifier securely');
          } catch (e2) {
            // If secure storage fails, that's okay - we'll use the in-memory version
            debugPrint('Failed to store in secure storage, using in-memory backup: $e2');
          }
        }
      } else {
        debugPrint('Warning: No code verifier received from FFI');
      }

      // Show a snackbar to inform the user
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Authenticating with Spotify...'),
          duration: Duration(seconds: 3),
        ),
      );

      // Wait for the auth code to be received by our HTTP server
      final code = await codeCompleter.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          debugPrint('Timeout waiting for auth code');
          return null;
        },
      );

      return await _completeAuthWithCode(code, context, scaffoldMessenger);
    } catch (e) {
      debugPrint('Authentication error: $e');
      if (context.mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Authentication error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
  }
  
  /// Complete the authentication flow with the authorization code
  Future<bool> _completeAuthWithCode(String? code, BuildContext context, ScaffoldMessengerState scaffoldMessenger) async {
    if (code == null) {
      debugPrint('Authentication failed: No code received');
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
    
    // First try to get verifier from secure storage
    String? verifier;
    try {
      // Try our enhanced SecureStorage first
      verifier = await secure_storage.SecureStorage.getSpotifyCodeVerifier();
      if (verifier != null) {
        debugPrint('Retrieved code verifier from enhanced secure storage');
      } else {
        // Fall back to direct secure storage
        const secureStorage = FlutterSecureStorage();
        verifier = await secureStorage.read(key: 'spotify_code_verifier');
        if (verifier != null) {
          debugPrint('Retrieved code verifier from secure storage');
        }
      }
    } catch (e) {
      debugPrint('Error retrieving code verifier from secure storage: $e');
    }
    
    // If not found in secure storage, use memory backup
    if (verifier == null || verifier.isEmpty) {
      verifier = _tempCodeVerifier;
      debugPrint('Using in-memory code verifier backup: ${verifier != null ? 'found' : 'not found'}');
    }
    
    if (verifier == null || verifier.isEmpty) {
      debugPrint('Error: No code verifier found for token exchange');
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Authentication failed: Missing code verifier'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    // Exchange code for token
    debugPrint('Exchanging code for token using verifier');
    final tokenData = await _exchangeCodeForToken(code, verifier);

    // Save tokens to secure storage
    if (tokenData != null) {
      await _saveTokens(
        tokenData['access_token'],
        tokenData['refresh_token'] ?? '',
        DateTime.now().add(Duration(seconds: tokenData['expires_in'] ?? 3600)),
      );
      
      // Initialize Spotify API wrapper with the new token
      _initializeApi();
      
      // Set instance as authenticated
      _isAuthenticated = true;
      
      // Fetch user details
      _fetchUserDetails();
      
      // Emit auth event
      _emitAuthEvent(true);
    
      return true;
    } else {
      debugPrint('Authentication failed: No token received');
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
  }
  
  /// Exchange the authorization code for an access token using PKCE
  Future<Map<String, dynamic>?> _exchangeCodeForToken(String code, String codeVerifier) async {
    try {
      debugPrint('Exchanging code for token with PKCE...');
      // Exchange the authorization code for tokens using PKCE
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': codeVerifier,
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store tokens
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;
        final expiresIn = data['expires_in'] as int;
        
        // Calculate expiry time
        final expiry = DateTime.now().add(Duration(seconds: expiresIn - 60)); // Subtract 60s for buffer
        
        // Always store in memory first
        _accessTokenInMemory = accessToken;
        _refreshTokenInMemory = refreshToken;
        _tokenExpiryInMemory = expiry;
        
        // Set instance variables immediately to ensure they're available even if storage fails
        _isAuthenticated = true;
        _accessToken = accessToken;
        _tokenExpiry = expiry;
        
        // Try to save to secure storage but don't let failures prevent authentication
        try {
          await _saveTokens(accessToken, refreshToken, expiry);
        } catch (e) {
          debugPrint('Warning: Failed to save tokens to secure storage, but continuing with in-memory tokens: $e');
          // We already have them in memory, so continue with authentication flow
        }
        
        // Initialize API
        _initializeApi();
        
        // Schedule token refresh
        _scheduleTokenRefresh();
        
        // Emit auth event
        _emitAuthEvent(true);
        
        // Fetch user profile
        _fetchAndEmitUserProfile();
        
        return data;
      } else {
        debugPrint('Token exchange failed with status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error exchanging code for token: $e');
      return null;
    }
  }

  /// Fetch user profile and emit event
  Future<void> _fetchAndEmitUserProfile() async {
    await _fetchUserDetails();
  }

  /// Initialize the Spotify API with the current access token
  void _initializeApi() {
    if (_accessToken != null) {
      debugPrint('Initializing Spotify API with access token');
      try {
        // For Spotify API, we don't need to provide a client secret when using authorization code with PKCE
        final credentials = s.SpotifyApiCredentials(
          clientId, 
          '', // Client secret is not needed for PKCE flow
          accessToken: _accessToken,
          // Don't pass scopes here as they're already encoded in the token
        );
        
        _spotifyApi = s.SpotifyApi(credentials);
        debugPrint('Spotify API initialized successfully');
      } catch (e) {
        debugPrint('Error initializing Spotify API: $e');
      }
    } else {
      debugPrint('Warning: Cannot initialize Spotify API - no access token available');
    }
  }

  /// Schedule a token refresh before the current token expires
  void _scheduleTokenRefresh() {
    if (_refreshTimer?.isActive ?? false) {
      _refreshTimer?.cancel();
    }
    
    if (_tokenExpiry != null) {
      final DateTime now = DateTime.now();
      final Duration timeUntilExpiry = _tokenExpiry!.difference(now);
      
      // Schedule refresh 5 minutes before expiry
      final Duration refreshTime = Duration(
        milliseconds: max(0, timeUntilExpiry.inMilliseconds - (5 * 60 * 1000)),
      );
      
      _refreshTimer = Timer(refreshTime, () => _refreshToken());
    }
  }

  /// Emit an authentication event
  void _emitAuthEvent(bool isAuthenticated) {
    _eventBus.fire(AuthStatusEvent(isAuthenticated));
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
            _accessToken = tokenData['accessToken'];
            debugPrint('Loaded access token from enhanced storage');
          } else {
            // Fall back to direct secure storage
            const storage = FlutterSecureStorage();
            _accessToken = await storage.read(key: 'spotify_access_token');
            debugPrint('Loaded access token from direct secure storage');
          }
          
          // If we still don't have a token, check memory backup
          if (_accessToken == null && _accessTokenInMemory != null) {
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
            
        _eventBus.fire(UserProfileEvent(
          data['id'] as String? ?? '',
          data['display_name'] as String? ?? '',
          imageUrl,
        ));
        
        // Also try to fetch the user's playlists since we know the token is working
        _fetchUserPlaylists();
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        debugPrint('Access token expired, attempting to refresh...');
        await _refreshToken();
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

  /// Save access token, refresh token, and expiry to secure storage
  Future<void> _saveTokens(String accessToken, String refreshToken, DateTime expiry) async {
    debugPrint('Saving tokens to secure storage...');
    
    // Always store tokens in memory as a fallback
    _accessTokenInMemory = accessToken;
    if (refreshToken.isNotEmpty) {
      _refreshTokenInMemory = refreshToken;
    }
    _tokenExpiryInMemory = expiry;
    
    // Try to save in secure storage
    try {
      // First try our enhanced secure storage
      await secure_storage.SecureStorage.saveSpotifyTokens(
        accessToken: accessToken,
        refreshToken: refreshToken.isNotEmpty ? refreshToken : null,
        expiryMillis: expiry.millisecondsSinceEpoch,
      );
      debugPrint('Tokens saved successfully in enhanced secure storage');
    } catch (e1) {
      debugPrint('Error saving to enhanced secure storage: $e1');
      // Fall back to direct secure storage
      try {
        const storage = FlutterSecureStorage();
        await storage.write(key: 'spotify_access_token', value: accessToken);
        if (refreshToken.isNotEmpty) {
          await storage.write(key: 'spotify_refresh_token', value: refreshToken);
        }
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
    
    // Set instance variables for immediate use
    _accessToken = accessToken;
    _tokenExpiry = expiry;
    _isAuthenticated = true;
  }

  /// Load tokens from secure storage or memory backup
  Future<bool> _loadTokens() async {
    try {
      // First try our enhanced secure storage
      final tokenData = await secure_storage.SecureStorage.getSpotifyTokens();
      if (tokenData != null && 
          tokenData['accessToken'] != null && 
          tokenData['expiryMillis'] != null) {
        _accessToken = tokenData['accessToken'];
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(tokenData['expiryMillis']);
        debugPrint('Tokens loaded from enhanced secure storage');
        return true;
      }
      
      // Fall back to direct secure storage
      const storage = FlutterSecureStorage();
      final accessToken = await storage.read(key: 'spotify_access_token');
      final expiryString = await storage.read(key: 'spotify_token_expiry');
      
      if (accessToken != null && expiryString != null) {
        _accessToken = accessToken;
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryString));
        debugPrint('Tokens loaded from direct secure storage');
        return true;
      }
    } catch (e) {
      debugPrint('Error loading tokens from secure storage: $e');
    }
    
    // Fall back to memory if all else fails
    if (_accessTokenInMemory != null && _tokenExpiryInMemory != null) {
      _accessToken = _accessTokenInMemory;
      _tokenExpiry = _tokenExpiryInMemory;
      debugPrint('Tokens loaded from memory backup');
      return true;
    }
    
    return false;
  }

  /// Refresh the access token using the refresh token
  Future<void> _refreshToken() async {
    try {
      // Try to get refresh token from secure storage
      String? refreshToken;
      try {
        const storage = FlutterSecureStorage();
        refreshToken = await storage.read(key: 'spotify_refresh_token');
      } catch (e) {
        debugPrint('Error retrieving refresh token from secure storage: $e');
      }
      
      if (refreshToken == null) {
        _isAuthenticated = false;
        _emitAuthEvent(false);
        return;
      }
      
      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        
        // Save the new tokens
        final newRefreshToken = data['refresh_token'];
        await _saveTokens(_accessToken!, newRefreshToken ?? refreshToken, _tokenExpiry!);
        
        // Reinitialize API with new token
        _initializeApi();
        
        // Schedule next refresh
        _scheduleTokenRefresh();
      } else {
        // If refresh fails, user needs to re-authenticate
        _isAuthenticated = false;
        _emitAuthEvent(false);
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      _isAuthenticated = false;
      _emitAuthEvent(false);
    }
  }

  /// Check if we have a valid access token
  Future<bool> hasValidAccessToken() async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'spotify_access_token');
      final expiryString = await storage.read(key: 'spotify_token_expiry');
      
      if (token == null || expiryString == null) {
        return false;
      }
      
      final expiry = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryString));
      final now = DateTime.now();
      
      if (now.isAfter(expiry)) {
        // Token has expired, try to refresh it
        _accessToken = token;
        await _refreshToken();
        return _isAuthenticated;
      }
      
      // Token is still valid
      _accessToken = token;
      _tokenExpiry = expiry;
      _isAuthenticated = true;
      _initializeApi();
      _scheduleTokenRefresh();
      return true;
    } catch (e) {
      debugPrint('Error checking token validity: $e');
      return false;
    }
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
      _tokenExpiry = null;
      _isAuthenticated = false;
      
      // Disconnect SDK if using it
      if (_useSdk) {
        try {
          await SpotifySdk.disconnect();
        } catch (e) {
          debugPrint('Error disconnecting Spotify SDK: $e');
        }
      }
      
      // Cancel any scheduled refreshes
      _refreshTimer?.cancel();
      
      // Emit event
      _emitAuthEvent(false);
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  /// Fetch the current user's profile from Spotify API
  /// Returns null if user is not authenticated or if there was an error
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (!_isAuthenticated || _accessToken == null) {
      debugPrint('Cannot get user: not authenticated or no access token');
      return null;
    }
    
    try {
      final headers = {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };
      
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Failed to get user profile: ${response.statusCode} - ${response.body}');
        return {'error': 'Failed to get user profile: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return {'error': 'Error getting user profile: $e'};
    }
  }

  /// Get recommendations based on seed tracks, artists, or genres
  Future<List<Map<String, dynamic>>> getRecommendations({
    List<String> seedTracks = const [],
    List<String> seedArtists = const [],
    List<String> seedGenres = const [],
    int limit = 10,
  }) async {
    if (!_isAuthenticated || _accessToken == null) {
      debugPrint('Cannot get recommendations: not authenticated');
      return [];
    }
    
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
      final uri = Uri.https('api.spotify.com', '/v1/recommendations', params);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['tracks']);
      } else {
        debugPrint('Failed to get recommendations: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting recommendations: $e');
      return [];
    }
  }
  
  /// Get the current playback state from Spotify
  Future<Map<String, dynamic>?> getPlaybackState() async {
    if (!_isAuthenticated || _accessToken == null) {
      debugPrint('Cannot get playback state: not authenticated');
      return null;
    }
    
    try {
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 204) {
        // 204 means no active device
        return {'error': 'No active device found'};
      } else {
        debugPrint('Failed to get playback state: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting playback state: $e');
      return null;
    }
  }
  
  /// Play a track on Spotify
  Future<bool> playTrack(String trackUri, {String? deviceId}) async {
    if (!_isAuthenticated || _accessToken == null) {
      debugPrint('Cannot play track: not authenticated');
      return false;
    }
    
    try {
      // Prepare the request body
      final Map<String, dynamic> body = {
        'uris': [trackUri],
      };
      
      // Add device ID if provided
      String endpoint = 'https://api.spotify.com/v1/me/player/play';
      if (deviceId != null && deviceId.isNotEmpty) {
        endpoint += '?device_id=$deviceId';
      }
      
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      
      if (response.statusCode == 204) {
        debugPrint('Track playback started successfully');
        // Emit a track change event
        final trackId = trackUri.split(':').last;
        _eventBus.fire(TrackChangeEvent(MediaItem(
          id: trackId,
          title: 'Now Playing',
          mediaType: 'music',
          overview: 'Spotify Track',
          posterPath: '',
          uri: trackUri,
          previewUrl: '',
        )));
        return true;
      } else {
        debugPrint('Failed to play track: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error playing track: $e');
      return false;
    }
  }
  
  /// Pause playback on Spotify
  Future<bool> pausePlayback({String? deviceId}) async {
    if (!_isAuthenticated || _accessToken == null) {
      debugPrint('Cannot pause playback: not authenticated');
      return false;
    }
    
    try {
      // Add device ID if provided
      String endpoint = 'https://api.spotify.com/v1/me/player/pause';
      if (deviceId != null && deviceId.isNotEmpty) {
        endpoint += '?device_id=$deviceId';
      }
      
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 204) {
        debugPrint('Playback paused successfully');
        return true;
      } else {
        debugPrint('Failed to pause playback: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error pausing playback: $e');
      return false;
    }
  }

  /// Attempt to initialize the Spotify SDK (iOS/Android only)
  /// and handle authentication
  Future<bool> _initializeSpotifySdk() async {
    bool connected = false;
    try {
      connected = await SpotifySdk.connectToSpotifyRemote(
        clientId: clientId,
        redirectUrl: redirectUri,
      );
      
      if (connected) {
        final token = await SpotifySdk.getAccessToken(
          clientId: clientId,
          redirectUrl: redirectUri,
          scope: scope,
        );
        
        if (token != null && token.isNotEmpty) {
          _accessToken = token;
          _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
          _isAuthenticated = true;
          
          // Save the token to secure storage
          await _saveTokens(
            token,
            '', // SDK doesn't provide refresh token
            _tokenExpiry!,
          );
          
          // Initialize the API client
          _initializeApi();
          
          // Fetch user details
          _fetchUserDetails();
          
          // Emit auth event
          _emitAuthEvent(true);
          
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error initializing Spotify SDK: $e');
    }
    return connected;
  }
}

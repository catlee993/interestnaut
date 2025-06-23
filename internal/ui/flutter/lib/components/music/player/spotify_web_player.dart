import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import '../../../models.dart';
import '../spotify_service.dart';
import './spotify_player_view.dart'; // Import to use SpotifyEvents and SpotifyPlaybackState

// Global reference to the active player state for reconnection
SpotifyWebPlayerState? _activeWebPlayerState;

//  A method to force reconnection of the Spotify Web Player from anywhere in the app
//  Returns true if reconnection was triggered, false if no player is available
bool forceSpotifyPlayerReconnection() {
  if (_activeWebPlayerState != null) {
    _activeWebPlayerState!.forcePlayerReconnection();
    return true;
  }
  return false;
}

// Global function to play a track using the active web player
bool globalPlayTrack(String trackUri) {
  if (_activeWebPlayerState != null) {
    _activeWebPlayerState!.playTrack(trackUri);
    return true;
  }
  return false;
}

// Global function to resume playback using the active web player
bool globalResumePlayback() {
  if (_activeWebPlayerState != null) {
    _activeWebPlayerState!.resumePlayback();
    return true;
  }
  return false;
}

// Global function to pause playback using the active web player
bool globalPausePlayback() {
  if (_activeWebPlayerState != null) {
    _activeWebPlayerState!.pausePlayback();
    return true;
  }
  return false;
}

/// A WebView-based Spotify player that uses the Spotify Web Playback SDK
/// to create a device ID for playback and provide event-driven updates
class SpotifyWebPlayer extends StatefulWidget {
  final SpotifyService spotifyService;
  final bool visible;
  final Function(String)? onError;
  
  const SpotifyWebPlayer({
    Key? key,
    required this.spotifyService,
    this.visible = false,
    this.onError,
  }) : super(key: key);

  @override
  State<SpotifyWebPlayer> createState() => SpotifyWebPlayerState();
}

class SpotifyWebPlayerState extends State<SpotifyWebPlayer> {
  // WebView controller
  WebViewController? _controller;
  
  // Player state
  bool _isReady = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  String _deviceId = '';
  Track? _currentTrack;
  String _errorMessage = '';
  
  // Reconnection state
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  
  // Debug log
  final List<String> _debugLog = [];
  
  // Keep track of player state for recovery
  DateTime? _lastSuccessfulConnection;
  
  @override
  void initState() {
    super.initState();
    
    // Store reference to active player state for global access
    _activeWebPlayerState = this;
    
    // Initialize WebView
    _initializeWebView();
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _activeWebPlayerState = null;
    _reconnectTimer?.cancel();
    _controller = null;
    super.dispose();
  }
  
  // Add to debug log with timestamp
  void _addToDebugLog(String message) {
    final timestamp = DateTime.now().toString().split('.').first;
    final logEntry = '[$timestamp] $message';
    
    if (_debugLog.length >= 100) {
      _debugLog.removeAt(0);
    }
    
    _debugLog.add(logEntry);
    
    // Only print important messages to reduce noise
    if (message.contains('Error') || 
        message.contains('Device ready') || 
        message.contains('Player ready') ||
        message.contains('Failed') ||
        message.contains('Successfully connected') ||
        message.contains('Sending initial token')) {
    debugPrint('SpotifyWebPlayer: $logEntry');
    }
  }
  
  // Initialize the WebView controller
  Future<void> _initializeWebView() async {
    _addToDebugLog('Initializing WebView');
    
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              debugPrint('WebView loading progress: $progress%');
            },
            onPageStarted: (String url) {
              _addToDebugLog('WebView page started loading: $url');
            },
            onPageFinished: (String url) {
              _addToDebugLog('WebView page finished loading: $url');
              // Send initial token to the player after HTML loads
              _sendInitialToken();
            },
            onWebResourceError: (WebResourceError error) {
              _handleWebViewError(error);
            },
          ),
        )
        ..addJavaScriptChannel(
          'SpotifyEvents',
          onMessageReceived: _handleJavaScriptMessageWrapper,
        );
      
      // Load the HTML content
      final htmlContent = await _loadHtmlContent();
      await controller.loadHtmlString(htmlContent);
      
      if (!_isDisposed) {
        setState(() {
          _controller = controller;
        });
      }
    } catch (e) {
      _addToDebugLog('Error initializing WebView: $e');
      _handleError('Failed to initialize WebView: $e');
    }
  }
  
  // Load the HTML content from the assets
  Future<String> _loadHtmlContent() async {
    try {
      final htmlContent = await rootBundle.loadString('assets/web/spotify_player.html');
      return htmlContent;
    } catch (e) {
      _addToDebugLog('Error loading HTML content: $e');
      throw Exception('Failed to load Spotify player HTML: $e');
    }
  }
  
  // Wrapper for handling JavaScript messages
  void _handleJavaScriptMessageWrapper(JavaScriptMessage message) {
    if (_isDisposed) {
      return;
    }
    
    try {
      // First check if the message looks like JSON (starts with { or [)
      final messageText = message.message.trim();
      if (!messageText.startsWith('{') && !messageText.startsWith('[')) {
        // This is a plain text message, just log it
        _addToDebugLog('JS (plain): $messageText');
        return;
      }
      
      final dynamic data = jsonDecode(message.message);
      _processMessageData(data);
    } catch (e) {
      _addToDebugLog('Error parsing message: $e - Message: ${message.message}');
      // Don't call _handleError for parsing errors, as they might just be debug messages
    }
  }
  
  // Process message data from JavaScript
  void _processMessageData(dynamic data) {
    final String type = data['type'] ?? 'unknown';
    
    switch (type) {
      case 'log':
        final message = data['message'] ?? 'No message';
        _addToDebugLog('JS: $message');
        break;
        
      case 'deviceReady':
        _handleDeviceReady(data);
        break;
        
      case 'playerStateChanged':
        _handlePlayerStateChanged(data);
        break;
        
      case 'error':
        final message = data['message'] ?? 'Unknown error';
        _handleError(message);
        break;
        
      case 'deviceDisconnected':
        _addToDebugLog('Player not ready: Device disconnected');
        break;
        
      default:
        _addToDebugLog('Unknown message type: $type');
    }
  }
  
  // Handle device ready message
  void _handleDeviceReady(dynamic data) {
    String? deviceId;
    
    // Handle different message formats
    if (data.containsKey('deviceId')) {
      deviceId = data['deviceId'] as String?;
    } else if (data.containsKey('device_id')) {
      deviceId = data['device_id'] as String?;
    }
    
    if (deviceId == null || deviceId.isEmpty) {
      _addToDebugLog('No device ID found in message: ${data.toString()}');
      _handleError('Failed to get device ID from Spotify');
      return;
    }
    
    _addToDebugLog('Device ready: $deviceId');
    
    setState(() {
      _deviceId = deviceId!;
      _isReady = true;
      _errorMessage = '';
    });
    
    // Mark successful connection
    _lastSuccessfulConnection = DateTime.now();
    
    // Set the device ID in the Spotify service
    widget.spotifyService.setActiveDeviceId(deviceId);
    
    // Emit device ready event
    SpotifyEvents.emitDeviceReady(deviceId);
  }
  
  // Handle player state changed message
  void _handlePlayerStateChanged(dynamic data) {
    try {
      final bool isPlaying = !(data['paused'] ?? true);
      final bool isBuffering = data['loading'] ?? false;
      
      // Extract track data if available
      Track? track;
      if (data.containsKey('track')) {
        final trackData = data['track'];
        if (trackData != null) {
          final List<Artist> artists = [];
          if (trackData['artists'] != null) {
            for (final artist in trackData['artists']) {
              artists.add(Artist(name: artist['name'] ?? 'Unknown Artist'));
            }
          }
          
          final List<ImageData> albumImages = [];
          if (trackData['album'] != null && trackData['album']['images'] != null) {
            for (final image in trackData['album']['images']) {
              albumImages.add(ImageData(
                url: image['url'] ?? '',
                width: image['width'] ?? 0,
                height: image['height'] ?? 0,
              ));
            }
          }
          
          track = Track(
            id: trackData['id'] ?? '',
            name: trackData['name'] ?? 'Unknown Track',
            artists: artists,
            album: Album(
              name: trackData['album']?['name'] ?? 'Unknown Album',
              images: albumImages,
            ),
            previewUrl: trackData['preview_url'] ?? '',
            uri: trackData['uri'] ?? '',
          );
        }
      }
      
      setState(() {
        _isPlaying = isPlaying;
        _isBuffering = isBuffering;
        if (track != null) {
          _currentTrack = track;
        }
      });
      
      // Create playback state object using the SpotifyPlaybackState from spotify_player_view.dart
      final playbackState = SpotifyPlaybackState(
        isPlaying: isPlaying,
        progressMs: data['position'] as int?,
        item: track,
      );
      
      // Emit track change event
      if (track != null) {
        SpotifyEvents.emitTrackChange(track);
      }
      
      // Emit playback state change event
      SpotifyEvents.emitPlaybackStateChange(playbackState);
      
      _addToDebugLog('Player state updated: playing=$isPlaying, buffering=$isBuffering, track=${track?.name ?? "None"}');
    } catch (e) {
      _addToDebugLog('Error handling player state change: $e');
    }
  }
  
  // Handle errors from the player
  void _handleError(String message) {
    _addToDebugLog('Error: $message');
    
    setState(() {
      _errorMessage = message;
    });
    
    // Notify parent if callback is provided
    widget.onError?.call(message);
    
    // Emit error event
    SpotifyEvents.emitError(message);
    
    // Only schedule reconnect for critical initialization errors
    if (message.contains('Failed to get device ID') || 
        message.contains('Failed to initialize WebView')) {
      _scheduleReconnect();
    }
  }
  
  // Handle WebView errors
  void _handleWebViewError(WebResourceError error) {
    final errorMessage = 'WebView error: ${error.description}';
    _addToDebugLog(errorMessage);
    
    if (error.errorCode == -2 || error.errorCode == -1) {
      // Network error, try to reconnect
      _scheduleReconnect();
    }
    
    _handleError(errorMessage);
  }
  
  // Schedule a reconnection attempt
  void _scheduleReconnect() {
    // Cancel any existing reconnect timer
    _reconnectTimer?.cancel();
    
    // Don't reconnect if already disposed or if we recently connected successfully
    if (_isDisposed || 
        (_lastSuccessfulConnection != null && 
         DateTime.now().difference(_lastSuccessfulConnection!).inMinutes < 5)) {
      return;
    }
    
    // Schedule a new reconnection attempt with longer delay
    _reconnectTimer = Timer(const Duration(seconds: 30), () {
      if (!_isDisposed) {
        _addToDebugLog('Attempting to reconnect player...');
        _refreshTokenAndReconnect();
      }
    });
  }
  
  // Refresh the token and reconnect the player
  Future<void> _refreshTokenAndReconnect() async {
    if (_isDisposed) return;
    
    _addToDebugLog('Refreshing token and reconnecting player');
    
    try {
      // Get a fresh token from the Spotify service
      final token = await widget.spotifyService.getAccessToken();
      
      if (token == null) {
        _addToDebugLog('Failed to get token for reconnection');
        _handleError('Failed to get authentication token');
        return;
      }
      
      // Update the player with the new token
      _updatePlayerToken(token);
      
      _addToDebugLog('Token refreshed, reconnecting player');
    } catch (e) {
      _addToDebugLog('Error refreshing token: $e');
      _handleError('Failed to refresh authentication token');
    }
  }
  
  // Update the player with a new token
  void _updatePlayerToken(String token) {
    final message = jsonEncode({
      'type': 'token',
      'token': token,
    });
    
    _controller?.runJavaScript('window.postMessage($message, "*");');
  }
  
  // Send initial token to the player when page loads
  Future<void> _sendInitialToken() async {
    try {
      final token = await widget.spotifyService.getAccessToken();
      if (token != null) {
        _addToDebugLog('Sending initial token to player');
        _updatePlayerToken(token);
      } else {
        _addToDebugLog('No token available to send to player');
        // Try to authenticate
        await widget.spotifyService.checkAuthentication();
      }
    } catch (e) {
      _addToDebugLog('Error sending initial token: $e');
    }
  }
  
  // Force player reconnection (can be called from outside)
  void forcePlayerReconnection() {
    if (_isDisposed) {
      return;
    }
    
    _addToDebugLog('Forcing player reconnection');
    
    // Check if we've reconnected recently to avoid reconnection loops
    final now = DateTime.now();
    if (_lastSuccessfulConnection != null && 
        now.difference(_lastSuccessfulConnection!).inSeconds < 5) {
      _addToDebugLog('Skipping reconnection - last successful connection was too recent');
      return;
    }
    
    _reconnectPlayer();
  }
  
  // Reconnect the player
  void _reconnectPlayer() {
    // Reset state
    setState(() {
      _isReady = false;
      _deviceId = '';
    });
    
    // Reinitialize WebView
    _initializeWebView();
  }
  
  // Check if the player needs recovery and recover if needed
  bool checkAndRecoverPlayerIfNeeded() {
    // Only recover if we've never connected successfully OR if it's been a very long time
    final needsRecovery = _lastSuccessfulConnection == null || 
        DateTime.now().difference(_lastSuccessfulConnection!).inHours > 1;
    
    if (needsRecovery) {
      _addToDebugLog('Player needs recovery, reconnecting...');
      _refreshTokenAndReconnect();
      return true;
    }
    
    return false;
  }
  
  // Method to play a track
  void playTrack(String trackUri) async {
    // Don't check for recovery on every play - only if player is not ready
    if (!_isReady || _deviceId.isEmpty) {
      _addToDebugLog('Player not ready, cannot play track');
      return;
    }
    
    // Execute the JavaScript to play the track
    _addToDebugLog('Playing track: $trackUri');
    
    final message = jsonEncode({
      'type': 'playTrack',
      'uri': trackUri,
    });
    
    _controller?.runJavaScript('window.postMessage($message, "*");');
  }
  
  // Method to pause playback at current position
  void pausePlayback() async {
    // Only check if player is ready
    if (!_isReady || _deviceId.isEmpty) {
      _addToDebugLog('Player not ready, cannot pause playback');
      return;
    }
    
    // Execute the JavaScript to pause playback
    _addToDebugLog('Pausing playback');
    
    final message = jsonEncode({
      'type': 'pause',
    });
    
    _controller?.runJavaScript('window.postMessage($message, "*");');
  }
  
  // Method to resume playback at current position
  void resumePlayback() async {
    // Only check if player is ready
    if (!_isReady || _deviceId.isEmpty) {
      _addToDebugLog('Player not ready, cannot resume playback');
      return;
    }
    
    // Execute the JavaScript to resume playback
    _addToDebugLog('Resuming playback');
    
    final message = jsonEncode({
      'type': 'resume',
    });
    
    _controller?.runJavaScript('window.postMessage($message, "*");');
  }
  
  // Check if the player is ready to play tracks
  bool isPlayerReady() {
    return _isReady && _deviceId.isNotEmpty;
  }
  
  // Get the current device ID
  String getDeviceId() {
    return _deviceId;
  }
  
  @override
  Widget build(BuildContext context) {
    // If not visible, render a minimal container
    if (!widget.visible) {
      return Container(
        width: 1,
        height: 1,
        color: Colors.transparent,
        child: _controller != null
          ? WebViewWidget(controller: _controller!)
          : const SizedBox.shrink(),
      );
    }
    
    // If visible, render the full player UI
    return Stack(
      children: [
        // The WebView widget
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: _controller != null
              ? WebViewWidget(controller: _controller!)
              : const Center(child: CircularProgressIndicator()),
          ),
        ),
        
        // Player UI overlay
        if (_isReady && _currentTrack != null) _buildPlayerUI(context),
        
        // Loading indicator
        if (_isBuffering || !_isReady)
          Positioned.fill(
            child: Container(
              color: Colors.black.withAlpha(200),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        
        // Error message
        if (_errorMessage.isNotEmpty)
          Positioned.fill(
            child: Container(
              color: Colors.black.withAlpha(200),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.withAlpha(230), size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error',
                      style: TextStyle(
                        color: Colors.white.withAlpha(230),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: forcePlayerReconnection,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildPlayerUI(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(230),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(77),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Track info
            Row(
              children: [
                // Album art
                if (_currentTrack?.album.images.isNotEmpty ?? false)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      _currentTrack!.album.images.first.url,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey[900],
                          child: const Icon(Icons.music_note, color: Colors.white54),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[900],
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                const SizedBox(width: 12),
                
                // Track details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTrack?.name ?? 'Unknown Track',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentTrack?.artists.map((a) => a.name).join(', ') ?? 'Unknown Artist',
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Play/Pause button
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: _isPlaying ? pausePlayback : resumePlayback,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

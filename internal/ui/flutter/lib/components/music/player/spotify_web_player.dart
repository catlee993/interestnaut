import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:flutter/services.dart';
import '../../../models.dart';
import '../spotify_service.dart';
import 'spotify_player_view.dart'; // Import to access SpotifyEvents

// Global reference to the most recent SpotifyWebPlayerState instance
// This allows forcing reconnection from outside the component
SpotifyWebPlayerState? _activeWebPlayerState;

/// A method to force reconnection of the Spotify Web Player from anywhere in the app
/// Returns true if reconnection was triggered, false if no player is available
bool forceSpotifyPlayerReconnection() {
  if (_activeWebPlayerState != null) {
    debugPrint('Forcing global Spotify player reconnection');
    _activeWebPlayerState!.forcePlayerReconnection();
    return true;
  }
  debugPrint('Cannot force player reconnection: No active player instance');
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
  WebViewController? _controller;
  WebviewController? _windowsController;
  String? _deviceId;
  Track? _currentTrack;
  bool _isReady = false;
  Timer? _reconnectTimer;
  String _htmlContent = '';
  String? _pendingTrackUri;
  
  // Debug log buffer
  final List<String> _debugLogs = [];
  final int _maxLogEntries = 100;
  
  @override
  void initState() {
    super.initState();
    _activeWebPlayerState = this;
    
    // Load the HTML content that will be used for the WebView
    _loadHtmlFromAssets().then((_) {
      if (Platform.isWindows) {
        _initializeWindowsWebView();
      } else {
        _initializeStandardWebView();
      }
    });
  }
  
  // Load the HTML content from the assets directory
  Future<void> _loadHtmlFromAssets() async {
    try {
      // Load from the correct assets/web directory path
      const String htmlPath = 'assets/web/spotify_player.html';
      _htmlContent = await rootBundle.loadString(htmlPath);
    } catch(e) {
      debugPrint('Error loading Spotify player HTML: $e');
    }
  }
  
  // Initialize the standard WebView for mobile and macOS/Linux
  void _initializeStandardWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
          onPageFinished: (_) => _onWebViewLoaded(),
        ),
      );
    
    if (_htmlContent.isNotEmpty) {
      _controller!.loadHtmlString(_htmlContent);
    }
  }
  
  // Initialize the Windows-specific WebView
  Future<void> _initializeWindowsWebView() async {
    try {
      _windowsController = WebviewController();
      await _windowsController!.initialize();
      
      // Configure WebView settings
      await _windowsController!.setBackgroundColor(Colors.transparent);
      
      // Set up a JavaScript callback for communicating with the WebView
      await _windowsController!.addScriptToExecuteOnDocumentCreated('''
        window.chrome.webview.addEventListener('message', event => {
          if (event.data) {
            window.chrome.webview.postMessage(JSON.stringify(event.data));
          }
        });
        
        // Create our own SpotifyEvents channel for compatibility with the mobile implementation
        window.SpotifyEvents = {
          postMessage: function(message) {
            window.chrome.webview.postMessage(message);
          }
        };
      ''');
      
      // Set up message handler
      _windowsController!.webMessage.listen((event) {
        try {
          // Use simple debugging to understand the event structure
          final eventString = event.toString();
          debugPrint('WebView message received: $eventString');
          
          // For Windows WebView, we need to parse the event as a message
          // The message is likely just a String, so handle it directly
          _handleWindowsMessage(event);
        } catch (e) {
          debugPrint('Error handling WebView message: $e');
        }
      });
      
      // Load HTML content
      if (_htmlContent.isNotEmpty) {
        debugPrint('Loading HTML content into Windows WebView');
        await _windowsController!.loadStringContent(_htmlContent);
      }
      
      // We need to manually trigger the onWebViewLoaded after a short delay
      // since we don't have a direct page loaded event
      Future.delayed(const Duration(milliseconds: 500), () {
        _onWebViewLoaded();
      });
    } catch (e) {
      debugPrint('Error initializing Windows WebView: $e');
    }
  }
  
  void _onWebViewLoaded() {
    if (_controller == null && _windowsController == null) return;
    
    // Set up JavaScript channel for communication with the WebView
    if (_controller != null) {
      _controller!.addJavaScriptChannel(
        'SpotifyEvents',
        onMessageReceived: _handleJavaScriptMessageWrapper,
      );
    }
    
    // Initialize the player with the access token
    _initializePlayer();
  }
  
  void _initializePlayer() {
    widget.spotifyService.getAccessToken().then((token) {
      if (token != null) {
        final message = json.encode({
          'type': 'token',
          'token': token,
        });
        if (_controller != null) {
          _controller!.runJavaScript("window.postMessage($message, '*');");
        } else if (_windowsController != null) {
          _executeWindowsJavaScript("window.postMessage($message, '*');");
        }
        debugPrint('Sent Spotify token to web player');
      } else {
        debugPrint('Cannot initialize Spotify Web Player: No access token available');
      }
    });
  }
  
  // Helper method to execute JavaScript in Windows WebView
  Future<void> _executeWindowsJavaScript(String script) async {
    try {
      debugPrint('Executing JS in Windows WebView: ${script.substring(0, min(50, script.length))}${script.length > 50 ? "..." : ""}');
      await _windowsController?.executeScript(script);
    } catch (e) {
      debugPrint('Error executing JavaScript in Windows WebView: $e');
    }
  }
  
  void _handleJavaScriptMessageWrapper(JavaScriptMessage message) {
    try {
      final dynamic data = jsonDecode(message.message);
      _handleJavaScriptMessage({'message': message.message});
    } catch (e) {
      debugPrint('Error processing JavaScript message: $e');
      // Still attempt to handle the raw message in case it's useful
      if (message.message.contains('error') && message.message.contains('message')) {
        // Try to extract error message if it looks like it contains one
        _handleError('Error in JavaScript: ${message.message}');
      }
    }
  }

  void _handleJavaScriptMessage(Map<String, dynamic> data) {
    try {
      // If the message is a JSON string, try to parse it
      if (data.containsKey('message') && data['message'] is String) {
        try {
          final dynamic parsedData = jsonDecode(data['message']);
          if (parsedData is Map<String, dynamic>) {
            // Process the parsed data
            _processMessageData(parsedData);
            return;
          }
        } catch (e) {
          // Not valid JSON or not a map, continue with original handling
          debugPrint('Message is not a valid JSON object: ${e.toString().substring(0, min(50, e.toString().length))}');
        }
      }
      
      // If we got here, either there was no 'message' field or it wasn't valid JSON
      // Try to process the data directly
      _processMessageData(data);
    } catch (e) {
      debugPrint('Error in _handleJavaScriptMessage: $e');
      _handleError('Error processing message: $e');
    }
  }
  
  void _processMessageData(Map<String, dynamic> data) {
    // Handle different message types
    if (data.containsKey('type')) {
      final messageType = data['type'];
      
      if (messageType == 'deviceReady') {
        _handleDeviceReady(data['deviceId'] as String? ?? '');
      } else if (messageType == 'playerStateChanged') {
        if (data.containsKey('state')) {
          _handlePlayerStateChanged(data['state'] as Map<String, dynamic>? ?? {});
        } else {
          _handlePlayerStateChanged(data);
        }
      } else if (messageType == 'error') {
        _handleError(data['message'] as String? ?? 'Unknown error');
      } else if (messageType == 'deviceDisconnected') {
        _handleDeviceDisconnected();
      }
    }
  }
  
  void _handleError(String errorMessage) {
    debugPrint('SpotifyWebPlayer Error: $errorMessage');
    // Add to debug logs
    _addToDebugLog('ERROR: $errorMessage');
    
    // You might want to notify listeners about this error
    widget.onError?.call(errorMessage);
  }
  
  void _handleDeviceDisconnected() {
    debugPrint('Spotify device disconnected');
    
    // Set states to reflect disconnection
    setState(() {
      _isReady = false;
      _deviceId = null;
    });
    
    // Clear the active device ID
    widget.spotifyService.clearActiveDeviceId();
    
    // Try to recover automatically
    forcePlayerReconnection();
  }
  
  void _handleDeviceReady(String deviceId) {
    if (_deviceId == deviceId) {
      // Skip if we've already processed this device ID
      debugPrint('Skipping duplicate device ready event for ID: $deviceId');
      return;
    }
    
    debugPrint('Spotify device ready: $deviceId');
    setState(() {
      _isReady = true;
      _deviceId = deviceId;
    });
    
    // Notify the SpotifyService about the device ID
    widget.spotifyService.setActiveDeviceId(deviceId);
    
    // Emit global event for device ready - this triggers player ready as well
    SpotifyEvents.emitDeviceReady(deviceId);
    
    // If there's a pending track, play it now
    if (_pendingTrackUri != null) {
      playTrack(_pendingTrackUri!);
      _pendingTrackUri = null;
    }
  }
  
  void _handlePlayerStateChanged(Map<String, dynamic> data) {
    // Update the current track and playback state
    final track = data['track'] as Map<String, dynamic>?;
    final isPaused = data['paused'] as bool? ?? true;
    final position = data['position'] as int? ?? 0;
    final duration = data['duration'] as int? ?? 30000;
    
    if (track != null) {
      final artists = track['artists'] as List<dynamic>? ?? [];
      final artistsList = artists.map((a) => 
        Artist(name: a['name'] as String? ?? '')
      ).toList();
      
      final album = track['album'] as Map<String, dynamic>? ?? {};
      final albumImages = album['images'] as List<dynamic>? ?? [];
      
      final albumObj = Album(
        name: album['name'] as String? ?? '',
        images: albumImages.map((img) => 
          ImageData(
            url: img['url'] as String? ?? '',
            height: img['height'] as int? ?? 0,
            width: img['width'] as int? ?? 0
          )
        ).toList()
      );
      
      final trackObj = Track(
        id: track['id'] as String? ?? '',
        name: track['name'] as String? ?? '',
        artists: artistsList,
        album: albumObj,
        previewUrl: track['preview_url'] as String? ?? '',
        uri: track['uri'] as String? ?? ''
      );
      
      setState(() {
        _currentTrack = trackObj;
      });
      
      // Create playback state object
      final playbackState = SpotifyPlaybackState(
        isPlaying: !isPaused,
        progressMs: position,
        item: trackObj
      );
      
      // Emit track change event
      SpotifyEvents.emitTrackChange(trackObj);
      debugPrint('Emitted track change event for track: ${trackObj.name}');
      
      // Emit playback state change event
      SpotifyEvents.emitPlaybackStateChange(playbackState);
      debugPrint('Emitted playback state change event: playing=${!isPaused}');
    }
  }
  
  // Method to play a track with a given Spotify URI
  void playTrack(String uri) async {
    // First check if the player needs recovery
    if (checkAndRecoverPlayerIfNeeded()) {
      debugPrint('Player was in bad state - queueing track $uri for after recovery');
      _pendingTrackUri = uri;
      return;
    }
    
    if (!_isReady) {
      debugPrint('Cannot play track: WebPlayer not ready yet');
      _pendingTrackUri = uri;
      return;
    }
    
    // Check if this is the current track that's paused - if so, just resume
    if (_currentTrack != null && _currentTrack!.uri == uri) {
      resumePlayback();
      return;
    }
    
    debugPrint('Playing track via web player: $uri');
    
    try {
      final message = jsonEncode({
        'type': 'playTrack',
        'uri': uri,
      });
      
      if (_controller != null) {
        _controller!.runJavaScript("window.postMessage($message, '*');");
      } else if (_windowsController != null) {
        _executeWindowsJavaScript("window.postMessage($message, '*');");
      }
      
      // Immediately emit a playback state change event to provide feedback before the 
      // actual event comes back from the player. This improves responsiveness.
      if (_currentTrack != null) {
        SpotifyEvents.emitPlaybackStateChange(SpotifyPlaybackState(
          isPlaying: true,
          progressMs: 0,
          item: _currentTrack,
        ));
      }
    } catch (e) {
      debugPrint('Error playing track: $e');
      // If JavaScript errors occur, try to recover the player
      forcePlayerReconnection();
      _pendingTrackUri = uri; // Queue the track for after recovery
    }
  }
  
  // Method to resume playback at current position
  void resumePlayback() async {
    // First check if the player needs recovery
    if (checkAndRecoverPlayerIfNeeded()) {
      debugPrint('Player was in bad state - cannot resume playback');
      return;
    }
    
    debugPrint('Resuming playback via web player');
    
    try {
      final message = jsonEncode({
        'type': 'resume',
      });
      
      if (_controller != null) {
        _controller!.runJavaScript("window.postMessage($message, '*');");
      } else if (_windowsController != null) {
        _executeWindowsJavaScript("window.postMessage($message, '*');");
      }
      
      // Immediately emit a playback state change event to provide feedback
      if (_currentTrack != null) {
        SpotifyEvents.emitPlaybackStateChange(SpotifyPlaybackState(
          isPlaying: true,
          progressMs: 0, // We don't know the exact progress here
          item: _currentTrack,
        ));
      }
    } catch (e) {
      debugPrint('Error resuming playback: $e');
      // If JavaScript errors occur, try to recover the player
      forcePlayerReconnection();
    }
  }
  
  // Method to pause playback
  void pausePlayback() async {
    // First check if the player needs recovery
    if (checkAndRecoverPlayerIfNeeded()) {
      debugPrint('Player was in bad state - cannot pause playback');
      return;
    }
    
    debugPrint('Pausing playback via web player');
    
    try {
      final message = jsonEncode({
        'type': 'pause',
      });
      
      if (_controller != null) {
        _controller!.runJavaScript("window.postMessage($message, '*');");
      } else if (_windowsController != null) {
        _executeWindowsJavaScript("window.postMessage($message, '*');");
      }
      
      // Immediately emit a playback state change event to provide feedback before the 
      // actual event comes back from the player. This improves responsiveness.
      if (_currentTrack != null) {
        SpotifyEvents.emitPlaybackStateChange(SpotifyPlaybackState(
          isPlaying: false,
          progressMs: 0, // We don't know the exact progress here
          item: _currentTrack,
        ));
      }
    } catch (e) {
      debugPrint('Error pausing playback: $e');
      // If JavaScript errors occur, try to recover the player
      forcePlayerReconnection();
    }
  }
  
  // Check if the player is ready to play tracks
  bool isPlayerReady() {
    return _isReady && _deviceId != null;
  }
  
  // Force a complete player reconnection - useful when the player gets into a bad state
  void forcePlayerReconnection() {
    debugPrint('Forcing complete player reconnection');
    
    // First set state to indicate reconnection
    setState(() {
      _isReady = false;
      _deviceId = null;
    });
    
    // Clear any existing device ID to prevent stale references
    widget.spotifyService.clearActiveDeviceId();
    debugPrint('Cleared active Spotify device ID');
    
    // Cancel any pending reconnection timers
    _reconnectTimer?.cancel();
    
    // Create a completely new WebViewController
    if (Platform.isWindows) {
      _initializeWindowsWebView();
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (error) {
              debugPrint('WebView error: ${error.description}');
            },
            onPageFinished: (_) => _onWebViewLoaded(),
          ),
        );
      
      // Reload HTML content which will reinitialize everything
      _loadHtmlFromAssets().then((_) {
        _controller!.loadHtmlString(_htmlContent);
      });
    }
  }
  
  // Check if the player is in a bad state and recover if needed
  bool checkAndRecoverPlayerIfNeeded() {
    // Check if we have critical issues
    bool needsRecovery = false;
    
    // Check for stale device ID
    final activeDeviceId = widget.spotifyService.getActiveDeviceId();
    if (_isReady && (_deviceId != activeDeviceId || _deviceId == null || _deviceId!.isEmpty)) {
      debugPrint('Device ID mismatch detected: player=$_deviceId, service=$activeDeviceId');
      needsRecovery = true;
    }
    
    // If we need recovery, force reconnection
    if (needsRecovery) {
      debugPrint('Player in bad state - forcing reconnection');
      forcePlayerReconnection();
      return true;
    }
    
    return false;
  }
  
  // Custom handler for Windows WebView messages
  void _handleWindowsMessage(dynamic message) {
    try {
      // The message is a string that could be JSON
      String messageStr = message.toString();
      
      // Try to parse as JSON
      try {
        final data = json.decode(messageStr);
        _handleJavaScriptMessage(data);
      } catch (e) {
        // Not valid JSON, might be a debug log message
        if (messageStr.startsWith('DEBUG:')) {
          // Handle debug log message
          final logMessage = messageStr.substring(6).trim();
          debugPrint('SpotifyWebPlayer Debug: $logMessage');
          
          // You could store these logs for later viewing
          _addToDebugLog(logMessage);
        } else {
          debugPrint('Raw WebView message: $messageStr');
        }
      }
    } catch (e) {
      debugPrint('Error handling Windows message: $e');
    }
  }

  void _handlePlayerProgressUpdate(Map<String, dynamic> progressData) {
    try {
      if (progressData.containsKey('position') && progressData.containsKey('duration')) {
        final position = progressData['position'] as int;
        // We're tracking duration but not using it currently
        // final duration = progressData['duration'] as int;
        
        // Update track progress (only if significant change to reduce rebuilds)
        if (position % 1000 < 50) {  // Update roughly every second
          setState(() {
            // Update state if needed
          });
        }
      }
    } catch (e) {
      debugPrint('Error handling player progress update: $e');
    }
  }

  // Add a message to the debug log
  void _addToDebugLog(String message) {
    _debugLogs.add('${DateTime.now().toIso8601String()}: $message');
    if (_debugLogs.length > _maxLogEntries) {
      _debugLogs.removeAt(0); // Remove oldest log when buffer is full
    }
    
    // Optionally notify listeners if you want to display these logs in the UI
    // setState(() {});
  }
  
  // Method to get debug logs (could be called from outside)
  List<String> getDebugLogs() {
    return List.from(_debugLogs);
  }
  
  // Method to clear debug logs
  void clearDebugLogs() {
    _debugLogs.clear();
    // setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // The WebView is kept at a minimal size when not visible
    // This keeps it loaded but not taking up screen space
    if (Platform.isWindows && _windowsController != null) {
      return SizedBox(
        width: widget.visible ? null : 1, 
        height: widget.visible ? null : 1,
        child: Webview(
          _windowsController!,
          permissionRequested: _onPermissionRequested,
        ),
      );
    } else {
      return SizedBox(
        width: widget.visible ? null : 1, 
        height: widget.visible ? null : 1,
        child: _controller != null ? WebViewWidget(controller: _controller!) : const SizedBox(),
      );
    }
  }
}

// Create a class to wrap Windows WebView messages to match JavaScriptMessage interface
class _WindowsJavaScriptMessage implements JavaScriptMessage {
  @override
  final String message;

  _WindowsJavaScriptMessage(this.message);
}

// Handle WebView permissions (required for Windows WebView)
Future<WebviewPermissionDecision> _onPermissionRequested(
      String url, WebviewPermissionKind kind, bool isUserInitiated) async {
    debugPrint('WebView permission requested: $kind for $url');
    // Automatically allow all permissions
    return WebviewPermissionDecision.allow;
  }

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import '../../../models.dart';
import '../spotify_service.dart';
import 'spotify_player_view.dart'; // Import to access SpotifyEvents

/// A WebView-based Spotify player that uses the Spotify Web Playback SDK
/// to create a device ID for playback and provide event-driven updates
class SpotifyWebPlayer extends StatefulWidget {
  final SpotifyService spotifyService;
  final bool visible;
  
  const SpotifyWebPlayer({
    Key? key,
    required this.spotifyService,
    this.visible = false,
  }) : super(key: key);

  @override
  State<SpotifyWebPlayer> createState() => SpotifyWebPlayerState();
}

class SpotifyWebPlayerState extends State<SpotifyWebPlayer> {
  late WebViewController _controller;
  String? _deviceId;
  Track? _currentTrack;
  final bool _isPlaying = false;
  bool _isReady = false;
  Timer? _reconnectTimer;
  String _htmlContent = '';
  final int _retryCount = 0;
  
  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _loadHtmlFromAssets();
  }
  
  @override
  void dispose() {
    _reconnectTimer?.cancel();
    super.dispose();
  }
  
  // Load the HTML content from the assets directory
  Future<void> _loadHtmlFromAssets() async {
    try {
      // Load from the correct assets/web directory path
      const String htmlPath = 'assets/web/spotify_player.html';
      _htmlContent = await rootBundle.loadString(htmlPath);
      _initWebView();
    } catch(e) {
      debugPrint('Error loading Spotify player HTML: $e');
    }
  }
  
  void _initWebView() {
    // Configure the WebView controller with only essential settings
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
          onPageFinished: (_) => _onWebViewLoaded(),
        ),
      );
    
    // Add JavaScript channel with try-catch for platform compatibility
    try {
      _controller.addJavaScriptChannel(
        'SpotifyEvents',
        onMessageReceived: _handleJavaScriptMessage,
      );
    } catch (e) {
      debugPrint('Error adding JavaScript channel: $e');
      // Channel might already exist, which is fine
    }
    
    // Try to set background color but handle platform limitations
    try {
      _controller.setBackgroundColor(Colors.transparent);
    } catch (e) {
      debugPrint('Could not set WebView background color: $e');
      // This is ok - we'll continue without setting the background color
    }
    
    // Load the HTML directly without modifications
    _controller.loadHtmlString(_htmlContent);
  }
  
  void _onWebViewLoaded() {
    // Simplified initialization that focuses only on sending the token
    widget.spotifyService.getAccessToken().then((token) {
      if (token != null) {
        // Send token to the player in the standard way
        final message = jsonEncode({
          'type': 'token',
          'token': token,
        });
        _controller.runJavaScript("window.postMessage($message, '*');");
        debugPrint('Sent Spotify token to web player');
      } else {
        debugPrint('Cannot initialize Spotify Web Player: No access token available');
      }
    }).catchError((error) {
      debugPrint('Error getting Spotify access token: $error');
    });
  }
  
  void _handleJavaScriptMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String?;
      
      debugPrint('Spotify Web Player message: $type');
      
      switch (type) {
        case 'deviceReady':
          _handleDeviceReady(data);
          break;
        case 'playerStateChanged':
          _handlePlayerStateChanged(data);
          break;
        case 'deviceDisconnected':
          _handleDeviceDisconnected();
          break;
        case 'error':
          debugPrint('Spotify Web Player error: ${data['message']}');
          // Notify other components about the error through events
          SpotifyEvents.emitError(data['message'] as String? ?? 'Unknown error');
          break;
      }
    } catch (e) {
      debugPrint('Error handling JavaScript message: $e');
    }
  }
  
  void _handleDeviceReady(Map<String, dynamic> data) {
    final deviceId = data['deviceId'] as String?;
    if (deviceId != null) {
      setState(() {
        _deviceId = deviceId;
        _isReady = true;
      });
      
      debugPrint('Spotify Web Player ready with device ID: $deviceId');
      
      // Notify the SpotifyService about the device ID
      widget.spotifyService.setActiveDeviceId(deviceId);
      
      // Emit an event for other components to know we're ready
      SpotifyEvents.emitDeviceReady(deviceId);
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
      
      // Emit playback state change event
      SpotifyEvents.emitPlaybackStateChange(playbackState);
    }
  }
  
  void _handleDeviceDisconnected() {
    setState(() {
      _isReady = false;
    });
    
    debugPrint('Spotify Web Player disconnected');
    
    // Try to reconnect after a delay
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _onWebViewLoaded);
  }
  
  // Method to play a track
  void playTrack(String uri) {
    if (!_isReady || _deviceId == null) {
      debugPrint('Cannot play track: Player not ready or no device ID');
      return;
    }
    
    debugPrint('Playing track via web player: $uri');
    
    // Simple approach - just send the message to play
    final message = jsonEncode({
      'type': 'playTrack',
      'uri': uri,
    });
    _controller.runJavaScript("window.postMessage($message, '*');");
  }
  
  // Method to pause playback
  void pausePlayback() {
    if (_isReady) {
      final message = jsonEncode({
        'type': 'pause',
      });
      _controller.runJavaScript("window.postMessage($message, '*');");
    }
  }
  
  // Check if the player is ready to play tracks
  bool isPlayerReady() {
    return _isReady && _deviceId != null;
  }
  
  @override
  Widget build(BuildContext context) {
    // The WebView is kept at a minimal size when not visible
    // This keeps it loaded but not taking up screen space
    return SizedBox(
      width: widget.visible ? null : 1, 
      height: widget.visible ? null : 1,
      child: WebViewWidget(controller: _controller),
    );
  }
}

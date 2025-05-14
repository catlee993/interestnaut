import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models.dart';
import './spotify_service.dart';
import '../../services/event_bus.dart';

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
  final WebViewController _controller = WebViewController();
  String? _deviceId;
  MediaItem? _currentTrack;
  bool _isPlaying = false;
  bool _isReady = false;
  final _eventBus = EventBus();
  Timer? _reconnectTimer;
  String _htmlContent = '';
  
  @override
  void initState() {
    super.initState();
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
      final htmlContent = await rootBundle.loadString('assets/web/spotify_player.html');
      setState(() {
        _htmlContent = htmlContent;
      });
      _initWebView();
    } catch (e) {
      debugPrint('Error loading Spotify player HTML: $e');
      // Instead of a complex fallback, just show a simple error message
      setState(() {
        _htmlContent = '''
        <!DOCTYPE html>
        <html>
        <body style="background-color: #1DB954; color: white; font-family: Arial; text-align: center; padding: 20px;">
          <h2>Error Loading Spotify Player</h2>
          <p>Could not load the Spotify player component.</p>
        </body>
        </html>
        ''';
      });
      _initWebView();
      
      // Show error in UI context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load Spotify player component'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }
  
  void _initWebView() {
    // Configure the WebView controller
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'SpotifyEvents',
        onMessageReceived: _handleJavaScriptMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
          onPageFinished: (_) => _onWebViewLoaded(),
        ),
      );
    
    // Load the HTML content directly
    _controller.loadHtmlString(_htmlContent);
  }
  
  void _onWebViewLoaded() {
    // When the WebView is loaded, initialize the player with the access token
    widget.spotifyService.getAccessToken().then((token) {
      if (token != null) {
        final message = jsonEncode({
          'type': 'token',
          'token': token,
        });
        _controller.runJavaScript("window.postMessage($message, '*');");
      } else {
        debugPrint('Cannot initialize Spotify Web Player: No access token available');
      }
    });
  }
  
  void _handleJavaScriptMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message);
      final type = data['type'] as String?;
      
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
      _eventBus.fire({
        'type': 'spotify_device_ready',
        'deviceId': deviceId,
      });
    }
  }
  
  void _handlePlayerStateChanged(Map<String, dynamic> data) {
    // Update the current track and playback state
    final track = data['track'] as Map<String, dynamic>?;
    final isPaused = data['paused'] as bool? ?? true;
    final position = data['position'] as int? ?? 0;
    final duration = data['duration'] as int? ?? 30000;
    
    if (track != null) {
      final artists = track['artists'] as List<dynamic>?;
      final artistNames = (artists ?? [])
          .map((a) => a['name'] as String?)
          .where((n) => n != null)
          .join(', ');
      
      setState(() {
        _currentTrack = MediaItem(
          id: track['id'] ?? '',
          title: track['name'] ?? 'Unknown Track',
          overview: artistNames.isNotEmpty ? artistNames : 'Unknown Artist',
          posterPath: track['album']?['images']?[0]?['url'] ?? '',
          uri: track['uri'] ?? '',
          mediaType: 'music',
        );
        _isPlaying = !isPaused;
      });
      
      // Fire an event for the player view to update
      _eventBus.fire({
        'type': 'spotify_playback_state',
        'is_playing': !isPaused,
        'position': position,
        'duration': duration,
        'track': {
          'id': track['id'] ?? '',
          'name': track['name'] ?? 'Unknown Track',
          'artist': artistNames.isNotEmpty ? artistNames : 'Unknown Artist',
          'albumArtUrl': track['album']?['images']?[0]?['url'] ?? '',
          'uri': track['uri'] ?? '',
        },
      });
    } else {
      setState(() {
        _isPlaying = !isPaused;
      });
      
      // Fire a playback state event without track info
      _eventBus.fire({
        'type': 'spotify_playback_state',
        'is_playing': !isPaused,
      });
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
    
    // Notify the app
    _eventBus.fire({
      'type': 'spotify_device_disconnected',
    });
  }
  
  // Method to play a track
  void playTrack(String uri) {
    if (_isReady && _deviceId != null) {
      final message = jsonEncode({
        'type': 'playTrack',
        'uri': uri,
      });
      _controller.runJavaScript("window.postMessage($message, '*');");
    } else {
      debugPrint('Cannot play track: Spotify Web Player not ready');
    }
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

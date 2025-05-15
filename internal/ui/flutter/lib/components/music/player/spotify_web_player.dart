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
  final WebViewController _controller = WebViewController();
  String? _deviceId;
  Track? _currentTrack;
  final bool _isPlaying = false;
  bool _isReady = false;
  Timer? _reconnectTimer;
  String _htmlContent = '';
  int _retryCount = 0;
  
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
    // Configure the WebView controller with only essential settings
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
      )
      ..setBackgroundColor(Colors.transparent);
    
    // Add a simple audio context initialization script to help with autoplay
    const audioEnableScript = """
    <script>
    // Simple script to help with audio permissions on various platforms
    document.addEventListener('DOMContentLoaded', () => {
      try {
        // Create a silent audio context to enable audio
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        console.log('Audio context created successfully');
      } catch(e) {
        console.error('Failed to create audio context:', e);
      }
    });
    </script>
    """;
    
    // Add the script inline to the HTML before the closing head tag
    _htmlContent = _htmlContent.replaceFirst('</head>', '$audioEnableScript</head>');
    
    // Load the HTML with audio enabling script
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
    // Simple retry mechanism to handle not-ready state
    if (!_isReady) {
      debugPrint('Attempting to play track but player not ready. Retrying in 2 seconds...');
      // Add a limited retry (max 3 times) to avoid infinite loops
      if (_retryCount < 3) {
        _retryCount++;
        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            playTrack(uri);
          }
        });
      } else {
        _retryCount = 0;
        debugPrint('Failed to play after 3 retry attempts');
      }
      return;
    }
    
    // Reset retry counter when we successfully reach ready state
    _retryCount = 0;
    
    if (_deviceId != null) {
      debugPrint('Playing track via web player: $uri');
      
      // Simple approach - just send the message to play
      final message = jsonEncode({
        'type': 'playTrack',
        'uri': uri,
      });
      _controller.runJavaScript("window.postMessage($message, '*');");
    } else {
      debugPrint('Cannot play track: No device ID available');
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

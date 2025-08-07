import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme.dart';
import 'standard_close_button.dart';

/// YouTube Player Dialog that handles platform-specific issues
class YouTubePlayerDialog extends StatefulWidget {
  final String videoId;

  const YouTubePlayerDialog({required this.videoId, Key? key}) : super(key: key);

  @override
  State<YouTubePlayerDialog> createState() => _YouTubePlayerDialogState();
}

class _YouTubePlayerDialogState extends State<YouTubePlayerDialog> {
  // Use WebViewController for macOS, YoutubePlayerController for others
  late final dynamic _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (Platform.isMacOS) {
      _initializeMacOSPlayer();
    } else {
      _initializeStandardPlayer();
    }
  }

  void _initializeMacOSPlayer() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadHtmlString(_getYouTubeHtml());
  }

  void _initializeStandardPlayer() {
    final youtubeController = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        showVideoAnnotations: false,
        enableCaption: true,
        enableJavaScript: true,
        loop: false,
        strictRelatedVideos: true,
        interfaceLanguage: 'en',
      ),
    );
    
    youtubeController.loadVideoById(videoId: widget.videoId);
    _controller = youtubeController;
    
    // Remove loading state after a delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  String _getYouTubeHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 0; background: #000; }
    iframe { width: 100%; height: 100vh; border: none; }
  </style>
</head>
<body>
  <iframe 
    src="https://www.youtube-nocookie.com/embed/${widget.videoId}?autoplay=1&modestbranding=1&rel=0" 
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
    allowfullscreen>
  </iframe>
</body>
</html>
''';
  }


  @override
  void dispose() {
    if (_controller is YoutubePlayerController) {
      _controller.close();
    } else if (_controller is WebViewController) {
      _controller.loadHtmlString('<html><body></body></html>');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: AppTheme.positiveColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'YouTube Player',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  StandardCloseButton(
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            // YouTube Player with proper aspect ratio
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      if (Platform.isMacOS)
                        WebViewWidget(controller: _controller as WebViewController)
                      else
                        YoutubePlayer(controller: _controller as YoutubePlayerController),
                      
                      if (_isLoading)
                        Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.positiveColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
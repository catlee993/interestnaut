import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
    _initializeWebViewPlayer();
  }

  void _initializeWebViewPlayer() {
    // Try advanced WebView configuration to bypass YouTube restrictions
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Use mobile user agent - sometimes less restricted
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1')
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            debugPrint('YouTube page finished loading: $url');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              // Only check for errors if we're on the actual YouTube page
              if (url.contains('youtube.com/embed/')) {
                debugPrint('Detected YouTube embed page, checking for errors...');
              }
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = 'Connection error';
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('Navigation request: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'InterestnautChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('JavaScript message: ${message.message}');
          if (mounted) {
            final data = message.message;
            if (data.contains('error_153') || data.contains('ERROR_153')) {
              setState(() {
                _hasError = true;
                _errorMessage = 'YouTube API Error (153)';
                _isLoading = false;
              });
            } else if (data.contains('age_restricted') || data.contains('sign_in_required')) {
              setState(() {
                _hasError = true;
                _errorMessage = 'Age-restricted content';
                _isLoading = false;
              });
            } else if (data.contains('embedding_disabled')) {
              setState(() {
                _hasError = true;
                _errorMessage = 'Video embedding disabled';
                _isLoading = false;
              });
            }
          }
        },
      );

    // Try multiple YouTube embedding strategies
    _tryMultipleEmbedMethods();
    
    // Disable aggressive error checking since video is actually working
    // Only keep the final URL-based check
    
    // Only show error if we're completely sure video failed (more lenient)
    Timer(const Duration(seconds: 12), () {
      if (mounted && !_hasError) {
        debugPrint('Final check - only show error if completely failed...');
        _controller.currentUrl().then((url) {
          debugPrint('Current WebView URL after 12 seconds: $url');
          // Only trigger error if we're definitely not on a YouTube page AND no audio/content loaded
          if ((url == null || url == 'about:blank') && !url.toString().contains('youtube')) {
            debugPrint('Video completely failed to load - showing error');
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = 'YouTube API Error (153)';
                _isLoading = false;
              });
            }
          } else {
            debugPrint('Video appears to be working - not showing error');
          }
        });
      }
    });
  }

  void _tryMultipleEmbedMethods() {
    // Method 1: Try youtube-nocookie.com (sometimes works better)
    final noCookieUrl = 'https://www.youtube-nocookie.com/embed/${widget.videoId}?autoplay=1&playsinline=1&modestbranding=1&rel=0&controls=1&origin=https://flutter.dev';
    debugPrint('Trying no-cookie embed: $noCookieUrl');
    
    _controller.loadRequest(Uri.parse(noCookieUrl));
    
    // Fallback to regular embed after 3 seconds if no-cookie fails
    Timer(const Duration(seconds: 3), () {
      _controller.currentUrl().then((currentUrl) {
        debugPrint('Current URL after 3s: $currentUrl');
        if (currentUrl == null || currentUrl == 'about:blank') {
          debugPrint('No-cookie failed, trying regular embed...');
          final regularUrl = 'https://www.youtube.com/embed/${widget.videoId}?autoplay=1&playsinline=1&modestbranding=1&rel=0&controls=1';
          _controller.loadRequest(Uri.parse(regularUrl));
        }
      });
    });
    
    // Final fallback: Try custom HTML with iframe after 6 seconds
    Timer(const Duration(seconds: 6), () {
      _controller.currentUrl().then((currentUrl) {
        if (currentUrl == null || currentUrl == 'about:blank') {
          debugPrint('Regular embed failed, trying custom HTML...');
          _controller.loadHtmlString(_getAdvancedYouTubeHtml());
        }
      });
    });
  }

  String _getAdvancedYouTubeHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="referrer" content="no-referrer">
  <style>
    body { 
      margin: 0; 
      padding: 0; 
      background: #000; 
    }
    .video-container {
      position: relative;
      width: 100%;
      height: 100vh;
      overflow: hidden;
    }
    iframe { 
      position: absolute;
      top: 0;
      left: 0;
      width: 100%; 
      height: 100%; 
      border: none; 
    }
    .fallback {
      display: none;
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: white;
      font-family: Arial, sans-serif;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="video-container">
    <iframe 
      id="youtube-iframe"
      src="https://www.youtube-nocookie.com/embed/${widget.videoId}?autoplay=1&modestbranding=1&rel=0&controls=1&playsinline=1&enablejsapi=0"
      allow="autoplay; encrypted-media; picture-in-picture"
      allowfullscreen
      referrerpolicy="no-referrer"
      sandbox="allow-same-origin allow-scripts allow-popups allow-forms">
    </iframe>
    <div class="fallback" id="fallback">
      <h3>Video Unavailable</h3>
      <p>This video cannot be played here.</p>
    </div>
  </div>
  
  <script>
    // Monitor iframe load
    var iframe = document.getElementById('youtube-iframe');
    var fallback = document.getElementById('fallback');
    
    setTimeout(function() {
      try {
        // Check if iframe loaded successfully
        if (iframe.contentDocument === null) {
          console.log('Iframe blocked - showing fallback');
          window.InterestnautChannel?.postMessage('embedding_disabled');
        }
      } catch (e) {
        // Cross-origin restriction is actually good - means iframe is working
        console.log('Iframe loaded successfully (cross-origin restriction is normal)');
      }
    }, 2000);
    
    iframe.onerror = function() {
      console.log('Iframe error occurred');
      fallback.style.display = 'block';
      iframe.style.display = 'none';
      window.InterestnautChannel?.postMessage('error_153');
    };
  </script>
</body>
</html>
''';
  }

  void _checkForVideoErrors() {
    // Check page content for error indicators
    _controller.runJavaScript('''
      (function() {
        var bodyText = document.body.innerText || document.body.textContent || '';
        var pageHTML = document.documentElement.innerHTML || '';
        
        console.log('Checking page content for errors...');
        console.log('Body text preview:', bodyText.substring(0, 200));
        
        // Check for Error 153
        if (bodyText.includes('Error 153') || 
            bodyText.includes('Video player configuration error') ||
            bodyText.includes('configuration error') ||
            pageHTML.includes('error=153')) {
          console.log('Found Error 153');
          window.InterestnautChannel.postMessage('error_153');
          return 'error_153';
        }
        
        // Check for age restrictions
        if (bodyText.includes('age-restricted') || 
            bodyText.includes('Sign in to confirm') ||
            bodyText.includes('This video is age-restricted') ||
            bodyText.includes('sign in to confirm your age')) {
          console.log('Found age restriction');
          window.InterestnautChannel.postMessage('age_restricted');
          return 'age_restricted';
        }
        
        // Check for embedding disabled
        if (bodyText.includes('Video unavailable') || 
            bodyText.includes('Watch this video on YouTube') ||
            bodyText.includes('not made this video available') ||
            bodyText.includes('uploader has not made this video available')) {
          console.log('Found embedding disabled');
          window.InterestnautChannel.postMessage('embedding_disabled');
          return 'embedding_disabled';
        }
        
        console.log('No errors found');
        return 'no_errors';
      })();
    ''').then((result) {
      debugPrint('JavaScript error check result: $result');
    }).catchError((error) {
      debugPrint('JavaScript error check failed: $error');
    });
  }

  String _getCustomYouTubeHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { 
      margin: 0; 
      padding: 0; 
      background: #000; 
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
    }
    iframe { 
      width: 100%; 
      height: 100vh; 
      border: none; 
    }
  </style>
</head>
<body>
  <iframe 
    id="youtubePlayer"
    src="https://www.youtube.com/embed/${widget.videoId}?autoplay=1&playsinline=1&modestbranding=1&rel=0&showinfo=0&controls=1" 
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
    allowfullscreen>
  </iframe>
  
  <script>
    // Monitor for YouTube errors
    window.addEventListener('message', function(event) {
      if (event.data && typeof event.data === 'string') {
        if (event.data.includes('error') || event.data.includes('153')) {
          window.InterestnautChannel?.postMessage('error_153');
        }
      }
    });
    
    // Check iframe content periodically
    setInterval(function() {
      try {
        const iframe = document.getElementById('youtubePlayer');
        if (iframe && iframe.contentWindow) {
          // Try to detect if iframe shows error content
          const iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
          if (iframeDoc && iframeDoc.body) {
            const text = iframeDoc.body.innerText || iframeDoc.body.textContent;
            if (text.includes('Error 153') || text.includes('configuration error')) {
              window.InterestnautChannel?.postMessage('error_153');
            }
          }
        }
      } catch (e) {
        // Cross-origin restrictions - this is expected
      }
    }, 2000);
  </script>
</body>
</html>
''';
  }



  Widget _buildCustomErrorScreen() {
    IconData errorIcon;
    String errorTitle;
    String errorDescription;
    Color primaryColor = const Color(0xFF7b68ee); // Interestnaut purple

    // Customize error screen based on error type
    switch (_errorMessage) {
      case 'YouTube API Error (153)':
        errorIcon = Icons.video_settings;
        errorTitle = 'YouTube API Issue';
        errorDescription = 'YouTube recently changed their systems, affecting video playback in many apps.';
        break;
      case 'Age-restricted content':
        errorIcon = Icons.verified_user;
        errorTitle = 'Age-Restricted Video';
        errorDescription = 'This video requires age verification and can only be watched on YouTube.';
        break;
      case 'Video embedding disabled':
        errorIcon = Icons.block;
        errorTitle = 'Embedding Disabled';
        errorDescription = 'The video owner has disabled playback outside of YouTube.';
        break;
      default:
        errorIcon = Icons.error_outline;
        errorTitle = 'Playback Issue';
        errorDescription = 'This video cannot be played in the app right now.';
    }

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Interestnaut branding
          Container(
            height: 48,
            width: 48,
            margin: const EdgeInsets.only(bottom: 24),
            child: Image.asset(
              'assets/images/logo/interestnaut-icon.png',
              fit: BoxFit.contain,
            ),
          ),
          
          // Error icon
          Icon(
            errorIcon,
            color: primaryColor,
            size: 56,
          ),
          
          const SizedBox(height: 24),
          
          // Error title
          Text(
            errorTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Error description
          Text(
            errorDescription,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'Inter',
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // Action buttons
          Column(
            children: [
              // Primary action: Watch on YouTube
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = 'https://www.youtube.com/watch?v=${widget.videoId}';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Watch on YouTube'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Secondary action: Close dialog
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up WebView
    if (_controller is WebViewController) {
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
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
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
                      WebViewWidget(controller: _controller as WebViewController),
                      
                      if (_isLoading)
                        Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.positiveColor,
                            ),
                          ),
                        ),
                      
                      if (_hasError)
                        Container(
                          color: Colors.black,
                          child: Center(
                            child: _buildCustomErrorScreen(),
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
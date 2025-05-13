import 'package:flutter/material.dart';
import '../../services/spotify_service.dart';
import '../../theme.dart';

/// A widget that displays a WebView for Spotify authentication
///
/// This widget is used to authenticate the user with Spotify
/// within the app, instead of using an external browser.
class SpotifyAuthView extends StatefulWidget {
  final Function(bool success) onAuthResult;

  const SpotifyAuthView({
    super.key,
    required this.onAuthResult,
  });

  @override
  State<SpotifyAuthView> createState() => _SpotifyAuthViewState();
}

class _SpotifyAuthViewState extends State<SpotifyAuthView> {
  final bool _isLoading = true;
  SpotifyService get _spotifyService => SpotifyService();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        color: AppTheme.backgroundColor,
        child: Column(
          children: [
            // Header with title and close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26), // 0.1 opacity = 26 alpha
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sign in to Spotify',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      widget.onAuthResult(false);
                      Navigator.of(context).pop();
                    },
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // Loading indicator
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: LinearProgressIndicator(
                  backgroundColor: AppTheme.primaryColor.withAlpha(51), // 0.2 opacity = 51 alpha
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            
            // Main WebView for authentication
            Expanded(
              child: FutureBuilder<void>(
                future: _authenticate(context),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  } else if (snapshot.hasError) {
                    // Error initiating authentication
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to authenticate with Spotify',
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {});  // Retry by rebuilding
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  return Container(); // WebView is managed by the authenticate method
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Authenticate with Spotify
  ///
  /// This method initiates the authentication process with Spotify
  /// and handles the WebView navigation to complete the process.
  Future<void> _authenticate(BuildContext context) async {
    // Authenticate is handled by SpotifyService to keep the UI clean
    // This also allows for platform-specific authentication methods
    final success = await _spotifyService.authenticate(context);
    
    if (success && mounted) {
      // Close dialog and notify parent of success
      widget.onAuthResult(true);
      Navigator.of(context).pop();
    }
  }
}

/// A button that triggers Spotify authentication
///
/// This widget displays a button that, when pressed, opens the
/// SpotifyAuthView to initiate the authentication process.
class SpotifyAuthButton extends StatelessWidget {
  final Function(bool success) onAuthResult;
  final String label;
  final IconData icon;

  const SpotifyAuthButton({
    super.key,
    required this.onAuthResult,
    this.label = 'Connect to Spotify',
    this.icon = Icons.music_note,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showAuthDialog(context),
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1DB954), // Spotify green
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
      ),
    );
  }

  void _showAuthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SpotifyAuthView(
        onAuthResult: onAuthResult,
      ),
    );
  }
}

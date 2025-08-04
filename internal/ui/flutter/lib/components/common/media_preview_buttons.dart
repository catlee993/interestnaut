import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../services/sqlite_db.dart';
import '../music/spotify_service.dart';
import 'standard_close_button.dart';
import '../../theme.dart';
import 'play_selector_button.dart';

/// Preview buttons for media items (YouTube/Spotify for music, YouTube for others)
class MediaPreviewButtons extends StatelessWidget {
  final String title;
  final String? artist;
  final String mediaType;
  final String? spotifyId; // For music: spotify track ID
  final String? youtubeId; // YouTube video ID
  final String? youtubeUrl; // Direct YouTube URL if available
  final bool alignLeft; // Whether to align buttons to the left

  const MediaPreviewButtons({
    Key? key,
    required this.title,
    this.artist,
    required this.mediaType,
    this.spotifyId,
    this.youtubeId,
    this.youtubeUrl,
    this.alignLeft = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _shouldShowPreviews(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!) {
          return const SizedBox.shrink();
        }

        // Use smart play selector button
        final playSelector = PlaySelectorButton(
          youtubeId: _shouldShowYouTube() ? youtubeId : null,
          spotifyId: _shouldShowSpotify() ? spotifyId : null,
          onYouTubePressed: _shouldShowYouTube() ? () => _openYouTube(context) : null,
          onSpotifyPressed: _shouldShowSpotify() ? () => _openSpotify(context) : null,
        );

        // If no external media buttons needed, return empty
        if (!_shouldShowYouTube() && !_shouldShowSpotify()) {
          return const SizedBox.shrink();
        }

        // Return play selector with optional spacing
        if (alignLeft) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: playSelector,
          );
        } else {
          // Add divider for non-aligned layout
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 30,
                width: 1,
                color: Colors.white.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: playSelector,
              ),
            ],
          );
        }
      },
    );
  }

  Future<bool> _shouldShowPreviews() async {
    final db = SQLiteDatabase();
    return await db.getYouTubePreviewsSetting();
  }

  bool _shouldShowYouTube() {
    // Show YouTube button if we have a youtubeId or youtubeUrl
    return youtubeId != null || youtubeUrl != null;
  }

  bool _shouldShowSpotify() {
    // Only show Spotify for music and if we have a Spotify ID
    return mediaType == 'music' && spotifyId != null;
  }

  void _openYouTube(BuildContext context) async {
    final videoId = youtubeId ?? '';
    try {
      // Show internal YouTube player
      showDialog(
        context: context,
        builder: (context) => YouTubePlayerDialog(videoId: videoId),
      );
    } catch (e) {
      debugPrint('Error opening YouTube player: $e');
      // Fallback to external app
      _openYouTubeExternal(videoId);
    }
  }

  void _openYouTubeExternal(String videoId) async {
    final url = 'https://www.youtube.com/watch?v=$videoId';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch YouTube URL: $url');
    }
  }

  void _openSpotify(BuildContext context) async {
    final trackId = spotifyId ?? '';
    try {
      final spotifyService = SpotifyService();
      
      // Check if user is authenticated
      final isAuthenticated = await spotifyService.checkAuthentication();
      
      if (!isAuthenticated) {
        // Show authentication dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Row(
                children: [
                  Icon(Icons.music_note, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text('Spotify Login Required', style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
              content: const Text(
                'You need to be logged into Spotify to play tracks.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openSpotifyExternal(trackId);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                  child: const Text('Open Spotify App'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.textSecondary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        return;
      }

      // Try to play the track
      final trackUri = 'spotify:track:$trackId';
      final success = await spotifyService.playTrack(trackUri);
      
      if (!success) {
        _openSpotifyExternal(trackId);
      }
    } catch (e) {
      debugPrint('Error playing Spotify track: $e');
      _openSpotifyExternal(trackId);
    }
  }

  void _openSpotifyExternal(String trackId) async {
    final spotifyUrl = 'spotify:track:$trackId';
    final webUrl = 'https://open.spotify.com/track/$trackId';
    
    // Try Spotify app first, fallback to web
    if (await canLaunchUrl(Uri.parse(spotifyUrl))) {
      await launchUrl(Uri.parse(spotifyUrl), mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(Uri.parse(webUrl))) {
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch Spotify URL: $webUrl');
    }
  }

}

// YouTube Player Dialog
class YouTubePlayerDialog extends StatefulWidget {
  final String videoId;

  const YouTubePlayerDialog({Key? key, required this.videoId}) : super(key: key);

  @override
  State<YouTubePlayerDialog> createState() => _YouTubePlayerDialogState();
}

class _YouTubePlayerDialogState extends State<YouTubePlayerDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'YouTube Player',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                StandardCloseButton(
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
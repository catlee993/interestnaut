import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'youtube_player_platform.dart';
import '../../shared/services/sqlite_db.dart';
import '../../features/music/presentation/spotify_service.dart';
import 'standard_close_button.dart';
import '../theme/theme.dart';
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
                color: Colors.white.withValues(alpha: 0.3),
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
    
    // Always try in-app player first, with custom error handling
    showDialog(
      context: context,
      builder: (context) => YouTubePlayerDialog(videoId: videoId),
    );
  }

  void _showYouTubeChoiceDialog(BuildContext context, String videoId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.play_circle_outline, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Play Video',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YouTube recently changed their API which affects in-app video playback.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Choose your preferred method:',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              // Try embedded player (may not work due to YouTube API changes)
              showDialog(
                context: context,
                builder: (context) => YouTubePlayerDialog(videoId: videoId),
              );
            },
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Try In-App (May Fail)'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _openYouTubeExternal(videoId);
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open YouTube (Recommended)'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.3),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
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

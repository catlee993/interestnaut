import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/sqlite_db.dart';
import '../music/spotify_service.dart';
import 'standard_close_button.dart';

/// Preview buttons for media items (YouTube/Spotify for music, YouTube for others)
class MediaPreviewButtons extends StatelessWidget {
  final String title;
  final String? artist;
  final String mediaType;
  final String? spotifyId; // For music: spotify track ID
  final String? youtubeId; // YouTube video ID
  final String? youtubeUrl; // Direct YouTube URL if available

  const MediaPreviewButtons({
    Key? key,
    required this.title,
    this.artist,
    required this.mediaType,
    this.spotifyId,
    this.youtubeId,
    this.youtubeUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _shouldShowPreviews(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!) {
          return const SizedBox.shrink();
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // YouTube Preview Button
            if (_shouldShowYouTube())
              _buildYouTubeButton(context),
            
            if (_shouldShowYouTube() && _shouldShowSpotify())
              const SizedBox(width: 8),
            
            // Spotify Play Button (music only)
            if (_shouldShowSpotify())
              _buildSpotifyButton(context),
          ],
        );
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

  Widget _buildYouTubeButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleYouTubePreview(context),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF0000).withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              const Text(
                'YouTube',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotifyButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleSpotifyPlay(context),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1DB954).withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              const Text(
                'Spotify',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleYouTubePreview(BuildContext context) {
    if (youtubeId != null && youtubeId!.isNotEmpty) {
      // Use YouTube ID to create direct URL
      final videoUrl = 'https://www.youtube.com/watch?v=$youtubeId';
      _showYouTubeModal(context, videoUrl);
    } else if (youtubeUrl != null && youtubeUrl!.isNotEmpty) {
      // Use provided YouTube URL
      _showYouTubeModal(context, youtubeUrl!);
    } else {
      // Generate search URL as fallback
      final query = artist != null ? '$title $artist' : title;
      final searchUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(query)}';
      _launchUrl(searchUrl);
    }
  }

  void _handleSpotifyPlay(BuildContext context) async {
    if (spotifyId == null) return;
    
    try {
      final spotifyService = SpotifyService();
      final trackUri = 'spotify:track:$spotifyId';
      
      final success = await spotifyService.playTrack(trackUri);
      if (success) {
        debugPrint('✅ Playing track on Spotify: $title');
        
        // Show a brief confirmation
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Playing "$title" on Spotify'),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF1DB954),
            ),
          );
        }
      } else {
        debugPrint('❌ Failed to play track on Spotify: $title');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to play track on Spotify'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error playing Spotify track: $e');
    }
  }

  void _showYouTubeModal(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => YouTubePreviewModal(
        title: title,
        artist: artist,
        youtubeUrl: url,
      ),
    );
  }

  void _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}

/// Modal dialog for YouTube video preview
class YouTubePreviewModal extends StatelessWidget {
  final String title;
  final String? artist;
  final String youtubeUrl;

  const YouTubePreviewModal({
    Key? key,
    required this.title,
    this.artist,
    required this.youtubeUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (artist != null)
                        Text(
                          artist!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                StandardCloseButton(
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // YouTube embed or web view
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'YouTube Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Video preview will be implemented here',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _launchYouTube(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0000),
                        ),
                        child: const Text(
                          'Open in YouTube',
                          style: TextStyle(color: Colors.white),
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

  void _launchYouTube() async {
    try {
      final uri = Uri.parse(youtubeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching YouTube URL: $e');
    }
  }
}
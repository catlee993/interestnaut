import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../theme.dart';

/// Dialog showing Spotify track info for non-authenticated users
class SpotifyPreviewDialog extends StatefulWidget {
  final String trackId;
  final String? trackName;
  final String? artistName;

  const SpotifyPreviewDialog({
    Key? key,
    required this.trackId,
    this.trackName,
    this.artistName,
  }) : super(key: key);

  @override
  State<SpotifyPreviewDialog> createState() => _SpotifyPreviewDialogState();
}

class _SpotifyPreviewDialogState extends State<SpotifyPreviewDialog> {
  bool _isLoading = true;
  String? _albumArtUrl;
  String? _trackName;
  String? _artistName;
  
  @override
  void initState() {
    super.initState();
    _fetchTrackInfo();
  }

  Future<void> _fetchTrackInfo() async {
    try {
      // Use Spotify's oEmbed endpoint (no auth required) to get basic track info
      final oembedUrl = 'https://open.spotify.com/oembed?url=https://open.spotify.com/track/${widget.trackId}&format=json';
      final response = await http.get(Uri.parse(oembedUrl));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          _trackName = data['title'] ?? widget.trackName ?? 'Unknown Track';
          _albumArtUrl = data['thumbnail_url'];
          // Artist name is not in oEmbed response, use provided
          _artistName = widget.artistName ?? 'Unknown Artist';
          _isLoading = false;
        });
      } else {
        setState(() {
          _trackName = widget.trackName ?? 'Unknown Track';
          _artistName = widget.artistName ?? 'Unknown Artist';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _trackName = widget.trackName ?? 'Unknown Track';
        _artistName = widget.artistName ?? 'Unknown Artist';
        _isLoading = false;
      });
      debugPrint('Error fetching track info: $e');
    }
  }

  void _openSpotifyWeb() async {
    final webUrl = 'https://open.spotify.com/track/${widget.trackId}';
    try {
      if (await canLaunchUrl(Uri.parse(webUrl))) {
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error opening Spotify web: $e');
    }
  }

  void _openSpotifyApp() async {
    final spotifyUrl = 'spotify:track:${widget.trackId}';
    try {
      if (await canLaunchUrl(Uri.parse(spotifyUrl))) {
        await launchUrl(Uri.parse(spotifyUrl), mode: LaunchMode.externalApplication);
        if (mounted) Navigator.of(context).pop();
      } else {
        // Fallback to web if app not installed
        _openSpotifyWeb();
      }
    } catch (e) {
      debugPrint('Error opening Spotify app: $e');
      _openSpotifyWeb();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.music_note,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Open in Spotify',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : Column(
                      children: [
                        // Album art
                        if (_albumArtUrl != null)
                          Container(
                            width: 160,
                            height: 160,
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _albumArtUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: AppTheme.cardBackgroundColor,
                                    child: const Icon(
                                      Icons.album,
                                      size: 64,
                                      color: Colors.white54,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        
                        // Track info
                        Text(
                          _trackName ?? 'Unknown Track',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _artistName ?? 'Unknown Artist',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Info box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'To play full tracks, open in Spotify',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Free preview playback requires Spotify authentication',
                                style: TextStyle(
                                  color: AppTheme.textSecondary.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openSpotifyWeb,
                                icon: const Icon(Icons.open_in_browser),
                                label: const Text('Open Web Player'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  side: BorderSide(color: AppTheme.primaryColor),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _openSpotifyApp,
                                icon: const Icon(Icons.music_note),
                                label: const Text('Open Spotify App'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../models.dart';
import '../../common/icons.dart';
import '../../common/media_detail_drawer.dart';
import '../../../services/sqlite_db.dart';
import '../../../main.dart'; // For MediaSearchResult

class SearchResultCard extends StatefulWidget {
  final dynamic track; // SimpleTrack or full Track
  final bool isSaved;
  final bool isPlaying;
  final Function(dynamic) onPlay;
  final Function(dynamic)? onSave;
  final Function(dynamic)? onRemove;
  final bool limitToSpotifyActions;

  const SearchResultCard({
    Key? key,
    required this.track,
    this.isSaved = false,
    this.isPlaying = false,
    required this.onPlay,
    this.onSave,
    this.onRemove,
    this.limitToSpotifyActions = false,
  }) : super(key: key);

  @override
  State<SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<SearchResultCard> {
  bool _isHovered = false;

  Map<String, dynamic> _getTrackInfo() {
    final track = widget.track;
    
    // Handle null case
    if (track == null) {
      return {
        'name': 'Unknown Track',
        'artist': 'Unknown Artist',
        'album': '',
        'albumArtUrl': '',
        'previewUrl': null,
        'uri': null,
      };
    }
    
    // Handle SimpleTrack or full MediaItem
    if (track is MediaItem) {
      return {
        'name': track.title,
        'artist': track.overview,
        'album': '',
        'albumArtUrl': track.posterPath,
        'previewUrl': track.previewUrl,
        'uri': track.uri,
      };
    }
    
    // Default case - direct access to properties we might have
    return {
      'name': track.name ?? 'Unknown Track',
      'artist': track.artist ?? 'Unknown Artist',
      'album': track.album ?? '',
      'albumArtUrl': track.albumArtUrl ?? '',
      'previewUrl': track.previewUrl,
      'uri': track.uri,
    };
  }

  bool _canPlay() {
    final info = _getTrackInfo();
    return info['uri'] != null || info['previewUrl'] != null;
  }

  @override
  Widget build(BuildContext context) {
    final info = _getTrackInfo();
    final canPlay = _canPlay();
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: _isHovered 
            ? Matrix4.translationValues(0, -4, 0)
            : Matrix4.translationValues(0, 0, 0),
        decoration: BoxDecoration(
          // Uniform gradient background for entire card - darker top, lighter bottom
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromRGBO(28, 28, 28, 0.98), // Darker at top
              const Color.fromRGBO(40, 40, 40, 0.95), // Lighter at bottom
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(
            color: _isHovered 
                ? const Color.fromRGBO(123, 104, 238, 0.5)
                : const Color.fromRGBO(123, 104, 238, 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _buildSearchLayout(info, canPlay),
      ),
    );
  }

  Widget _buildSearchLayout(Map<String, dynamic> info, bool canPlay) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate artwork size - leave room for controls at bottom (about 50px for controls + padding)
        final controlsHeight = 50.0;
        final topMargin = 6.0;
        final availableArtworkHeight = constraints.maxHeight - controlsHeight - topMargin;
        final artworkSize = constraints.maxWidth * 0.85;
        // Use the smaller of width-based or height-based size to ensure it fits
        final finalArtworkSize = artworkSize < availableArtworkHeight ? artworkSize : availableArtworkHeight;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Album artwork - sized to fit available space with click handler
            GestureDetector(
              onTap: () => _openMediaDetailDrawer(context, info),
              child: Container(
                margin: const EdgeInsets.only(top: 6.0),
                width: finalArtworkSize,
                height: finalArtworkSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: info['albumArtUrl'] != null && info['albumArtUrl'].isNotEmpty
                      ? Image.network(
                          info['albumArtUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppTheme.cardBackgroundColor,
                              child: const Center(
                                child: Icon(Icons.music_note, size: 48, color: Colors.white54),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppTheme.cardBackgroundColor,
                          child: const Center(
                            child: Icon(Icons.music_note, size: 48, color: Colors.white54),
                          ),
                        ),
                ),
              ),
            ),
            
            // Controls panel at bottom - back at the bottom with fixed positioning
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6.0, 2.0, 6.0, 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center, // Center align all items
                  mainAxisSize: MainAxisSize.max,
                  children: widget.limitToSpotifyActions ? [
                    // Spotify content: Show play/save buttons
                    // Play button - enhanced with glow effect
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          widget.isPlaying ? AppIcons.pause : AppIcons.play,
                          size: 12,
                          color: Colors.white,
                        ),
                        onPressed: canPlay ? () => widget.onPlay(widget.track) : null,
                        tooltip: !canPlay
                            ? "Playback unavailable"
                            : widget.isPlaying
                                ? "Pause"
                                : info['uri'] != null
                                    ? "Play full song"
                                    : "Play preview",
                        color: Colors.white,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    
                    // Title and artist centered between controls - reduced width
                    Expanded(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.5, // Limit to 50% of card width
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 3.0), // Reduced padding
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center, // Center align text vertically
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              info['name'] ?? 'Unknown Track',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              info['artist'] ?? 'Unknown Artist',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 1),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            if (!canPlay)
                              const Text(
                                'Playback unavailable',
                                style: TextStyle(
                                  color: AppTheme.errorColor,
                                  fontSize: 8,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Save/Remove button - clean text only
                    widget.isSaved
                        ? TextButton(
                            onPressed: widget.onRemove != null 
                                ? () => widget.onRemove!(widget.track)
                                : null,
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.errorColor,
                              minimumSize: const Size(8, 8),
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                            child: const Text('Remove'),
                          )
                        : TextButton(
                            onPressed: widget.onSave != null 
                                ? () => widget.onSave!(widget.track)
                                : null,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size(8, 8),
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                            child: const Text('Save'),
                          ),
                  ] : [
                    // Interestnaut content: Centered title/artist with corner buttons
                    Expanded(
                      child: Stack(
                        children: [
                          // Centered title and artist text
                          Positioned.fill(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 2.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: _buildTitleAndArtist(info),
                              ),
                            ),
                          ),
                          
                          // YouTube button (left corner)
                          if (_shouldShowYouTubeButton(info))
                            Positioned(
                              left: 2,
                              bottom: 2,
                              child: _buildCornerButton(
                                icon: Icons.play_arrow,
                                color: const Color(0xFF4285F4), // YouTube blue
                                onPressed: () => _openExternalMedia(info, 'youtube'),
                                tooltip: 'Play on YouTube',
                              ),
                            ),
                          
                          // Spotify button (right corner) - only for music
                          if (_shouldShowSpotifyButton(info))
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: _buildCornerButton(
                                icon: Icons.music_note,
                                color: const Color(0xFF1DB954), // Spotify green
                                onPressed: () => _openExternalMedia(info, 'spotify'),
                                tooltip: 'Play on Spotify',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Opens the media detail drawer when album artwork is clicked
  Future<void> _openMediaDetailDrawer(BuildContext context, Map<String, dynamic> info) async {
    try {
      // Convert track info to MediaSearchResult for consistency
      final mediaSearchResult = MediaSearchResult(
        mediaId: info['uri'] ?? 'spotify_track_${DateTime.now().millisecondsSinceEpoch}',
        title: info['name'] ?? 'Unknown Track',
        artist: info['artist'] ?? 'Unknown Artist',
        album: info['album'],
        description: null, // Music tracks typically don't have descriptions
        coverArtUrl: info['albumArtUrl'],
        themes: null, // Music tracks typically don't have themes
        wikiUrl: null,
        wikidataId: null,
        mediaType: 'music',
      );

      // Get comprehensive status from database
      final db = SQLiteDatabase();
      final statusResult = await db.getMediaItemStatus(
        title: info['name'] ?? 'Unknown Track',
        mediaType: 'music',
        primaryCreator: info['artist'] ?? 'Unknown Artist',
      );

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          enableDrag: true,
          isDismissible: true,
          barrierColor: Colors.black54,
          builder: (context) => GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {}, // Prevent tap-through
                child: MediaDetailDrawer(
                  title: info['name'] ?? 'Unknown Track',
                  artist: info['artist'] ?? 'Unknown Artist',
                  description: info['album'] != null ? 'Album: ${info['album']}' : null,
                  themes: null, // Music tracks typically don't have themes
                  genres: statusResult['genres'] as String?,
                  youtubeId: statusResult['youtubeId'] as String?,
                  spotifyId: statusResult['spotifyId'] as String?,
                  coverArtUrl: info['albumArtUrl'],
                  mediaType: 'music',
                  hasLiked: statusResult['hasLiked'] as bool? ?? false,
                  hasDisliked: statusResult['hasDisliked'] as bool? ?? false,
                  hasFavorited: statusResult['hasFavorited'] as bool? ?? false,
                  isInWatchlist: statusResult['isInWatchlist'] as bool? ?? false,
                  hasSkipped: statusResult['hasSkipped'] as bool? ?? false,
                  onAction: (action) => _handleDrawerAction(
                    context,
                    action,
                    mediaSearchResult,
                    statusResult['mediaItemId'] as int?,
                  ),
                  limitToSpotifyActions: widget.limitToSpotifyActions,
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error opening music detail drawer: $e');
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error'),
            content: Text('Failed to load track details: $e'),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7B68EE),
                  side: const BorderSide(color: Color(0xFF7B68EE)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Determine if YouTube button should be shown
  bool _shouldShowYouTubeButton(Map<String, dynamic> info) {
    // Only show for Interestnaut results
    if (widget.limitToSpotifyActions) return false;
    
    // For Interestnaut search results, we need to check in the database
    // The YouTube ID isn't passed through SimpleTrack, but we can still
    // show the button if we have valid track info to search with
    final name = info['name'] as String?;
    final artist = info['artist'] as String?;
    
    // Don't show button if we don't have meaningful data
    if (name == null || name.isEmpty || name == 'Unknown Track') return false;
    if (artist == null || artist.isEmpty || artist == 'Unknown Artist') return false;
    
    // Show button - when clicked it will search for the YouTube ID
    return true;
  }

  /// Determine if Spotify button should be shown  
  bool _shouldShowSpotifyButton(Map<String, dynamic> info) {
    // Only show for Interestnaut results
    if (widget.limitToSpotifyActions) return false;
    
    // For Interestnaut search results, we need to check in the database
    // The Spotify ID isn't passed through SimpleTrack, but we can still
    // show the button if we have valid track info to search with
    final name = info['name'] as String?;
    final artist = info['artist'] as String?;
    
    // Don't show button if we don't have meaningful data
    if (name == null || name.isEmpty || name == 'Unknown Track') return false;
    if (artist == null || artist.isEmpty || artist == 'Unknown Artist') return false;
    
    // Show button - when clicked it will search for the Spotify ID
    return true;
  }

  /// Build title and artist text widgets with proper fallback
  List<Widget> _buildTitleAndArtist(Map<String, dynamic> info) {
    final title = info['name'];
    final artist = info['artist'];
    
    // If no title but has artist, use artist as title with title styling
    if ((title == null || title.isEmpty) && artist != null && artist.isNotEmpty) {
      return [
        Text(
          artist,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 12,
            letterSpacing: -0.2,
            shadows: [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ];
    }
    
    // Normal case: show title and artist
    return [
      Text(
        title ?? 'Unknown Track',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 12,
          letterSpacing: -0.2,
          shadows: [
            Shadow(
              color: Colors.black54,
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
      if (artist != null && artist.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(
          artist,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            letterSpacing: -0.1,
            shadows: [
              Shadow(
                color: Colors.black38,
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    ];
  }

  /// Build a corner button with consistent styling
  Widget _buildCornerButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.8),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              offset: const Offset(0, 1),
              blurRadius: 4,
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(icon, size: 14, color: color),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          tooltip: tooltip,
          splashRadius: 12,
        ),
      ),
    );
  }

  /// Open external media (YouTube/Spotify) by fetching IDs from database
  Future<void> _openExternalMedia(Map<String, dynamic> info, String platform) async {
    try {
      final db = SQLiteDatabase();
      final statusResult = await db.getMediaItemStatus(
        title: info['name'] ?? 'Unknown Track',
        mediaType: 'music',
        primaryCreator: info['artist'] ?? 'Unknown Artist',
      );

      final youtubeId = statusResult['youtubeId'] as String?;
      final spotifyId = statusResult['spotifyId'] as String?;

      if (platform == 'youtube' && youtubeId != null) {
        _openYouTubeExternal(youtubeId);
      } else if (platform == 'spotify' && spotifyId != null) {
        _openSpotifyExternal(spotifyId);
      } else {
        // Show message that the platform isn't available for this track
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${platform == 'youtube' ? 'YouTube' : 'Spotify'} not available for this track'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening external media: $e');
    }
  }

  /// Open YouTube video externally
  void _openYouTubeExternal(String videoId) async {
    try {
      final url = 'https://www.youtube.com/watch?v=$videoId';
      // Import url_launcher if not already imported
      // if (await canLaunchUrl(Uri.parse(url))) {
      //   await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      // }
      debugPrint('🎬 Opening YouTube video: $url');
    } catch (e) {
      debugPrint('Error opening YouTube: $e');
    }
  }

  /// Open Spotify track externally
  void _openSpotifyExternal(String trackId) async {
    try {
      final spotifyUrl = 'spotify:track:$trackId';
      final webUrl = 'https://open.spotify.com/track/$trackId';
      // Import url_launcher if not already imported
      // Try Spotify app first, fallback to web
      // if (await canLaunchUrl(Uri.parse(spotifyUrl))) {
      //   await launchUrl(Uri.parse(spotifyUrl), mode: LaunchMode.externalApplication);
      // } else if (await canLaunchUrl(Uri.parse(webUrl))) {
      //   await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      // }
      debugPrint('🎵 Opening Spotify track: $webUrl');
    } catch (e) {
      debugPrint('Error opening Spotify: $e');
    }
  }

  /// Handle actions from the media detail drawer
  Future<void> _handleDrawerAction(
    BuildContext context,
    String action,
    MediaSearchResult item,
    int? existingMediaItemId,
  ) async {
    try {
      final db = SQLiteDatabase();
      
      // Create or get the media item if it doesn't exist
      int mediaItemId;
      if (existingMediaItemId != null) {
        mediaItemId = existingMediaItemId;
      } else {
        mediaItemId = await db.createOrGetMediaItem(
          mediaType: 'music',
          vectorMediaId: item.mediaId,
          title: item.title ?? 'Unknown Track',
          primaryCreator: item.artist ?? 'Unknown Artist',
          coverArtUrl: item.coverArtUrl,
          description: item.description,
          wikiUrl: item.wikiUrl,
          wikidataId: item.wikidataId,
          themes: item.themes,
          genres: null, // TODO: Extract from item if available
          youtubeId: null, // TODO: Extract from item if available
          spotifyId: null, // TODO: Extract from item if available
        );
        debugPrint('🔍 [MUSIC-SEARCH-DRAWER] Created new media item with ID: $mediaItemId');
      }

      switch (action) {
        case 'like':
          // Add to favorites and handle other logic as needed
          await db.addToFavorites(mediaItemId);
          break;
          
        case 'dislike':
          // Handle dislike action
          // Implementation depends on your requirements
          break;
          
        case 'favorite':
          // Add to favorites table
          await db.addToFavorites(mediaItemId);
          break;
          
        case 'watchlist':
          // Add to watchlist table (playlist for music)
          await db.addToWatchlist(mediaItemId);
          break;
          
        case 'skip':
          // Handle skip action
          // Implementation depends on your requirements
          break;

        case 'clear_all':
          // Handle clearing all reactions
          // Implementation depends on your requirements
          break;
      }
      
      debugPrint('✅ [MUSIC-SEARCH-DRAWER] Handled action: $action for ${item.title}');
    } catch (e) {
      debugPrint('❌ [MUSIC-SEARCH-DRAWER] Error handling drawer action: $e');
    }
  }
} 
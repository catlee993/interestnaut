import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../models.dart';
import '../../common/icons.dart';

class TrackCard extends StatefulWidget {
  final dynamic track; // SimpleTrack or full Track
  final bool isSaved;
  final bool isPlaying;
  final Function(dynamic) onPlay;
  final Function(dynamic)? onSave;
  final Function(dynamic)? onRemove;

  const TrackCard({
    Key? key,
    required this.track,
    this.isSaved = false,
    this.isPlaying = false,
    required this.onPlay,
    this.onSave,
    this.onRemove,
  }) : super(key: key);

  @override
  State<TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<TrackCard> {
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
          color: AppTheme.surfaceColor,
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
        child: AspectRatio(
          aspectRatio: 1, // 1:1 aspect ratio as in React
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius - 2), // Adjust for border
            child: Stack(
              children: [
                // Album art background
                Positioned.fill(
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
                
                // Playing indicator at the top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    color: widget.isPlaying ? AppTheme.primaryColor : Colors.transparent,
                  ),
                ),
                
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.98),
                          Colors.black.withOpacity(0.75),
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                
                // Controls and text overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // Play button
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(21),
                          ),
                          child: IconButton(
                            icon: Icon(
                              widget.isPlaying ? AppIcons.pause : AppIcons.play,
                              size: AppIcons.iconSizeSmall,
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
                        
                        // Track info
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  info['name'] ?? 'Unknown Track',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  info['artist'] ?? 'Unknown Artist',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!canPlay)
                                  const Text(
                                    'Playback unavailable',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Save/Remove button
                        widget.isSaved
                            ? TextButton(
                                onPressed: widget.onRemove != null 
                                    ? () => widget.onRemove!(widget.track)
                                    : null,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.errorColor,
                                  minimumSize: const Size(10, 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  textStyle: const TextStyle(fontSize: 14),
                                ),
                                child: const Text('Remove'),
                              )
                            : TextButton(
                                onPressed: widget.onSave != null 
                                    ? () => widget.onSave!(widget.track)
                                    : null,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(10, 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  textStyle: const TextStyle(fontSize: 14),
                                ),
                                child: const Text('Save'),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
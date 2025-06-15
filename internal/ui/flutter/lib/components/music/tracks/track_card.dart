import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../models.dart';
import '../../common/icons.dart';

enum TrackCardLayout { search, library }

class TrackCard extends StatefulWidget {
  final dynamic track; // SimpleTrack or full Track
  final bool isSaved;
  final bool isPlaying;
  final Function(dynamic) onPlay;
  final Function(dynamic)? onSave;
  final Function(dynamic)? onRemove;
  final TrackCardLayout layout;

  const TrackCard({
    Key? key,
    required this.track,
    this.isSaved = false,
    this.isPlaying = false,
    required this.onPlay,
    this.onSave,
    this.onRemove,
    this.layout = TrackCardLayout.search,
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
        child: widget.layout == TrackCardLayout.library 
            ? _buildLibraryLayout(info, canPlay)
            : _buildSearchLayout(info, canPlay),
      ),
    );
  }

  Widget _buildSearchLayout(Map<String, dynamic> info, bool canPlay) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Playing indicator at the top
          Container(
            height: 3,
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.isPlaying ? AppTheme.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(height: 12),
          
          // Album artwork - no overlays, rounded corners per Spotify guidelines
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4), // 4px for large devices per Spotify guidelines
              child: Container(
                width: double.infinity,
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
          
          const SizedBox(height: 12),
          
          // Track title - separate from artwork
          Text(
            info['name'] ?? 'Unknown Track',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 4),
          
          // Artist name
          Text(
            info['artist'] ?? 'Unknown Artist',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          if (!canPlay) ...[
            const SizedBox(height: 4),
            const Text(
              'Playback unavailable',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Controls row - separate from artwork
          Row(
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
              
              const Spacer(),
              
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
        ],
      ),
    );
  }

  Widget _buildLibraryLayout(Map<String, dynamic> info, bool canPlay) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate perfect square artwork size based on card width
        final artworkSize = constraints.maxWidth;
        final minControlsHeight = 60.0; // Minimum space needed for controls
        final controlsHeight = (constraints.maxHeight - artworkSize).clamp(minControlsHeight, double.infinity);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album artwork - perfect square based on card width
            Container(
              width: artworkSize,
              height: artworkSize,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.cardBorderRadius),
                  topRight: Radius.circular(AppTheme.cardBorderRadius),
                ),
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
            
            // Purple border separator
            Container(
              height: 2,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color.fromRGBO(123, 104, 238, 0.8),
                    const Color.fromRGBO(123, 104, 238, 1.0),
                    const Color.fromRGBO(123, 104, 238, 0.8),
                  ],
                ),
              ),
            ),
            
            // Controls panel at bottom - balanced spacing above and below controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // Balanced vertical padding for equal spacing above and below play button
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Play button - smaller
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: IconButton(
                      icon: Icon(
                        widget.isPlaying ? AppIcons.pause : AppIcons.play,
                        size: 16, // Smaller icon
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
                  
                  // Title and artist centered between controls - more compact
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0), // Reduced padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            info['name'] ?? 'Unknown Track',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14, // Smaller font
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 1), // Reduced spacing
                          Text(
                            info['artist'] ?? 'Unknown Artist',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12, // Smaller font
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          if (!canPlay) ...[
                            const SizedBox(height: 1),
                            const Text(
                              'Playback unavailable',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10, // Smaller font
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // Remove button - smaller
                  TextButton(
                    onPressed: widget.onRemove != null 
                        ? () => widget.onRemove!(widget.track)
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      minimumSize: const Size(10, 10),
                      padding: const EdgeInsets.symmetric(horizontal: 6), // Reduced padding
                      textStyle: const TextStyle(fontSize: 12), // Smaller font
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
} 
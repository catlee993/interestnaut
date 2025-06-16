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
          // Add subtle purple background tint like MediaLibraryCard
          color: const Color(0xFF7B68EE).withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(
            color: _isHovered 
                ? const Color(0xFF7B68EE).withOpacity(0.6) // Stronger purple on hover
                : const Color(0xFF7B68EE).withOpacity(0.4), // More prominent purple normally
            width: 2,
          ),
          // Add purple glow effect to match library cards
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B68EE).withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
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
                        width: artworkSize,
                        height: artworkSize,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF7B68EE).withOpacity(0.1), // Purple fallback like MediaLibraryCard
                            child: const Center(
                              child: Icon(Icons.music_note, size: 48, color: Colors.white54),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: const Color(0xFF7B68EE).withOpacity(0.1), // Purple fallback like MediaLibraryCard
                        child: const Center(
                          child: Icon(Icons.music_note, size: 48, color: Colors.white54),
                        ),
                      ),
              ),
            ),
            
            // Controls panel at bottom - sleeker design with gradient and transparency
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // Reduced vertical padding
                decoration: BoxDecoration(
                  // Gradient background - exact same as MediaLibraryCard watchlist items
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0x40000000), // rgba(0,0,0,0.25) at 70%
                      const Color(0x66000000), // rgba(0,0,0,0.4) at 85%
                      const Color(0x99000000), // rgba(0,0,0,0.6) at 95%
                      Colors.black,             // rgba(0,0,0,1) at 100%
                    ],
                    stops: [0.0, 0.70, 0.85, 0.95, 1.0],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppTheme.cardBorderRadius),
                    bottomRight: Radius.circular(AppTheme.cardBorderRadius),
                  ),
                  // Add subtle shadow for depth
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(0, -1),
                    ),
                  ],
                  // Subtle top border to separate from artwork
                  border: Border(
                    top: BorderSide(
                      color: _isHovered 
                          ? const Color.fromRGBO(123, 104, 238, 0.41) // Brighter purple on hover
                          : const Color.fromRGBO(123, 104, 238, 0.4), // Subtle purple normally
                      width: _isHovered ? 1.5 : 1.0, // Slightly thicker on hover
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Play button - enhanced with glow effect
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(18),
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              info['name'] ?? 'Unknown Track',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
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
                            const SizedBox(height: 1),
                            Text(
                              info['artist'] ?? 'Unknown Artist',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
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
                    
                    // Remove button - clean text only
                    TextButton(
                      onPressed: widget.onRemove != null 
                          ? () => widget.onRemove!(widget.track)
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        minimumSize: const Size(10, 10),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      child: const Text('Remove'),
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
} 
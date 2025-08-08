import 'package:flutter/material.dart';
import '../../../../shared/models/models.dart';
import '../tracks/track_card.dart';
import '../../../../shared/theme/theme.dart';

class LibrarySection extends StatelessWidget {
  final List<Track> savedTracks;
  final int currentPage;
  final int totalTracks;
  final int itemsPerPage;
  final Track? nowPlayingTrack;
  final bool isPlaybackPaused;
  final Future<void> Function(Track) onPlay;
  final Future<void> Function(Track) onSave;
  final Future<void> Function(Track) onRemove;
  final VoidCallback onNextPage;
  final VoidCallback onPrevPage;
  final bool showHeader;

  const LibrarySection({
    Key? key,
    required this.savedTracks,
    required this.currentPage,
    required this.totalTracks,
    required this.itemsPerPage,
    this.nowPlayingTrack,
    required this.isPlaybackPaused,
    required this.onPlay,
    required this.onSave,
    required this.onRemove,
    required this.onNextPage,
    required this.onPrevPage,
    this.showHeader = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 16.0),
            child: Text(
                                      'FAVORITES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (savedTracks.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No saved tracks yet. Search for tracks to add them to your library.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ] else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate card width based on 2 columns and spacing
                final availableWidth = constraints.maxWidth - 24.0; // Account for spacing
                final cardWidth = (availableWidth - 24.0) / 2; // 2 columns with 24px gap
                
                // Calculate card height: square artwork + controls space
                final artworkSize = cardWidth;
                final controlsHeight = 60.0; // Fixed height for controls
                final cardHeight = artworkSize + controlsHeight;
                
                return Wrap(
                  spacing: 24.0,
                  runSpacing: 24.0,
                  children: savedTracks.map((track) {
                    // Convert Track to SimpleTrack for TrackCard compatibility
                    final simpleTrack = SimpleTrack(
                      id: track.id,
                      name: track.name,
                      artist: track.artists.isNotEmpty ? track.artists.first.name : 'Unknown Artist',
                      album: track.album.name,
                      albumArtUrl: track.album.images.isNotEmpty ? track.album.images.first.url : '',
                      uri: track.uri,
                      previewUrl: track.previewUrl,
                    );
                    
                    return SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: TrackCard(
                        track: simpleTrack,
                        isSaved: true,
                        isPlaying: !isPlaybackPaused && nowPlayingTrack?.id == track.id,
                        onPlay: (t) => onPlay(track), // Pass original track to onPlay
                        onSave: (t) => onSave(track), // Pass original track to onSave
                        onRemove: (t) => onRemove(track), // Pass original track to onRemove
                        layout: TrackCardLayout.library, // Use library layout for liked songs
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            // Pagination controls - original styling with OutlinedButton
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100, // Fixed width for both buttons
                  child: OutlinedButton(
                    onPressed: currentPage == 1 ? null : onPrevPage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFA855F7),
                      side: const BorderSide(color: Color(0xFFA855F7)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // More compact
                    ),
                    child: Transform.scale(
                      scaleX: 0.9, // Slightly compressed horizontally
                      scaleY: 1.05, // Slightly taller than normal
                      child: Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: 12, // Reduced font size for compact buttons
                          fontWeight: FontWeight.w200,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Page $currentPage of ${((totalTracks + itemsPerPage - 1) / itemsPerPage).floor()}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 100, // Same fixed width as Previous button
                  child: OutlinedButton(
                    onPressed: currentPage * itemsPerPage >= totalTracks ? null : onNextPage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFA855F7),
                      side: const BorderSide(color: Color(0xFFA855F7)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // More compact
                    ),
                    child: Transform.scale(
                      scaleX: 0.9, // Slightly compressed horizontally
                      scaleY: 1.05, // Slightly taller than normal
                      child: Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 12, // Reduced font size for compact buttons
                          fontWeight: FontWeight.w200,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
      ],
    );
  }
}
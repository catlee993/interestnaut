import 'package:flutter/material.dart';
import '../../../models.dart';
import '../tracks/track_card.dart';
import '../../common/media_grid.dart';

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
              'Your Library',
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
            MediaGrid(
              columns: 2, // Use 2 columns for better spacing
              spacing: 24.0, // Add more spacing between cards
              childAspectRatio: 0.88, // Just enough height for square artwork + controls without too much extra space
              children: savedTracks
                  .map((track) {
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
                    
                    return TrackCard(
                      track: simpleTrack,
                        isSaved: true,
                        isPlaying: !isPlaybackPaused && nowPlayingTrack?.id == track.id,
                      onPlay: (t) => onPlay(track), // Pass original track to onPlay
                      onSave: (t) => onSave(track), // Pass original track to onSave
                      onRemove: (t) => onRemove(track), // Pass original track to onRemove
                      layout: TrackCardLayout.library, // Use library layout for liked songs
                    );
                  })
                  .toList(),
            ),
            const SizedBox(height: 16),
            // Pagination controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: currentPage > 1 ? onPrevPage : null,
                  child: const Text('Previous'),
                ),
                Text(
                  'Page $currentPage of ${(totalTracks / itemsPerPage).ceil()}',
                  style: const TextStyle(color: Colors.white),
                ),
                ElevatedButton(
                  onPressed: currentPage * itemsPerPage < totalTracks ? onNextPage : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
      ],
    );
  }
}
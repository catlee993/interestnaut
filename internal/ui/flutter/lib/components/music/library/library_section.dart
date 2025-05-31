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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            const Center(
              child: Text(
                'Your Library', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (savedTracks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No saved tracks yet. Search for tracks to add them to your library.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            MediaGrid(
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
                    );
                  })
                  .toList(),
            ),
            const SizedBox(height: 16),
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
                    ),
                    child: const Text('Previous'),
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
                    ),
                    child: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
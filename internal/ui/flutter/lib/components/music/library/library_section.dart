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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your Library', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          if (savedTracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No saved tracks yet. Search for tracks to add them to your library.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            MediaGrid(
              children: savedTracks
                  .map((track) => TrackCard(
                        track: track,
                        isSaved: true,
                        isPlaying: !isPlaybackPaused && nowPlayingTrack?.id == track.id,
                        onPlay: (t) => onPlay(t),
                        onSave: (t) => onSave(t),
                        onRemove: (t) => onRemove(t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: currentPage == 1 ? null : onPrevPage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFFA855F7),
                    side: BorderSide(color: Color(0xFFA855F7)),
                  ),
                  child: Text('Previous'),
                ),
                const SizedBox(width: 16),
                Text(
                  'Page $currentPage of ${((totalTracks + itemsPerPage - 1) / itemsPerPage).floor()}',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: currentPage * itemsPerPage >= totalTracks ? null : onNextPage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFFA855F7),
                    side: BorderSide(color: Color(0xFFA855F7)),
                  ),
                  child: Text('Next'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
} 
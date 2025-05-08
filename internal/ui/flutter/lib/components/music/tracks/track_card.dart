import 'package:flutter/material.dart';
import '../../../models.dart';

class TrackCard extends StatelessWidget {
  final dynamic track; // Track or SimpleTrack
  final bool isSaved;
  final bool isPlaying;
  final Future<void> Function(dynamic track) onPlay;
  final Future<void> Function(SimpleTrack track)? onSave;
  final Future<void> Function(SimpleTrack track)? onRemove;
  final bool isCurrentTrack;
  final VoidCallback? onPlayPause;

  const TrackCard({
    Key? key,
    required this.track,
    required this.onPlay,
    this.isSaved = false,
    this.isPlaying = false,
    this.onSave,
    this.onRemove,
    this.isCurrentTrack = false,
    this.onPlayPause,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final info = getTrackInfo(track);
    final hasUri = (track is Track && track.uri.isNotEmpty) || (track is SimpleTrack && track.uri.isNotEmpty);
    final canPlay = hasUri || (info['previewUrl']?.isNotEmpty ?? false);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPlaying ? Theme.of(context).colorScheme.primary : Colors.purple.withOpacity(0.3),
          width: 2,
        ),
      ),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(info['albumArtUrl'] ?? ''),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              height: 4,
              color: isPlaying ? Theme.of(context).colorScheme.primary : Colors.transparent,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color.fromRGBO(0, 0, 0, 0.98),
                    Color.fromRGBO(0, 0, 0, 0.75),
                    Colors.transparent,
                  ],
                  stops: [0, 0.4, 1],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _PlayButton(
                    isPlaying: isPlaying && isCurrentTrack,
                    canPlay: canPlay,
                    onPressed: () async {
                      if (isCurrentTrack && isPlaying && onPlayPause != null) {
                        onPlayPause!();
                      } else {
                        await onPlay(track);
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
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
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          info['artist'] ?? 'Unknown Artist',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!canPlay)
                          const Text(
                            'Playback unavailable',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  isSaved
                      ? TextButton(
                          onPressed: onRemove != null ? () => onRemove!(track as SimpleTrack) : null,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red[200],
                            minimumSize: const Size(40, 32),
                          ),
                          child: const Text('Remove'),
                        )
                      : TextButton(
                          onPressed: onSave != null ? () => onSave!(track as SimpleTrack) : null,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size(40, 32),
                          ),
                          child: const Text('Save'),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool canPlay;
  final VoidCallback onPressed;

  const _PlayButton({
    required this.isPlaying,
    required this.canPlay,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: canPlay ? onPressed : null,
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      color: Colors.white,
      iconSize: 28,
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        disabledBackgroundColor: Colors.grey[800],
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(10),
      ),
      tooltip: !canPlay
          ? 'Playback unavailable'
          : isPlaying
              ? 'Pause'
              : 'Play',
    );
  }
}

Map<String, dynamic> getTrackInfo(dynamic track) {
  if (track == null) {
    return {
      'name': 'Unknown Track',
      'artist': 'Unknown Artist',
      'album': '',
      'albumArtUrl': '',
      'previewUrl': '',
    };
  }
  if (track is Track) {
    return {
      'name': track.name,
      'artist': track.artists.isNotEmpty ? track.artists[0].name : 'Unknown Artist',
      'album': track.album.name,
      'albumArtUrl': track.album.images.isNotEmpty ? track.album.images[0].url : '',
      'previewUrl': track.previewUrl,
    };
  }
  if (track is SimpleTrack) {
    return {
      'name': track.name,
      'artist': track.artist,
      'album': track.album,
      'albumArtUrl': track.albumArtUrl,
      'previewUrl': track.previewUrl,
    };
  }
  return {
    'name': 'Unknown Track',
    'artist': 'Unknown Artist',
    'album': '',
    'albumArtUrl': '',
    'previewUrl': '',
  };
} 
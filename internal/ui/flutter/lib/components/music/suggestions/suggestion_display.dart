import 'package:flutter/material.dart';
import '../../../models.dart';
import '../../common/reason_card.dart';

class SuggestionDisplay extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final bool isProcessingLibrary;
  final Track? suggestedTrack;
  final String? suggestionReason;
  final bool isPlaybackPaused;
  final Track? nowPlayingTrack;
  final VoidCallback onRequestSuggestion;
  final VoidCallback onSkipSuggestion;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onAddToLibrary;
  final VoidCallback onPlayPause;

  const SuggestionDisplay({
    Key? key,
    required this.isLoading,
    this.error,
    required this.isProcessingLibrary,
    this.suggestedTrack,
    this.suggestionReason,
    required this.isPlaybackPaused,
    this.nowPlayingTrack,
    required this.onRequestSuggestion,
    required this.onSkipSuggestion,
    required this.onLike,
    required this.onDislike,
    required this.onAddToLibrary,
    required this.onPlayPause,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color.fromRGBO(123, 104, 238, 0.7)),
        ),
      );
    }
    if (error != null && error!.isNotEmpty) {
      final truncatedError = error!.length > 500 ? error!.substring(0, 500) + '...' : error!;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color.fromRGBO(194, 59, 133, 0.1),
              border: Border.all(color: Color.fromRGBO(194, 59, 133, 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              truncatedError,
              style: TextStyle(color: Color(0xFFC23B85), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isProcessingLibrary ? null : onRequestSuggestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromRGBO(123, 104, 238, 0.7),
              shape: StadiumBorder(),
            ),
            child: Text('Try Again'),
          ),
        ],
      );
    }
    if (suggestedTrack == null) {
      return Center(
        child: ElevatedButton(
          onPressed: isProcessingLibrary ? null : onRequestSuggestion,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color.fromRGBO(123, 104, 238, 0.7),
            shape: StadiumBorder(),
          ),
          child: Text('Get a Suggestion'),
        ),
      );
    }
    final isPlaying = !isPlaybackPaused && nowPlayingTrack?.id == suggestedTrack.id;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (suggestedTrack.albumArtUrl.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Color.fromRGBO(123, 104, 238, 0.5), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                suggestedTrack.albumArtUrl,
                width: 160,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
          ),
        Text(
          suggestedTrack.name,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          suggestedTrack.artist,
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        if (suggestionReason != null && suggestionReason!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ReasonCard(reason: suggestionReason!),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
              onPressed: onPlayPause,
              color: Color.fromRGBO(123, 104, 238, 1),
              iconSize: 32,
              tooltip: isPlaying ? 'Pause' : 'Play',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.thumb_up, color: Colors.white),
              onPressed: onLike,
              tooltip: 'Like',
            ),
            IconButton(
              icon: Icon(Icons.thumb_down, color: Colors.white),
              onPressed: onDislike,
              tooltip: 'Dislike',
            ),
            IconButton(
              icon: Icon(Icons.library_add, color: Colors.white),
              onPressed: onAddToLibrary,
              tooltip: 'Add to Library',
            ),
            IconButton(
              icon: Icon(Icons.skip_next, color: Colors.white),
              onPressed: onSkipSuggestion,
              tooltip: 'Skip',
            ),
          ],
        ),
      ],
    );
  }
} 
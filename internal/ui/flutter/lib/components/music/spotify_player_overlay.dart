import 'dart:ui';
import 'package:flutter/material.dart';
import 'music_section_controller.dart';
import '../../theme.dart';

class SpotifyPlayerOverlay extends StatelessWidget {
  final MusicSectionController controller;

  const SpotifyPlayerOverlay({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.isAuthenticated || controller.nowPlayingTrack == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withValues(alpha: 0.95),
          border: const Border(
            top: BorderSide(color: AppTheme.surfaceHover, width: 1),
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Album art
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: controller.nowPlayingTrack!.albumArtUrl.isNotEmpty
                      ? Image.network(
                          controller.nowPlayingTrack!.albumArtUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 64,
                          height: 64,
                          color: AppTheme.surfaceHover,
                          child: const Icon(
                            Icons.music_note,
                            color: AppTheme.textTertiary,
                            size: 24,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                
                // Track info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        controller.nowPlayingTrack!.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.nowPlayingTrack!.artist,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Play/pause button
                IconButton(
                  onPressed: () {
                    if (controller.isPlaybackPaused) {
                      controller.resumePlayback();
                    } else {
                      controller.pausePlayback();
                    }
                  },
                  icon: Icon(
                    controller.isPlaybackPaused ? Icons.play_arrow : Icons.pause,
                    color: AppTheme.textPrimary,
                    size: 32,
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
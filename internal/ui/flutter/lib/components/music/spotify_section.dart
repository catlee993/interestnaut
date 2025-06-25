import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'music_section_controller.dart';
import 'library/library_section.dart';
import '../../theme.dart';

class SpotifySection extends StatelessWidget {
  final MusicSectionController controller;

  const SpotifySection({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32.0), // Add spacing before the title
        Center(
          child: AppTheme.themedLibraryHeader('SPOTIFY LIBRARY'),
        ),
        const SizedBox(height: 24.0), // Add spacing between title and content
        _buildSpotifyContent(context),
      ],
    );
  }

  Widget _buildSpotifyContent(BuildContext context) {
    if (!controller.isAuthenticated) {
      return _buildSpotifyAuthPrompt(context);
    }

    // Only show loading spinner for initial load, not pagination
    if (controller.isLoadingLibrary && controller.likedTracks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.spotifyGreen,
        ),
      );
    }

    if (controller.likedTracks.isEmpty && !controller.isLoadingLibrary) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No liked tracks found in your Spotify library.',
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Show tracks even during pagination - LibrarySection will handle pagination state
    return Column(
      children: [
        // Optional: Add a subtle pagination indicator
        if (controller.isPaginating)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.spotifyGreen,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Loading...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        // Use the full-featured LibrarySection with pagination and controls
        LibrarySection(
          savedTracks: controller.likedTracks,
          currentPage: controller.currentSpotifyPage,
          totalTracks: controller.totalSpotifyTracks,
          itemsPerPage: controller.itemsPerPage,
          nowPlayingTrack: controller.nowPlayingTrack,
          isPlaybackPaused: controller.isPlaybackPaused,
          onPlay: controller.playSpotifyTrack,
          onSave: controller.saveSpotifyTrack,
          onRemove: controller.removeSpotifyTrack,
          onNextPage: controller.nextSpotifyPage,
          onPrevPage: controller.prevSpotifyPage,
          showHeader: false, // We already have the header above
        ),
      ],
    );
  }

  Widget _buildSpotifyAuthPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
      child: Column(
        children: [
          const Icon(
            FontAwesomeIcons.spotify,
            color: AppTheme.spotifyGreen,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Connect to Spotify',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect your Spotify account to see your liked tracks and play music.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => controller.authenticateSpotify(context),
            icon: const Icon(FontAwesomeIcons.spotify),
            label: const Text('Connect Spotify'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.spotifyGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
} 
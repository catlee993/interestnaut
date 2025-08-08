import 'package:flutter/material.dart';
import 'music_section_controller.dart';
import 'library/library_section.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/spotify_branding.dart';

class SpotifySection extends StatelessWidget {
  final MusicSectionController controller;

  const SpotifySection({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // Hide entire section (including header) if not connected
    if (!controller.isAuthenticated) {
      return const SizedBox.shrink();
    }
    
    return Column(
      children: [
        const SizedBox(height: 32.0), // Add spacing before the title
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpotifyBranding(
                type: SpotifyBrandingType.fullLogo,
                size: SpotifyBrandingSize.medium,
                color: SpotifyBrandingColor.green,
                showAttribution: false,
              ),
              const SizedBox(width: 16),
              Transform(
                transform: Matrix4.identity()..scale(AppTheme.libraryHeaderScaleX, 1.0),
                alignment: Alignment.center,
                child: Text(
                  'LIBRARY',
                  style: AppTheme.libraryHeaderMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24.0), // Add spacing between title and content
        _buildSpotifyContent(context),
      ],
    );
  }

  Widget _buildSpotifyContent(BuildContext context) {
    // Only show loading spinner for initial load, not pagination
    if (controller.isLoadingLibrary && controller.likedTracks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.spotifyGreen,
        ),
      );
    }

    if (controller.likedTracks.isEmpty && !controller.isLoadingLibrary) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'ADD SOMETHING TO YOUR LIKES',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w200,
              letterSpacing: 1.5, // Wide letter spacing for Interestnaut theme
            ),
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


} 
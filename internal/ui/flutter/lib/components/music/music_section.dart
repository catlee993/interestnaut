import 'package:flutter/material.dart';
import '../common/media_section_wrapper.dart';
import '../common/media_library_grid.dart';
import 'music_section_controller.dart';
import 'spotify_section.dart';
import 'spotify_player_overlay.dart';

class MusicSection extends StatefulWidget {
  const MusicSection({super.key});

  @override
  State<MusicSection> createState() => _MusicSectionState();
  
  // Static method to refresh favorites from search
  static void refreshFavoritesFromSearch() {
    final state = _MusicSectionState._currentState;
    if (state != null && state.mounted) {
      state._controller?.loadDbLibrary();
    }
  }

  // Static method to refresh playlist from search
  static void refreshPlaylistFromSearch() {
    final state = _MusicSectionState._currentState;
    if (state != null && state.mounted) {
      state._controller?.loadDbWatchlist();
    }
  }
}

class _MusicSectionState extends State<MusicSection> {
  // Static state reference for search refresh
  static _MusicSectionState? _currentState;
  
  MusicSectionController? _controller;

  @override
  void initState() {
    super.initState();
    // Set static reference for search refresh
    _currentState = this;
    
    // Initialize controller
    _controller = MusicSectionController();
    _controller!.addListener(_onControllerChanged);
    
    // Load initial data
    _controller!.loadDbSuggestion();
    _controller!.loadDbLibrary();
    _controller!.loadDbWatchlist();
  }

  @override
  void dispose() {
    _currentState = null;
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return loading state if controller is not yet initialized
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return MediaSectionWrapper(
      controller: _controller!,
      mediaType: 'music',
      cardFormat: CardFormat.poster, // Use poster format for main suggestion like other sections
      // Square format will still be used automatically for grid items in favorites/playlist
      additionalSections: [
        // Spotify section with authentication and library
        SpotifySection(controller: _controller!),
      ],
      playerOverlay: SpotifyPlayerOverlay(controller: _controller!),
    );
  }
}

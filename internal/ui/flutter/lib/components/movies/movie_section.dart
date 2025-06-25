import 'package:flutter/material.dart';
import '../common/media_section_wrapper.dart';
import 'movie_section_controller.dart';

class MovieSection extends StatefulWidget {
  const MovieSection({super.key});

  @override
  State<MovieSection> createState() => _MovieSectionState();
  
  // Static method to refresh favorites from search
  static void refreshFavoritesFromSearch() {
    final state = _MovieSectionState._currentState;
    if (state != null && state.mounted) {
      state._controller?.loadDbLibrary();
    }
  }

  // Static method to refresh watchlist from search
  static void refreshWatchlistFromSearch() {
    final state = _MovieSectionState._currentState;
    if (state != null && state.mounted) {
      state._controller?.loadDbWatchlist();
    }
  }
}

class _MovieSectionState extends State<MovieSection> {
  static _MovieSectionState? _currentState;
  
  MovieSectionController? _controller;

  @override
  void initState() {
    super.initState();
    _currentState = this;
    _controller = MovieSectionController();
    _controller?.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    if (_currentState == this) {
      _currentState = null;
    }
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return MediaSectionWrapper(
      controller: _controller!,
      mediaType: 'movie',
    );
  }
} 
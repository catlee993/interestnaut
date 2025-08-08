import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/media_section_wrapper.dart';
import 'tv_show_section_controller.dart';
import '../../../features/recommendations/data/recommendation_service.dart';

class TVShowSection extends StatefulWidget {
  const TVShowSection({super.key});

  @override
  State<TVShowSection> createState() => _TVShowSectionState();
  
  // Static method to refresh favorites from search
  static void refreshFavoritesFromSearch({String? title, String? primaryCreator}) {
    final state = _TVShowSectionState._currentState;
    if (state != null && state.mounted) {
      state._controller?.loadDbLibrary();
      
      // Sync current suggestion state if search item matches
      if (title != null && primaryCreator != null) {
        state._controller?.syncCurrentSuggestionFromSearch(
          title: title,
          primaryCreator: primaryCreator,
        );
      }
    }
  }

  // Static method to refresh watchlist from search
  static void refreshWatchlistFromSearch({String? title, String? primaryCreator}) {
    final state = _TVShowSectionState._currentState;
    if (state != null && state.mounted) {
      state._controller?.loadDbWatchlist();
      
      // Sync current suggestion state if search item matches
      if (title != null && primaryCreator != null) {
        state._controller?.syncCurrentSuggestionFromSearch(
          title: title,
          primaryCreator: primaryCreator,
        );
      }
    }
  }
}

class _TVShowSectionState extends State<TVShowSection> {
  // Static state reference for search refresh
  static _TVShowSectionState? _currentState;
  
  TVShowSectionController? _controller;

  @override
  void initState() {
    super.initState();
    // Set static reference for search refresh
    _currentState = this;
    
    // Initialize controller with recommendation service from provider
    final recommendationService = Provider.of<RecommendationService>(context, listen: false);
    _controller = TVShowSectionController(recommendationService);
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
      mediaType: 'tv_show',
    );
  }
} 
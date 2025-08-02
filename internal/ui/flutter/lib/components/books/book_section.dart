import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../common/media_section_wrapper.dart';
import 'book_section_controller.dart';
import '../../services/recommendation_service.dart';

class BookSection extends StatefulWidget {
  const BookSection({super.key});

  @override
  State<BookSection> createState() => _BookSectionState();
  
  // Static method to refresh favorites from search
  static void refreshFavoritesFromSearch({String? title, String? primaryCreator}) {
    final state = _BookSectionState._currentState;
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

  // Static method to refresh reading list from search
  static void refreshReadingListFromSearch({String? title, String? primaryCreator}) {
    final state = _BookSectionState._currentState;
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

class _BookSectionState extends State<BookSection> {
  // Static state reference for search refresh
  static _BookSectionState? _currentState;
  
  BookSectionController? _controller;

  @override
  void initState() {
    super.initState();
    // Set static reference for search refresh
    _currentState = this;
    
    // Initialize controller with recommendation service from provider
    final recommendationService = Provider.of<RecommendationService>(context, listen: false);
    _controller = BookSectionController(recommendationService);
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
      mediaType: 'book',
    );
  }
}
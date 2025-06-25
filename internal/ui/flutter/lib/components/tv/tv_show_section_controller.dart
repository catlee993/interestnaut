import '../common/base_media_section_controller.dart';
import '../../services/recommendation_service.dart';
import 'package:flutter/foundation.dart';

/// TV show-specific controller that extends the base controller
/// TV shows have no unique behavior, so this is just a thin wrapper
class TVShowSectionController extends BaseMediaSectionController {
  TVShowSectionController() : super('tv_show');
  
  // TV shows don't need any special behavior beyond the base controller
  // All the suggestion loading, library management, etc. is handled by the base class
  
  @override
  void onSuggestionLiked(MediaSuggestion suggestion) {
    // TV show-specific behavior when suggestion is liked
    debugPrint('TV show suggestion liked: ${suggestion.title}');
  }
  
  @override
  void onSuggestionDisliked(MediaSuggestion suggestion) {
    // TV show-specific behavior when suggestion is disliked
    debugPrint('TV show suggestion disliked: ${suggestion.title}');
  }
  
  @override
  void onSuggestionSkipped(MediaSuggestion suggestion) {
    // TV show-specific behavior when suggestion is skipped
    debugPrint('TV show suggestion skipped: ${suggestion.title}');
  }
  
  @override
  void onSuggestionFavorited(MediaSuggestion suggestion) {
    // TV show-specific behavior when suggestion is favorited
    debugPrint('TV show suggestion favorited: ${suggestion.title}');
  }
  
  @override
  void onSuggestionAddedToWatchlist(MediaSuggestion suggestion) {
    // TV show-specific behavior when suggestion is added to watchlist
    debugPrint('TV show suggestion added to watchlist: ${suggestion.title}');
  }
} 
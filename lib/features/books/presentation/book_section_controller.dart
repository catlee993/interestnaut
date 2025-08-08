import '../../../shared/widgets/base_media_section_controller.dart';
import '../../../features/recommendations/data/recommendation_service.dart';
import 'package:flutter/foundation.dart';

/// Book-specific controller that extends the base controller
/// Books have no unique behavior, so this is just a thin wrapper
class BookSectionController extends BaseMediaSectionController {
  BookSectionController(RecommendationService recommendationService) : super('book', recommendationService);
  
  // Books don't need any special behavior beyond the base controller
  // All the suggestion loading, library management, etc. is handled by the base class
  
  @override
  void onSuggestionLiked(MediaSuggestion suggestion) {
    // Book-specific behavior when suggestion is liked
    debugPrint('Book suggestion liked: ${suggestion.title}');
  }
  
  @override
  void onSuggestionDisliked(MediaSuggestion suggestion) {
    // Book-specific behavior when suggestion is disliked
    debugPrint('Book suggestion disliked: ${suggestion.title}');
  }
  
  @override
  void onSuggestionSkipped(MediaSuggestion suggestion) {
    // Book-specific behavior when suggestion is skipped
    debugPrint('Book suggestion skipped: ${suggestion.title}');
  }
  
  @override
  void onSuggestionFavorited(MediaSuggestion suggestion) {
    // Book-specific behavior when suggestion is favorited
    debugPrint('Book suggestion favorited: ${suggestion.title}');
  }
  
  @override
  void onSuggestionAddedToWatchlist(MediaSuggestion suggestion) {
    // Book-specific behavior when suggestion is added to reading list
    debugPrint('Book suggestion added to reading list: ${suggestion.title}');
  }
} 
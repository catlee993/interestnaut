import '../common/base_media_section_controller.dart';
import '../../services/recommendation_service.dart';

/// Book-specific controller that extends the base controller
/// Books have no unique behavior, so this is just a thin wrapper
class BookSectionController extends BaseMediaSectionController {
  BookSectionController() : super('book');
  
  // Books don't need any special behavior beyond the base controller
  // All the suggestion loading, library management, etc. is handled by the base class
  
  @override
  void onSuggestionLiked(MediaSuggestion suggestion) {
    // Book-specific behavior when suggestion is liked (if needed)
    // For now, just use the default behavior
  }
  
  @override
  void onSuggestionDisliked(MediaSuggestion suggestion) {
    // Book-specific behavior when suggestion is disliked (if needed)
    // For now, just use the default behavior
  }
  
  @override
  void onSuggestionSkipped(MediaSuggestion suggestion) {
    // Book-specific behavior when suggestion is skipped (if needed)
    // For now, just use the default behavior
  }
  
  @override
  void onSuggestionFavorited(MediaSuggestion suggestion) {
    // Book-specific behavior when suggestion is favorited (if needed)
    // For now, just use the default behavior
  }
  
  @override
  void onSuggestionAddedToWatchlist(MediaSuggestion suggestion) {
    // Book-specific behavior when suggestion is added to reading list (if needed)
    // For now, just use the default behavior
  }
} 
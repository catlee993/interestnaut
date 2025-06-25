import '../common/base_media_section_controller.dart';
import '../../services/recommendation_service.dart';

/// Movie-specific controller that extends the base controller
/// Movies have no unique behavior, so this is just a thin wrapper
class MovieSectionController extends BaseMediaSectionController {
  MovieSectionController() : super('movie');
  
  // Movies don't need any special behavior beyond the base controller
  // All the suggestion loading, library management, etc. is handled by the base class
  
  @override
  void onSuggestionLiked(MediaSuggestion suggestion) {
    // Movie-specific behavior when suggestion is liked (if needed)
    // For now, just use the default behavior
  }
  
  @override
  void onSuggestionDisliked(MediaSuggestion suggestion) {
    // Movie-specific behavior when suggestion is disliked (if needed)
    // For now, just use the default behavior
  }
  
  @override
  void onSuggestionSkipped(MediaSuggestion suggestion) {
    // Movie-specific behavior when suggestion is skipped (if needed)
    // For now, just use the default behavior
  }
  
  @override
  void onSuggestionFavorited(MediaSuggestion suggestion) {
    // Movie-specific behavior when suggestion is favorited (if needed)
    // For now, just use the default behavior
  }
  
  @override
  void onSuggestionAddedToWatchlist(MediaSuggestion suggestion) {
    // Movie-specific behavior when suggestion is added to watchlist (if needed)
    // For now, just use the default behavior
  }
} 
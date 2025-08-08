import '../../../shared/widgets/base_media_section_controller.dart';
import '../../../features/recommendations/data/recommendation_service.dart';
import 'package:flutter/foundation.dart';

/// Game-specific controller that extends the base controller
/// Games have no unique behavior, so this is just a thin wrapper
class GameSectionController extends BaseMediaSectionController {
  GameSectionController(RecommendationService recommendationService) : super('video_game', recommendationService);
  
  // Override base controller methods for game-specific behavior
  @override
  void onSuggestionLiked(MediaSuggestion suggestion) {
    // Game-specific behavior when suggestion is liked
    debugPrint('Game suggestion liked: ${suggestion.title}');
  }
  
  @override
  void onSuggestionDisliked(MediaSuggestion suggestion) {
    // Game-specific behavior when suggestion is disliked
    debugPrint('Game suggestion disliked: ${suggestion.title}');
  }
  
  @override
  void onSuggestionSkipped(MediaSuggestion suggestion) {
    // Game-specific behavior when suggestion is skipped
    debugPrint('Game suggestion skipped: ${suggestion.title}');
  }
  
  @override
  void onSuggestionFavorited(MediaSuggestion suggestion) {
    // Game-specific behavior when suggestion is favorited
    debugPrint('Game suggestion favorited: ${suggestion.title}');
  }
  
  @override
  void onSuggestionAddedToWatchlist(MediaSuggestion suggestion) {
    // Game-specific behavior when suggestion is added to playlist
    debugPrint('Game suggestion added to playlist: ${suggestion.title}');
  }
} 
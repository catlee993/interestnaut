import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/recommendations/data/recommendation_service.dart';

/// Event types for recommendation updates
enum RecommendationEventType {
  suggestionReady,
  suggestionError,
  suggestionStarted,
  suggestionProgress,  // New event for progress updates
}

/// Event data for recommendation updates
class RecommendationEvent {
  final RecommendationEventType type;
  final String mediaType;
  final MediaSuggestion? suggestion;
  final String? error;
  final double? progress;  // Progress percentage (0.0-1.0)
  final String? progressMessage;  // Human-readable progress message
  final DateTime timestamp;

  RecommendationEvent({
    required this.type,
    required this.mediaType,
    this.suggestion,
    this.error,
    this.progress,
    this.progressMessage,
  }) : timestamp = DateTime.now();
}

/// Service for managing recommendation events using streams
class RecommendationEventService {
  static final RecommendationEventService _instance = RecommendationEventService._internal();
  factory RecommendationEventService() => _instance;
  RecommendationEventService._internal();

  // Stream controller for recommendation events
  final StreamController<RecommendationEvent> _eventController = 
      StreamController<RecommendationEvent>.broadcast();

  /// Stream of recommendation events
  Stream<RecommendationEvent> get events => _eventController.stream;

  /// Stream filtered by media type
  Stream<RecommendationEvent> eventsForMediaType(String mediaType) {
    return events.where((event) => event.mediaType == mediaType);
  }

  /// Emit a suggestion ready event
  void emitSuggestionReady(String mediaType, MediaSuggestion suggestion) {
    debugPrint('📡 Emitting suggestion ready event for $mediaType: ${suggestion.title}');
    _eventController.add(RecommendationEvent(
      type: RecommendationEventType.suggestionReady,
      mediaType: mediaType,
      suggestion: suggestion,
    ));
  }

  /// Emit a suggestion error event
  void emitSuggestionError(String mediaType, String error) {
    debugPrint('📡 Emitting suggestion error event for $mediaType: $error');
    _eventController.add(RecommendationEvent(
      type: RecommendationEventType.suggestionError,
      mediaType: mediaType,
      error: error,
    ));
  }

  /// Emit a suggestion progress event
  void emitSuggestionProgress(String mediaType, double progress, String message) {
    debugPrint('📡 Emitting suggestion progress event for $mediaType: ${(progress * 100).toStringAsFixed(1)}% - $message');
    _eventController.add(RecommendationEvent(
      type: RecommendationEventType.suggestionProgress,
      mediaType: mediaType,
      progress: progress,
      progressMessage: message,
    ));
  }

  /// Emit a suggestion started event
  void emitSuggestionStarted(String mediaType) {
    debugPrint('📡 Emitting suggestion started event for $mediaType');
    _eventController.add(RecommendationEvent(
      type: RecommendationEventType.suggestionStarted,
      mediaType: mediaType,
    ));
  }

  /// Dispose resources
  void dispose() {
    _eventController.close();
  }
} 
import 'package:flutter/foundation.dart';
import 'package:interestnaut/services/llama_service.dart';
import 'package:interestnaut/services/go_bindings.dart';
import 'package:interestnaut/services/model_constants.dart';

// --- Data Models ---

enum SuggestionStatus {
  pending,
  skipped,
  liked,
  disliked,
  added, // Favorited
  archived, // User has removed/deleted it from view, kept for history
}

class MediaSuggestion {
  final String id; // Assuming ID is non-nullable, assigned by Go DB
  final String query; // The original LLM query or bot's raw suggestion text
  final String mediaType; // e.g., "music", "movie", "book"
  final String? title; // Enriched title from Wikidata/Wikipedia
  final String? artist; // Specific for music, adapt as needed for other types
  final String? album;  // Specific for music
  final String? coverArtUrl; // URL for cover art
  final String? description; // Enriched description
  final String? wikiUrl;
  final String? wikidataId;
  final String? botReasoning; // LLM's reasoning for the suggestion, or Go's reasoning for match
  SuggestionStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MediaSuggestion({
    required this.id,
    required this.query,
    required this.mediaType,
    this.title,
    this.artist,
    this.album,
    this.coverArtUrl,
    this.description,
    this.wikiUrl,
    this.wikidataId,
    this.botReasoning,
    this.status = SuggestionStatus.pending,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MediaSuggestion.fromJson(Map<String, dynamic> json) {
    return MediaSuggestion(
      id: json['id'] as String,
      query: json['query'] as String,
      mediaType: json['media_type'] as String,
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      coverArtUrl: json['cover_art_url'] as String?,
      description: json['description'] as String?,
      wikiUrl: json['wiki_url'] as String?,
      wikidataId: json['wikidata_id'] as String?,
      botReasoning: json['bot_reasoning'] as String?,
      status: SuggestionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => SuggestionStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'media_type': mediaType,
        'title': title,
        'artist': artist,
        'album': album,
        'cover_art_url': coverArtUrl,
        'description': description,
        'wiki_url': wikiUrl,
        'wikidata_id': wikidataId,
        'bot_reasoning': botReasoning,
        'status': status.toString().split('.').last,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  String toPromptSummary() {
    String summary = title ?? query;
    if (mediaType == 'music' && artist != null) summary = '$artist - $summary';
    return '$summary - Status: ${status.toString().split('.').last}';
  }
}

class RecommendationService extends ChangeNotifier {
  final LlamaService _llamaService;
  final RecommendationBindings _recommendationBindings;
  final List<MediaSuggestion> _suggestions = [];
  bool _isLoading = false; // Global loading indicator
  String? _error;

  // New fields for proactive queue management
  final List<String> _managedMediaTypes = ['music', 'movie', 'book']; // TODO: Make this configurable or dynamic
  final Set<String> _activeMediaQueuesBeingFilled = {};
  String? _currentlyProcessingMediaType; // For UI feedback on which queue is active
  final int _minSuggestionsQueue = 3; // Target minimum pending suggestions

  RecommendationService(this._llamaService, this._recommendationBindings);

  List<MediaSuggestion> get suggestions => _suggestions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentlyProcessingMediaType => _currentlyProcessingMediaType;

  // --- Initialization and Proactive Queue Management ---

  Future<void> initializeAndPrefillQueues() async {
    if (_isLoading && _activeMediaQueuesBeingFilled.isNotEmpty) {
      debugPrint('Initialization or prefill already in progress.');
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Clear local cache and fetch ALL existing suggestions for managed types from DB.
      _suggestions.clear();
      for (final mediaType in _managedMediaTypes) {
        try {
          debugPrint('Fetching initial suggestions for $mediaType...');
          final suggestionsForType = await _recommendationBindings.getAllSuggestions(mediaType, statusFilter: '');
          _suggestions.addAll(suggestionsForType);
          debugPrint('Fetched ${suggestionsForType.length} suggestions for $mediaType.');
        } catch (e) {
          debugPrint('Error fetching initial suggestions for $mediaType: $e');
          // Continue to other media types even if one fails
        }
      }
      // Notify once after all initial data is potentially loaded.
      // This ensures the UI has access to all existing liked/skipped items etc.
      notifyListeners();

      // 2. For each media type, ensure its PENDING queue is at the minimum.
      for (final mediaType in _managedMediaTypes) {
        debugPrint('Ensuring suggestion queue for $mediaType post-initialization...');
        // We await each call to process media types sequentially for LLM calls.
        await ensureSuggestionQueue(mediaType);
      }
      debugPrint('Initial prefill of all media type queues completed.');

    } catch (e) {
      _error = 'Failed during initial suggestion prefill: $e';
      debugPrint(_error);
    } finally {
      // Clear global loading state only if no specific queues are still being filled
      // (ensureSuggestionQueue manages _activeMediaQueuesBeingFilled)
      if (_activeMediaQueuesBeingFilled.isEmpty) {
        _isLoading = false;
        _currentlyProcessingMediaType = null;
      }
      notifyListeners();
      debugPrint('Finished initializing and prefilling queues.');
    }
  }

  // Renamed from fetchInitialSuggestions and functionality merged into initializeAndPrefillQueues & ensureSuggestionQueue
  // Future<void> fetchInitialSuggestions(String mediaType, {String statusFilter = ''}) async { ... }

  Future<void> ensureSuggestionQueue(String mediaType) async {
    if (!_managedMediaTypes.contains(mediaType)) {
      debugPrint('ensureSuggestionQueue called for unmanaged media type: $mediaType');
      return;
    }

    if (_activeMediaQueuesBeingFilled.contains(mediaType)) {
      debugPrint('Suggestion queue for $mediaType is already being processed.');
      return;
    }
    _activeMediaQueuesBeingFilled.add(mediaType);
    _currentlyProcessingMediaType = mediaType;
    
    bool needsGlobalLoadingUpdate = !_isLoading; // Only set global isLoading if not already set
    if (needsGlobalLoadingUpdate) {
      _isLoading = true;
      notifyListeners(); // Notify global loading start
    }

    String? loopError;
    bool madeChangesThisRun = false;

    try {
      int currentPendingCount = _suggestions
          .where((s) => s.mediaType == mediaType && s.status == SuggestionStatus.pending)
          .length;
      debugPrint('Queue for $mediaType: $currentPendingCount pending, target $_minSuggestionsQueue.');

      // Check LlamaService state before entering the loop
      if (!_llamaService.isRunning) {
        debugPrint('\u{26A0} LlamaService not running - attempting initialization');
        try {
          // Check if LlamaService can be initialized
          // Get the model path first
          final modelPath = await LlamaService.getModelPath();
          
          // Call initialize with correct parameters
          bool llamaInitialized = await _llamaService.initialize(
            modelPath,
            toastCallback: (msg, {isError = false}) {
              debugPrint('LLAMA init: $msg${isError ? " (ERROR)" : ""}');
            }
          );
          
          if (llamaInitialized) {
            debugPrint('\u{2705} Successfully initialized LlamaService');
          } else {
            loopError = 'Failed to initialize LlamaService. Cannot generate suggestions.';
            debugPrint('\u{274C} $loopError');
            return; // Exit early
          }
        } catch (e) {
          loopError = 'Error initializing LlamaService: $e';
          debugPrint('\u{274C} $loopError');
          return; // Exit early
        }
      }

      while (currentPendingCount < _minSuggestionsQueue) {
        if (!_llamaService.isRunning) {
          loopError = 'LlamaService not running. Cannot generate suggestions for $mediaType.';
          debugPrint('\u{274C} $loopError');
          break; 
        }

        debugPrint('\u{1F504} Generating new suggestion for $mediaType. Current pending: $currentPendingCount');
        try {
          // Get the appropriate prompt template for the media type
          final promptTemplate = getPromptTemplateForMediaType(mediaType);
            
          // Get previous suggestions for this media type to inform the LLM
          final history = _suggestions
              .where((s) => s.mediaType == mediaType) 
              .map((s) => s.toPromptSummary())
              .take(10) // Show the last 10 suggestions to provide more context
              .toList();
                
          // Format the prompt with previous suggestions
          final formattedPrompt = formatPromptWithPreviousSuggestions(promptTemplate, history);

          debugPrint('\u{270D} Prompt for $mediaType: ${formattedPrompt.length} chars');
          final String rawSuggestionText = await _llamaService.generateFullResponse(formattedPrompt);
          
          if (rawSuggestionText.trim().isEmpty) {
            debugPrint('\u{26A0} LLM returned an empty suggestion for $mediaType. Skipping this attempt.');
            // Small delay before continuing to avoid rapid retries
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          }
          
          debugPrint('\u{2705} Generated suggestion for $mediaType: "${rawSuggestionText.trim()}"');
          String llmReasoning = 'Suggested by LLM based on general knowledge and previous interactions.';

          debugPrint('\u{1F50D} Finding and saving suggestion via Go FFI...');
          final newSuggestion = await _recommendationBindings.findAndSaveSuggestion(
            rawSuggestionText.trim(),
            mediaType,
            llmReasoning,
          );
          
          // Add to local cache if not already present (should be new from DB)
          if (!_suggestions.any((s) => s.id == newSuggestion.id)) {
              _suggestions.add(newSuggestion);
              madeChangesThisRun = true;
              debugPrint('\u{2705} Added new suggestion ${newSuggestion.id} for $mediaType: "${newSuggestion.title ?? newSuggestion.query}"');
          } else {
              debugPrint('\u{26A0} Suggestion ${newSuggestion.id} for $mediaType already in local cache. This might be unexpected.');
          }
          
          currentPendingCount = _suggestions
              .where((s) => s.mediaType == mediaType && s.status == SuggestionStatus.pending)
              .length;
          
          if (madeChangesThisRun) {
             notifyListeners(); // Notify after each successful addition for UI responsiveness
             madeChangesThisRun = false; // Reset for next potential addition in loop
          }
        } catch (e) {
          debugPrint('\u{274C} Error generating suggestion for $mediaType: $e');
          // Save error to provide feedback but don't stop trying for minimum queue
          loopError = 'Failed to generate a suggestion for $mediaType: $e';
          // Break out of the loop if we encounter an error to avoid too many rapid failures
          break;
        }
      }
      debugPrint('${loopError == null ? "\u{2705}" : "\u{26A0}"} Queue processing for $mediaType completed ${loopError == null ? "successfully" : "with errors"}. Current pending count: $currentPendingCount');
    } catch (e) {
      // Catch errors from initial count or other unexpected issues within the try block for the media type
      loopError = 'Error during suggestion queue processing for $mediaType: $e';
      debugPrint('\u{274C} $loopError');
    }
    finally {
      _activeMediaQueuesBeingFilled.remove(mediaType);
      if (loopError != null) _error = loopError;

      if (_activeMediaQueuesBeingFilled.isEmpty) {
        _isLoading = false; // Clear global loading if all specific queues are done
        _currentlyProcessingMediaType = null;
      }
      // Always notify at the end of processing for a specific media type, 
      // regardless of global _isLoading, to update _currentlyProcessingMediaType or _error.
      notifyListeners();
      debugPrint('Finished ensuring suggestion queue for $mediaType.');
    }
  }


  Future<void> updateSuggestionStatus(String suggestionId, SuggestionStatus newStatus) async {
    final index = _suggestions.indexWhere((s) => s.id == suggestionId);
    if (index == -1) {
      _error = 'Suggestion with ID $suggestionId not found for status update.';
      debugPrint(_error);
      notifyListeners();
      return;
    }

    var suggestion = _suggestions[index];
    final originalStatus = suggestion.status;
    final mediaType = suggestion.mediaType;

    // Optimistic UI update
    suggestion.status = newStatus;
    // Create a new instance for ChangeNotifier to detect change if MediaSuggestion is complex
    _suggestions[index] = MediaSuggestion.fromJson(suggestion.toJson()); 
    notifyListeners();

    try {
      final newStatusString = newStatus.toString().split('.').last;
      await _recommendationBindings.updateSuggestionStatus(suggestion.id, newStatusString);
      debugPrint('Updated status for suggestion ${suggestion.id} to $newStatusString in DB.');

      // Successfully updated in DB. Now ensure the queue for this media type is topped up.
      await ensureSuggestionQueue(mediaType);

    } catch (e) {
      _error = 'Failed to update suggestion status for $suggestionId to $newStatus: $e';
      debugPrint(_error);
      // Revert optimistic UI update on error
      suggestion.status = originalStatus;
      _suggestions[index] = MediaSuggestion.fromJson(suggestion.toJson());
      notifyListeners();
    }
  }

  Future<void> deleteSuggestion(String suggestionId) async {
    debugPrint('RecommendationService: Attempting to "delete" (archive) suggestion $suggestionId');
    final suggestionIndex = _suggestions.indexWhere((s) => s.id == suggestionId);
    if (suggestionIndex == -1) {
      _error = 'Suggestion with ID $suggestionId not found for deletion.';
      debugPrint(_error);
      return;
    }

    final suggestion = _suggestions[suggestionIndex];
    final originalStatus = suggestion.status;

    // Update status to archived in the backend
    try {
      // Instead of a direct delete, update its status
      await _recommendationBindings.updateSuggestionStatus(suggestionId, SuggestionStatus.archived.name);
      // No need to call a non-existent _recommendationBindings.deleteSuggestion(suggestionId);
      
      // If successful, update local cache and notify
      _suggestions.removeAt(suggestionIndex);
      notifyListeners();
      debugPrint('RecommendationService: Suggestion $suggestionId archived and removed from local cache.');

      // Trigger queue refilling for the affected media type
      // Use a set to avoid redundant calls if multiple suggestions of the same type are acted upon quickly
      ensureSuggestionQueue(suggestion.mediaType).catchError((e) {
        // Log error from ensureSuggestionQueue, but don't let it crash deleteSuggestion
        debugPrint('Error ensuring suggestion queue after archiving suggestion $suggestionId: $e');
      });

    } catch (e) {
      _error = 'Failed to archive suggestion $suggestionId: $e';
      debugPrint(_error);
      // Optionally, revert local changes if backend update fails, though current model is remove then refill
      // For now, we assume the queue refill logic will handle inconsistencies or rely on next full init.
      debugPrint('Error during archiving suggestion $suggestionId: $e. Suggestion might still be in local cache with status $originalStatus or removed.');
      // If we had kept it in the list and only changed status:
      // _suggestions[suggestionIndex] = suggestion.copyWith(status: originalStatus);
      notifyListeners(); // Notify even on error to reflect potential state changes or error messages
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  List<MediaSuggestion> getSuggestionsForMediaType(String mediaType, {SuggestionStatus? status}) {
    var filtered = _suggestions.where((s) => s.mediaType == mediaType);
    if (status != null) {
      filtered = filtered.where((s) => s.status == status);
    }
    return filtered.toList();
  }
}

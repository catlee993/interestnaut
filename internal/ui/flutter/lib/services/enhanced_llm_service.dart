import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sqlite_db.dart';
import 'llama_service.dart';
import 'recommendation_service.dart';
import '../models.dart';

/// Enhanced LLM Service for intelligent recommendation improvement
/// Implements two-stage LLM processing:
/// 1. User Profile Distillation (background, cached)
/// 2. Contextual Reasoning (real-time, fast)
class EnhancedLLMService {
  static final EnhancedLLMService _instance = EnhancedLLMService._internal();
  factory EnhancedLLMService() => _instance;
  EnhancedLLMService._internal();

  final LlamaService _llamaService = LlamaService();
  final SQLiteDatabase _db = SQLiteDatabase();
  
  // Cache for user preference profiles
  final Map<String, UserPreferenceProfile> _profileCache = {};
  Timer? _profileUpdateTimer;
  
  /// Initialize the enhanced LLM service
  Future<void> init() async {
    await _llamaService.initializeAuto();
    await _db.init();
    
    // Start background profile updates every 5 minutes
    _profileUpdateTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _updateUserProfiles(),
    );
    
    debugPrint('Enhanced LLM Service initialized');
  }

  /// Generate enhanced reasoning using user history + vector result
  Future<String> generateEnhancedReasoning({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    double? similarity,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    debugPrint('🚀 [ENHANCED] Starting enhanced reasoning for $mediaType: "$mediaTitle"');
    debugPrint('🚀 [ENHANCED] Query: "$userQuery", Artist: $artist, Themes: $themes');
    
    try {
      // Step 1: Get or generate user preference profile (cached)
      debugPrint('🚀 [ENHANCED] Step 1: Getting user preference profile...');
      final profile = await _getUserPreferenceProfile(mediaType);
      debugPrint('🚀 [ENHANCED] Profile loaded: ${profile.preferredThemes.length} themes, ${profile.preferredArtists.length} artists');
      
      // Step 2: Generate contextual reasoning with user profile
      debugPrint('🚀 [ENHANCED] Step 2: Generating contextual reasoning...');
      final reasoning = await _generateContextualReasoningWithProfile(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        similarity: similarity,
        userProfile: profile,
      );
      
      stopwatch.stop();
      debugPrint('⏱️ [ENHANCED] ✅ Enhanced reasoning completed in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('📝 [ENHANCED] Final reasoning: "$reasoning"');
      
      return reasoning;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ENHANCED] Enhanced reasoning FAILED in ${stopwatch.elapsedMilliseconds}ms: $e');
      
      // Fallback to basic reasoning
      debugPrint('🔄 [ENHANCED] Falling back to basic LlamaService reasoning...');
      final basicReasoning = await _llamaService.generateExplanation(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        similarity: similarity,
      );
      
      debugPrint('🔄 [ENHANCED] Basic reasoning result: "$basicReasoning"');
      return basicReasoning;
    }
  }

  /// Get or generate user preference profile for a media type
  Future<UserPreferenceProfile> _getUserPreferenceProfile(String mediaType) async {
    // Check cache first
    if (_profileCache.containsKey(mediaType)) {
      final profile = _profileCache[mediaType]!;
      
      // Use cached profile if it's less than 1 hour old
      if (DateTime.now().difference(profile.lastUpdated).inHours < 1) {
        return profile;
      }
    }
    
    // Generate new profile in background isolate
    final profile = await _generateUserPreferenceProfile(mediaType);
    _profileCache[mediaType] = profile;
    
    return profile;
  }

  /// Generate user preference profile using user history
  Future<UserPreferenceProfile> _generateUserPreferenceProfile(String mediaType) async {
    try {
      // Get user interaction history
      final likedSuggestions = await _db.getLikedRecommendations(mediaType);
      final dislikedSuggestions = await _db.getDislikedRecommendations(mediaType);
      
      // Get user's library/favorites for this media type
      final libraryItems = await _getUserLibraryItems(mediaType);
      
      // Distill preferences using LLM
      final profile = await compute(_distillUserPreferences, {
        'mediaType': mediaType,
        'likedSuggestions': likedSuggestions.map((s) => s.toJson()).toList(),
        'dislikedSuggestions': dislikedSuggestions.map((s) => s.toJson()).toList(),
        'libraryItems': libraryItems,
      });
      
      debugPrint('✅ Generated preference profile for $mediaType: ${profile.preferredThemes.length} themes');
      
      return profile;
    } catch (e) {
      debugPrint('❌ Error generating preference profile: $e');
      return UserPreferenceProfile.empty(mediaType);
    }
  }

  /// Distill user preferences in isolate (pure computation)
  static Future<UserPreferenceProfile> _distillUserPreferences(Map<String, dynamic> params) async {
    final String mediaType = params['mediaType'];
    final List<dynamic> likedSuggestionsJson = params['likedSuggestions'];
    final List<dynamic> dislikedSuggestionsJson = params['dislikedSuggestions'];
    final List<String> libraryItems = List<String>.from(params['libraryItems']);
    
    // Parse suggestions from JSON
    final likedSuggestions = likedSuggestionsJson
        .map((json) => MediaSuggestion.fromJson(json))
        .toList();
    final dislikedSuggestions = dislikedSuggestionsJson
        .map((json) => MediaSuggestion.fromJson(json))
        .toList();
    
    // Extract themes and patterns
    final preferredThemes = <String, int>{};
    final avoidedThemes = <String, int>{};
    final preferredArtists = <String, int>{};
    final avoidedArtists = <String, int>{};
    
    // Analyze liked content
    for (final suggestion in likedSuggestions) {
      if (suggestion.themes != null) {
        final themes = suggestion.themes!.split(',').map((t) => t.trim()).toList();
        for (final theme in themes) {
          if (theme.isNotEmpty) {
            preferredThemes[theme] = (preferredThemes[theme] ?? 0) + 1;
          }
        }
      }
      
      if (suggestion.artist != null && suggestion.artist!.isNotEmpty) {
        preferredArtists[suggestion.artist!] = (preferredArtists[suggestion.artist!] ?? 0) + 1;
      }
    }
    
    // Analyze disliked content
    for (final suggestion in dislikedSuggestions) {
      if (suggestion.themes != null) {
        final themes = suggestion.themes!.split(',').map((t) => t.trim()).toList();
        for (final theme in themes) {
          if (theme.isNotEmpty) {
            avoidedThemes[theme] = (avoidedThemes[theme] ?? 0) + 1;
          }
        }
      }
      
      if (suggestion.artist != null && suggestion.artist!.isNotEmpty) {
        avoidedArtists[suggestion.artist!] = (avoidedArtists[suggestion.artist!] ?? 0) + 1;
      }
    }
    
    // Generate LLM-based user constraints
    final constraints = _generateUserConstraints(
      mediaType: mediaType,
      preferredThemes: preferredThemes,
      avoidedThemes: avoidedThemes,
      preferredArtists: preferredArtists,
      avoidedArtists: avoidedArtists,
      librarySize: libraryItems.length,
    );
    
    return UserPreferenceProfile(
      mediaType: mediaType,
      preferredThemes: preferredThemes.keys.toList(),
      avoidedThemes: avoidedThemes.keys.toList(),
      preferredArtists: preferredArtists.keys.toList(),
      avoidedArtists: avoidedArtists.keys.toList(),
      constraints: constraints,
      lastUpdated: DateTime.now(),
    );
  }

  /// Generate user constraints using LLM reasoning
  static List<String> _generateUserConstraints({
    required String mediaType,
    required Map<String, int> preferredThemes,
    required Map<String, int> avoidedThemes,
    required Map<String, int> preferredArtists,
    required Map<String, int> avoidedArtists,
    required int librarySize,
  }) {
    final constraints = <String>[];
    
    // Theme-based constraints
    if (preferredThemes.isNotEmpty) {
      final topThemes = preferredThemes.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      
      if (topThemes.length >= 3) {
        constraints.add(
          'User strongly prefers ${topThemes.take(3).map((e) => e.key).join(', ')} themes'
        );
      }
    }
    
    if (avoidedThemes.isNotEmpty) {
      final topAvoids = avoidedThemes.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      
      if (topAvoids.length >= 2) {
        constraints.add(
          'User dislikes ${topAvoids.take(2).map((e) => e.key).join(', ')} themes'
        );
      }
    }
    
    // Artist/creator-based constraints
    if (preferredArtists.isNotEmpty) {
      final topArtists = preferredArtists.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      
      if (topArtists.length >= 2) {
        final artistType = _getArtistType(mediaType);
        constraints.add(
          'User enjoys $artistType like ${topArtists.take(2).map((e) => e.key).join(', ')}'
        );
      }
    }
    
    // Library size-based constraints
    if (librarySize > 100) {
      constraints.add('User has extensive $mediaType library, suggest more niche/unique items');
    } else if (librarySize < 20) {
      constraints.add('User has small $mediaType library, suggest popular/accessible items');
    }
    
    return constraints;
  }

  /// Format user profile for LLM input
  String _formatUserProfileForLLM(UserPreferenceProfile userProfile) {
    final parts = <String>[];
    
    if (userProfile.preferredThemes.isNotEmpty) {
      parts.add(userProfile.preferredThemes.take(5).join(', '));
    }
    
    if (userProfile.preferredArtists.isNotEmpty) {
      parts.add(userProfile.preferredArtists.take(3).join(', '));
    }
    
    return parts.join('; ');
  }

  /// Get artist type label for media type
  static String _getArtistType(String mediaType) {
    switch (mediaType) {
      case 'music': return 'artists';
      case 'movie': return 'directors';
      case 'tv_show': return 'creators';
      case 'book': return 'authors';
      case 'video_game': return 'developers';
      default: return 'creators';
    }
  }

  /// Generate contextual reasoning with user profile
  Future<String> _generateContextualReasoningWithProfile({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    double? similarity,
    required UserPreferenceProfile userProfile,
  }) async {
    // Use actual LLM inference for personalized reasoning
    debugPrint('🧠 [LLM] Starting enhanced reasoning for: $mediaTitle');
    debugPrint('🧠 [LLM] User query: "$userQuery"');
    debugPrint('🧠 [LLM] User profile: ${userProfile.preferredThemes.length} themes, ${userProfile.preferredArtists.length} artists');
    
    try {
      final userProfileString = _formatUserProfileForLLM(userProfile);
      debugPrint('🧠 [LLM] Formatted user profile: "$userProfileString"');
      
      // Generate with TinyLlama
      debugPrint('🧠 [LLM] Calling TinyLlama generateReasoningExplanation...');
      final reasoning = await _llamaService.generateReasoningExplanation(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        userProfile: userProfileString,
        similarity: similarity,
      );
      
      debugPrint('🧠 [LLM] ✅ LLM reasoning SUCCESS: "$reasoning"');
      return reasoning;
    } catch (e) {
      debugPrint('❌ [LLM] LLM reasoning FAILED: $e');
      debugPrint('❌ [LLM] Stack trace: ${StackTrace.current}');
      
      // Fallback to rule-based reasoning
      debugPrint('🔄 [LLM] Using rule-based fallback...');
      final fallbackReasoning = _generateRuleBasedReasoning(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        similarity: similarity,
        userProfile: userProfile,
      );
      
      debugPrint('🔄 [LLM] Fallback reasoning: "$fallbackReasoning"');
      return fallbackReasoning;
    }
  }

  /// Build personalized prompt for LLM
  String _buildPersonalizedPrompt({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    double? similarity,
    required UserPreferenceProfile userProfile,
  }) {
    final buffer = StringBuffer();
    
    // Context setup
    buffer.writeln('You are explaining why "$mediaTitle" is recommended for someone who searched "$userQuery".');
    
    // Media details
    buffer.writeln('\nMedia: $mediaTitle');
    if (artist != null && artist.isNotEmpty && artist.toLowerCase() != 'unknown') {
      final artistType = _getArtistType(mediaType);
      buffer.writeln('$artistType: $artist');
    }
    if (themes != null && themes.isNotEmpty) {
      buffer.writeln('Themes: $themes');
    }
    if (description != null && description.isNotEmpty) {
      buffer.writeln('Description: ${description.length > 100 ? description.substring(0, 100) + '...' : description}');
    }
    
    // User preferences
    if (userProfile.preferredThemes.isNotEmpty) {
      buffer.writeln('\nUser likes: ${userProfile.preferredThemes.take(5).join(', ')}');
    }
    if (userProfile.avoidedThemes.isNotEmpty) {
      buffer.writeln('User dislikes: ${userProfile.avoidedThemes.take(3).join(', ')}');
    }
    if (userProfile.preferredArtists.isNotEmpty) {
      final artistType = _getArtistType(mediaType);
      buffer.writeln('Favorite $artistType: ${userProfile.preferredArtists.take(3).join(', ')}');
    }
    
    // Match quality
    if (similarity != null) {
      final matchQuality = similarity > 0.8 ? 'excellent' : 
                          similarity > 0.6 ? 'strong' : 
                          similarity > 0.4 ? 'good' : 'moderate';
      buffer.writeln('\nMatch quality: $matchQuality (${(similarity * 100).toInt()}%)');
    }
    
    // Instructions
    buffer.writeln('\nWrite a personalized 2-3 sentence explanation focusing on why this matches their search and preferences. Be conversational and specific.');
    buffer.write('\nExplanation:');
    
    return buffer.toString();
  }

  /// Rule-based fallback reasoning (original logic)
  String _generateRuleBasedReasoning({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    double? similarity,
    required UserPreferenceProfile userProfile,
  }) {
    final buffer = StringBuffer();
    
    // Start with base match assessment
    if (similarity != null && similarity > 0.8) {
      buffer.write('This $mediaType is an excellent match ');
    } else if (similarity != null && similarity > 0.6) {
      buffer.write('This $mediaType is a strong match ');
    } else if (similarity != null && similarity > 0.4) {
      buffer.write('This $mediaType is a good match ');
    } else {
      buffer.write('This $mediaType relates to ');
    }
    
    buffer.write('your search for "$userQuery"');
    
    // Add personalized reasoning based on user profile
    final personalizedReasons = <String>[];
    
    // Check theme alignment
    if (themes != null && themes.isNotEmpty) {
      final mediaThemes = themes.split(',').map((t) => t.trim()).toList();
      final matchingPreferred = mediaThemes
          .where((theme) => userProfile.preferredThemes.contains(theme))
          .toList();
      final matchingAvoided = mediaThemes
          .where((theme) => userProfile.avoidedThemes.contains(theme))
          .toList();
      
      if (matchingPreferred.isNotEmpty) {
        if (matchingPreferred.length == 1) {
          personalizedReasons.add('features your preferred ${matchingPreferred.first} theme');
        } else {
          personalizedReasons.add('combines your favorite ${matchingPreferred.take(2).join(' and ')} themes');
        }
      }
      
      if (matchingAvoided.isNotEmpty && matchingPreferred.isEmpty) {
        // If it has avoided themes but no preferred ones, mention it carefully
        personalizedReasons.add('explores ${matchingAvoided.first} themes in a fresh way');
      }
    }
    
    // Check artist/creator alignment
    if (artist != null && artist.isNotEmpty && artist.toLowerCase() != 'unknown') {
      if (userProfile.preferredArtists.contains(artist)) {
        final artistType = _getArtistType(mediaType);
        personalizedReasons.add('by $artist, one of your preferred $artistType');
      } else {
        final artistType = _getArtistType(mediaType);
        personalizedReasons.add('introduces you to $artist\'s distinctive style');
      }
    }
    
    // Add personalized reasons
    if (personalizedReasons.isNotEmpty) {
      buffer.write(' and ');
      if (personalizedReasons.length == 1) {
        buffer.write(personalizedReasons.first);
      } else if (personalizedReasons.length == 2) {
        buffer.write('${personalizedReasons.first} while ${personalizedReasons.last}');
      } else {
        buffer.write('${personalizedReasons.take(2).join(', ')}, among other appealing qualities');
      }
    }
    
    // Add learning insight
    if (userProfile.preferredThemes.isNotEmpty) {
      buffer.write('. Based on your history with ');
      buffer.write(userProfile.preferredThemes.take(2).join(' and '));
      buffer.write(' content, this should align well with your taste');
    }
    
    buffer.write('.');
    
    return buffer.toString();
  }

  /// Get user library items for a media type
  Future<List<String>> _getUserLibraryItems(String mediaType) async {
    // This would integrate with your existing library/favorites system
    // For now, return empty list - you'd implement based on your data structure
    try {
      final prefs = await SharedPreferences.getInstance();
      final libraryJson = prefs.getString('user_library_$mediaType');
      if (libraryJson != null) {
        final library = jsonDecode(libraryJson) as List<dynamic>;
        return library.map((item) => item.toString()).toList();
      }
    } catch (e) {
      debugPrint('Error loading library for $mediaType: $e');
    }
    return [];
  }

  /// Update user profiles in background
  Future<void> _updateUserProfiles() async {
    try {
      const mediaTypes = ['music', 'movie', 'tv_show', 'book', 'video_game'];
      
      for (final mediaType in mediaTypes) {
        // Only update if cache is stale
        if (_profileCache.containsKey(mediaType)) {
          final profile = _profileCache[mediaType]!;
          if (DateTime.now().difference(profile.lastUpdated).inHours < 1) {
            continue; // Skip if recent
          }
        }
        
        // Update profile in background
        _generateUserPreferenceProfile(mediaType).then((profile) {
          _profileCache[mediaType] = profile;
          debugPrint('🔄 Updated preference profile for $mediaType');
        }).catchError((e) {
          debugPrint('❌ Failed to update profile for $mediaType: $e');
        });
      }
    } catch (e) {
      debugPrint('❌ Error updating user profiles: $e');
    }
  }

  /// Clear cached profiles (useful for testing or user reset)
  void clearProfileCache() {
    _profileCache.clear();
    debugPrint('🗑️ Cleared preference profile cache');
  }

  /// Dispose resources
  void dispose() {
    _profileUpdateTimer?.cancel();
    _profileCache.clear();
  }
}

/// User preference profile for a specific media type
class UserPreferenceProfile {
  final String mediaType;
  final List<String> preferredThemes;
  final List<String> avoidedThemes;
  final List<String> preferredArtists;
  final List<String> avoidedArtists;
  final List<String> constraints;
  final DateTime lastUpdated;

  UserPreferenceProfile({
    required this.mediaType,
    required this.preferredThemes,
    required this.avoidedThemes,
    required this.preferredArtists,
    required this.avoidedArtists,
    required this.constraints,
    required this.lastUpdated,
  });

  factory UserPreferenceProfile.empty(String mediaType) {
    return UserPreferenceProfile(
      mediaType: mediaType,
      preferredThemes: [],
      avoidedThemes: [],
      preferredArtists: [],
      avoidedArtists: [],
      constraints: [],
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mediaType': mediaType,
      'preferredThemes': preferredThemes,
      'avoidedThemes': avoidedThemes,
      'preferredArtists': preferredArtists,
      'avoidedArtists': avoidedArtists,
      'constraints': constraints,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory UserPreferenceProfile.fromJson(Map<String, dynamic> json) {
    return UserPreferenceProfile(
      mediaType: json['mediaType'],
      preferredThemes: List<String>.from(json['preferredThemes']),
      avoidedThemes: List<String>.from(json['avoidedThemes']),
      preferredArtists: List<String>.from(json['preferredArtists']),
      avoidedArtists: List<String>.from(json['avoidedArtists']),
      constraints: List<String>.from(json['constraints']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
} 
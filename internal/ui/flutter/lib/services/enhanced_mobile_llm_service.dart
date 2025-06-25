import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'llama_service.dart';
import 'mobile_performance_config.dart';

/// Enhanced Mobile LLM Service
/// Optimized for mobile devices with response validation and fallback strategies
class EnhancedMobileLLMService {
  static final EnhancedMobileLLMService _instance = EnhancedMobileLLMService._internal();
  factory EnhancedMobileLLMService() => _instance;
  EnhancedMobileLLMService._internal();
  
  final LlamaService _llamaService = LlamaService();
  final List<String> _recentResponses = [];
  int _consecutiveFailures = 0;
  
  /// Initialize the enhanced mobile LLM service
  Future<bool> initialize() async {
    try {
      return await _llamaService.initializeAuto();
    } catch (e) {
      debugPrint('❌ Enhanced Mobile LLM initialization failed: $e');
      return false;
    }
  }
  
  /// Generate mobile-optimized explanation with validation and fallbacks
  Future<String> generateMobileExplanation({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    double? similarity,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Try LLM generation with mobile constraints
      if (_llamaService.isInitialized && _consecutiveFailures < 3) {
        final llmResponse = await _generateValidatedLLMResponse(
          userQuery: userQuery,
          mediaTitle: mediaTitle,
          mediaType: mediaType,
          artist: artist,
          themes: themes,
          description: description,
          similarity: similarity,
        );
        
        if (llmResponse != null) {
          _consecutiveFailures = 0;
          stopwatch.stop();
          
          // Record performance
          MobilePerformanceMonitor.recordSearch(
            mediaType: 'llm_generation',
            durationMs: stopwatch.elapsedMilliseconds,
            vectorsProcessed: 1,
          );
          
          return llmResponse;
        }
      }
      
      // Fallback to rule-based explanation
      _consecutiveFailures++;
      stopwatch.stop();
      
      return _generateRuleBasedExplanation(
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        similarity: similarity,
      );
      
    } catch (e) {
      _consecutiveFailures++;
      stopwatch.stop();
      debugPrint('❌ LLM generation failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      
      return _generateRuleBasedExplanation(
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        similarity: similarity,
      );
    }
  }
  
  /// Generate LLM response with validation and mobile optimizations
  Future<String?> _generateValidatedLLMResponse({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    double? similarity,
  }) async {
    try {
      // Build mobile-optimized prompt
      final prompt = _buildMobileOptimizedPrompt(
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
      );
      
             // Generate with mobile constraints
       final response = await _llamaService.generateReasoningExplanation(
         userQuery: userQuery,
         mediaTitle: mediaTitle,
         mediaType: mediaType,
         artist: artist,
         themes: themes,
       ).timeout(
        Duration(milliseconds: MobilePerformanceConfig.llmTimeoutMs),
        onTimeout: () {
          debugPrint('⏰ LLM generation timed out after ${MobilePerformanceConfig.llmTimeoutMs}ms');
          return '';
        },
      );
      
      // Validate response quality
      if (_isValidResponse(response)) {
        return _cleanAndEnhanceResponse(response, mediaTitle, artist);
      } else {
        debugPrint('❌ Invalid LLM response: "$response"');
        return null;
      }
      
    } catch (e) {
      debugPrint('❌ LLM generation error: $e');
      return null;
    }
  }
  
  /// Build mobile-optimized prompt for TinyLlama with smart truncation
  String _buildMobileOptimizedPrompt({
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
  }) {
    // Mobile-specific truncation limits (more aggressive than desktop)
    const int maxTitleLength = 40;
    const int maxArtistLength = 25;
    const int maxContextLength = 60;
    
    // Truncate title if too long
    String truncatedTitle = mediaTitle;
    if (mediaTitle.length > maxTitleLength) {
      truncatedTitle = mediaTitle.substring(0, maxTitleLength - 3) + '...';
    }
    
    // Truncate artist if provided and too long
    String artistInfo = '';
    if (artist != null && artist.isNotEmpty && artist.toLowerCase() != 'unknown') {
      String truncatedArtist = artist;
      if (artist.length > maxArtistLength) {
        truncatedArtist = artist.substring(0, maxArtistLength - 3) + '...';
      }
      artistInfo = ' by $truncatedArtist';
    }
    
    // Get context (prefer themes over description) and truncate
    String context = '';
    if (themes != null && themes.isNotEmpty) {
      context = themes.split(',').map((t) => t.trim()).take(2).join(', ');
    } else if (description != null && description.isNotEmpty) {
      context = description;
    } else {
      context = 'Great $mediaType';
    }
    
    if (context.length > maxContextLength) {
      context = context.substring(0, maxContextLength - 3) + '...';
    }
    
    // Ultra-compact prompt designed for TinyLlama
    final prompt = '''Explain: $truncatedTitle$artistInfo
Context: $context
Why recommend?''';
    
    // Final safety check for mobile token limits
    const int maxMobilePromptLength = 200;
    if (prompt.length > maxMobilePromptLength) {
      debugPrint('⚠️ Mobile prompt too long (${prompt.length} chars), using minimal version');
      return 'Explain: ${truncatedTitle.length > 25 ? truncatedTitle.substring(0, 22) + '...' : truncatedTitle}$artistInfo\nWhy good?';
    }
    
    return prompt;
  }
  
  /// Validate if LLM response is acceptable
  bool _isValidResponse(String response) {
    final cleaned = response.trim();
    
    // Check for common failure patterns
    if (cleaned.isEmpty) return false;
    if (cleaned.length < 5) return false;
    if (cleaned == '1.' || cleaned == '1') return false;
    if (cleaned.startsWith('Error')) return false;
    if (cleaned.contains('</s>')) return false;
    if (cleaned.contains('[INST]')) return false;
    
    // Check for repetitive patterns
    if (_isRepetitive(cleaned)) return false;
    
    // Check if it starts with a valid pattern
    final startsValid = MobilePerformanceConfig.validResponseStarters
        .any((starter) => cleaned.startsWith(starter));
    
    // Must either start validly or contain meaningful content
    return startsValid || cleaned.contains(' ') && cleaned.length > 10;
  }
  
  /// Check if response is repetitive or looping
  bool _isRepetitive(String text) {
    if (text.length < 20) return false;
    
    // Check for repeated phrases
    final words = text.split(' ');
    if (words.length < 4) return false;
    
    // Look for repeated 3-word sequences
    for (int i = 0; i < words.length - 5; i++) {
      final phrase = '${words[i]} ${words[i + 1]} ${words[i + 2]}';
      final remaining = words.skip(i + 3).join(' ');
      if (remaining.contains(phrase)) {
        return true; // Found repetition
      }
    }
    
    return false;
  }
  
  /// Clean and enhance LLM response
  String _cleanAndEnhanceResponse(String response, String mediaTitle, String? artist) {
    var cleaned = response.trim();
    
    // Remove common artifacts
    cleaned = cleaned.replaceAll('</s>', '');
    cleaned = cleaned.replaceAll('[/INST]', '');
    cleaned = cleaned.replaceAll('\n', ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    // Ensure it ends with punctuation
    if (!cleaned.endsWith('.') && !cleaned.endsWith('!') && !cleaned.endsWith('?')) {
      cleaned += '.';
    }
    
    // Ensure it mentions the media title if it doesn't
    if (!cleaned.toLowerCase().contains(mediaTitle.toLowerCase())) {
      cleaned = '$mediaTitle - $cleaned';
    }
    
    // Limit length for mobile display
    if (cleaned.length > 120) {
      cleaned = cleaned.substring(0, 117) + '...';
    }
    
    return cleaned;
  }
  
  /// Generate rule-based explanation as fallback
  String _generateRuleBasedExplanation({
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    double? similarity,
  }) {
    final templates = _getRuleBasedTemplates(mediaType);
    final template = templates[Random().nextInt(templates.length)];
    
    // Fill in template variables
    var explanation = template
        .replaceAll('{title}', mediaTitle)
        .replaceAll('{artist}', artist ?? 'this artist')
        .replaceAll('{type}', mediaType);
    
    // Add theme-based context if available
    if (themes != null && themes.isNotEmpty) {
      final themeList = themes.split(',').map((t) => t.trim()).take(2);
      explanation += ' Features ${themeList.join(' and ')} elements.';
    }
    
    // Add similarity context if available
    if (similarity != null && similarity > 0.7) {
      explanation += ' Highly matches your preferences.';
    }
    
    return explanation;
  }
  
  /// Get template explanations by media type
  List<String> _getRuleBasedTemplates(String mediaType) {
    switch (mediaType) {
      case 'music':
        return [
          '{title} by {artist} offers a compelling sound worth exploring.',
          'This track by {artist} showcases excellent musical craftsmanship.',
          '{title} presents a great example of quality {type} composition.',
          'A solid choice that demonstrates {artist}\'s musical talents.',
        ];
      case 'movie':
        return [
          '{title} delivers an engaging cinematic experience.',
          'This film offers compelling storytelling and production.',
          '{title} represents quality filmmaking worth watching.',
          'A well-crafted movie that showcases excellent direction.',
        ];
      case 'tv_show':
        return [
          '{title} provides engaging television entertainment.',
          'This series offers compelling character development.',
          '{title} delivers quality storytelling across episodes.',
          'A well-produced show with strong narrative elements.',
        ];
      case 'book':
        return [
          '{title} offers engaging literary content.',
          'This book provides compelling narrative and insights.',
          '{title} delivers quality writing and storytelling.',
          'A well-crafted work that showcases excellent writing.',
        ];
      case 'video_game':
        return [
          '{title} provides engaging interactive entertainment.',
          'This game offers compelling gameplay mechanics.',
          '{title} delivers quality gaming experience.',
          'A well-designed game with excellent production values.',
        ];
      default:
        return [
          '{title} offers quality content worth exploring.',
          'This {type} provides compelling entertainment value.',
          '{title} delivers excellent production quality.',
        ];
    }
  }
  
  /// Get generation statistics
  Map<String, dynamic> getStats() {
    return {
      'consecutiveFailures': _consecutiveFailures,
      'totalResponses': _recentResponses.length,
      'isLLMAvailable': _llamaService.isInitialized,
      'fallbackUsageRate': _consecutiveFailures > 0 ? _consecutiveFailures / max(1, _recentResponses.length) : 0.0,
    };
  }
  
  /// Reset failure counter (call when LLM is fixed)
  void resetFailureCounter() {
    _consecutiveFailures = 0;
    debugPrint('🔄 LLM failure counter reset');
  }
} 
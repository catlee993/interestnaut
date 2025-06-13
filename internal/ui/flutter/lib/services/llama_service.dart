import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'llm_downloader_service.dart';
import 'model_constants.dart';

/// LlamaService
/// Handles on-device TinyLlama model management and inference
/// Optimized for mobile recommendation explanations with vector database results
class LlamaService {
  static final LlamaService _instance = LlamaService._internal();
  factory LlamaService() => _instance;
  LlamaService._internal();
  
  // Update the default download URL to TinyLlama
  static const String _tinyllamaUrl = 'https://interestnaut.com/models/tinyllama-1.1b-chat-q4_0.gguf';
  
  bool _isInitialized = false;

  /// Initialize the service with TinyLlama model
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Update the default download URL to TinyLlama
      LLMDownloaderService.defaultModelDownloadUrl = _tinyllamaUrl;
      
      // Check if model exists using the existing service
      final hasModel = await LLMDownloaderService.hasModels();
      
      if (hasModel) {
        _isInitialized = true;
        debugPrint('TinyLlama model found, service initialized');
        return true;
      } else {
        debugPrint('TinyLlama model not found, will download when needed');
        return false;
      }
    } catch (e) {
      debugPrint('Error initializing TinyLlama service: $e');
      return false;
    }
  }

  /// Download TinyLlama model using the existing downloader service
  Future<bool> downloadModel() async {
    try {
      debugPrint('Downloading TinyLlama model...');
      
      // Get model directory and download using existing service
      final modelDir = await LLMDownloaderService.getModelDirectory();
      final response = await LLMDownloaderService.downloadModel(
        modelDir,
        kTinyLlamaModelFileName, // Use TinyLlama filename
        downloadUrl: _tinyllamaUrl,
      );
      
      if (response.success) {
        _isInitialized = true;
        debugPrint('TinyLlama model downloaded successfully');
        return true;
            } else {
        debugPrint('Failed to download TinyLlama: ${response.error}');
        return false;
            }
    } catch (e) {
      debugPrint('Error downloading TinyLlama: $e');
      return false;
    }
  }

  /// Generate explanation for media recommendation
  /// Currently provides intelligent fallback explanations based on vector database context
  /// TODO: Integrate GGUF inference when llama_cpp_dart API is stable
  Future<String> generateExplanation({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    double? similarity,
  }) async {
    // Try to initialize if not already done
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // TODO: Replace with actual GGUF inference
      // For now, provide intelligent explanations based on available context
      return _generateContextualExplanation(
        userQuery: userQuery,
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        description: description,
        similarity: similarity,
      );
    } catch (e) {
      debugPrint('Error generating explanation: $e');
      return _getFallbackExplanation(userQuery, mediaTitle, mediaType, themes);
    }
  }

  /// Generate contextual explanation using available metadata
  String _generateContextualExplanation({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? description,
    double? similarity,
  }) {
    final buffer = StringBuffer();
    
    // Start with similarity-based reasoning
    if (similarity != null && similarity > 0.7) {
      buffer.write('This $mediaType is a strong match ');
    } else if (similarity != null && similarity > 0.5) {
      buffer.write('This $mediaType is a good match ');
    } else {
      buffer.write('This $mediaType relates to ');
    }
    
    buffer.write('your search for "$userQuery"');
    
    // Add theme-based reasoning
    if (themes != null && themes.isNotEmpty) {
      final themesList = themes.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      if (themesList.isNotEmpty) {
        if (themesList.length == 1) {
          buffer.write(' through its ${themesList.first} theme');
        } else if (themesList.length == 2) {
          buffer.write(' through its ${themesList.first} and ${themesList.last} themes');
        } else {
          buffer.write(' through themes like ${themesList.take(2).join(', ')}, and others');
        }
      }
    }
    
    // Add artist/creator context
    if (artist != null && artist.isNotEmpty && artist.toLowerCase() != 'unknown') {
      if (mediaType == 'music') {
        buffer.write(', featuring ${artist}\'s distinctive style');
      } else if (mediaType == 'book') {
        buffer.write(', showcasing ${artist}\'s writing approach');
      } else if (mediaType == 'movie' || mediaType == 'tv_show') {
        buffer.write(', with ${artist}\'s creative direction');
      } else {
        buffer.write(', created by $artist');
      }
    }
    
    buffer.write('.');
    
    return buffer.toString();
  }

  /// Fallback explanation when context is limited
  String _getFallbackExplanation(String userQuery, String mediaTitle, String mediaType, String? themes) {
    final themesList = themes?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList() ?? [];
    
    if (themesList.isNotEmpty) {
      final primaryTheme = themesList.first;
      return 'This $mediaType matches your interest in $primaryTheme and related themes.';
    }
    
    return 'This $mediaType is recommended based on your search for "$userQuery".';
  }

  /// Check if model is available locally
  Future<bool> isModelAvailable() async {
    return await LLMDownloaderService.hasModels();
  }

  /// Get model file size
  Future<int> getModelSize() async {
    try {
      final modelDir = await LLMDownloaderService.getModelDirectory();
      final modelFile = File(path.join(modelDir, kTinyLlamaModelFileName));
      if (await modelFile.exists()) {
        return await modelFile.length();
      }
    } catch (e) {
      debugPrint('Error getting model size: $e');
    }
    return 0;
  }

  /// Get model file path for external use
  Future<String> getModelPath() async {
    final modelDir = await LLMDownloaderService.getModelDirectory();
    return path.join(modelDir, kTinyLlamaModelFileName);
      }
      
  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if model is downloading
  /// Note: This is a best-effort check since we can't access private downloader state
  bool get isDownloading => false; // TODO: Implement proper download state tracking

  /// Dispose resources
  void dispose() {
    _isInitialized = false;
  }
}

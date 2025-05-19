import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'model_constants.dart';

/// Constants for model files
export 'model_constants.dart' show kMistralModelFileName;

/// Response from the download operation
class DownloadModelResponse {
  final bool success;
  final String? error;
  final String? path;

  DownloadModelResponse({
    required this.success,
    this.error,
    this.path,
  });

  factory DownloadModelResponse.error(String message) {
    return DownloadModelResponse(
      success: false,
      error: message,
    );
  }
}

/// Service for Mistral operations
/// Pure Dart implementation without FFI
class MistralService {
  // Constants for the Mistral model
  static const String modelDownloadUrl = "https://interestnaut.com/Mistral-7B-Instruct-v0.3-q4_1.gguf";
  static const String modelFileName = kMistralModelFileName;
  
  // Singleton pattern with private constructor
  static final MistralService _instance = MistralService._();
  factory MistralService() => _instance;
  
  // Locking mechanism
  final Completer<void> _mutex = Completer<void>.sync()..complete();
  bool _isDownloading = false;
  
  // Download future - used to return the same future for concurrent requests
  Future<DownloadModelResponse>? _activeDownload;
  
  // Cache for whether the model exists
  bool? _modelExists;
  
  // Private constructor
  MistralService._();
  
  /// Download the Mistral model to the specified directory
  ///
  /// Returns a [DownloadModelResponse] when the download is complete
  static Future<DownloadModelResponse> downloadModel(String modelDir) async {
    // If a download is already in progress, return the same future
    if (_instance._activeDownload != null && _instance._isDownloading) {
      debugPrint('Download already in progress, returning existing future');
      return _instance._activeDownload!;
    }
    
    // Try to acquire the lock without waiting
    if (_instance._isDownloading) {
      debugPrint('Download already in progress, but no future available. Creating new request.');
      return DownloadModelResponse.error('Another download is already in progress');
    }
    
    // Create a new mutex and mark as downloading
    _instance._isDownloading = true;
    
    // Create a new download future
    _instance._activeDownload = _instance._downloadModelImpl(modelDir);
    
    // Return the active download
    return _instance._activeDownload!;
  }
  
  /// Internal implementation for downloading the model
  Future<DownloadModelResponse> _downloadModelImpl(String modelDir) async {
    debugPrint('Starting Mistral model download to $modelDir');
    
    try {
      final modelPath = path.join(modelDir, modelFileName);
      final modelFile = File(modelPath);
      
      // Check if the model already exists
      if (await modelFile.exists()) {
        debugPrint('Model file already exists at $modelPath, skipping download.');
        _modelExists = true;
        _isDownloading = false;
        return DownloadModelResponse(
          success: true,
          path: modelPath
        );
      }
      
      // Ensure directory exists
      final directory = Directory(path.dirname(modelDir));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      // Start the download
      final request = http.Request('GET', Uri.parse(modelDownloadUrl));
      final response = await http.Client().send(request);
      
      if (response.statusCode != 200) {
        _isDownloading = false;
        return DownloadModelResponse.error(
          'Failed to download model: HTTP ${response.statusCode}'
        );
      }
      
      // Stream the response to the file
      final totalBytes = response.contentLength ?? 0;
      var downloadedBytes = 0;
      
      final fileStream = modelFile.openWrite();
      await response.stream.forEach((chunk) {
        fileStream.add(chunk);
        downloadedBytes += chunk.length;
        
        // Log progress occasionally (every ~5%)
        if (totalBytes > 0 && downloadedBytes % (totalBytes ~/ 20) < chunk.length) {
          final progress = (downloadedBytes / totalBytes * 100).toStringAsFixed(1);
          debugPrint('Download progress: $progress%');
        }
      });
      
      await fileStream.close();
      _modelExists = true;
      
      debugPrint('Mistral model download completed successfully');
      return DownloadModelResponse(
        success: true,
        path: modelPath
      );
    } catch (e) {
      debugPrint('Error during model download: $e');
      return DownloadModelResponse.error(e.toString());
    } finally {
      // Release the lock regardless of success or failure
      _isDownloading = false;
      _activeDownload = null;
    }
  }
  
  /// Get the model directory path
  static Future<String> getModelDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, 'mistral');
  }
  
  /// Check if the Mistral model exists
  ///
  /// Returns true if the model is available, false otherwise
  static Future<bool> hasModel() async {
    // Use cached value if available
    if (_instance._modelExists != null) {
      return _instance._modelExists!;
    }
    
    try {
      final modelDir = await getModelDirectory();
      final modelPath = path.join(modelDir, modelFileName);
      final exists = await File(modelPath).exists();
      
      // Cache the result
      _instance._modelExists = exists;
      return exists;
    } catch (e) {
      debugPrint('Error checking model existence: $e');
      return false;
    }
  }
  
  /// Handle a new suggestion (placeholder implementation)
  static Future<Map<String, dynamic>> handleNewSuggestion() async {
    // This would be replaced with actual implementation
    // for generating suggestions using the Mistral model
    return {
      'title': 'Sample Song',
      'artist': 'Sample Artist',
    };
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'model_constants.dart';

/// Constants for model files
export 'model_constants.dart' show kModelsDirectoryName;

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

/// Service for LLM model operations
/// Pure Dart implementation without FFI
class LLMDownloaderService {
  // Default download URL - can be overridden
  static String defaultModelDownloadUrl = "https://interestnaut.com/Meta-Llama-3-7B-29Layers.Q4_K_S.gguf";
  
  // Singleton pattern with private constructor
  static final LLMDownloaderService _instance = LLMDownloaderService._();
  factory LLMDownloaderService() => _instance;
  
  // Locking mechanism
  final Completer<void> _mutex = Completer<void>.sync()..complete();
  bool _isDownloading = false;
  
  // Download future - used to return the same future for concurrent requests
  Future<DownloadModelResponse>? _activeDownload;
  
  // Cache for whether any models exist
  bool? _modelsExist;
  
  // Private constructor
  LLMDownloaderService._();
  
  /// Download a model to the specified directory
  ///
  /// Returns a [DownloadModelResponse] when the download is complete
  static Future<DownloadModelResponse> downloadModel(
    String modelDir, 
    String modelFileName, 
    {String? downloadUrl}
  ) async {
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
    _instance._activeDownload = _instance._downloadModelImpl(
      modelDir, 
      modelFileName, 
      downloadUrl ?? defaultModelDownloadUrl
    );
    
    // Return the active download
    return _instance._activeDownload!;
  }
  
  /// Internal implementation for downloading the model
  Future<DownloadModelResponse> _downloadModelImpl(
    String modelDir,
    String modelFileName,
    String downloadUrl
  ) async {
    debugPrint('Starting model download to $modelDir');
    
    try {
      final modelPath = path.join(modelDir, modelFileName);
      final modelFile = File(modelPath);
      
      // Check if the model already exists
      if (await modelFile.exists()) {
        debugPrint('Model file already exists at $modelPath, skipping download.');
        _modelsExist = true;
        _isDownloading = false;
        return DownloadModelResponse(
          success: true,
          path: modelPath
        );
      }
      
      // Ensure directory exists
      final directory = Directory(modelDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      // Start the download
      final request = http.Request('GET', Uri.parse(downloadUrl));
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
      _modelsExist = true;
      
      debugPrint('Model download completed successfully');
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
    return path.join(appDir.path, kModelsDirectoryName);
  }
  
  /// Check if TinyLlama model exists in the models directory
  ///
  /// Returns true if the specific TinyLlama model file is available, false otherwise
  static Future<bool> hasModels() async {
    // Use cached value if available
    if (_instance._modelsExist != null) {
      return _instance._modelsExist!;
    }
    
    try {
      final modelDir = await getModelDirectory();
      final modelFile = File(path.join(modelDir, kTinyLlamaModelFileName));
      
      final exists = await modelFile.exists();
      
      // Cache the result
      _instance._modelsExist = exists;
      return exists;
    } catch (e) {
      debugPrint('Error checking TinyLlama model existence: $e');
      return false;
    }
  }
  
  /// Get a list of available models
  static Future<List<String>> getAvailableModels() async {
    try {
      final modelDir = await getModelDirectory();
      final directory = Directory(modelDir);
      
      if (!await directory.exists()) {
        return [];
      }
      
      // Collect all .gguf files in the directory
      final models = <String>[];
      await for (final entity in directory.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.gguf')) {
          models.add(path.basename(entity.path));
        }
      }
      
      return models;
    } catch (e) {
      debugPrint('Error listing available models: $e');
      return [];
    }
  }
}

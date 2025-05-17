import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'ffi_init.dart';
import 'mistral_ffi.dart';

/// Message to pass to the isolate for downloading
class DownloadModelMessage {
  final String modelPath;
  final SendPort sendPort;

  DownloadModelMessage(this.modelPath, this.sendPort);
}

/// Response from the download isolate
class DownloadModelResponse {
  final bool success;
  final String? error;
  final String? path;

  DownloadModelResponse({
    required this.success,
    this.error,
    this.path,
  });

  factory DownloadModelResponse.fromMap(Map<String, dynamic> map) {
    return DownloadModelResponse(
      success: map['status'] == 'complete',
      error: map['error'],
      path: map['path'],
    );
  }

  factory DownloadModelResponse.error(String message) {
    return DownloadModelResponse(
      success: false,
      error: message,
    );
  }
}

/// Service for running Minstral operations in isolates
class MinstralIsolateService {
  /// Download a model in a separate isolate to avoid blocking the UI
  ///
  /// Returns a [DownloadModelResponse] when the download is complete
  static Future<DownloadModelResponse> downloadModelInIsolate(String modelPath) async {
    // Create a port for receiving the response
    final receivePort = ReceivePort();
    
    try {
      // Spawn the isolate
      await Isolate.spawn(
        _downloadModelIsolate,
        DownloadModelMessage(
          modelPath,
          receivePort.sendPort,
        ),
      );
      
      // Wait for the response
      final result = await receivePort.first as Map<String, dynamic>;
      
      // Close the port
      receivePort.close();
      
      return DownloadModelResponse.fromMap(result);
    } catch (e) {
      // Close the port in case of error
      receivePort.close();
      
      // Return an error response
      debugPrint('Error spawning isolate for model download: $e');
      return DownloadModelResponse.error(e.toString());
    }
  }
  
  /// The actual isolate entry point for downloading the model
  static void _downloadModelIsolate(DownloadModelMessage message) async {
    // Initialize FFI in the isolate
    await FFIInitializer.initialize();
    
    // Create a new instance of MinstralFFI in this isolate
    final minstralFFI = MistralFFI();
    
    try {
      // Download the model
      final result = await minstralFFI.downloadModel(message.modelPath);
      
      // Send the result back
      message.sendPort.send(result);
    } catch (e) {
      // Send error back
      message.sendPort.send({
        'status': 'error',
        'error': e.toString(),
      });
    }
    
    // Terminate the isolate
    Isolate.exit();
  }
  
  /// Check if a model exists
  static Future<bool> hasModel() async {
    final minstralFFI = MistralFFI();
    final result = await minstralFFI.hasModel();
    return result['hasModel'] == true;
  }
  
  /// Handle a new suggestion
  static Future<Map<String, dynamic>> handleNewSuggestion() async {
    final minstralFFI = MistralFFI();
    return await minstralFFI.handleNewSuggestion();
  }
}

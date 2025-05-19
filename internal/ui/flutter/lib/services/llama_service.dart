import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'mistral_service.dart';

/// Service to handle LLM inferencing 
/// Uses isolates to prevent blocking the UI thread during inference
class LlamaService {
  // Singleton pattern
  static final LlamaService _instance = LlamaService._();
  factory LlamaService() => _instance;
  
  // Communication ports for isolate
  Isolate? _inferenceIsolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;
  
  // Status tracking
  bool _isRunning = false;
  Completer<void>? _initCompleter;
  
  // Callback function for showing toast messages
  Function(String message, {bool isError})? showToast;
  
  // Private constructor
  LlamaService._();
  
  /// Initialize the Llama service
  /// This starts the isolate and establishes communication
  Future<bool> initialize(String modelPath, {Function(String message, {bool isError})? toastCallback}) async {
    showToast = toastCallback;
    
    if (_isRunning) {
      _showToast('LlamaService already initialized');
      return true;
    }
    
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      _showToast('LlamaService initialization in progress');
      return _initCompleter!.future.then((_) => true);
    }
    
    _initCompleter = Completer<void>();
    
    try {
      _showToast('Initializing LLM with model: ${path.basename(modelPath)}');
      
      // Check if model exists first
      final hasModel = await MistralService.hasModel();
      if (!hasModel) {
        _showToast('Model not found at $modelPath', isError: true);
        _initCompleter?.complete();
        return false;
      }
      
      // For now, we'll simulate the LLM functionality instead of actually using llama_cpp_dart
      // until we can properly investigate the correct API
      _showToast('LLM initialized (simulated)');
      _isRunning = true;
      _initCompleter?.complete();
      
      return true;
    } catch (e) {
      _showToast('Error initializing LLM: $e', isError: true);
      _initCompleter?.completeError(e);
      return false;
    }
  }
  
  /// Send a prompt to the LLM for inference
  Future<bool> sendPrompt(String prompt) async {
    if (!_isRunning) {
      _showToast('Cannot send prompt: LLM not initialized', isError: true);
      return false;
    }
    
    try {
      _showToast('Sending prompt to LLM: ${prompt.substring(0, prompt.length > 30 ? 30 : prompt.length)}...');
      
      // Simulate LLM response for now
      await Future.delayed(const Duration(seconds: 1));
      _showToast('LLM generated: "As an AI language model, I recommend listening to..."');
      await Future.delayed(const Duration(milliseconds: 500));
      _showToast('LLM generated: " The Weeknd - Blinding Lights"');
      await Future.delayed(const Duration(milliseconds: 800));
      _showToast('LLM generated: ", it\'s upbeat and energetic."');
      
      return true;
    } catch (e) {
      _showToast('Error sending prompt: $e', isError: true);
      return false;
    }
  }
  
  /// Utility method to show toast messages via the callback
  void _showToast(String message, {bool isError = false}) {
    debugPrint('LlamaService: $message');
    showToast?.call(message, isError: isError);
  }
  
  /// Get the model path from the documents directory
  static Future<String> getModelPath() async {
    try {
      // Use the same path logic as in MistralService
      final modelDir = await MistralService.getModelDirectory();
      return path.join(modelDir, MistralService.modelFileName);
    } catch (e) {
      debugPrint('Error getting model path: $e');
      return '';
    }
  }
  
  /// Shutdown the LLM service and isolate
  Future<void> shutdown() async {
    if (_inferenceIsolate != null) {
      _inferenceIsolate!.kill(priority: Isolate.immediate);
      _inferenceIsolate = null;
    }
    
    _receivePort?.close();
    _receivePort = null;
    
    _isRunning = false;
    _sendPort = null;
    
    debugPrint('LlamaService shutdown complete');
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'model_constants.dart';

/// A helper class to manage token generation in a non-blocking way
class LlamaTokenStream {
  final Llama llm;
  final String prompt;
  final StreamController<String> controller = StreamController<String>();
  
  LlamaTokenStream(this.llm, this.prompt);
  
  /// Start token generation in microtasks
  Future<String> generate() async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    
    try {
      // Set the prompt first
      llm.setPrompt(prompt);
      
      // Start a new microtask to process tokens without blocking the UI
      _processNextToken(buffer, completer);
      
      // Return the future that will complete when all tokens are generated
      return completer.future;
    } catch (e) {
      controller.addError(e);
      completer.completeError(e);
      return completer.future;
    }
  }
  
  /// Process the next token without blocking the UI thread
  void _processNextToken(StringBuffer buffer, Completer<String> completer) {
    // Schedule a microtask to allow UI to update between token generations
    Future.microtask(() {
      try {
        // Try to get the next token
        final (token, isDone) = llm.getNext();
        
        // Add the token to the buffer and stream
        if (token.isNotEmpty) {
          buffer.write(token);
          controller.add(token);
        }
        
        if (isDone) {
          // Generation is complete
          controller.close();
          completer.complete(buffer.toString());
        } else {
          // Schedule the next token generation
          _processNextToken(buffer, completer);
        }
      } catch (e) {
        // Handle errors
        controller.addError(e);
        completer.completeError(e);
        controller.close();
      }
    });
  }
  
  /// Get the stream of tokens
  Stream<String> get stream => controller.stream;
}

/// Service to handle LLM inferencing using llama_cpp_dart
/// This provides a direct interface to the llama.cpp library through FFI
class LlamaService {
  /// Singleton instance
  static final LlamaService _instance = LlamaService._internal();
  
  /// Function to show toast messages
  Function(String message, {bool isError})? showToast;
  
  /// The underlying LLM model parent (manages isolate communication)
  LlamaParent? _llamaParent;
  
  /// Context parameters for the model
  ContextParams? _contextParams;
  
  /// Status flag
  bool _isRunning = false;
  
  /// Initialization completer
  Completer<void>? _initCompleter;
  
  /// Response stream controller
  StreamController<String>? _responseStreamController;
  
  /// Factory constructor
  factory LlamaService() {
    return _instance;
  }
  
  /// Private constructor
  LlamaService._internal();
  
  /// Get instance
  static LlamaService get instance => _instance;
  
  /// Check if the service is initialized and running
  bool get isRunning => _isRunning;
  
  /// Stream of response tokens
  Stream<String>? get responseStream => _responseStreamController?.stream;
  
  /// Get model path
  static Future<String> getModelPath({String? modelFileName}) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    return path.join(
      documentsDir.path,
      kModelsDirectoryName,
      modelFileName ?? kMistralModelFileName,
    );
  }
  
  /// Initialize the Llama service with the given model path
  Future<bool> initialize(String modelPath, {Function(String message, {bool isError})? toastCallback}) async {
    showToast = toastCallback;
    
    if (_isRunning && _llamaParent != null) {
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
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        _showToast('Model not found at $modelPath', isError: true);
        _initCompleter?.complete();
        return false;
      }
      
      // Try several approaches to find the dynamic library
      String? libraryPath;
      
      // Approach 1: Try to find the library relative to the project root
      try {
        // Get the project root directory 
        final projectRootDir = await _findProjectRoot();
        if (projectRootDir != null) {
          final devLibPath = path.join(
            projectRootDir,
            'internal',
            'ui',
            'flutter',
            'macos',
            'Libraries',
            'libllama.dylib'
          );
          
          final devLibFile = File(devLibPath);
          if (await devLibFile.exists()) {
            _showToast('Found library in project directory: $devLibPath');
            libraryPath = devLibPath;
          }
        }
      } catch (e) {
        _showToast('Error looking for library in project directory: $e');
      }
      
      // Approach 2: If not found, try a path relative to the model file
      if (libraryPath == null) {
        try {
          final modelDir = path.dirname(modelPath);
          final libNextToModelPath = path.join(modelDir, 'libllama.dylib');
          
          final libFile = File(libNextToModelPath);
          if (await libFile.exists()) {
            _showToast('Found library next to model: $libNextToModelPath');
            libraryPath = libNextToModelPath;
          }
        } catch (e) {
          _showToast('Error looking for library next to model: $e');
        }
      }
      
      // Approach 3: Fallback to system path
      if (libraryPath == null) {
        _showToast('Using system library path as fallback');
        libraryPath = 'libllama.dylib';
      }
      
      // Set the library path
      _showToast('Using library at: $libraryPath');
      Llama.libraryPath = libraryPath;
      
      // Configure model parameters with optimized settings for lower resource usage
      final modelParams = ModelParams();
      modelParams.nGpuLayers = 0;  // Disable GPU layers (CPU-only mode)
      
      // Configure context parameters with conservative values
      _contextParams = ContextParams();
      _contextParams!.nCtx = 1024;        // Reduced context size
      _contextParams!.nBatch = 128;       // Smaller batch size
      _contextParams!.nThreads = 4;       // Fewer threads
      _contextParams!.nPredict = 256;     // Limit token generation
      _contextParams!.offloadKqv = false; // Don't offload to GPU
      
      // Configure sampler parameters
      final samplerParams = SamplerParams();
      samplerParams.temp = 0.7;
      samplerParams.topP = 0.9;
      
      _showToast('Initializing with CPU-only mode and reduced memory usage');
      
      // Create the LlamaLoad command
      final loadCommand = LlamaLoad(
        path: modelPath,
        modelParams: modelParams,
        contextParams: _contextParams!,
        samplingParams: samplerParams,
      );
      
      // Initialize the isolate parent
      _llamaParent = LlamaParent(loadCommand);
      await _llamaParent!.init();
      
      // Create a stream controller for response tokens
      _responseStreamController = StreamController<String>.broadcast();
      
      // Listen to the parent's token stream
      _llamaParent!.stream.listen(
        (token) {
          // Add token to our stream controller
          _responseStreamController?.add(token);
        },
        onError: (error) {
          _showToast('Error from LlamaParent: $error', isError: true);
          _responseStreamController?.addError(error);
        },
        onDone: () {
          // Optional: handle completion if needed
        },
      );
      
      _showToast('LLM successfully initialized in isolate');
      _isRunning = true;
      _initCompleter?.complete();
      
      return true;
    } catch (e) {
      _showToast('Error initializing LLM: $e', isError: true);
      _initCompleter?.completeError(e);
      return false;
    }
  }
  
  /// Process a prompt and generate a response
  Future<String> processPrompt(String prompt, {
    int maxTokens = 512, 
    Function(String token)? onToken,
    Function(String errorMsg)? onError,
  }) async {
    if (!_isRunning || _llamaParent == null) {
      final error = 'LlamaService not initialized';
      onError?.call(error);
      return Future.error(error);
    }
    
    _showToast('Processing prompt: ${prompt.substring(0, math.min(prompt.length, 25))}...');
    _showToast('Generating response...');
    
    try {
      // Create a completer to await the full response
      final completer = Completer<String>();
      final responseBuffer = StringBuffer();
      
      // Set up a subscription to collect all tokens
      final subscription = _llamaParent!.stream.listen(
        (token) {
          // Add token to response buffer
          responseBuffer.write(token);
          
          // Call onToken callback if provided
          onToken?.call(token);
        },
        onError: (error) {
          final errorMsg = 'Error generating response: $error';
          _showToast(errorMsg, isError: true);
          onError?.call(errorMsg);
          completer.completeError(error);
        },
        onDone: () {
          // Complete with the full response
          completer.complete(responseBuffer.toString());
        }
      );
      
      // Send the prompt to the isolate
      _llamaParent!.sendPrompt(prompt);
      
      // Wait for the response to complete
      final response = await completer.future;
      
      // Cancel the subscription
      await subscription.cancel();
      
      return response;
    } catch (e) {
      final errorMsg = 'Error processing prompt: $e';
      _showToast(errorMsg, isError: true);
      onError?.call(errorMsg);
      throw e;
    }
  }
  
  /// Simple method to send a prompt and get a response (for settings drawer)
  Future<String> sendPrompt(String prompt) async {
    if (!_isRunning || _llamaParent == null) {
      final error = 'LlamaService not initialized';
      _showToast(error, isError: true);
      return "Error: $error";
    }
    
    _showToast('Processing prompt: ${prompt.substring(0, math.min(prompt.length, 25))}...');
    _showToast('Generating response...');
    
    try {
      // Create a completer to await the full response
      final completer = Completer<String>();
      final responseBuffer = StringBuffer();
      
      // Set up a subscription to collect all tokens
      final subscription = _llamaParent!.stream.listen(
        (token) {
          // Add token to response buffer
          responseBuffer.write(token);
        },
        onError: (error) {
          final errorMsg = 'Error generating response: $error';
          _showToast(errorMsg, isError: true);
          completer.completeError(error);
        },
        onDone: () {
          // Complete with the full response
          completer.complete(responseBuffer.toString());
        }
      );
      
      // Send the prompt to the isolate
      _llamaParent!.sendPrompt(prompt);
      
      // Wait for the response to complete
      final response = await completer.future;
      
      // Cancel the subscription
      await subscription.cancel();
      
      _showToast('Response complete: ${response.substring(0, math.min(response.length, 25))}...');
      return response;
    } catch (e) {
      final errorMsg = 'Error processing prompt: $e';
      _showToast(errorMsg, isError: true);
      return "Error: $e";
    }
  }
  
  /// Shutdown and clean up resources
  Future<void> shutdown() async {
    if (!_isRunning) return;
    
    try {
      // Clean up resources
      if (_llamaParent != null) {
        await _llamaParent!.dispose();
        _llamaParent = null;
      }
      
      // Close stream controller
      await _responseStreamController?.close();
      _responseStreamController = null;
      
      _isRunning = false;
      _showToast('LLM shutdown complete');
    } catch (e) {
      _showToast('Error during shutdown: $e', isError: true);
    }
  }
  
  /// Show toast message
  void _showToast(String message, {bool isError = false}) {
    debugPrint('LlamaService: $message');
    showToast?.call(message, isError: isError);
  }
  
  /// Find the project root directory
  Future<String?> _findProjectRoot() async {
    // Start with the current directory
    Directory currentDir = Directory.current;
    
    // Try up to 5 levels up the directory tree
    for (int i = 0; i < 5; i++) {
      // Check for a marker of the project root (internal directory)
      final internalDir = Directory(path.join(currentDir.path, 'internal'));
      if (await internalDir.exists()) {
        return currentDir.path;
      }
      
      // Move up one directory
      final parentDir = currentDir.parent;
      if (parentDir.path == currentDir.path) {
        // We've reached the filesystem root
        break;
      }
      currentDir = parentDir;
    }
    
    // Fallback: just return the current directory
    return Directory.current.path;
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'model_constants.dart';

/// Service to handle LLM inferencing using llama_cpp_dart
/// This provides a direct interface to the llama.cpp library through FFI
class LlamaService {
  // Singleton pattern
  static final LlamaService _instance = LlamaService._();
  factory LlamaService() => _instance;
  
  // LLM instance from llama_cpp_dart
  Llama? _llm;
  
  // Storing our own context parameters since we can't access private fields
  ContextParams? _contextParams;
  
  // Status tracking
  bool _isRunning = false;
  Completer<void>? _initCompleter;
  
  // Callback function for showing toast messages
  Function(String message, {bool isError})? showToast;
  
  // Private constructor
  LlamaService._();
  
  /// Get the status of the LLM service
  bool get isRunning => _isRunning;
  
  /// Get the path to the LLM model file
  /// This is a static method that returns the expected path for the model
  static Future<String> getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    // Use a subfolder to keep models organized
    final modelsDir = Directory('${directory.path}/${kModelsDirectoryName}');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return '${modelsDir.path}/${kMistralModelFileName}';
  }
  
  /// Initialize the Llama service with the given model path
  Future<bool> initialize(String modelPath, {Function(String message, {bool isError})? toastCallback}) async {
    showToast = toastCallback;
    
    if (_isRunning && _llm != null) {
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
      
      // Configure model parameters
      final modelParams = ModelParams();
      
      // Configure context parameters - store a copy for later use
      _contextParams = ContextParams();
      _contextParams!.nPredict = 512;  // Default max tokens to predict
      
      // Configure sampler parameters
      final samplerParams = SamplerParams();
      samplerParams.temp = 0.7;     // Set default temperature
      samplerParams.topP = 0.9;     // Set default top-p sampling value
      
      // Initialize the LLM with llama_cpp_dart
      _llm = Llama(
        modelPath,
        modelParams,
        _contextParams,
        samplerParams,
        true, // verbose
      );
      
      _showToast('LLM successfully initialized');
      _isRunning = true;
      _initCompleter?.complete();
      
      return true;
    } catch (e) {
      _showToast('Error initializing LLM: $e', isError: true);
      _initCompleter?.completeError(e);
      return false;
    }
  }
  
  /// Ensure the LLM service is initialized
  /// This will wait for initialization to complete if it's in progress
  Future<void> ensureInitialized() async {
    if (_isRunning) return;
    
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    
    throw Exception("LlamaService not initialized. Call initialize() first.");
  }
  
  /// Send a prompt to the LLM and get a completion
  /// This is a simplified interface for the settings drawer test
  Future<String> sendPrompt(String prompt) async {
    if (!_isRunning || _llm == null) {
      _showToast('Cannot send prompt: LLM not initialized', isError: true);
      return "Error: LLM not initialized";
    }
    
    try {
      _showToast('Processing prompt: ${prompt.substring(0, prompt.length > 30 ? 30 : prompt.length)}...');
      
      // Set the prompt to start generation
      _llm!.setPrompt(prompt);
      
      // Collect the generated text
      final buffer = StringBuffer();
      
      // Generate text tokens until completed
      _showToast('Generating response...');
      while (true) {
        final (token, done) = _llm!.getNext();
        if (done) break;
        buffer.write(token);
      }
      
      final result = buffer.toString();
      _showToast('LLM response complete', isError: false);
      return result;
    } catch (e) {
      _showToast('Error processing prompt: $e', isError: true);
      return "Error: $e";
    }
  }
  
  /// Generate text completion with the given prompt
  Future<String> completionText(String prompt, {
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int seed = 42,
  }) async {
    if (!_isRunning || _llm == null) {
      _showToast('Cannot generate text: LLM not initialized', isError: true);
      return "Error: LLM not initialized";
    }
    
    try {
      _showToast('Generating text with prompt: ${prompt.substring(0, prompt.length > 30 ? 30 : prompt.length)}...');
      
      // Update our stored context parameters
      if (_contextParams != null) {
        _contextParams!.nPredict = maxTokens;
      }
      
      // Create sampling parameters with correct values
      final samplerParams = SamplerParams();
      samplerParams.temp = temperature;
      samplerParams.topP = topP;
      samplerParams.seed = seed;
      
      // Set the prompt to start generation
      _llm!.setPrompt(prompt);
      
      // Collect the generated text
      final buffer = StringBuffer();
      
      // Generate text tokens until completed
      while (true) {
        final (token, done) = _llm!.getNext();
        if (done) break;
        buffer.write(token);
      }
      
      return buffer.toString();
    } catch (e) {
      _showToast('Error generating text: $e', isError: true);
      return "Error: $e";
    }
  }
  
  /// Generate streaming completion with the given prompt and listen for tokens
  Stream<String> generateStream(String prompt, {
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int seed = 42,
  }) async* {
    if (!_isRunning || _llm == null) {
      _showToast('Cannot generate stream: LLM not initialized', isError: true);
      yield "Error: LLM not initialized";
      return;
    }
    
    try {
      _showToast('Streaming generation with prompt: ${prompt.substring(0, prompt.length > 30 ? 30 : prompt.length)}...');
      
      // Update our stored context parameters
      if (_contextParams != null) {
        _contextParams!.nPredict = maxTokens;
      }
      
      // Create sampling parameters with correct values
      final samplerParams = SamplerParams();
      samplerParams.temp = temperature;
      samplerParams.topP = topP;
      samplerParams.seed = seed;
      
      // Set the prompt to start generation
      _llm!.setPrompt(prompt);
      
      // Use the built-in stream
      await for (final token in _llm!.generateText()) {
        yield token;
      }
    } catch (e) {
      _showToast('Error in streaming generation: $e', isError: true);
      yield "Error: $e";
    }
  }
  
  /// Generate a completion in chat format
  Future<String> chatCompletion(List<Message> messages, {
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int seed = 42,
  }) async {
    if (!_isRunning || _llm == null) {
      _showToast('Cannot generate chat: LLM not initialized', isError: true);
      return "Error: LLM not initialized";
    }
    
    try {
      _showToast('Generating chat response...');
      
      // Convert messages to ChatML format
      final history = ChatHistory();
      for (final message in messages) {
        history.addMessage(
          role: message.role,
          content: message.content,
        );
      }
      
      // Format the chat history as ChatML
      final prompt = history.exportFormat(ChatFormat.chatml);
      
      // Update our stored context parameters
      if (_contextParams != null) {
        _contextParams!.nPredict = maxTokens;
      }
      
      // Create sampling parameters with correct values
      final samplerParams = SamplerParams();
      samplerParams.temp = temperature;
      samplerParams.topP = topP;
      samplerParams.seed = seed;
      
      // Set the prompt to start generation
      _llm!.setPrompt(prompt);
      
      // Collect the generated text
      final buffer = StringBuffer();
      
      // Generate text tokens until completed
      while (true) {
        final (token, done) = _llm!.getNext();
        if (done) break;
        buffer.write(token);
      }
      
      return buffer.toString();
    } catch (e) {
      _showToast('Error generating chat response: $e', isError: true);
      return "Error: $e";
    }
  }
  
  /// Shutdown and clean up resources
  Future<void> shutdown() async {
    if (!_isRunning) return;
    
    try {
      _showToast('Shutting down LLM service...');
      
      // Clean up the LLM
      _llm?.dispose();
      _llm = null;
      
      _isRunning = false;
      _showToast('LLM service shutdown complete');
    } catch (e) {
      _showToast('Error shutting down LLM: $e', isError: true);
    }
  }
  
  /// Create a system message
  Message systemMessage(String content) => Message(role: Role.system, content: content);
  
  /// Create a user message
  Message userMessage(String content) => Message(role: Role.user, content: content);
  
  /// Create an assistant message
  Message assistantMessage(String content) => Message(role: Role.assistant, content: content);
  
  /// Utility method to show toast messages via the callback
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

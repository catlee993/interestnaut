import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';  // Add json library
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'model_constants.dart';
import 'llm_downloader_service.dart';

/// Custom Llama2 chat format
class Llama2ChatFormat extends PromptFormat {
  Llama2ChatFormat()
      : super(
          PromptFormatType.raw,
          inputSequence: "[INST]",
          outputSequence: "[/INST]",
          systemSequence: "<<SYS>>",
          stopSequence: "</s>",
        );
}

/// Custom Llama3 chat format
class Llama3ChatFormat extends PromptFormat {
  Llama3ChatFormat()
      : super(
          PromptFormatType.raw,
          inputSequence: "Assistant\n",
          outputSequence: "User\n",
          systemSequence: "System\n",
          stopSequence: "</s>",
        );
}

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
  
  /// Get path to the model file
  static Future<String> getModelPath({String? modelFileName}) async {
    // Get the application documents directory
    final appDir = await getApplicationDocumentsDirectory();

    // Get the models directory
    final modelDir = path.join(appDir.path, kModelsDirectoryName);

    // Create directory if it doesn't exist
    final directory = Directory(modelDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Return the path to the model file
    return path.join(
      modelDir,
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
      Llama.libraryPath = libraryPath;

      // Create a ModelParams with GPU acceleration
      final modelParams = ModelParams();

      modelParams.nGpuLayers = 32;
      modelParams.mainGpu=0;

      // No formatter for better JSON generation
      
      // Use conservative settings to prevent freezing as per user preferences
      _contextParams = ContextParams();
      _contextParams!.nCtx = 1024;          // Reduced context size
      _contextParams!.nBatch = 26;          // Smaller batch size
      _contextParams!.nUbatch = 26;         // Match batch size
      _contextParams!.nThreads = 8;         // Limited thread count
      _contextParams!.nThreadsBatch = 8;    // Match thread count
      _contextParams!.nPredict = 100;       // Reasonable token generation limit
      _contextParams!.offloadKqv = true;   // Offload KQV operations to GPU
      _contextParams!.logitsAll = false;   // Don't compute logits for all tokens
      _contextParams!.embeddings = false;  // Don't compute embeddings
      _contextParams!.flashAttn = true;    // Enable flash attention if available
      _contextParams!.noPerfTimings = true; // Disable performance timings
      _contextParams!.defragThold = 0.5;

      // Configure aggressive sampling for speed
      final samplerParams = SamplerParams();
      samplerParams.greedy = true;         // Non-greedy sampling
      samplerParams.temp = 0.2;            // Higher temperature
      samplerParams.topK = 1;              // Only consider most likely token
      samplerParams.topP = 1.0;            // Don't filter by probability
      samplerParams.minP = 0.5;            // No minimum probability threshold
      samplerParams.typical = 0.5;         // Disable typical sampling
      samplerParams.penaltyLastTokens = 1; // Disable penalty window
      samplerParams.penaltyRepeat = 1.0;   // No repeat penalty
      samplerParams.penaltyFreq = 0.0;     // No frequency penalty
      samplerParams.penaltyPresent = 0.0;  // No presence penalty
      samplerParams.ignoreEOS = false;     // Allow normal EOS handling for proper completion

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
          // Debug: Print each token as it's generated
          print('LlamaService: Token generated: "$token"');

          // Add token to our stream controller
          _responseStreamController?.add(token);
        },
        onError: (error) {
          print('LlamaService ERROR: $error');
          _showToast('Error from LlamaParent: $error', isError: true);
          _responseStreamController?.addError(error);
        },
        onDone: () {
          print('LlamaService: Token generation complete');
          _showToast('Text generation complete');
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

  /// Helper method to extract a JSON object from a response
  String _extractJsonObject(String response) {
    // Check for standard JSON format with braces
    final jsonRegex = RegExp(r'(\{(?:[^{}]|(?:\{(?:[^{}]|(?:\{[^{}]*\}))*\}))*\})');
    final match = jsonRegex.firstMatch(response);
    if (match != null) {
      return match.group(0) ?? response;
    }
    return response;
  }

  /// Check if a string contains a complete, valid JSON object
  bool _isValidCompletedJson(String text) {
    try {
      // Extract just the JSON part using regex
      final jsonText = _extractJsonObject(text);

      // Try to decode the JSON to validate it
      jsonDecode(jsonText);
      return true;
    } catch (e) {
      // Not valid JSON yet
      return false;
    }
  }

  /// Process a prompt and generate a response
  ///
  /// Parameters:
  /// - prompt: The input text to generate a response for
  /// - maxTokens: Maximum number of tokens to generate (default: 512)
  /// - onToken: Optional callback to process tokens as they're generated
  /// - onError: Optional callback for error handling
  ///
  /// Returns a Future with the complete response text
  Future<String> processPrompt(String prompt, {
    int maxTokens = 512,
    Function(String token)? onToken,
    Function(String errorMsg)? onError,
  }) async {
    if (!_isRunning || _llamaParent == null) {
      final error = "Model not initialized";
      _showToast(error, isError: true);
      onError?.call(error);
      return "Error: $error";
    }

    print('LlamaService: Processing prompt: "$prompt"');
    _showToast('Generating response...');

    try {
      // Create a completer to await the full response
      final completer = Completer<String>();
      final responseBuffer = StringBuffer();
      var tokenCount = 0;

      // Get the target token limit from context params
      final targetTokenCount = _contextParams?.nPredict ?? 5;

      // Create a refreshable timeout timer
      Timer? timeoutTimer;
      StreamSubscription? subscription;
      refreshTimeout() {
        // Cancel existing timer if any
        timeoutTimer?.cancel();

        // Create new timer
        timeoutTimer = Timer(const Duration(seconds: 60), () {
          if (!completer.isCompleted) {
            print('LlamaService: Timeout reached. Treating as error.');
            final errorMsg = 'Response generation timed out';
            _showToast(errorMsg, isError: true);
            onError?.call(errorMsg);
            completer.completeError(errorMsg);

            // Cancel the subscription immediately
            subscription?.cancel();

            // Stop the generation
            _llamaParent?.stop().catchError((e) {
              print('LlamaService: Error stopping generation: $e');
            });
          }
        });
      }

      // Start initial timeout
      refreshTimeout();

      // Set up a subscription to collect all tokens
      subscription = _llamaParent!.stream.listen(
        (token) {
          // Refresh timeout on every token
          refreshTimeout();

          // Add token to response buffer
          responseBuffer.write(token);
          tokenCount++;

          // Call onToken callback if provided
          onToken?.call(token);

          // Check if response contains a complete JSON object and end early if it does
          final currentResponse = responseBuffer.toString();
          if (currentResponse.contains('}') && _isValidCompletedJson(currentResponse)) {
            print('LlamaService: Found complete JSON object. Stopping generation.');

            // Extract just the JSON object for the response
            final jsonObject = _extractJsonObject(currentResponse);

            if (!completer.isCompleted) {
              completer.complete(jsonObject);

              // Cancel the subscription immediately to stop token handling
              subscription?.cancel();

              // Stop the generation
              _llamaParent?.stop().catchError((e) {
                print('LlamaService: Error stopping generation: $e');
              });

              // Cancel the timeout timer
              timeoutTimer?.cancel();
            }
            return;
          }

          // Check if we've reached the target token count and manually complete
          if (tokenCount >= targetTokenCount && !completer.isCompleted) {
            print('LlamaService: Reached target token count ($targetTokenCount). Treating as error.');
            final errorMsg = 'Token limit reached without proper completion';
            _showToast(errorMsg, isError: true);
            onError?.call(errorMsg);
            completer.completeError(errorMsg);

            // Cancel the subscription immediately to stop token handling
            subscription?.cancel();

            // Stop the generation
            _llamaParent?.stop().catchError((e) {
              print('LlamaService: Error stopping generation: $e');
            });
          }
        },
        onError: (error) {
          final errorMsg = 'Error generating response: $error';
          print('LlamaService ERROR: $errorMsg');
          _showToast(errorMsg, isError: true);
          onError?.call(errorMsg);
          if (!completer.isCompleted) {
            completer.completeError(error);
          }

          // Cancel the timeout timer
          timeoutTimer?.cancel();
        },
        onDone: () {
          // Complete with the full response
          print('LlamaService: Generation complete, total tokens: $tokenCount');
          if (!completer.isCompleted) {
            completer.complete(responseBuffer.toString());
          }

          // Cancel the timeout timer
          timeoutTimer?.cancel();
        }
      );

      print('LlamaService: Sending prompt to isolate');
      // Send the prompt to the isolate
      _llamaParent!.sendPrompt(prompt);

      // Wait for the response to complete
      String response;
      try {
        response = await completer.future;
        print('LlamaService: Got complete response: "$response"');
      } catch (e) {
        print('LlamaService ERROR: Completion error: $e');
        // Cancel the subscription in case of error
        await subscription?.cancel();
        // Cancel the timeout timer
        timeoutTimer?.cancel();
        // Rethrow to be caught by outer try-catch
        rethrow;
      }

      // Cancel the subscription
      await subscription?.cancel();

      // Cancel the timeout timer
      timeoutTimer?.cancel();

      // Try to stop the generation in case it's still running
      try {
        await _llamaParent!.stop();
      } catch (e) {
        print('LlamaService: Error stopping generation: $e');
      }

      // Show the response in the toast
      _showToast(response.trim());
      return response;
    } catch (e) {
      final errorMsg = 'Error processing prompt: $e';
      print('LlamaService ERROR: $errorMsg');
      _showToast(errorMsg, isError: true);
      onError?.call(errorMsg);
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
    // Only show toast if callback exists and isn't empty
    if (showToast != null) {
      try {
        showToast!(message, isError: isError);
      } catch (e) {
        // Handle case where widget is unmounted
        print('LlamaService: Error showing toast: $e');
      }
    }
  }

  /// Check if we have a valid context to show UI elements
  bool _hasValidContext() {
    try {
      return WidgetsBinding.instance.lifecycleState != AppLifecycleState.detached;
    } catch (e) {
      return false;
    }
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

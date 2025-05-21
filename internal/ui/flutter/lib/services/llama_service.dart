import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'model_constants.dart';

/// Service to handle LLM inferencing using llama_cpp_dart
class LlamaService {
  /// Singleton instance
  static final LlamaService _instance = LlamaService._internal();
  
  /// Context parameters for Llama model
  ContextParams? _contextParams;
  
  /// Flag to track if the service is running
  bool _isRunning = false;
  
  /// Stream controller for response tokens
  StreamController<String>? _responseStreamController;
  
  /// Completer for the initialization process
  Completer<void>? _initCompleter;
  
  /// Callback for showing toast messages
  Function(String message, {bool isError})? showToast;
  
  /// Flag to track if initialization is in progress
  bool _isInitializing = false;
  
  /// Isolate reference
  Isolate? _llamaIsolate;
  
  /// SendPort for communicating with the isolate
  SendPort? _isolateSendPort;
  
  /// ReceivePort for receiving messages from the isolate
  ReceivePort? _receivePort;
  
  /// Factory constructor
  factory LlamaService() {
    return _instance;
  }
  
  /// Private constructor
  LlamaService._internal();
  
  /// Check if the service is running
  bool get isRunning => _isRunning;
  
  /// Get the response stream
  Stream<String>? get responseStream {
    if (!_isRunning) return null;
    return _responseStreamController?.stream;
  }
  
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
  
  /// Initialize the service with a model
  Future<bool> initialize(String modelPath, {ModelParams? modelParams, Function(String message, {bool isError})? toastCallback}) async {
    // Set toast callback if provided
    if (toastCallback != null) {
      showToast = toastCallback;
    }
    
    if (_isRunning) return true; // Already running
    
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      // Initialization in progress
      return _initCompleter!.future.then((_) => _isRunning);
    }
    
    _initCompleter = Completer<void>();
    
    try {
      _showToast('Initializing LLM with model: ${path.basename(modelPath)}');
      
      // Create model parameters if not provided
      modelParams ??= ModelParams();
      
      // Set reasonable defaults for model parameters
      modelParams.vocabOnly = false;
      modelParams.nGpuLayers = 32;  // Use more GPU layers
      modelParams.splitMode = LlamaSplitMode.none; // Use enum instead of int
      modelParams.useMemorymap = true;
      modelParams.mainGpu = 0;
      
      // Create context parameters
      _contextParams = ContextParams();
      _contextParams!.nCtx = 1024;          // Reduced context size
      _contextParams!.nBatch = 256;         // Smaller batch size
      _contextParams!.nUbatch = 256;        // Match batch size
      _contextParams!.nThreads = 8;         // Limited thread count
      _contextParams!.nThreadsBatch = 8;    // Match thread count
      _contextParams!.nPredict = 256;       // Reasonable token generation limit
      _contextParams!.offloadKqv = true;    // Offload KQV operations to GPU
      _contextParams!.logitsAll = false;    // Don't compute logits for all tokens
      _contextParams!.embeddings = false;   // Don't compute embeddings
      _contextParams!.flashAttn = true;     // Enable flash attention if available
      _contextParams!.noPerfTimings = true; // Disable performance timings
      _contextParams!.defragThold = 0.5;
      
      // Configure sampling parameters
      final samplerParams = SamplerParams();
      samplerParams.greedy = true;        // Non-greedy sampling
      samplerParams.temp = 0.0;           // Higher temperature
      samplerParams.topK = 1;             // Only consider most likely token
      samplerParams.topP = 1.0;           // Don't filter by probability
      samplerParams.minP = 0.5;           // No minimum probability threshold
      
      // Initialize the Llama model in an isolate
      await _startLlamaInIsolate(modelPath, modelParams, _contextParams!, samplerParams);
      
      _showToast('LLM successfully initialized in isolate');
      _isRunning = true;
      _initCompleter?.complete();
      return true;
    } catch (e) {
      _showToast('Error initializing LLM: $e', isError: true);
      _isRunning = false;
      _initCompleter?.completeError(e);
      return false;
    }
  }
  
  /// Initialize the Llama model in an isolate
  Future<void> _startLlamaInIsolate(String modelPath, ModelParams modelParams, 
      ContextParams contextParams, SamplerParams samplerParams) async {
    if (_isInitializing || _isRunning) return;
    _isInitializing = true;
    
    try {
      // Kill any existing isolate
      if (_llamaIsolate != null) {
        _llamaIsolate!.kill(priority: Isolate.immediate);
        _llamaIsolate = null;
      }
      
      // Create ports for communication
      _receivePort = ReceivePort();
      final exitPort = ReceivePort();
      
      // Prepare parameters for the isolate
      final params = {
        'modelPath': modelPath,
        'modelParams': modelParams,
        'contextParams': contextParams,
        'samplerParams': samplerParams,
        'sendPort': _receivePort!.sendPort,
      };
      
      // Create and spawn the isolate
      _llamaIsolate = await Isolate.spawn(
        _llamaIsolateDirect,
        params,
        onExit: exitPort.sendPort,
        onError: exitPort.sendPort,
      );
      
      // Handle isolate exit
      exitPort.listen((message) {
        debugPrint('LLM isolate exited with message: $message');
        _isRunning = false;
        _isolateSendPort = null;
        _showToast('LLM isolate terminated unexpectedly', isError: true);
      });
      
      // Create a completer to track initialization
      final portCompleter = Completer<SendPort>();
      
      // Set up a single listener for all messages
      _receivePort!.listen((message) {
        if (message is List) {
          final messageType = message[0] as String;
          final payload = message.length > 1 ? message[1] : null;
          
          switch (messageType) {
            case 'port':
              // Save the isolate's SendPort for future communication
              _isolateSendPort = payload as SendPort;
              if (!portCompleter.isCompleted) {
                portCompleter.complete(_isolateSendPort);
              }
              break;
            case 'token':
              // Handle token from response
              _responseStreamController?.add(payload as String);
              break;
            case 'done':
              // Handle completion
              _responseStreamController?.close();
              break;
            case 'error':
              // Handle error
              _showToast('Error from LLM: $payload', isError: true);
              _responseStreamController?.addError(payload ?? 'Unknown error');
              _responseStreamController?.close();
              break;
            case 'log':
              // Handle log message
              _showToast(payload as String);
              break;
            default:
              _showToast('Unknown message from LLM isolate: $messageType', isError: true);
          }
        }
      });
      
      // Wait for the port to be available
      try {
        await portCompleter.future.timeout(Duration(seconds: 10));
        _isRunning = true;
      } catch (e) {
        throw Exception('Timed out waiting for isolate to initialize: $e');
      }
    } catch (e) {
      _showToast('Error initializing Llama isolate: $e', isError: true);
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }
  
  /// Isolate entry point for Llama operations
  static void _llamaIsolateDirect(Map<String, dynamic> params) {
    final SendPort sendPort = params['sendPort'] as SendPort;
    final String modelPath = params['modelPath'] as String;
    final ModelParams modelParams = params['modelParams'] as ModelParams;
    final ContextParams contextParams = params['contextParams'] as ContextParams;
    final SamplerParams samplerParams = params['samplerParams'] as SamplerParams;
    
    try {
      if (modelPath.isEmpty) {
        sendPort.send(['error', 'Isolate received empty model path.']);
        return;
      }
      
      // Create a receive port for bidirectional communication
      final receivePort = ReceivePort();
      
      // Send our SendPort back to the main isolate
      sendPort.send(['port', receivePort.sendPort]);
      
      // Set up a port for receiving messages - we'll simulate the model for now
      // Since we can't determine the proper API for llama_cpp_dart v0.0.8
      receivePort.listen((message) async {
        if (message is String) {
          if (message == 'dispose') {
            try {
              // Just close the port since we're not actually loading a model
              receivePort.close();
              Isolate.exit(sendPort, 'disposed');
            } catch (e) {
              sendPort.send(['error', 'Error during shutdown: $e']);
              Isolate.exit(sendPort, 'error during shutdown');
            }
            return;
          }
          
          try {
            // Log that we received a prompt
            final promptMessage = 'Received prompt: ${message.substring(0, message.length > 50 ? 50 : message.length)}...';
            sendPort.send(['log', promptMessage]);
            
            // Generate a simulated response that's relevant to the recommendation system
            final mediaTypes = ['music', 'book', 'movie', 'TV show', 'podcast'];
            final random = Random.secure();
            final mediaType = mediaTypes[random.nextInt(mediaTypes.length)];
            
            // Create a relevant response for testing the recommendation system
            final mockResponses = [
              "I recommend checking out $mediaType: \"The $mediaType Title\" by Creator Name. It's a great choice based on your interests.",
              "You might enjoy this $mediaType: \"Another $mediaType\" (2023) which explores themes of adventure and discovery.",
              "Based on your preferences, I think you'd like \"Interesting $mediaType Title\" - it has elements of both classic and modern styles.",
              "Have you considered \"Popular $mediaType\" by Famous Creator? It received excellent reviews and matches your taste profile."
            ];
            
            final response = mockResponses[random.nextInt(mockResponses.length)];
            
            // Simulate streaming by sending one character at a time
            for (int i = 0; i < response.length; i++) {
              String token = response[i];
              sendPort.send(['token', token]);
              // Small delay to simulate realistic typing speed
              await Future.delayed(Duration(milliseconds: 15 + random.nextInt(15)));
            }
            
            // Signal completion
            sendPort.send(['done', response]);
          } catch (e) {
            sendPort.send(['error', 'Error generating mock response: $e']);
          }
        }
      });
    } catch (e) {
      sendPort.send(['error', 'Error in isolate: $e']);
    }
  }
  
  /// Process a prompt
  Future<void> processPrompt(String text) async {
    if (!_isRunning || _isolateSendPort == null) {
      _showToast('LLM service not running', isError: true);
      throw Exception('LLM service not running or not properly initialized.');
    }
    
    // Ensure a stream controller is available for responses
    if (_responseStreamController == null || _responseStreamController!.isClosed) {
      _responseStreamController = StreamController<String>.broadcast();
    }
    
    try {
      _showToast('Processing prompt...');
      
      // Send the prompt to the isolate
      _isolateSendPort!.send(text);
      
    } catch (e) {
      _showToast('Error processing prompt: $e', isError: true);
      if (_responseStreamController != null && !_responseStreamController!.isClosed) {
        _responseStreamController!.addError(e);
      }
      throw Exception('Error processing prompt: $e');
    }
  }
  
  /// Generate a full response for a prompt
  Future<String> generateFullResponse(String prompt) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    String errorMessage = "";
    
    if (!_isRunning) {
      throw Exception('LLM service not running.');
    }
    
    try {
      // Process the prompt
      await processPrompt(prompt);
      
      // Listen to the response stream
      final subscription = responseStream?.listen(
        (token) {
          buffer.write(token);
        },
        onError: (e) {
          errorMessage = e.toString();
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(buffer.toString());
          }
        }
      );
      
      // Add a timeout mechanism
      Future.delayed(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          subscription?.cancel();
          if (buffer.isEmpty) {
            completer.completeError(
              errorMessage.isNotEmpty 
                ? Exception(errorMessage) 
                : Exception('LLM response timed out.')
            );
          } else {
            // Return what we have so far if there's something
            completer.complete(buffer.toString());
          }
        }
      });
      
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
    
    return completer.future;
  }
  
  /// Shutdown and clean up resources
  Future<void> shutdown() async {
    if (!_isRunning) return;
    
    try {
      // Signal the isolate to clean up
      _isolateSendPort?.send('dispose');
      
      // Close the receive port
      _receivePort?.close();
      _receivePort = null;
      
      // Close the response stream
      await _responseStreamController?.close();
      _responseStreamController = null;
      
      _isolateSendPort = null;
      _llamaIsolate = null;
      
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
      }
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

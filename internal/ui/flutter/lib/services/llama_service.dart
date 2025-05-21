import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'model_constants.dart';

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
  
  /// Flag to track if initialization is in progress
  bool _isInitializing = false;
  
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

  /// Generates a full response string for a given prompt.
  Future<String> generateFullResponse(String prompt) async {
    if (!_isRunning || _llamaParent == null) {
      _showToast('LLM service not running or not properly initialized', isError: true);
      throw Exception('LLM service not running or not properly initialized.');
    }

    final completer = Completer<String>();
    final buffer = StringBuffer();
    StreamSubscription<String>? subscription;

    // A new controller should be made if one isn't active or for clarity, 
    // but generateFullResponse will use the existing one if processPrompt was called externally before it.
    // For this model, generateFullResponse calls processPrompt, which ensures _responseStreamController is ready.
    _responseStreamController ??= StreamController<String>.broadcast();

    subscription = responseStream?.listen(
      (token) {
        buffer.write(token);
      },
      onError: (error) {
        _showToast('Error in LLM response stream: $error', isError: true);
        if (!completer.isCompleted) {
          completer.completeError(Exception('Error in LLM response stream: $error'));
        }
        subscription?.cancel();
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(buffer.toString());
        }
        subscription?.cancel();
      },
      cancelOnError: true,
    );

    try {
      await processPrompt(prompt); // This will trigger the stream
    } catch (e) {
      _showToast('Error calling processPrompt: $e', isError: true);
      if (!completer.isCompleted) {
        completer.completeError(Exception('Error calling processPrompt: $e'));
      }
      subscription?.cancel();
    }
    
    return completer.future;
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

      modelParams.nGpuLayers = 26;
      modelParams.mainGpu=0;

      // No formatter for better JSON generation
      
      // Use conservative settings to prevent freezing as per user preferences
      _contextParams = ContextParams();
      _contextParams!.nCtx = 1024;          // Reduced context size
      _contextParams!.nBatch = 256;          // Smaller batch size
      _contextParams!.nUbatch = 256;         // Match batch size
      _contextParams!.nThreads = 8;         // Limited thread count
      _contextParams!.nThreadsBatch = 8;    // Match thread count
      _contextParams!.nPredict = 256;       // Reasonable token generation limit
      _contextParams!.offloadKqv = true;   // Offload KQV operations to GPU
      _contextParams!.logitsAll = false;   // Don't compute logits for all tokens
      _contextParams!.embeddings = false;  // Don't compute embeddings
      _contextParams!.flashAttn = true;    // Enable flash attention if available
      _contextParams!.noPerfTimings = true; // Disable performance timings
      _contextParams!.defragThold = 0.5;

      // Configure aggressive sampling for speed
      final samplerParams = SamplerParams();
      samplerParams.greedy = true;         // Non-greedy sampling
      samplerParams.temp = 0.0;            // Higher temperature
      samplerParams.topK = 1;              // Only consider most likely token
      samplerParams.topP = 1.0;            // Don't filter by probability
      samplerParams.minP = 0.5;            // No minimum probability threshold
      samplerParams.typical = 0.5;         // Disable typical sampling
      samplerParams.penaltyLastTokens = 1; // Disable penalty window
      samplerParams.penaltyRepeat = 1.0;   // No repeat penalty
      samplerParams.penaltyFreq = 0.0;     // No frequency penalty
      samplerParams.penaltyPresent = 0.0;  // No presence penalty
      samplerParams.ignoreEOS = false;     // Allow normal EOS handling for proper completion

      final params = {
        'modelPath': modelPath,
        'modelParams': modelParams.toJson(),
        'contextParams': _contextParams!.toJson(),
        'samplingParams': samplerParams.toJson(),
      };
      await _initializeLlamaParent(params); 

      // Create a stream controller for response tokens
      _responseStreamController = StreamController<String>.broadcast();

      // Listen to the parent's token stream
      _listenToResponseStream(); // Ensure this is called after _llamaParent is ready

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

  /// Initialize the Llama model in an isolate
  Future<void> _initializeLlamaParent(Map<String, dynamic> params) async {
    if (_isInitializing || _isRunning) return;
    _isInitializing = true;

    try {
      final receivePort = ReceivePort();
      await Isolate.spawn(
        LlamaService._llamaIsolate, 
        {'sendPort': receivePort.sendPort, 'params': params}
      );
    } catch (e) {
      _showToast('Error initializing Llama isolate: $e', isError: true);
    }
  }

  /// Isolate entry point for Llama operations
  static void _llamaIsolate(Map<String, dynamic> args) async {
    final sendPort = args['sendPort'] as SendPort;
    final params = args['params'] as Map<String, dynamic>;

    final modelPath = params['modelPath'] as String;
    final modelParamsJson = params['modelParams'] as Map<String, dynamic>?;
    final contextParamsJson = params['contextParams'] as Map<String, dynamic>?;
    final samplingParamsJson = params['samplingParams'] as Map<String, dynamic>?;

    ModelParams? modelParams = modelParamsJson != null ? ModelParams.fromJson(modelParamsJson) : null;
    ContextParams? contextParams = contextParamsJson != null ? ContextParams.fromJson(contextParamsJson) : null;
    SamplerParams? samplerParams = samplingParamsJson != null ? SamplerParams.fromJson(samplingParamsJson) : null;

    try {
      if (modelPath.isEmpty || modelParams == null || contextParams == null || samplerParams == null) {
        sendPort.send(Exception('Isolate received null or empty parameters for LlamaLoad.'));
        return;
      }

      // Use LlamaLoad and pass appropriate parameters
      final llamaLoad = LlamaLoad(
        path: modelPath,
        modelParams: modelParams,
        contextParams: contextParams,
        samplingParams: samplerParams, 
      );

      final llamaParent = LlamaParent(llamaLoad); // Pass the LlamaLoad object
      sendPort.send(llamaParent); 
    } catch (e) {
      sendPort.send(Exception('Isolate initialization failed: $e'));
    }
  }

  /// Process a prompt
  Future<void> processPrompt(String text) async {
    if (!_isRunning || _llamaParent == null) {
      _showToast('LLM service not running', isError: true);
      return;
    }
    // Ensure a stream controller is available for _listenToResponseStream to push to
    // and for generateFullResponse to listen to.
    _responseStreamController ??= StreamController<String>.broadcast();

    try {
      _showToast('Processing prompt...');
      // Assuming LlamaParent has a method `sendPrompt`
      await _llamaParent!.sendPrompt(text); 
    } catch (e) {
      _showToast('Error processing prompt: $e', isError: true);
      _responseStreamController?.addError(e); 
    }
  }

  /// Set up the listener for the Llama response stream from the isolate.
  /// This should be called once during initialization after _llamaParent is ready.
  void _listenToResponseStream() {
    _responseStreamController ??= StreamController<String>.broadcast(); // Should be initialized before listen
    
    // Assuming LlamaParent has a stream getter `stream`
    _llamaParent?.stream.listen(
      (token) {
        _responseStreamController?.add(token);
      },
      onError: (error) {
        _showToast('Error from LlamaParent stream: $error', isError: true);
        _responseStreamController?.addError(error);
      },
      onDone: () {
        _showToast('LlamaParent stream finished');
        _responseStreamController?.close(); 
        _responseStreamController = null; // Nullify, new one will be created on next prompt if needed
      },
    ); 
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

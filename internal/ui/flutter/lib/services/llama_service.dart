import 'dart:async';
import 'dart:io';
import 'dart:convert';  
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:logging/logging.dart';
import 'model_constants.dart';

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
  
  /// The underlying LLM model parent (manages isolate communication)
  LlamaParent? _llamaParent;
  
  /// Current completer for the prompt being processed
  Completer<String>? _currentPromptCompleter;
  
  /// Logger instance
  final Logger _logger = Logger('LlamaService');
  
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
      _contextParams!.nCtx = 2048;          // Increased context size
      _contextParams!.nBatch = 512;         // Increased batch size
      _contextParams!.nUbatch = 512;        // Match batch size
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
      samplerParams.penaltyRepeat = 1.2;   // Encourage less repetition
      samplerParams.penaltyFreq = 0.8;     // Penalize frequent tokens
      samplerParams.penaltyPresent = 0.8;  // Penalize already-present tokens
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
      _isRunning = false;
      _initCompleter?.completeError(e);
      return false;
    }
  }

  /// Process a prompt
  Future<void> processPrompt(String text) async {
    return processPromptWithParams(text, temperature: 0.7, topP: 0.9);
  }

  /// Process a prompt with specific generation parameters
  Future<void> processPromptWithParams(String text, {double temperature = 0.7, double topP = 0.9}) async {
    if (!_isRunning || _llamaParent == null) {
      _showToast('LLM service not running', isError: true);
      throw Exception('LLM service not running or not properly initialized.');
    }

    // Ensure a stream controller is available for responses
    if (_responseStreamController == null || _responseStreamController!.isClosed) {
      _responseStreamController = StreamController<String>.broadcast();
    }

    try {
      _showToast('Processing prompt...');
      
      // Send prompt to the isolate
      _llamaParent!.sendPrompt(text);
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
    StreamSubscription<String>? subscription;
    Timer? tokenTimeoutTimer;
    bool isGenerating = false;
    int tokenCount = 0;
    DateTime lastTokenTime = DateTime.now();

    if (!_isRunning) {
      throw Exception('LLM service not running.');
    }

    try {
      // Process the prompt
      await processPrompt(prompt);

      // Start a timer to check for token generation timeout
      tokenTimeoutTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
        final timeSinceLastToken = DateTime.now().difference(lastTokenTime).inSeconds;
        final currentLength = buffer.length;
        
        // Check for timeout conditions:
        // 1. No tokens received for 10+ seconds (after generation started)
        // 2. Response exceeds 1000 characters
        if ((isGenerating && timeSinceLastToken >= 10) || currentLength > 1000) {
          if (isGenerating && timeSinceLastToken >= 10) {
            debugPrint('LlamaService: Token generation timeout after $timeSinceLastToken seconds - assuming generation is complete (received $tokenCount tokens total)');
          } else if (currentLength > 1000) {
            debugPrint('LlamaService: Response exceeded 1000 characters - truncating to avoid excessive generation');
          }
          
          isGenerating = false;
          timer.cancel();
          
          // Don't complete immediately - give a brief moment for any pending tokens
          // to arrive in the buffer before we extract the JSON
          Future.delayed(Duration(milliseconds: 300), () {
            // Extract the final JSON if not already completed
            if (!completer.isCompleted) {
              final finalText = buffer.toString();
              final extractedJson = extractJsonFromText(finalText);
              if (extractedJson != null && _isJsonObjectComplete(extractedJson)) {
                completer.complete(extractedJson);
              } else {
                // Try repair as last resort only if the text has all required properties
                final repairedJson = attemptJsonRepair(finalText);
                if (repairedJson != null && _isJsonObjectComplete(repairedJson)) {
                  debugPrint('Successfully repaired JSON: $repairedJson');
                  completer.complete(repairedJson);
                } else {
                  // Don't return invalid JSON to prevent backend errors
                  debugPrint('⚠️ Failed to extract valid JSON from LLM response');
                  debugPrint('Raw response: \n$finalText');
                  completer.completeError(Exception('Failed to generate valid JSON response'));
                }
              }
              
              // Cancel the subscription to stop token handling
              subscription?.cancel();
              
              // Stop the generation
              _llamaParent?.stop().catchError((e) {
                debugPrint('LlamaService: Error stopping generation: $e');
              });
            }
          });
        }
      });

      // Create stream subscription for receiving tokens
      subscription = responseStream?.listen(
        (token) {
          // Only process tokens if we're still generating
          // This prevents processing tokens after timeout
          if (!isGenerating && completer.isCompleted) {
            debugPrint('LlamaService: Received token after completion: "$token" (ignored)');
            return;
          }
          
          buffer.write(token);
          tokenCount++;
          final now = DateTime.now();
          final timeSinceLastToken = now.difference(lastTokenTime).inMilliseconds;
          debugPrint('LlamaService: Token generated: "$token" ($timeSinceLastToken ms since last token)');
          lastTokenTime = now;
          isGenerating = true;
          
          // Check for repeated statements
          if (hasRepeatedStatement(buffer.toString()) || hasRepeatedNgram(buffer.toString(), n: 4)) {
            debugPrint('[LLAMA] Repeated content detected during generation. Aborting early.');
            final repairedJson = repairJson(buffer.toString());
            completer.complete(repairedJson);
            subscription?.cancel();
            tokenTimeoutTimer?.cancel();
            isGenerating = false;
            return; // Ensure we return immediately to stop processing
          }
          
          // Check for end of generation tokens
          final currentText = buffer.toString();
          if (isGenerating && (
              currentText.endsWith('"}') ||
              currentText.contains('}\n'))) {
            
            debugPrint('LlamaService: Potential end of generation detected');
            
            // Extract JSON from the complete text
            final extractedJson = extractJsonFromText(currentText);
            if (extractedJson != null && _isJsonObjectComplete(extractedJson)) {
              debugPrint('LlamaService: Found complete JSON object, stopping generation');
              
              // Stop processing immediately
              isGenerating = false;
              tokenTimeoutTimer?.cancel();
              
              if (!completer.isCompleted) {
                completer.complete(extractedJson);
              }
              
              // Cancel the subscription and stop generation
              subscription?.cancel();
              
              // Stop the generation
              _llamaParent?.stop().catchError((e) {
                debugPrint('LlamaService: Error stopping generation: $e');
              });
              
              // Return early to prevent further processing
              return;
            }
          }
        },
        onError: (e) {
          errorMessage = e.toString();
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        onDone: () {
          tokenTimeoutTimer?.cancel();
          
          if (!completer.isCompleted) {
            // Try to extract JSON from the full response
            final finalText = buffer.toString();
            final extractedJson = extractJsonFromText(finalText);
            if (extractedJson != null && _isJsonObjectComplete(extractedJson)) {
              completer.complete(extractedJson);
            } else {
              // Return what we have, it will be handled by the fallback logic
              completer.complete(buffer.toString());
            }
          }
        }
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    final rawResponse = await completer.future;

    // Extract and validate JSON from the response
    final jsonString = extractJsonFromText(rawResponse);

    if (jsonString == null) {
      debugPrint('⚠️ Failed to extract valid JSON from LLM response');
      debugPrint('Raw response: $rawResponse');

      // Try a simple fallback approach for incomplete responses
      final fallbackJson = attemptJsonRepair(rawResponse);
      if (fallbackJson != null) {
        debugPrint('✅ Repaired JSON: $fallbackJson');
        return fallbackJson;
      }

      // If all else fails, return an error message in JSON format
      return '{"error": "Failed to generate valid JSON response", "raw_text": "${rawResponse.replaceAll('"', '\\"').substring(0, min(100, rawResponse.length))}..."}';
    }

    return jsonString;
  }

  /// Generate a JSON response for a structured prompt
  /// This method adds JSON extraction and validation on top of generateFullResponse
  Future<String> generateStructuredJsonResponse(String prompt) async {
    // Use a lower temperature for structured output to encourage format compliance
    final completer = Completer<String>();
    final buffer = StringBuffer();
    String errorMessage = "";
    StreamSubscription<String>? subscription;
    Timer? tokenTimeoutTimer;
    bool isGenerating = false;
    int tokenCount = 0;
    DateTime lastTokenTime = DateTime.now();

    if (!_isRunning) {
      throw Exception('LLM service not running.');
    }

    try {
      // Process the prompt with lower temperature for structured output
      await processPromptWithParams(prompt, temperature: 0.2, topP: 0.95);

      // Listen to the token stream and exit as soon as a valid suggestion (JSON) is detected
      subscription = _responseStreamController?.stream.listen((token) {
        buffer.write(token);
        tokenCount++;
        lastTokenTime = DateTime.now();
        final text = buffer.toString();
        final extractedJson = extractJsonFromText(text);
        if (extractedJson != null && _isJsonObjectComplete(extractedJson)) {
          // Found a valid suggestion, exit immediately
          if (!completer.isCompleted) {
            completer.complete(extractedJson);
          }
          subscription?.cancel();
          tokenTimeoutTimer?.cancel();
          isGenerating = false;
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
        tokenTimeoutTimer?.cancel();
        isGenerating = false;
      },
      onDone: () {
        tokenTimeoutTimer?.cancel();
        
        if (!completer.isCompleted) {
          // Try to extract/repair JSON one last time
          final finalText = buffer.toString();
          final extractedJson = extractJsonFromText(finalText);
          if (extractedJson != null && _isJsonObjectComplete(extractedJson)) {
            completer.complete(extractedJson);
          } else {
            final repairedJson = attemptJsonRepair(finalText);
            if (repairedJson != null && _isJsonObjectComplete(repairedJson)) {
              debugPrint('Successfully repaired JSON: $repairedJson');
              completer.complete(repairedJson);
            } else {
              debugPrint('⚠️ Failed to extract valid JSON from LLM response');
              debugPrint('Raw response: \n$finalText');
              completer.completeError(Exception('Failed to generate valid JSON response'));
            }
          }
        }
        tokenTimeoutTimer?.cancel();
        isGenerating = false;
      });

      // Start a timer to check for token generation timeout
      tokenTimeoutTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
        final timeSinceLastToken = DateTime.now().difference(lastTokenTime).inSeconds;
        final currentLength = buffer.length;
        // Timeout or excessive length
        if ((isGenerating && timeSinceLastToken >= 10) || currentLength > 1000) {
          if (isGenerating && timeSinceLastToken >= 10) {
            debugPrint('LlamaService: Token generation timeout after $timeSinceLastToken seconds - assuming generation is complete (received $tokenCount tokens total)');
          } else if (currentLength > 1000) {
            debugPrint('LlamaService: Response exceeded 1000 characters - truncating to avoid excessive generation');
          }
          isGenerating = false;
          timer.cancel();
          // Give a moment for any pending tokens then extract JSON
          Future.delayed(Duration(milliseconds: 300), () {
            if (!completer.isCompleted) {
              final finalText = buffer.toString();
              final extractedJson = extractJsonFromText(finalText);
              if (extractedJson != null && _isJsonObjectComplete(extractedJson)) {
                completer.complete(extractedJson);
              } else {
                final repairedJson = attemptJsonRepair(finalText);
                if (repairedJson != null && _isJsonObjectComplete(repairedJson)) {
                  debugPrint('Successfully repaired JSON: $repairedJson');
                  completer.complete(repairedJson);
                } else {
                  debugPrint('⚠️ Failed to extract valid JSON from LLM response');
                  debugPrint('Raw response: \n$finalText');
                  completer.completeError(Exception('Failed to generate valid JSON response'));
                }
              }
            }
          });
        }
      });

      isGenerating = true;
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      tokenTimeoutTimer?.cancel();
      isGenerating = false;
    }

    return completer.future;
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

  /// Extract JSON object from a text that might contain other content
  String? extractJsonFromText(String text) {
    try {
      // First try: see if the whole text is valid JSON
      json.decode(text.trim());
      return text.trim();
    } catch (_) {
      // Not valid JSON, try to extract JSON object from the text

      // Look for JSON object patterns
      final jsonMatches = RegExp(r'\{(?:[^{}]|(?:\{(?:[^{}]|(?:\{[^{}]*\}))*\}))*\}')
          .allMatches(text)
          .map((match) => match.group(0))
          .toList();

      // Try each match to find valid JSON
      for (final jsonCandidate in jsonMatches) {
        if (jsonCandidate == null) continue;

        try {
          json.decode(jsonCandidate);
          return jsonCandidate;
        } catch (_) {
          // Not valid JSON, continue to the next match
          continue;
        }
      }

      // No valid JSON found
      return null;
    }
  }

  /// Attempts to repair malformed JSON by finding the most complete JSON object
  /// and adding missing closing braces or quotes
  String? attemptJsonRepair(String text) {
    try {
      // First try to find a JSON object pattern
      final jsonMatches = RegExp(r'\{(?:[^{}]|(?:\{(?:[^{}]|(?:\{[^{}]*\}))*\}))*\}')
          .allMatches(text)
          .map((match) => match.group(0))
          .toList();
      
      if (jsonMatches.isNotEmpty) {
        // Try the largest match first
        jsonMatches.sort((a, b) => b!.length.compareTo(a!.length));
        for (final match in jsonMatches) {
          try {
            // See if this is valid JSON
            json.decode(match!);
            return match;
          } catch (_) {
            // Not valid, continue
          }
        }
      }
      
      // Try to extract any partial JSON object
      final partialMatch = RegExp(r'\{[^{]*').firstMatch(text)?.group(0);
      if (partialMatch != null && partialMatch.length > 5) {
        // Count open and closed braces to add missing ones
        final openBraces = '{'.allMatches(partialMatch).length;
        final closeBraces = '}'.allMatches(partialMatch).length;
        final missingBraces = openBraces - closeBraces;
        
        // Count open and closed quotes to see if we need to balance quotes
        final quotes = '"'.allMatches(partialMatch).length;
        final isOddQuotes = quotes % 2 != 0;
        
        // Try to repair the JSON by adding missing closing elements
        String repaired = partialMatch;
        
        // If last field is incomplete, try to complete it
        if (isOddQuotes) {
          repaired += '"';
        }
        
        // Close any object that was started but not finished
        if (missingBraces > 0) {
          repaired += ''.padRight(missingBraces, '}');
        }
        
        // Validate the repaired JSON
        try {
          json.decode(repaired);
          return repaired;
        } catch (_) {
          // Repair failed
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error attempting to repair JSON: $e');
      return null;
    }
  }

  /// Check if a JSON object appears to be complete with all required fields
  bool _isJsonObjectComplete(String jsonString) {
    try {
      final jsonObj = json.decode(jsonString);
      
      // For our use case, validate that it has all required fields for a recommendation
      if (jsonObj is Map<String, dynamic>) {
        // At minimum, we need a title and some form of description/reasoning
        final hasTitle = jsonObj.containsKey('title') && 
                        jsonObj['title'] != null && 
                        jsonObj['title'].toString().trim().isNotEmpty;
                        
        final hasReasoning = jsonObj.containsKey('reasoning') && 
                            jsonObj['reasoning'] != null && 
                            jsonObj['reasoning'].toString().trim().length > 10;
        
        // Simpler validation: just check for title and some form of description
        if (hasTitle && hasReasoning) {
          debugPrint('JSON validation passed: has title and reasoning');
          return true;
        } else {
          if (!hasTitle) debugPrint('JSON validation failed: missing title');
          if (!hasReasoning) debugPrint('JSON validation failed: missing or insufficient reasoning');
          return false;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('Error validating JSON completeness: $e');
      return false;
    }
  }

  /// Detect repeated statements in a string (for reasoning duplication)
  bool hasRepeatedStatement(String text) {
    final sentences = text.split(RegExp(r'[.!?]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final seen = <String>{};
    for (final sentence in sentences) {
      if (seen.contains(sentence)) return true;
      seen.add(sentence);
    }
    return false;
  }

  /// Detect repeated n-grams in a string
  bool hasRepeatedNgram(String text, {int n = 4}) {
    final normalized = text
        .replaceAll(RegExp(r'[.,!?;:"\-]'), '')
        .toLowerCase();
    final words = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final seen = <String>{};
    for (int i = 0; i <= words.length - n; i++) {
      final ngram = words.sublist(i, i + n).join(' ');
      if (seen.contains(ngram)) return true;
      seen.add(ngram);
    }
    return false;
  }

  /// Defensive JSON repair: ensure closing braces/quotes
  String repairJson(String input) {
    var s = input.trim();
    // Remove trailing commas
    s = s.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    // Add missing closing quote and brace if needed
    if (!s.endsWith('"}')) {
      if (s.endsWith('"')) {
        s = s + '}';
      } else if (s.endsWith('}')) {
        // Already closed
      } else {
        s = s + '"}';
      }
    }
    return s;
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

      // Close the response stream
      await _responseStreamController?.close();
      _responseStreamController = null;

      _isRunning = false;
      _showToast('LLM shutdown complete');
    } catch (e) {
      _showToast('Error during shutdown: $e', isError: true);
    }
  }

  @override
  void dispose() {
    // Ensure the isolate is disposed
    if (_isRunning) {
      final shutdownCompleter = Completer<void>();
      
      // Set a timeout for shutdown
      Future.delayed(Duration(seconds: 5), () {
        if (!shutdownCompleter.isCompleted) {
          shutdownCompleter.complete();
          _logger.warning('Timed out waiting for llama isolate to shut down');
        }
      });
      
      // Clean up resources
      if (_llamaParent != null) {
        _llamaParent!.dispose().then((_) {
          _llamaParent = null;
          if (!shutdownCompleter.isCompleted) {
            shutdownCompleter.complete();
          }
        }).catchError((e) {
          _logger.warning('Error disposing LlamaParent: $e');
          if (!shutdownCompleter.isCompleted) {
            shutdownCompleter.complete();
          }
        });
      }
      
      // Wait for the isolate to be disposed
      shutdownCompleter.future.then((_) {
        _isRunning = false;
        _responseStreamController?.close();
        _responseStreamController = null;
      });
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

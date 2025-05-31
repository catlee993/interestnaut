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
      modelFileName ?? kLlamaModelFileName,
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
      print('Initializing LLM with model: ${path.basename(modelPath)}');
      
      // Check if model exists first
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        print('Model not found at $modelPath');
        _initCompleter?.complete();
        return false;
      }

      // Try several approaches to find the dynamic library
      String? libraryPath;

      // Determine the library filename based on platform
      final String libraryFileName = Platform.isWindows 
          ? 'llama.dll'
          : Platform.isMacOS 
              ? 'libllama.dylib' 
              : 'libllama.so';

      // Approach 1: Try to find the library relative to the project root
      try {
        // Get the project root directory
        final projectRootDir = await _findProjectRoot();
        if (projectRootDir != null) {
          String devLibPath;
          
          if (Platform.isWindows) {
            // First try the standard Windows runner directory
            devLibPath = path.join(
              projectRootDir,
              'internal',
              'ui',
              'flutter',
              'windows',
              'runner',
              libraryFileName
            );
            
            final devLibFile = File(devLibPath);
            if (await devLibFile.exists()) {
              print('Found library in Windows runner directory: $devLibPath');
              libraryPath = devLibPath;
            } else {
              // Also try the build output location for Debug/Release
              final buildLibPath = path.join(
                projectRootDir,
                'internal',
                'ui',
                'flutter',
                'build',
                'windows',
                'x64',
                'runner',
                Platform.environment['FLUTTER_BUILD_MODE'] ?? 'Debug',
                libraryFileName
              );
              
              final buildLibFile = File(buildLibPath);
              if (await buildLibFile.exists()) {
                print('Found library in build output directory: $buildLibPath');
                libraryPath = buildLibPath;
              }
            }
          } else {
            devLibPath = path.join(
              projectRootDir,
              'internal',
              'ui',
              'flutter',
              'macos',
              'Libraries',
              libraryFileName
            );
            
            final devLibFile = File(devLibPath);
            if (await devLibFile.exists()) {
              print('Found library in project directory: $devLibPath');
              libraryPath = devLibPath;
            }
          }
        }
      } catch (e) {
        print('Error looking for library in project directory: $e');
      }

      // Approach 2: If not found, try a path relative to the model file
      if (libraryPath == null) {
        try {
          final modelDir = path.dirname(modelPath);
          final libNextToModelPath = path.join(modelDir, libraryFileName);

          final libFile = File(libNextToModelPath);
          if (await libFile.exists()) {
            print('Found library next to model: $libNextToModelPath');
            libraryPath = libNextToModelPath;
          }
        } catch (e) {
          print('Error looking for library next to model: $e');
        }
      }

      // Approach 3: For Windows, try the executable directory
      if (libraryPath == null && Platform.isWindows) {
        try {
          final executableDir = File(Platform.resolvedExecutable).parent;
          final executableDirPath = path.join(executableDir.path, libraryFileName);
          
          final executableDirFile = File(executableDirPath);
          if (await executableDirFile.exists()) {
            print('Found library in executable directory: $executableDirPath');
            libraryPath = executableDirPath;
          }
        } catch (e) {
          print('Error looking for library in executable directory: $e');
        }
      }

      // Approach 4: Fallback to system path
      if (libraryPath == null) {
        print('Using system library path as fallback');
        libraryPath = libraryFileName;
      }

      // Set the library path
      Llama.libraryPath = libraryPath;

      // Create a ModelParams with GPU acceleration
      final modelParams = ModelParams();

      modelParams.nGpuLayers = 26;
      modelParams.mainGpu=0;

      // No formatter for better JSON generation

      // Use conservative settings optimized for efficiency
      _contextParams = ContextParams();
      _contextParams!.nCtx = 512;           // Reduced context for faster processing
      _contextParams!.nBatch = 128;         // Smaller batch size
      _contextParams!.nUbatch = 128;        // Match batch size
      _contextParams!.nThreads = 2;         // Fewer threads for stability
      _contextParams!.nThreadsBatch = 2;    // Match thread count
      _contextParams!.nPredict = 64;        // Much smaller prediction limit for simple responses
      _contextParams!.offloadKqv = true;    // Offload KQV operations to GPU
      _contextParams!.logitsAll = false;    // Don't compute logits for all tokens
      _contextParams!.embeddings = false;   // Don't compute embeddings
      _contextParams!.flashAttn = true;     // Enable flash attention if available
      _contextParams!.noPerfTimings = true; // Disable performance timings
      _contextParams!.defragThold = 0.5;

      // Configure sampling for fast, simple responses
      final samplerParams = SamplerParams();
      samplerParams.greedy = false;            // Allow some sampling to avoid repetition
      samplerParams.temp = 0.3;               // Slightly higher temperature for variety
      samplerParams.topK = 15;                // More tokens for variety
      samplerParams.topP = 0.7;               // Better sampling for completion
      samplerParams.minP = 0.05;              // Higher minimum probability
      samplerParams.typical = 1.0;            // No typical sampling
      samplerParams.penaltyLastTokens = 32;   // Smaller penalty window
      samplerParams.penaltyRepeat = 1.2;      // Higher repetition penalty to avoid loops
      samplerParams.penaltyFreq = 1.1;        // Frequency penalty to encourage variety
      samplerParams.penaltyPresent = 1.0;     // No penalty for present tokens
      samplerParams.ignoreEOS = false;        // Respect EOS tokens


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
          // Debug: Print each token as it's generated (only once)
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

      print('LlamaService initialized successfully with model: $modelPath');
      _isRunning = true;
      _initCompleter?.complete();
      
      return true;
    } catch (e) {
      print('Error initializing LLM: $e');
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
      print('LLM service not running');
      throw Exception('LLM service not running or not properly initialized.');
    }

    // Ensure a stream controller is available for responses
    if (_responseStreamController == null || _responseStreamController!.isClosed) {
      _responseStreamController = StreamController<String>.broadcast();
    }

    try {
      print('Processing prompt with text: "${text.substring(0, min(100, text.length))}..."');
      
      // Clear any existing generation first to prevent contamination
      try {
        await _llamaParent!.stop();
        print('LlamaService: Stopped any previous generation');
      } catch (e) {
        print('LlamaService: Warning - could not stop previous generation: $e');
      }
      
      // Send prompt to the isolate
      _llamaParent!.sendPrompt(text);
    } catch (e) {
      print('Error processing prompt: $e');
      if (_responseStreamController != null && !_responseStreamController!.isClosed) {
        _responseStreamController!.addError(e);
      }
      throw Exception('Error processing prompt: $e');
    }
  }

  /// Generate a JSON response for a structured prompt
  /// This method handles token generation and includes JSON extraction and validation
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
    bool hasLoggedToken = false; // Track if we've already logged this token

    if (!_isRunning) {
      throw Exception('LLM service not running.');
    }

    try {
      // Process the prompt with lower temperature for structured output
      await processPromptWithParams(prompt);

      // Listen to the token stream and exit as soon as a valid suggestion (JSON) is detected
      subscription = _responseStreamController?.stream.listen((token) {
        buffer.write(token);
        tokenCount++;
        lastTokenTime = DateTime.now();
        
        // We don't need to log tokens here since they're already logged in the parent stream listener
        
        // Check for repetition with reduced frequency to save resources
        final text = buffer.toString();
        
        // Reduce repetition checking frequency from every 5 to every 15 tokens
        if (tokenCount % 15 == 0) { // Only check every 15 tokens to reduce overhead
          print('LlamaService: Checking for repetition at token $tokenCount (text length: ${text.length})');
        }
        
        // Only check for repetition after we have enough text and less frequently
        if (text.length > 60 && tokenCount % 10 == 0 && (hasRepeatedNgram(text, n: 4, minOccurrences: 3) || text.length > 300)) {
          print('[LLAMA] Repeated content detected during generation. Aborting early.');
          
          // CRITICAL: Immediately stop token generation
          _llamaParent?.stop();
          
          final repairedJson = attemptJsonRepair(text);
          if (!completer.isCompleted) {
            if (repairedJson != null) {
              print('[LLAMA] Completing with repaired JSON after repetition detected');
              completer.complete(repairedJson);
            } else {
              print('[LLAMA] Unable to repair JSON after repetition detected');
              completer.completeError(Exception('Repetition detected and unable to repair JSON'));
            }
          }
          subscription?.cancel();
          tokenTimeoutTimer?.cancel();
          isGenerating = false;
          
          // Explicitly stop the generation
          _llamaParent?.stop().catchError((e) {
            print('LlamaService: Error stopping generation after repetition detected');
          });
          return;
        }
        
        final extractedJson = extractJsonFromText(text);
        if (extractedJson != null) {
          // Check if the JSON is actually complete with non-empty required fields
          try {
            final json = jsonDecode(extractedJson);
            if (json is Map) {
              // Check for any valid JSON structure with non-empty values
              bool hasCompleteFields = false;
              
              // Check for simple status JSON (warm-up)
              if (json.containsKey('status') && 
                  json['status'] is String && 
                  json['status'].toString().trim().isNotEmpty) {
                hasCompleteFields = true;
              }
              // Check for test JSON
              else if (json.containsKey('test') && 
                       json['test'] is String && 
                       json['test'].toString().trim().isNotEmpty) {
                hasCompleteFields = true;
              }
              // Check for music recommendations
              else if (json.containsKey('title') && 
                       json.containsKey('artist') && 
                       json.containsKey('reasoning') &&
                       json['title'] is String && 
                       json['title'].toString().trim().isNotEmpty &&
                       json['artist'] is String && 
                       json['artist'].toString().trim().isNotEmpty &&
                       json['reasoning'] is String && 
                       json['reasoning'].toString().trim().isNotEmpty) {
                hasCompleteFields = true;
              }
              // Check for movie recommendations
              else if (json.containsKey('title') && 
                       json.containsKey('director') && 
                       json.containsKey('reasoning') &&
                       json['title'] is String && 
                       json['title'].toString().trim().isNotEmpty &&
                       json['director'] is String && 
                       json['director'].toString().trim().isNotEmpty &&
                       json['reasoning'] is String && 
                       json['reasoning'].toString().trim().isNotEmpty) {
                hasCompleteFields = true;
              }
              // Check for book recommendations
              else if (json.containsKey('title') && 
                       json.containsKey('author') && 
                       json.containsKey('reasoning') &&
                       json['title'] is String && 
                       json['title'].toString().trim().isNotEmpty &&
                       json['author'] is String && 
                       json['author'].toString().trim().isNotEmpty &&
                       json['reasoning'] is String && 
                       json['reasoning'].toString().trim().isNotEmpty) {
                hasCompleteFields = true;
              }
              
              if (hasCompleteFields) {
                // Found a complete valid JSON, exit immediately
                print('LlamaService: Found complete JSON with all required fields');
                
                // CRITICAL: Immediately stop token generation
                _llamaParent?.stop();
                
                if (!completer.isCompleted) {
                  completer.complete(extractedJson);
                }
                subscription?.cancel();
                tokenTimeoutTimer?.cancel();
                isGenerating = false;
                
                // Explicitly stop the generation to prevent further token generation
                _llamaParent?.stop().catchError((e) {
                  print('LlamaService: Error stopping generation after JSON extraction: $e');
                });
              } else {
                print('LlamaService: Found JSON but missing or empty required fields, continuing generation...');
                // Continue generation - this JSON is incomplete
              }
            }
          } catch (e) {
            print('LlamaService: JSON parsing error, continuing generation: $e');
            // Continue generation - this JSON is malformed
          }
        }
        
        // Check for 3-line format completion (Title\nArtist\nReasoning\n)
        final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
        if (lines.length >= 3) {
          // Check if we have 3 meaningful lines (not just placeholder text)
          bool hasCompleteThreeLines = true;
          for (int i = 0; i < 3; i++) {
            final line = lines[i].trim();
            if (line.isEmpty || line.length < 2) {
              hasCompleteThreeLines = false;
              break;
            }
          }
          
          if (hasCompleteThreeLines) {
            print('LlamaService: Found complete 3-line format');
            
            // CRITICAL: Immediately stop token generation
            _llamaParent?.stop();
            
            if (!completer.isCompleted) {
              // Return just the first 3 lines joined
              final threeLineResponse = lines.take(3).join('\n');
              completer.complete(threeLineResponse);
            }
            subscription?.cancel();
            tokenTimeoutTimer?.cancel();
            isGenerating = false;
            
            // Explicitly stop the generation
            _llamaParent?.stop().catchError((e) {
              print('LlamaService: Error stopping generation after 3-line completion: $e');
            });
            return;
          }
        }
      },
      onError: (e) {
        // CRITICAL: Immediately stop token generation on error
        _llamaParent?.stop();
        
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
        tokenTimeoutTimer?.cancel();
        isGenerating = false;
        
        // Ensure generation is stopped on error
        _llamaParent?.stop().catchError((e) {
          print('LlamaService: Error stopping generation after error: $e');
        });
      },
      onDone: () {
        tokenTimeoutTimer?.cancel();
        
        if (!completer.isCompleted) {
          // Try to extract/repair JSON one last time
          final finalText = buffer.toString();
          final extractedJson = extractJsonFromText(finalText);
          if (extractedJson != null) {
            completer.complete(extractedJson);
          } else {
            final repairedJson = attemptJsonRepair(finalText);
            if (repairedJson != null) {
              print('Successfully repaired JSON: $repairedJson');
              completer.complete(repairedJson);
            } else {
              print('⚠️ Failed to extract valid JSON from LLM response');
              print('Raw response: \n$finalText');
              completer.completeError(Exception('Failed to generate valid JSON response'));
            }
          }
        }
        isGenerating = false;
      });

      // Start a timer to check for token generation timeout
      tokenTimeoutTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
        final timeSinceLastToken = DateTime.now().difference(lastTokenTime).inSeconds;
        final currentLength = buffer.length;
        // Reduced timeout to 5 seconds for simple responses
        if ((isGenerating && timeSinceLastToken >= 5) || currentLength > 200) {
          if (isGenerating && timeSinceLastToken >= 5) {
            print('LlamaService: Token generation timeout after $timeSinceLastToken seconds - assuming generation is complete (received $tokenCount tokens total)');
            print('LlamaService: Buffer length: ${buffer.length}');
            print('LlamaService: Last 50 chars of buffer: "${buffer.length > 50 ? buffer.toString().substring(buffer.length - 50) : buffer.toString()}"');
          } else if (currentLength > 200) {
            print('LlamaService: Response exceeded 200 characters - truncating for simple format');
          }
          isGenerating = false;
          timer.cancel();
          
          // CRITICAL: Immediately stop token generation on timeout
          _llamaParent?.stop();
          
          // Give a moment for any pending tokens then extract content
          Future.delayed(Duration(milliseconds: 100), () {
            if (!completer.isCompleted) {
              final finalText = buffer.toString();
              // For simple format, just return the raw text
              completer.complete(finalText);
              
              // Cancel the subscription to stop token handling
              subscription?.cancel();
              
              // Stop the generation
              _llamaParent?.stop().catchError((e) {
                print('LlamaService: Error stopping generation: $e');
              });
            }
          });
        }
      });

      isGenerating = true;
    } catch (e) {
      // CRITICAL: Immediately stop token generation on exception
      _llamaParent?.stop();
      
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      tokenTimeoutTimer?.cancel();
      isGenerating = false;
      
      // Ensure generation is stopped on error
      _llamaParent?.stop().catchError((e) {
        print('LlamaService: Error stopping generation after exception: $e');
      });
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

      // Look for JSON object patterns - be more aggressive
      final jsonMatches = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}')
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

      // Look for patterns that might indicate the start of JSON even if malformed
      final partialJsonMatch = RegExp(r'\{[^{]*"title"[^{]*').firstMatch(text);
      if (partialJsonMatch != null) {
        final candidate = partialJsonMatch.group(0);
        if (candidate != null) {
          // Try to repair this JSON fragment
          final repaired = attemptJsonRepair(candidate);
          if (repaired != null) {
            return repaired;
          }
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
      print('Error attempting to repair JSON: $e');
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
          print('JSON validation passed: has title and reasoning');
          return true;
        } else {
          if (!hasTitle) print('JSON validation failed: missing title');
          if (!hasReasoning) print('JSON validation failed: missing or insufficient reasoning');
          return false;
        }
      }
      
      return false;
    } catch (e) {
      print('Error validating JSON completeness: $e');
      return false;
    }
  }

  /// Robust repetition detection for streaming text generation
  bool hasRepeatedNgram(String text, {int n = 4, int minOccurrences = 2}) {
    // Need enough text to detect meaningful repetition
    if (text.length < 40) return false;
    
    // Reduce debug logging frequency
    if (text.length % 50 == 0) { // Only log every 50 characters instead of every call
      print('REPETITION CHECK: Analyzing text of length ${text.length}');
    }
    
    // Focus on the most recent portion of text where repetition is likely occurring
    final windowSize = 400; 
    final recentText = text.length > windowSize 
        ? text.substring(text.length - windowSize) 
        : text;
    
    // Special check for "He is the best" pattern which is a common issue
    final heIsTheBestPattern = RegExp(r'(He|he) is the best\..*?(He|he) is the best\.');
    if (heIsTheBestPattern.hasMatch(recentText)) {
      print('REPETITION DETECTED: "He is the best" pattern found');
      return true;
    }
    
    // Find repeated sentences with simple period-based splitting
    final sentences = recentText.split('.');
    if (sentences.length >= 3) {
      // Get last few sentences for comparison
      for (int i = sentences.length - 1; i >= 2; i--) {
        final currSentence = sentences[i].trim().toLowerCase();
        final prevSentence = sentences[i-1].trim().toLowerCase();
        
        // Skip empty sentences
        if (currSentence.isEmpty || prevSentence.isEmpty) continue;
        
        // If two consecutive sentences are identical
        if (currSentence == prevSentence) {
          print('REPETITION DETECTED: Repeated sentence: "$currSentence"');
          return true;
        }
        
        // If the current sentence appears anywhere earlier in the text
        // with exact match (excluding current and previous sentence)
        int occurrenceCount = 0;
        for (int j = 0; j < i-1; j++) {
          if (sentences[j].trim().toLowerCase() == currSentence) {
            occurrenceCount++;
            if (occurrenceCount >= minOccurrences - 1) { // -1 because we already found one occurrence
              print('REPETITION DETECTED: Sentence "$currSentence" appears multiple times');
              return true;
            }
          }
        }
      }
    }
    
    // Check for word-level repetition patterns
    final words = recentText.split(RegExp(r'\s+'));
    if (words.length >= 8) {
      // Track the count of "the best" phrases
      int theBestCount = 0;
      
      // Check for excessive use of specific phrases
      for (int i = 0; i < words.length - 1; i++) {
        if (words[i].toLowerCase() == 'the' && 
            i < words.length - 1 && 
            words[i+1].toLowerCase() == 'best') {
          theBestCount++;
          
          if (theBestCount >= minOccurrences + 1) {
            print('REPETITION DETECTED: Phrase "the best" appears $theBestCount times');
            return true;
          }
        }
      }
      
      // Check for repeating word patterns (e.g., "He is the best. He is the best.")
      Map<String, int> patternCounts = {};
      for (int i = 0; i <= words.length - 4; i++) {
        final pattern = '${words[i]} ${words[i+1]} ${words[i+2]} ${words[i+3]}'.toLowerCase();
        patternCounts[pattern] = (patternCounts[pattern] ?? 0) + 1;
        
        if ((patternCounts[pattern] ?? 0) >= minOccurrences) {
          print('REPETITION DETECTED: Word pattern "$pattern" repeats ${patternCounts[pattern]} times');
          return true;
        }
      }
    }
    
    // Generic token-based repetition detection (simplified for performance)
    // Test smaller token sizes more frequently as they're more likely to catch repetition
    final tokenSizes = [3, 5, 10, 15];
    
    for (final tokenSize in tokenSizes) {
      if (recentText.length > tokenSize * 3) {
        // Get the last N characters
        final lastNChars = recentText.substring(recentText.length - tokenSize);
        
        // Count occurrences in the earlier text
        final earlierText = recentText.substring(0, recentText.length - tokenSize);
        
        // Count occurrences
        int occurrenceCount = 0;
        int startIndex = 0;
        while (true) {
          final index = earlierText.indexOf(lastNChars, startIndex);
          if (index == -1) break;
          
          occurrenceCount++;
          if (occurrenceCount >= minOccurrences - 1) { // -1 because we're looking for one less occurrence in the earlier text
            // Check how close the last occurrence is to the end
            final lastPos = earlierText.lastIndexOf(lastNChars);
            final distanceFromEnd = recentText.length - tokenSize - lastPos;
            
            // If it's very close, it's likely a repetition loop
            if (distanceFromEnd < tokenSize * 4) {
              print('REPETITION DETECTED: Pattern "$lastNChars" repeats with small gap (distance: $distanceFromEnd)');
              return true;
            }
            break;
          }
          startIndex = index + 1;
        }
      }
    }
    
    // No repetition detected
    return false;
  }

  /// Calculate string similarity using a simplified Levenshtein ratio
  double _calculateStringSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    // Count matching characters in sequence
    int matches = 0;
    final minLength = min(s1.length, s2.length);
    
    for (int i = 0; i < minLength; i++) {
      if (s1[i] == s2[i]) matches++;
    }
    
    // Calculate similarity ratio
    return matches / max(s1.length, s2.length);
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
      print('LLM shutdown complete');
    } catch (e) {
      print('Error during shutdown: $e');
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
          print('Timed out waiting for llama isolate to shut down');
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
          print('Error disposing LlamaParent: $e');
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

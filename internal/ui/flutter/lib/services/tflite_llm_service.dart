import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// ONNX Runtime-based LLM service for modern ML model inference
/// Uses flutter_onnxruntime which supports advanced operations and better performance
class TFLiteLLMService {
  static const String kModelFileName = 'model_int8.onnx';  // Using 1GB int8 quantized model
  static const int kMaxTokens = 25;    // REDUCED: Much shorter responses to save resources
  static const int kVocabSize = 32000; // TinyLlama vocab size
  
  // 🔋 MOBILE PERFORMANCE LIMITS - AGGRESSIVE
  static const int kMaxInputTokens = 20;    // VERY short input length
  static const int kMaxContextLength = 30;  // VERY short context window
  static const int kMaxInferenceTimeMs = 3000; // 3 second max inference time
  
  OrtSession? _session;
  OnnxRuntime? _onnxRuntime;
  bool _isInitialized = false;
  
  /// Circuit breaker for error handling
  int _consecutiveErrors = 0;
  static const int maxConsecutiveErrors = 3;
  
  /// Callback for showing toast messages
  Function(String message, {bool isError})? showToast;
  
  /// Initialize the ONNX Runtime LLM service
  Future<bool> initialize({Function(String message, {bool isError})? toastCallback}) async {
    if (_isInitialized) return true;
    
    showToast = toastCallback;
    
    try {
      debugPrint('🔄 Starting ONNX Runtime LLM initialization...');
      debugPrint('🤖 [ONNX] Initializing TinyLlama ONNX Runtime service with 1GB int8 model...');
      
      // Get model path from Documents directory
      final modelPath = _getModelPath();
      
      if (!await File(modelPath).exists()) {
        debugPrint('❌ [ONNX] Model file not found at: $modelPath');
        _showToast('TinyLlama ONNX model not found at: $modelPath', isError: true);
        return false;
      }
      
      debugPrint('🔍 [ONNX] Loading TinyLlama 1GB int8 model from: $modelPath');
      debugPrint('⚡ [ONNX] Using RESOURCE-LIMITED configuration for mobile...');
      
      // Initialize ONNX Runtime with basic settings (flutter_onnxruntime limitations)
      _onnxRuntime = OnnxRuntime();
      
      try {
        // Create ONNX session - using standard method since options aren't available
        _session = await _onnxRuntime!.createSession(modelPath);
        
        debugPrint('✅ [ONNX] Session created successfully');
        
        // Print model info
        try {
          final inputNames = _session!.inputNames;
          final outputNames = _session!.outputNames;
          
          debugPrint('📊 [ONNX] Model inputs: ${inputNames.join(", ")}');
          debugPrint('📊 [ONNX] Model outputs: ${outputNames.join(", ")}');
        } catch (e) {
          debugPrint('📊 [ONNX] Could not get model info: $e');
        }
        
      } catch (e) {
        debugPrint('⚠️ [ONNX] Session creation failed: $e');
        throw e;
      }
      
      _isInitialized = true;
      _consecutiveErrors = 0;
      
      debugPrint('✅ [ONNX] TinyLlama 1GB int8 LLM service initialized successfully');
      _showToast('TinyLlama ONNX LLM ready (1GB int8)');
      
      return true;
      
    } catch (e) {
      debugPrint('💥 [ONNX] Initialization failed: $e');
      
      // Provide helpful guidance
      if (e.toString().contains('file not found') || e.toString().contains('No such file')) {
        debugPrint('🔧 [ONNX] Model files not found - check model directory');
        _showToast('TinyLlama ONNX model files not found. Please ensure they are in ~/Documents/models/TinyLlama-1.1B-Chat-v1.0-ONNX/onnx/', isError: true);
      } else {
        _showToast('Failed to initialize TinyLlama ONNX LLM: $e', isError: true);
      }
      
      return false;
    }
  }
  
  /// Generate reasoning explanation using TinyLlama ONNX
  Future<String> generateReasoningExplanation({
    required String userQuery,
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? userProfile,
    double? similarity,
  }) async {
    if (!_isInitialized) {
      debugPrint('❌ [ONNX] Service not initialized - real model required, no fallbacks');
      throw Exception('ONNX service not initialized - no mocked responses allowed');
    }
    
    // Check circuit breaker
    if (_consecutiveErrors >= maxConsecutiveErrors) {
      debugPrint('❌ [ONNX] Circuit breaker active - too many errors - real model required, no fallbacks');
      throw Exception('ONNX model failed too many times - no mocked responses allowed');
    }
    
    try {
      debugPrint('🧠 [ONNX] Generating reasoning with TinyLlama 1GB int8...');
      
      // Build prompt for TinyLlama
      final prompt = _buildTinyLlamaPrompt(
        mediaTitle: mediaTitle,
        mediaType: mediaType,
        artist: artist,
        themes: themes,
        userProfile: userProfile,
      );
      
      debugPrint('📝 [ONNX] TinyLlama prompt: "$prompt"');
      
      // Generate response using ONNX
      final response = await _generateWithONNX(prompt);
      
      // Clean and validate response
      final cleanedResponse = _cleanResponse(response);
      
      if (cleanedResponse.isNotEmpty && !_isQuestionResponse(cleanedResponse)) {
        _consecutiveErrors = 0; // Reset error counter on success
        debugPrint('✅ [ONNX] TinyLlama response: "$cleanedResponse"');
        return cleanedResponse;
      } else {
        throw Exception('Invalid response from TinyLlama: $cleanedResponse');
      }
      
    } catch (e) {
      _consecutiveErrors++;
      debugPrint('❌ [ONNX] TinyLlama error (${_consecutiveErrors}/${maxConsecutiveErrors}): $e');
      
      // NO FALLBACK REASONING - REAL MODEL REQUIRED
      throw Exception('ONNX generation failed: $e - no mocked responses allowed');
    }
  }
  
  /// Build prompt optimized for TinyLlama with resource constraints
  String _buildTinyLlamaPrompt({
    required String mediaTitle,
    required String mediaType,
    String? artist,
    String? themes,
    String? userProfile,
  }) {
    final mediaTypeText = mediaType == 'video_game' ? 'game' : mediaType;
    final artistText = artist != null ? ' by $artist' : '';
    
    // MUCH SHORTER prompt to reduce resource usage
    // TinyLlama chat format prompt - simplified
    return '<|user|>\nWhy enjoy "$mediaTitle"$artistText?\n<|assistant|>\n';
  }
  
  /// Generate text using ONNX Runtime
  Future<String> _generateWithONNX(String prompt) async {
    // Check if we have a real ONNX session
    if (_session == null) {
      throw Exception('ONNX model not loaded - no actual model available');
    }
    
    try {
      debugPrint('🔤 [ONNX] Starting RESOURCE-LIMITED ONNX inference...');
      
      // Tokenize input with length limits
      final inputTokens = _tokenizeSimple(prompt);
      final limitedTokens = inputTokens.length > kMaxInputTokens 
          ? inputTokens.take(kMaxInputTokens).toList()  // Truncate if too long
          : inputTokens;
      
      debugPrint('🔤 [ONNX] Input tokens (${limitedTokens.length}/${inputTokens.length}): ${limitedTokens.take(10)}...');
      
      if (limitedTokens.length > kMaxInputTokens) {
        debugPrint('⚠️ [ONNX] Input truncated from ${inputTokens.length} to ${limitedTokens.length} tokens');
      }
      
      // Get input names from model
      final inputNames = _session!.inputNames;
      if (inputNames.isEmpty) {
        throw Exception('Model has no input tensors');
      }
      
      // Create inputs map
      final inputs = <String, OrtValue>{};
      
      // Create input_ids tensor using Int64List for proper int64 type
      final inputIdsTensor = await OrtValue.fromList(
        Int64List.fromList(limitedTokens), // Use limited tokens
        [1, limitedTokens.length] // batch_size=1, sequence_length
      );
      inputs['input_ids'] = inputIdsTensor;
      
      // Create attention_mask tensor using Int64List
      final attentionMask = List.filled(limitedTokens.length, 1);
      final attentionMaskTensor = await OrtValue.fromList(
        Int64List.fromList(attentionMask),
        [1, limitedTokens.length]
      );
      inputs['attention_mask'] = attentionMaskTensor;
      
      // Create position_ids tensor if required using Int64List
      if (inputNames.contains('position_ids')) {
        final positionIds = List.generate(limitedTokens.length, (i) => i);
        final positionIdsTensor = await OrtValue.fromList(
          Int64List.fromList(positionIds),
          [1, limitedTokens.length]
        );
        inputs['position_ids'] = positionIdsTensor;
      }
      
      // Create empty KV cache tensors for first inference pass
      for (final inputName in inputNames) {
        if (inputName.startsWith('past_key_values.') && (inputName.endsWith('.key') || inputName.endsWith('.value'))) {
          // Create empty cache tensor for first pass: [batch_size, num_heads, 0, head_dim]
          // Fixed dimensions based on model error: batch_size=1, num_heads=4, seq_len=0 (empty), head_dim=64
          final emptyCacheTensor = await OrtValue.fromList(
            Float32List.fromList([]), // Empty cache
            [1, 4, 0, 64] // Corrected TinyLlama dimensions
          );
          inputs[inputName] = emptyCacheTensor;
          debugPrint('🔧 [ONNX] Added empty KV cache tensor: $inputName [1,4,0,64]');
        }
      }
      
      debugPrint('🎯 [ONNX] Running inference with ${inputs.length} inputs: ${inputs.keys.join(', ')}...');
      
      // Add aggressive timeout to prevent lag - 3 seconds max for mobile
      final outputs = await _session!.run(inputs).timeout(
        Duration(milliseconds: kMaxInferenceTimeMs),
        onTimeout: () {
          debugPrint('⏰ [ONNX] Inference timed out after ${kMaxInferenceTimeMs}ms');
          throw TimeoutException('ONNX inference timed out', Duration(milliseconds: kMaxInferenceTimeMs));
        },
      );
      debugPrint('✅ [ONNX] Inference completed, got ${outputs.length} outputs');
      
      // Extract output data with better error handling
      String responseText = '';
      final outputNames = _session!.outputNames;
      if (outputNames.isNotEmpty && outputs.containsKey(outputNames[0])) {
        final outputTensor = outputs[outputNames[0]]!;
        final outputData = await outputTensor.asList();
        
        debugPrint('🔍 [ONNX] Output data type: ${outputData.runtimeType}');
        debugPrint('🔍 [ONNX] Output data length: ${outputData.length}');
        
        // Handle different output formats more safely
        List<int> tokenIds;
        if (outputData.isNotEmpty) {
          try {
            debugPrint('🔍 [ONNX] First element type: ${outputData[0].runtimeType}');
            
            // Check the actual structure
            if (outputData[0] is List) {
              // Multi-dimensional output (batch, sequence, vocab)
              final batch = outputData[0] as List;
              debugPrint('🔍 [ONNX] Batch length: ${batch.length}');
              
              if (batch.isNotEmpty && batch[0] is List) {
                final sequence = batch[0] as List;
                debugPrint('🔍 [ONNX] Sequence length: ${sequence.length}');
                
                // This is logits for all vocab tokens, find the max probability token
                final logits = sequence.cast<double>();
                final maxIndex = _findMaxIndex(logits);
                debugPrint('🔍 [ONNX] Selected token: $maxIndex from ${logits.length} logits');
                debugPrint('🔍 [ONNX] Max logit value: ${logits[maxIndex].toStringAsFixed(3)}');
                debugPrint('🔍 [ONNX] Top 5 logits: ${_getTopKIndices(logits, 5)}');
                tokenIds = [maxIndex];
              } else {
                tokenIds = [2]; // EOS token as fallback
              }
            } else if (outputData[0] is double || outputData[0] is int) {
              // Single value output - convert directly to token IDs
              debugPrint('🔍 [ONNX] Single value output detected');
              tokenIds = outputData.cast<double>().map((d) => d.round().clamp(0, kVocabSize - 1)).toList();
            } else {
              debugPrint('🔍 [ONNX] Unknown output format, using fallback');
              tokenIds = [2]; // EOS token as fallback
            }
          } catch (e) {
            debugPrint('⚠️ [ONNX] Error processing output: $e');
            debugPrint('⚠️ [ONNX] Output sample: ${outputData.take(3).toList()}');
            tokenIds = [2]; // EOS token as fallback
          }
        } else {
          tokenIds = [2]; // EOS token as fallback
        }
        
        // Convert to text (simplified)
        responseText = _detokenizeSimple(tokenIds);
        debugPrint('📝 [ONNX] Raw output: "$responseText"');
      } else {
        throw Exception('No valid outputs from model');
      }
      
      // Clean up tensors
      for (final input in inputs.values) {
        input.dispose();
      }
      for (final output in outputs.values) {
        output.dispose();
      }
      
      return responseText;
      
    } catch (e) {
      debugPrint('❌ [ONNX] Real ONNX generation error: $e');
      throw Exception('ONNX generation failed: $e');
    }
  }
  
  /// Simple tokenization (replace with proper TinyLlama tokenizer in production)
  List<int> _tokenizeSimple(String text) {
    // This is a very simplified tokenizer
    // In production, you'd use the actual TinyLlama tokenizer
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final tokens = <int>[];
    
    // Add BOS token
    tokens.add(1);
    
    for (final word in words) {
      // Hash-based token assignment (simplified)
      final hash = word.hashCode.abs() % (kVocabSize - 100) + 100;
      tokens.add(hash);
    }
    
    // Add EOS token
    tokens.add(2);
    
    return tokens;
  }
  
  /// Find the index of maximum value in a list
  int _findMaxIndex(List<double> values) {
    if (values.isEmpty) return 0;
    
    double maxValue = values[0];
    int maxIndex = 0;
    
    for (int i = 1; i < values.length; i++) {
      if (values[i] > maxValue) {
        maxValue = values[i];
        maxIndex = i;
      }
    }
    
    return maxIndex;
  }

  /// Get top K indices with highest values for debugging
  List<Map<String, dynamic>> _getTopKIndices(List<double> values, int k) {
    if (values.isEmpty) return [];
    
    final indexed = <Map<String, dynamic>>[];
    for (int i = 0; i < values.length; i++) {
      indexed.add({'index': i, 'value': values[i]});
    }
    
    indexed.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
    
    return indexed.take(k).toList();
  }

  /// Simple detokenization 
  String _detokenizeSimple(List<int> tokens) {
    // This is a very simplified detokenizer
    // In production, you'd use the actual TinyLlama tokenizer
    final words = <String>[];
    
    for (final token in tokens) {
      if (token == 1) continue; // Skip BOS
      if (token == 2) break;    // Stop at EOS
      
      // Simple mapping (this is fake - real tokenizer would have vocab)
      if (token < 100) {
        words.add('<unk>');
      } else {
        // Generate a simple word based on token
        final wordLength = (token % 7) + 3;
        final chars = 'abcdefghijklmnopqrstuvwxyz';
        var word = '';
        var seed = token;
        for (int i = 0; i < wordLength; i++) {
          word += chars[seed % chars.length];
          seed = seed ~/ chars.length;
        }
        words.add(word);
      }
    }
    
    return words.join(' ');
  }
  
  /// Clean and validate response
  String _cleanResponse(String response) {
    return response
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[^\w]*'), '')
        .replaceAll(RegExp(r'[^\w\s.,!?-]*$'), '');
  }
  
  /// Check if response is a question (invalid)
  bool _isQuestionResponse(String response) {
    return response.trim().endsWith('?') || 
           response.toLowerCase().startsWith('what') ||
           response.toLowerCase().startsWith('how') ||
           response.toLowerCase().startsWith('why');
  }
  
  /// Show toast message
  void _showToast(String message, {bool isError = false}) {
    if (showToast != null) {
      try {
        showToast!(message, isError: isError);
      } catch (e) {
        debugPrint('⚠️ [ONNX] Toast error: $e');
      }
    }
  }
  
  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Check if model is available
  Future<bool> isModelAvailable() async {
    // Check if we have a real initialized ONNX session
    final hasRealModel = _isInitialized && _session != null;
    debugPrint('🔍 [ONNX] Model availability check: $hasRealModel (initialized: $_isInitialized, session: ${_session != null})');
    return hasRealModel;
  }
  
  /// Get the path to the TinyLlama ONNX model
  String _getModelPath() {
    final homeDir = Platform.environment['HOME'] ?? '';
    return '$homeDir/Documents/models/TinyLlama-1.1B-Chat-v1.0-ONNX/onnx/$kModelFileName';
  }
  
  /// Dispose resources
  void dispose() {
    debugPrint('🧹 [ONNX] Disposing TinyLlama service...');
    
    try {
      _session?.close();
      _session = null;
      _onnxRuntime = null;
      _isInitialized = false;
      debugPrint('✅ [ONNX] TinyLlama service disposed successfully');
    } catch (e) {
      debugPrint('⚠️ [ONNX] Error during disposal: $e');
    }
  }
} 
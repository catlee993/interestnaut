import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;

/// ONNX Runtime-based LLM service for modern ML model inference
/// Uses flutter_onnxruntime which supports advanced operations and better performance
class TFLiteLLMService {
  static const String kModelFileName = 'model_int8.onnx';  // Using 1GB int8 quantized model
  static const int kMaxTokens = 40;    // Longer for coherent responses
  static const int kVocabSize = 32000; // TinyLlama vocab size
  
  // 🔋 MOBILE PERFORMANCE LIMITS - OPTIMIZED FOR QUALITY
  static const int kMaxInputTokens = 25;    // Slightly longer input
  static const int kMaxContextLength = 50;  // Longer context for coherence
  static const int kMaxInferenceTimeMs = 5000; // 5 second max for quality
  
  // 🎯 GENERATION PARAMETERS FOR QUALITY
  static const double kTemperature = 0.8;   // Higher randomness to avoid repetition
  static const int kTopK = 50;             // Larger top-K for more diversity
  static const double kTopP = 0.95;        // Higher nucleus sampling for variety
  
  // Real TinyLlama vocabulary storage
  static Map<String, int>? _vocab;
  static Map<int, String>? _reverseVocab;
  static bool _vocabInitialized = false;
  
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
      
      // Load TinyLlama tokenizer vocabulary
      debugPrint('🔤 [INIT] Loading TinyLlama tokenizer...');
      await _loadTinyLlamaVocab();
      
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
    
    // Improved TinyLlama prompt format - more natural and directive
    final themesContext = themes != null ? ' Key themes include: $themes.' : '';
    
    // Use a more natural format that TinyLlama responds better to
    return '<|user|>\nWrite a recommendation for the $mediaTypeText "$mediaTitle"$artistText.$themesContext Explain why it\'s worth reading/watching/playing in 2-3 sentences.\n<|assistant|>\n"$mediaTitle" is compelling because';
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
      final inputTokens = await _tokenizeSimple(prompt);
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
      
      // Start autoregressive generation
      final generatedTokens = <int>[];
      var currentTokens = List<int>.from(limitedTokens);
      var kvCache = <String, OrtValue>{}; // Store KV cache between iterations
      
      debugPrint('🔄 [AUTOREGRESSIVE] Starting generation...');
      
      for (int step = 0; step < kMaxTokens; step++) {
        debugPrint('🔄 [AUTOREGRESSIVE] Step ${step + 1}/${kMaxTokens}');
        
        // Create fresh inputs for this step
        final currentInputs = <String, OrtValue>{};
        
        // For subsequent steps, only use the last token
        final inputTokensForStep = step == 0 ? currentTokens : [currentTokens.last];
        
        // Create input_ids tensor
        final inputIdsTensor = await OrtValue.fromList(
          Int64List.fromList(inputTokensForStep),
          [1, inputTokensForStep.length]
        );
        currentInputs['input_ids'] = inputIdsTensor;
        
        // Create attention_mask tensor
        final attentionMask = List.filled(currentTokens.length, 1);
        final attentionMaskTensor = await OrtValue.fromList(
          Int64List.fromList(attentionMask),
          [1, currentTokens.length]
        );
        currentInputs['attention_mask'] = attentionMaskTensor;
        
        // Create position_ids tensor if required
        if (inputNames.contains('position_ids')) {
          final positionIds = step == 0 
              ? List.generate(inputTokensForStep.length, (i) => i)
              : [currentTokens.length - 1]; // Position of the new token
          final positionIdsTensor = await OrtValue.fromList(
            Int64List.fromList(positionIds),
            [1, positionIds.length]
          );
          currentInputs['position_ids'] = positionIdsTensor;
        }
        
        // Add KV cache tensors
        for (final inputName in inputNames) {
          if (inputName.startsWith('past_key_values.') && (inputName.endsWith('.key') || inputName.endsWith('.value'))) {
            if (kvCache.containsKey(inputName)) {
              // Use cached values from previous step
              currentInputs[inputName] = kvCache[inputName]!;
            } else {
              // First step - empty cache
              final emptyCacheTensor = await OrtValue.fromList(
                Float32List.fromList([]),
                [1, 4, 0, 64]
              );
              currentInputs[inputName] = emptyCacheTensor;
            }
          }
        }
        
        debugPrint('🎯 [ONNX] Running inference with ${currentInputs.length} inputs: ${currentInputs.keys.join(", ")}...');
        
        // Run inference with timeout
        final outputs = await _session!.run(currentInputs).timeout(
          Duration(milliseconds: kMaxInferenceTimeMs),
          onTimeout: () {
            debugPrint('⏰ [ONNX] Inference timed out after ${kMaxInferenceTimeMs}ms');
            throw TimeoutException('ONNX inference timed out', Duration(milliseconds: kMaxInferenceTimeMs));
          },
        );
        debugPrint('✅ [ONNX] Inference completed, got ${outputs.length} outputs');
        
        // Extract logits and next token
        int nextToken = 2; // Default to EOS
        final outputNames = _session!.outputNames;
        
        if (outputNames.isNotEmpty && outputs.containsKey('logits')) {
          final logitsTensor = outputs['logits']!;
          final logitsData = await logitsTensor.asList();
          
          debugPrint('🔍 [ONNX] Output data type: ${logitsData.runtimeType}');
          debugPrint('🔍 [ONNX] Output data length: ${logitsData.length}');
          
          if (logitsData.isNotEmpty && logitsData[0] is List) {
            final batch = logitsData[0] as List;
            debugPrint('🔍 [ONNX] Batch length: ${batch.length}');
            
            if (batch.isNotEmpty) {
              final lastTokenLogits = batch.last as List;
              debugPrint('🔍 [ONNX] Sequence length: ${lastTokenLogits.length}');
              
                             final logits = lastTokenLogits.cast<double>();
               nextToken = _sampleToken(logits, generatedTokensCount: generatedTokens.length);
               
               debugPrint('🔍 [ONNX] Selected token: $nextToken from ${logits.length} logits');
               debugPrint('🔍 [ONNX] Token probability: ${logits[nextToken].toStringAsFixed(3)}');
               debugPrint('🔍 [ONNX] Top 5 candidates: ${_getTopKIndices(logits, 5)}');
            }
          }
        }
        
        // Update KV cache for next iteration
        kvCache.clear();
        for (final outputName in outputNames) {
          if (outputName.startsWith('present.') && (outputName.endsWith('.key') || outputName.endsWith('.value'))) {
            final cacheInputName = outputName.replaceFirst('present.', 'past_key_values.');
            if (outputs.containsKey(outputName)) {
              kvCache[cacheInputName] = outputs[outputName]!;
            }
          }
        }
        
        // Clean up current step inputs (but not cached KV values)
        for (final entry in currentInputs.entries) {
          if (!entry.key.startsWith('past_key_values.')) {
            entry.value.dispose();
          }
        }
        
        // More lenient EOS handling - don't stop immediately if we haven't generated enough
        if (nextToken == 2 && generatedTokens.length >= 15) { // Only stop on EOS if we have reasonable content
          debugPrint('🔚 [AUTOREGRESSIVE] EOS token reached after ${generatedTokens.length} tokens, stopping generation');
          break;
        } else if (nextToken == 2 && generatedTokens.length < 15) {
          debugPrint('⚠️ [AUTOREGRESSIVE] Early EOS token (${generatedTokens.length} tokens) - ignoring and continuing');
          // Don't add EOS token, try to continue generation
          continue;
        }
        
        // Add token to sequence
        generatedTokens.add(nextToken);
        currentTokens.add(nextToken);
        
        // Check for meaningful completion after reasonable progress
        if (generatedTokens.length >= 15) { // Need at least 15 tokens for coherent response
          final partialText = _detokenizeSimple(generatedTokens);
          
          // Stop if we have a complete thought (multiple sentences or good length)
          if (partialText.length > 60) {
            final sentences = partialText.split(RegExp(r'[.!?]+'));
            if (sentences.length >= 2 && sentences.last.trim().isEmpty) {
              debugPrint('🔚 [AUTOREGRESSIVE] Complete explanation detected (${sentences.length - 1} sentences), stopping');
              break;
            }
            
            // Or if we have one very substantial sentence with proper ending
            if (partialText.length > 100 && (partialText.contains('.') || partialText.contains('!'))) {
              debugPrint('🔚 [AUTOREGRESSIVE] Substantial response detected, stopping early');
              break;
            }
          }
        }
      }
      
      // Clean up remaining KV cache
      for (final tensor in kvCache.values) {
        tensor.dispose();
      }
      
      // Convert generated tokens to text
      final responseText = _detokenizeSimple(generatedTokens);
      debugPrint('📝 [ONNX] Generated ${generatedTokens.length} tokens: "$responseText"');
      
      return responseText;
      
    } catch (e) {
      debugPrint('❌ [ONNX] Real ONNX generation error: $e');
      throw Exception('ONNX generation failed: $e');
    }
  }
  
  /// Load real TinyLlama tokenizer vocabulary
  Future<void> _loadTinyLlamaVocab() async {
    if (_vocabInitialized) return;
    
    try {
      debugPrint('🔤 [TOKENIZER] Loading real TinyLlama vocabulary...');
      
      final homeDir = Platform.environment['HOME'] ?? '';
      final tokenizerPath = '$homeDir/Documents/models/TinyLlama-1.1B-Chat-v1.0-ONNX/tokenizer.json';
      
      final file = File(tokenizerPath);
      if (!await file.exists()) {
        throw Exception('TinyLlama tokenizer not found at: $tokenizerPath');
      }
      
      final jsonStr = await file.readAsString();
      final tokenizerData = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Extract vocab from model.vocab
      final vocab = tokenizerData['model']['vocab'] as Map<String, dynamic>;
      _vocab = {};
      _reverseVocab = {};
      
      // Convert to proper types
      for (final entry in vocab.entries) {
        final token = entry.key;
        final id = entry.value as int;
        _vocab![token] = id;
        _reverseVocab![id] = token;
      }
      
      // Add special tokens
      final addedTokens = tokenizerData['added_tokens'] as List<dynamic>;
      for (final tokenData in addedTokens) {
        final token = tokenData['content'] as String;
        final id = tokenData['id'] as int;
        _vocab![token] = id;
        _reverseVocab![id] = token;
      }
      
      debugPrint('✅ [TOKENIZER] Loaded ${_vocab!.length} tokens from real TinyLlama vocabulary');
      _vocabInitialized = true;
      
    } catch (e) {
      debugPrint('❌ [TOKENIZER] Failed to load TinyLlama vocabulary: $e');
      throw Exception('Failed to load tokenizer: $e');
    }
  }

  /// Real TinyLlama tokenization using loaded vocabulary
  Future<List<int>> _tokenizeSimple(String text) async {
    await _loadTinyLlamaVocab();
    
    final tokens = <int>[];
    
    // Add BOS token <s>
    tokens.add(1);
    
    debugPrint('🔤 [TOKENIZER] Tokenizing: "$text"');
    
    // Handle special tokens first
    if (text.contains('<|user|>') || text.contains('<|assistant|>')) {
      debugPrint('🔤 [TOKENIZER] Processing special tokens...');
      
      // Simple approach for special tokens
      final parts = text.split(RegExp(r'(<\|[^|]+\|>)'));
      
      for (final part in parts) {
        if (part.isEmpty) continue;
        
        if (part.startsWith('<|') && part.endsWith('|>')) {
          // Special token
          if (_vocab!.containsKey(part)) {
            tokens.add(_vocab![part]!);
            debugPrint('🔤 [TOKENIZER] Special token: "$part" -> ${_vocab![part]}');
          } else {
            debugPrint('⚠️ [TOKENIZER] Unknown special token: $part');
            // Try to tokenize as regular text instead of using <unk>
            final fallbackTokens = _tokenizeText(part);
            tokens.addAll(fallbackTokens);
          }
        } else {
          // Regular text - tokenize word by word
          final subTokens = _tokenizeText(part);
          tokens.addAll(subTokens);
        }
      }
    } else {
      // No special tokens - process normally
      final subTokens = _tokenizeText(text);
      tokens.addAll(subTokens);
    }
    
    // Don't add EOS token here - let the model decide when to end
    debugPrint('🔤 [TOKENIZER] Result: ${tokens.length} tokens (no EOS): ${tokens.take(10)}...');
    return tokens;
  }
  
  /// Tokenize regular text using real vocabulary
  List<int> _tokenizeText(String text) {
    final tokens = <int>[];
    
    // Split on spaces (simplified SentencePiece approach)
    final words = text.split(' ');
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) continue;
      
      // First word gets space prefix, others don't in simplified approach
      final isFirstWord = i == 0 || (i > 0 && words[i-1].isEmpty);
      final processedWord = isFirstWord ? '▁$word' : word;
      
      // Try exact match first
      if (_vocab!.containsKey(processedWord)) {
        tokens.add(_vocab![processedWord]!);
        continue;
      }
      
      // Try without space prefix
      if (_vocab!.containsKey(word)) {
        tokens.add(_vocab![word]!);
        continue;
      }
      
      // Fallback: subword tokenization
      final subTokens = _tokenizeSubword(processedWord);
      tokens.addAll(subTokens);
    }
    
    return tokens;
  }
  
  /// Simple subword tokenization for unknown words
  List<int> _tokenizeSubword(String word) {
    final tokens = <int>[];
    
    String remaining = word;
    
    while (remaining.isNotEmpty) {
      // Find longest matching token
      String? bestMatch;
      int bestLength = 0;
      
      // Try progressively shorter substrings
      for (int len = remaining.length; len >= 1; len--) {
        final substr = remaining.substring(0, len);
        if (_vocab!.containsKey(substr)) {
          bestMatch = substr;
          bestLength = len;
          break;
        }
      }
      
      if (bestMatch != null) {
        tokens.add(_vocab![bestMatch]!);
        remaining = remaining.substring(bestLength);
      } else {
        // Unknown character - use <unk> token
        tokens.add(0);
        remaining = remaining.substring(1);
      }
    }
    
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

  /// Sample token using temperature, top-k, and top-p for natural generation
  int _sampleToken(List<double> logits, {int generatedTokensCount = 0}) {
    if (logits.isEmpty) return 2; // EOS fallback
    
    // Apply temperature scaling
    final scaledLogits = logits.map((logit) => logit / kTemperature).toList();
    
    // Reduce EOS probability early in generation to encourage longer responses
    if (generatedTokensCount < 20) {
      scaledLogits[2] = scaledLogits[2] - 2.0; // Strongly discourage EOS early
      debugPrint('🚫 [SAMPLING] Reduced EOS probability early in generation (${generatedTokensCount} tokens)');
    } else if (generatedTokensCount < 30) {
      scaledLogits[2] = scaledLogits[2] - 1.0; // Moderately discourage EOS mid-generation
    }
    
    // Convert to probabilities (softmax)
    final maxLogit = scaledLogits.reduce((a, b) => a > b ? a : b);
    final expLogits = scaledLogits.map((logit) => math.exp(logit - maxLogit)).toList();
    final sumExp = expLogits.reduce((a, b) => a + b);
    final probabilities = expLogits.map((exp) => exp / sumExp).toList();
    
    // Apply top-k filtering
    final topKIndices = _getTopKIndices(probabilities, kTopK);
    
    // Apply top-p (nucleus) sampling  
    topKIndices.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
    
    double cumulativeProb = 0.0;
    final validCandidates = <Map<String, dynamic>>[];
    
    for (final candidate in topKIndices) {
      final prob = candidate['value'] as double;
      cumulativeProb += prob;
      validCandidates.add(candidate);
      
      if (cumulativeProb >= kTopP) break;
    }
    
    // Sample from valid candidates
    if (validCandidates.isEmpty) {
      return _findMaxIndex(probabilities); // Fallback to greedy
    }
    
    // Weighted random selection
    final random = math.Random();
    final randomValue = random.nextDouble();
    
    double runningSum = 0.0;
    final totalValidProb = validCandidates.fold<double>(0.0, (sum, c) => sum + (c['value'] as double));
    
    for (final candidate in validCandidates) {
      final normalizedProb = (candidate['value'] as double) / totalValidProb;
      runningSum += normalizedProb;
      
      if (randomValue <= runningSum) {
        return candidate['index'] as int;
      }
    }
    
    // Fallback to first valid candidate
    return validCandidates.first['index'] as int;
  }

  /// Real TinyLlama detokenization using loaded vocabulary
  String _detokenizeSimple(List<int> tokens) {
    if (_reverseVocab == null) {
      debugPrint('⚠️ [TOKENIZER] Vocabulary not loaded, cannot detokenize');
      return '<vocab_not_loaded>';
    }
    
    final parts = <String>[];
    
    debugPrint('🔤 [TOKENIZER] Detokenizing ${tokens.length} tokens: ${tokens.take(10)}...');
    
    for (final token in tokens) {
      if (token == 1) {
        // Skip BOS token <s>
        continue;
      }
      if (token == 2) {
        // Stop at EOS token </s>
        break;
      }
      
      if (_reverseVocab!.containsKey(token)) {
        final tokenStr = _reverseVocab![token]!;
        
        // Handle special hex tokens like <0x0A> by converting to actual characters
        if (tokenStr.startsWith('<0x') && tokenStr.endsWith('>')) {
          try {
            final hexStr = tokenStr.substring(3, tokenStr.length - 1);
            final charCode = int.parse(hexStr, radix: 16);
            if (charCode == 10) { // Newline
              parts.add('\n');
            } else if (charCode == 13) { // Carriage return
              parts.add('\r');
            } else if (charCode >= 32 && charCode <= 126) { // Printable ASCII
              parts.add(String.fromCharCode(charCode));
            } else {
              parts.add(' '); // Replace other special chars with space
            }
          } catch (e) {
            debugPrint('⚠️ [TOKENIZER] Failed to parse hex token: $tokenStr');
            parts.add(' ');
          }
        } else {
          parts.add(tokenStr);
        }
        
        debugPrint('🔤 [TOKENIZER] Token $token -> "$tokenStr"');
      } else {
        debugPrint('⚠️ [TOKENIZER] Unknown token: $token');
        parts.add('<unk>');
      }
    }
    
    // Join and clean up SentencePiece formatting
    final rawText = parts.join('');
    
    // Replace ▁ (space markers) with actual spaces
    final cleanText = rawText
        .replaceAll('▁', ' ')
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize multiple spaces
        .trim();
    
    debugPrint('🔤 [TOKENIZER] Detokenized result: "$cleanText"');
    return cleanText;
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
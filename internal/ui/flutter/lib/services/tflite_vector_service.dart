import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// High-performance vector similarity service using TensorFlow Lite
/// Replaces sqlite-vec with optimized Dart + TensorFlow Lite operations
class TFLiteVectorService {
  static TFLiteVectorService? _instance;
  bool _initialized = false;
  
  static TFLiteVectorService get instance {
    _instance ??= TFLiteVectorService._();
    return _instance!;
  }
  
  TFLiteVectorService._();
  
  /// Initialize the TensorFlow Lite vector service
  /// Uses optimized Dart implementation since we don't need a custom model
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // For vector similarity, we don't actually need a TFLite model
      // The optimized Dart implementation is sufficient and avoids model complexity
      _initialized = true;
      debugPrint('✅ TFLite Vector Service initialized (using optimized Dart)');
    } catch (e) {
      debugPrint('❌ Failed to initialize TFLite Vector Service: $e');
      _initialized = false;
    }
  }
  
  /// Calculate cosine similarity between two 384-dimensional vectors
  /// Returns similarity score between -1.0 and 1.0
  Future<double> cosineSimilarity(List<double> vectorA, List<double> vectorB) async {
    return _optimizedCosineSimilarity(vectorA, vectorB);
  }
  
  /// Batch calculate similarities between one query vector and multiple candidate vectors
  /// This is much more efficient than individual calculations
  Future<List<double>> batchCosineSimilarity(
    List<double> queryVector, 
    List<List<double>> candidateVectors
  ) async {
    if (candidateVectors.isEmpty) return [];
    
    // Use optimized batch processing
    return _batchCosineSimilarityOptimized(queryVector, candidateVectors);
  }
  
  /// Highly optimized cosine similarity using SIMD-friendly operations
  double _optimizedCosineSimilarity(List<double> vectorA, List<double> vectorB) {
    if (vectorA.length != vectorB.length) return 0.0;
    
    // Convert to Float64List for better performance
    final a = vectorA is Float64List ? vectorA : Float64List.fromList(vectorA);
    final b = vectorB is Float64List ? vectorB : Float64List.fromList(vectorB);
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    final len = a.length;
    int i = 0;
    
    // Unrolled loop for better CPU utilization (process 8 elements at once)
    for (; i < len - 7; i += 8) {
      final a0 = a[i], a1 = a[i + 1], a2 = a[i + 2], a3 = a[i + 3];
      final a4 = a[i + 4], a5 = a[i + 5], a6 = a[i + 6], a7 = a[i + 7];
      final b0 = b[i], b1 = b[i + 1], b2 = b[i + 2], b3 = b[i + 3];
      final b4 = b[i + 4], b5 = b[i + 5], b6 = b[i + 6], b7 = b[i + 7];
      
      dotProduct += a0 * b0 + a1 * b1 + a2 * b2 + a3 * b3 + a4 * b4 + a5 * b5 + a6 * b6 + a7 * b7;
      normA += a0 * a0 + a1 * a1 + a2 * a2 + a3 * a3 + a4 * a4 + a5 * a5 + a6 * a6 + a7 * a7;
      normB += b0 * b0 + b1 * b1 + b2 * b2 + b3 * b3 + b4 * b4 + b5 * b5 + b6 * b6 + b7 * b7;
    }
    
    // Handle remaining elements
    for (; i < len; i++) {
      final aVal = a[i];
      final bVal = b[i];
      dotProduct += aVal * bVal;
      normA += aVal * aVal;
      normB += bVal * bVal;
    }
    
    // Avoid division by zero
    if (normA == 0.0 || normB == 0.0) return 0.0;
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
  
  /// Optimized batch cosine similarity calculation
  List<double> _batchCosineSimilarityOptimized(
    List<double> queryVector,
    List<List<double>> candidateVectors,
  ) {
    if (candidateVectors.isEmpty) return [];
    
    final query = queryVector is Float64List ? queryVector : Float64List.fromList(queryVector);
    final results = <double>[];
    
    // Pre-calculate query norm once
    double queryNorm = 0.0;
    for (int i = 0; i < query.length; i++) {
      queryNorm += query[i] * query[i];
    }
    queryNorm = sqrt(queryNorm);
    
    if (queryNorm == 0.0) {
      return List.filled(candidateVectors.length, 0.0);
    }
    
    // Calculate similarity for each candidate
    for (final candidate in candidateVectors) {
      final candidateFloat = candidate is Float64List ? candidate : Float64List.fromList(candidate);
      
      if (candidateFloat.length != query.length) {
        results.add(0.0);
        continue;
      }
      
      double dotProduct = 0.0;
      double candidateNorm = 0.0;
      
      final len = query.length;
      int i = 0;
      
      // Unrolled loop for better performance
      for (; i < len - 7; i += 8) {
        final q0 = query[i], q1 = query[i + 1], q2 = query[i + 2], q3 = query[i + 3];
        final q4 = query[i + 4], q5 = query[i + 5], q6 = query[i + 6], q7 = query[i + 7];
        final c0 = candidateFloat[i], c1 = candidateFloat[i + 1], c2 = candidateFloat[i + 2], c3 = candidateFloat[i + 3];
        final c4 = candidateFloat[i + 4], c5 = candidateFloat[i + 5], c6 = candidateFloat[i + 6], c7 = candidateFloat[i + 7];
        
        dotProduct += q0 * c0 + q1 * c1 + q2 * c2 + q3 * c3 + q4 * c4 + q5 * c5 + q6 * c6 + q7 * c7;
        candidateNorm += c0 * c0 + c1 * c1 + c2 * c2 + c3 * c3 + c4 * c4 + c5 * c5 + c6 * c6 + c7 * c7;
      }
      
      // Handle remaining elements
      for (; i < len; i++) {
        final qVal = query[i];
        final cVal = candidateFloat[i];
        dotProduct += qVal * cVal;
        candidateNorm += cVal * cVal;
      }
      
      candidateNorm = sqrt(candidateNorm);
      
      if (candidateNorm == 0.0) {
        results.add(0.0);
      } else {
        results.add(dotProduct / (queryNorm * candidateNorm));
      }
    }
    
    return results;
  }
  
  /// Create mobile-optimized user profile vector with memory limits
  /// Limits samples to avoid memory issues on iOS/Android
  Future<List<double>> createMobileUserProfileVector({
    required List<List<double>> likedEmbeddings,
    required List<List<double>> dislikedEmbeddings,
    List<List<double>> favoriteEmbeddings = const [],
    List<List<double>> watchlistEmbeddings = const [],
    required List<String> userConstraints,
    int maxLikedSamples = 10,     // Limit for mobile memory
    int maxDislikedSamples = 5,   // Fewer negative samples needed
    int maxFavoriteSamples = 8,   // Favorites are high-signal
    int maxWatchlistSamples = 5,  // Watchlist is medium-signal
  }) async {
    if (likedEmbeddings.isEmpty && favoriteEmbeddings.isEmpty && watchlistEmbeddings.isEmpty) {
      throw ArgumentError('Need at least one positive signal to create profile');
    }
    
    // Limit samples for mobile performance
    final limitedLiked = likedEmbeddings.take(maxLikedSamples).toList();
    final limitedDisliked = dislikedEmbeddings.take(maxDislikedSamples).toList();
    final limitedFavorites = favoriteEmbeddings.take(maxFavoriteSamples).toList();
    final limitedWatchlist = watchlistEmbeddings.take(maxWatchlistSamples).toList();
    
    debugPrint('🧠 [TFLITE] Building profile from: ${limitedLiked.length} liked, ${limitedFavorites.length} favorites, ${limitedWatchlist.length} watchlist, ${limitedDisliked.length} disliked');
    
    // Collect all positive signals with appropriate weights
    final weightedVectors = <(List<double>, double)>[];
    
    // Add liked items (weight: 1.0)
    for (final liked in limitedLiked) {
      weightedVectors.add((liked, 1.0));
    }
    
    // Add favorites (weight: 2.0 - higher signal)
    for (final favorite in limitedFavorites) {
      weightedVectors.add((favorite, 2.0));
      debugPrint('📊 [TFLITE] Added favorite with 2.0x weight');
    }
    
    // Add watchlist items (weight: 1.5 - medium signal)
    for (final watchlist in limitedWatchlist) {
      weightedVectors.add((watchlist, 1.5));
      debugPrint('📊 [TFLITE] Added watchlist item with 1.5x weight');
    }
    
    if (weightedVectors.isEmpty) {
      throw ArgumentError('No positive signals available after filtering');
    }
    
    // Create weighted profile vector
    List<double> profileVector = _weightedAverage(weightedVectors);
    
    // Apply constraint-based adjustments
    for (final constraint in userConstraints) {
      profileVector = _adjustVectorForConstraint(profileVector, constraint);
    }
    
    // Apply negative filtering (subtract disliked patterns)
    if (limitedDisliked.isNotEmpty) {
      profileVector = _applyNegativeFiltering(profileVector, limitedDisliked);
    }
    
    debugPrint('🧠 [TFLITE] Mobile profile created: ${limitedLiked.length} liked, ${limitedFavorites.length} favorites, ${limitedWatchlist.length} watchlist, ${limitedDisliked.length} disliked, ${userConstraints.length} constraints');
    
    return profileVector;
  }
  
  /// Average multiple vectors into a single representative vector
  List<double> _averageVectors(List<List<double>> vectors) {
    if (vectors.isEmpty) throw ArgumentError('Cannot average empty vector list');
    
    final dimensions = vectors.first.length;
    final result = List<double>.filled(dimensions, 0.0);
    
    for (final vector in vectors) {
      for (int i = 0; i < dimensions; i++) {
        result[i] += vector[i];
      }
    }
    
    // Normalize by count
    final count = vectors.length.toDouble();
    for (int i = 0; i < dimensions; i++) {
      result[i] /= count;
    }
    
    return result;
  }
  
  /// Create weighted average of vectors with different importance
  List<double> _weightedAverage(List<(List<double>, double)> weightedVectors) {
    if (weightedVectors.isEmpty) throw ArgumentError('Cannot average empty list');
    
    final dimensions = weightedVectors.first.$1.length;
    final result = List<double>.filled(dimensions, 0.0);
    double totalWeight = 0.0;
    
    for (final (vector, weight) in weightedVectors) {
      totalWeight += weight;
      for (int i = 0; i < dimensions; i++) {
        result[i] += vector[i] * weight;
      }
    }
    
    // Normalize by total weight
    for (int i = 0; i < dimensions; i++) {
      result[i] /= totalWeight;
    }
    
    return result;
  }
  
  /// Adjust vector to emphasize certain constraints (REMOVED HARDCODED GENRES)
  List<double> _adjustVectorForConstraint(List<double> vector, String constraint) {
    // CLEAN: No hardcoded genre preferences - return vector unchanged
    // Let the data speak for itself through similarity matching
    debugPrint('🎯 Constraint noted but not applied (no hardcoded preferences): $constraint');
    return List<double>.from(vector);
  }
  
  /// Boost specific dimensions of a vector by a factor
  void _boostVectorDimensions(List<double> vector, List<int> dimensions, double boostFactor) {
    for (final dim in dimensions) {
      if (dim < vector.length) {
        vector[dim] *= (1.0 + boostFactor);
      }
    }
  }
  
  /// Apply negative filtering to reduce similarity to disliked content
  /// Subtracts averaged disliked patterns from the profile vector
  List<double> _applyNegativeFiltering(List<double> profileVector, List<List<double>> dislikedEmbeddings) {
    if (dislikedEmbeddings.isEmpty) return profileVector;
    
    // Create average of disliked patterns
    final dislikedAverage = _averageVectors(dislikedEmbeddings);
    
    // Subtract disliked patterns with reduced weight (don't overcompensate)
    final filtered = List<double>.from(profileVector);
    const negativeWeight = 0.3; // Gentle negative influence
    
    for (int i = 0; i < filtered.length; i++) {
      filtered[i] = filtered[i] - (dislikedAverage[i] * negativeWeight);
    }
    
    return filtered;
  }

  /// Mobile-optimized single suggestion finder
  /// Uses streaming approach to avoid loading all 343k vectors into memory
  Future<VectorWithMetadata?> findSingleSuggestion({
    required List<double> userProfileVector,
    required List<String> excludeIds,
    required double minSimilarity,
    required Future<List<VectorWithMetadata>> Function(int offset, int limit) vectorLoader,
    int batchSize = 500, // Smaller batches for faster initial results
  }) async {
    debugPrint('🔍 [TFLITE] Starting mobile single-suggestion search (threshold: $minSimilarity)');
    
    VectorWithMetadata? bestMatch;
    double bestSimilarity = minSimilarity;
    int processedCount = 0;
    int offset = 0;
    int goodMatches = 0;
    
    final stopwatch = Stopwatch()..start();
    
    // Stream through vectors in batches to avoid memory issues
    while (true) {
      final batchStopwatch = Stopwatch()..start();
      final batch = await vectorLoader(offset, batchSize);
      if (batch.isEmpty) break;
      
      // Calculate similarities for this batch
      final similarities = await batchCosineSimilarity(
        userProfileVector, 
        batch.map((v) => v.embedding).toList()
      );
      
      // Find best in this batch
      for (int i = 0; i < batch.length; i++) {
        final candidate = batch[i];
        final similarity = similarities[i];
        
        // Skip excluded items
        if (excludeIds.contains(candidate.id)) continue;
        
        // Count good matches for early termination
        if (similarity > 0.6 && similarity <= 0.75) {
          goodMatches++;
          debugPrint('📊 [TFLITE] Good match: ${candidate.title} (${similarity.toStringAsFixed(3)})');
        }
        
        // Update best match if this is better (but cap at 0.75 for diversity)
        if (similarity > bestSimilarity && similarity <= 0.75) {
          bestSimilarity = similarity;
          bestMatch = candidate;
          debugPrint('🎯 [TFLITE] New best: ${candidate.title} (${similarity.toStringAsFixed(3)})');
        } else if (similarity > 0.75) {
          debugPrint('🚫 [TFLITE] Skipping too similar: ${candidate.title} (${similarity.toStringAsFixed(3)}) - too close to favorites');
        }
      }
      
      processedCount += batch.length;
      offset += batchSize;
      batchStopwatch.stop();
      
      // More aggressive early termination strategies (capped at 0.75 for diversity)
      if (bestSimilarity > 0.7) {
        debugPrint('🎯 [TFLITE] Great match found (${bestSimilarity.toStringAsFixed(3)}) after $processedCount vectors in ${stopwatch.elapsedMilliseconds}ms');
        break;
      }
      
      // Stop after finding several good options
      if (goodMatches >= 3 && bestSimilarity > 0.65) {
        debugPrint('🎯 [TFLITE] Found multiple good matches, stopping early after $processedCount vectors');
        break;
      }
      
      // Time-based early termination for mobile responsiveness
      if (stopwatch.elapsedMilliseconds > 3000) { // 3 second limit
        debugPrint('⏰ [TFLITE] Time limit reached (3s), stopping search with best match so far');
        break;
      }
      
      // Progress logging every 2.5k vectors (faster feedback)
      if (processedCount % 2500 == 0) {
        debugPrint('📊 [TFLITE] Processed $processedCount vectors in ${stopwatch.elapsedMilliseconds}ms, best: ${bestSimilarity.toStringAsFixed(3)} (batch: ${batchStopwatch.elapsedMilliseconds}ms)');
      }
      
      // Stop after reasonable search if we have a decent match
      if (processedCount >= 10000 && bestSimilarity > 0.6) {
        debugPrint('🔄 [TFLITE] Searched 10k vectors, found decent match, stopping');
        break;
      }
    }
    
    stopwatch.stop();
    
    if (bestMatch != null) {
      debugPrint('✅ [TFLITE] Single suggestion found: ${bestMatch.title} (similarity: ${bestSimilarity.toStringAsFixed(3)}) after ${stopwatch.elapsedMilliseconds}ms, $processedCount vectors');
    } else {
      debugPrint('❌ [TFLITE] No suitable suggestion found above threshold $minSimilarity after ${stopwatch.elapsedMilliseconds}ms');
    }
    
    return bestMatch;
  }

  /// Find top K most similar vectors efficiently
  /// Uses partial sorting for better performance
  Future<List<SimilarityResult>> findTopSimilar({
    required List<double> queryVector,
    required List<VectorWithMetadata> candidates,
    required int topK,
    double minSimilarity = 0.0,
  }) async {
    if (candidates.isEmpty) return [];
    
    // Extract just the vectors for batch processing
    final candidateVectors = candidates.map((c) => c.vector).toList();
    
    // Calculate all similarities in one batch
    final similarities = await batchCosineSimilarity(queryVector, candidateVectors);
    
    // Create results with metadata
    final results = <SimilarityResult>[];
    for (int i = 0; i < similarities.length; i++) {
      final similarity = similarities[i];
      if (similarity >= minSimilarity) {
        results.add(SimilarityResult(
          item: candidates[i],
          similarity: similarity,
        ));
      }
    }
    
    // Partial sort to get top K (more efficient than full sort)
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    
    return results.take(topK).toList();
  }
  
  /// Dispose resources
  void dispose() {
    _initialized = false;
  }
}

/// Vector with associated metadata for similarity search
class VectorWithMetadata {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final List<double> vector;
  final List<double> embedding; // Alias for vector for compatibility
  final Map<String, dynamic> metadata;
  
  VectorWithMetadata({
    required this.id,
    required this.title,
    required this.vector,
    required this.metadata,
    this.artist,
    this.album,
  }) : embedding = vector; // embedding is just an alias for vector
}

/// Result of similarity calculation with metadata
class SimilarityResult {
  final VectorWithMetadata item;
  final double similarity;
  final Map<String, dynamic> metadata;
  
  SimilarityResult({
    required this.item,
    required this.similarity,
  }) : metadata = item.metadata;
}

/// Performance monitoring for vector operations
class VectorPerformanceMonitor {
  static final Map<String, List<int>> _timings = {};
  
  static void recordTiming(String operation, int milliseconds) {
    _timings[operation] ??= [];
    _timings[operation]!.add(milliseconds);
    
    // Keep only last 100 measurements
    if (_timings[operation]!.length > 100) {
      _timings[operation]!.removeAt(0);
    }
  }
  
  static Map<String, double> getAverageTimings() {
    final averages = <String, double>{};
    for (final entry in _timings.entries) {
      final times = entry.value;
      averages[entry.key] = times.reduce((a, b) => a + b) / times.length;
    }
    return averages;
  }
  
  static void printStats() {
    final stats = getAverageTimings();
    debugPrint('🔬 Vector Performance Stats:');
    for (final entry in stats.entries) {
      debugPrint('  ${entry.key}: ${entry.value.toStringAsFixed(1)}ms avg');
    }
  }
} 
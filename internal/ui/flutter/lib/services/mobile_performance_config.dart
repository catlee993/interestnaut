import 'dart:io';
import 'package:flutter/foundation.dart';

/// Mobile Performance Configuration
/// Optimized limits for iOS and Android devices to balance quality with performance
class MobilePerformanceConfig {
  // 🔋 BATTERY-CONSCIOUS LIMITS
  
  /// Maximum vectors to process per search session
  static const int maxVectorsPerSearch = 25000; // Reduced from 343k
  
  /// Batch size for vector similarity calculations
  static const int vectorBatchSize = 800; // Optimized for modern mobile devices
  
  /// Maximum behavioral samples for user profile creation
  static const int maxLikedSamples = 5;     // Reduced from 10
  static const int maxDislikedSamples = 3;  // Reduced from 5
  static const int maxSkippedSamples = 2;
  
  /// Early termination thresholds
  static const double excellentSimilarityThreshold = 0.85; // Stop if found
  static const int maxProcessingTimeMs = 3000; // 3 second timeout
  
  // 📱 DEVICE-SPECIFIC CONFIGURATIONS
  
  /// iOS optimized settings
  static const MobileDeviceConfig iosConfig = MobileDeviceConfig(
    maxVectors: 40000,  // Increased for modern iOS devices
    batchSize: 1000,    // Higher batch size for better performance
    maxThreads: 4,      // More threads for recent iPhones
    useMetalAcceleration: true,
    aggressiveMemoryManagement: true,
  );
  
  /// Android optimized settings  
  static const MobileDeviceConfig androidConfig = MobileDeviceConfig(
    maxVectors: 30000,  // Increased for modern Android flagships
    batchSize: 800,     // Higher batch size for better performance
    maxThreads: 3,      // More threads for recent Android devices
    useMetalAcceleration: false,
    aggressiveMemoryManagement: true,
  );
  
  // 🧠 LLM PERFORMANCE LIMITS
  
  /// TinyLlama model limits for mobile
  static const int maxLlmTokens = 80;        // Increased with larger batch size
  static const double lowTemperature = 0.5;  // Balanced creativity and stability
  static const int llmTimeoutMs = 2500;      // 2.5s timeout for better generation
  
  /// Response validation patterns
  static const List<String> validResponseStarters = [
    'This',
    'A',
    'An',
    'Great',
    'Perfect',
    'Excellent',
  ];
  
  // 🎯 SEARCH QUALITY THRESHOLDS
  
  /// Minimum similarity thresholds by search type
  static const Map<String, double> minSimilarityThresholds = {
    'liked_match': 0.65,      // Lower threshold for behavioral matching
    'favorite_match': 0.45,   // Even lower for favorites
    'constraint_match': 0.55, // Medium for text constraints
    'random_fallback': 0.0,   // No threshold for random
  };
  
  /// Collection size limits by media type
  static const Map<String, int> mediaTypeVectorLimits = {
    'music': 40000,     // Music has most data
    'movie': 25000,     // Movies second
    'tv_show': 20000,   // TV shows third  
    'book': 15000,      // Books smaller dataset
    'video_game': 10000,// Games smallest
  };
  
  // ⚡ PERFORMANCE MONITORING
  
  /// Performance warning thresholds
  static const int slowSearchWarningMs = 2000;
  static const int memoryWarningMB = 100;
  static const double batteryWarningPercent = 1.0; // Warn if >1% battery per search
  
  /// Get device-appropriate config
  static MobileDeviceConfig getDeviceConfig() {
    if (Platform.isIOS) {
      return iosConfig;
    } else {
      return androidConfig;
    }
  }
  
  /// Calculate recommended vector limit for current device
  static int getRecommendedVectorLimit(String mediaType) {
    final baseLimit = mediaTypeVectorLimits[mediaType] ?? 20000;
    final deviceConfig = getDeviceConfig();
    
    // Adjust based on device capabilities
    return (baseLimit * (deviceConfig.maxVectors / 25000)).round();
  }
  
  /// Check if current search parameters are mobile-friendly
  static bool isMobileFriendly({
    required int vectorCount,
    required int batchSize,
    required String mediaType,
  }) {
    final limit = getRecommendedVectorLimit(mediaType);
    return vectorCount <= limit && batchSize <= vectorBatchSize;
  }
}

/// Device-specific configuration
class MobileDeviceConfig {
  final int maxVectors;
  final int batchSize;  
  final int maxThreads;
  final bool useMetalAcceleration;
  final bool aggressiveMemoryManagement;
  
  const MobileDeviceConfig({
    required this.maxVectors,
    required this.batchSize,
    required this.maxThreads,
    required this.useMetalAcceleration,
    required this.aggressiveMemoryManagement,
  });
}

/// Mobile performance monitoring
class MobilePerformanceMonitor {
  static final Map<String, List<int>> _searchTimes = {};
  static int _totalSearches = 0;
  static double _totalBatteryUsed = 0.0;
  
  /// Record a search performance metric
  static void recordSearch({
    required String mediaType,
    required int durationMs,
    required int vectorsProcessed,
    double? batteryUsed,
  }) {
    _searchTimes[mediaType] ??= [];
    _searchTimes[mediaType]!.add(durationMs);
    _totalSearches++;
    
    if (batteryUsed != null) {
      _totalBatteryUsed += batteryUsed;
    }
    
    // Warn if performance is degrading
    if (durationMs > MobilePerformanceConfig.slowSearchWarningMs) {
      debugPrint('⚠️ Slow search detected: ${durationMs}ms for $vectorsProcessed vectors');
    }
  }
  
  /// Get performance statistics
  static Map<String, dynamic> getStats() {
    final avgTimes = <String, double>{};
    for (final entry in _searchTimes.entries) {
      final times = entry.value;
      avgTimes[entry.key] = times.reduce((a, b) => a + b) / times.length;
    }
    
    return {
      'averageSearchTimes': avgTimes,
      'totalSearches': _totalSearches,
      'averageBatteryPerSearch': _totalSearches > 0 ? _totalBatteryUsed / _totalSearches : 0.0,
      'recommendedOptimizations': _getOptimizationRecommendations(avgTimes),
    };
  }
  
  static List<String> _getOptimizationRecommendations(Map<String, double> avgTimes) {
    final recommendations = <String>[];
    
    for (final entry in avgTimes.entries) {
      if (entry.value > MobilePerformanceConfig.slowSearchWarningMs) {
        recommendations.add('Reduce vector limit for ${entry.key}');
      }
    }
    
    if (_totalBatteryUsed / _totalSearches > MobilePerformanceConfig.batteryWarningPercent) {
      recommendations.add('Implement more aggressive early termination');
    }
    
    return recommendations;
  }
} 
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Performance monitoring service for LLM and recommendation timing
class LLMPerformanceMonitor {
  static final LLMPerformanceMonitor _instance = LLMPerformanceMonitor._internal();
  factory LLMPerformanceMonitor() => _instance;
  LLMPerformanceMonitor._internal();

  final Map<String, Stopwatch> _activeTimers = {};
  final List<PerformanceMetric> _metrics = [];
  Timer? _reportTimer;
  
  /// Initialize performance monitoring
  void init() {
    // Report performance metrics every 30 seconds
    _reportTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _reportPerformanceMetrics(),
    );
    
    debugPrint('📊 LLM Performance Monitor initialized');
  }

  /// Start timing a specific operation
  void startTiming(String operationId) {
    final stopwatch = Stopwatch()..start();
    _activeTimers[operationId] = stopwatch;
    debugPrint('⏱️ [START] $operationId');
  }

  /// Stop timing and record metric
  void stopTiming(String operationId, {
    String? mediaType,
    bool? usedUserProfile,
    int? profileThemeCount,
    int? profileArtistCount,
    Map<String, dynamic>? additionalData,
  }) {
    final stopwatch = _activeTimers.remove(operationId);
    if (stopwatch == null) {
      debugPrint('⚠️ No active timer found for $operationId');
      return;
    }
    
    stopwatch.stop();
    final duration = stopwatch.elapsedMilliseconds;
    
    final metric = PerformanceMetric(
      operationId: operationId,
      durationMs: duration,
      timestamp: DateTime.now(),
      mediaType: mediaType,
      usedUserProfile: usedUserProfile,
      profileThemeCount: profileThemeCount,
      profileArtistCount: profileArtistCount,
      additionalData: additionalData,
    );
    
    _metrics.add(metric);
    
    // Keep only last 100 metrics
    if (_metrics.length > 100) {
      _metrics.removeAt(0);
    }
    
    debugPrint('⏱️ [STOP] $operationId: ${duration}ms${_formatMetricDetails(metric)}');
  }

  /// Format metric details for logging
  String _formatMetricDetails(PerformanceMetric metric) {
    final details = <String>[];
    
    if (metric.mediaType != null) {
      details.add('type=${metric.mediaType}');
    }
    
    if (metric.usedUserProfile == true) {
      details.add('enhanced=true');
      if (metric.profileThemeCount != null) {
        details.add('themes=${metric.profileThemeCount}');
      }
      if (metric.profileArtistCount != null) {
        details.add('artists=${metric.profileArtistCount}');
      }
    } else if (metric.usedUserProfile == false) {
      details.add('enhanced=false');
    }
    
    if (metric.additionalData != null) {
      for (final entry in metric.additionalData!.entries) {
        details.add('${entry.key}=${entry.value}');
      }
    }
    
    return details.isNotEmpty ? ' (${details.join(', ')})' : '';
  }

  /// Get performance statistics for a specific operation
  PerformanceStats getStats(String operationId) {
    final operationMetrics = _metrics
        .where((m) => m.operationId == operationId)
        .toList();
    
    if (operationMetrics.isEmpty) {
      return PerformanceStats.empty(operationId);
    }
    
    final durations = operationMetrics.map((m) => m.durationMs).toList()..sort();
    final enhancedMetrics = operationMetrics.where((m) => m.usedUserProfile == true).toList();
    final basicMetrics = operationMetrics.where((m) => m.usedUserProfile == false).toList();
    
    return PerformanceStats(
      operationId: operationId,
      totalCount: operationMetrics.length,
      averageDurationMs: durations.reduce((a, b) => a + b) / durations.length,
      minDurationMs: durations.first,
      maxDurationMs: durations.last,
      medianDurationMs: durations[durations.length ~/ 2],
      enhancedReasoningCount: enhancedMetrics.length,
      basicReasoningCount: basicMetrics.length,
      enhancedAverageDurationMs: enhancedMetrics.isNotEmpty 
          ? enhancedMetrics.map((m) => m.durationMs).reduce((a, b) => a + b) / enhancedMetrics.length
          : 0.0,
      basicAverageDurationMs: basicMetrics.isNotEmpty
          ? basicMetrics.map((m) => m.durationMs).reduce((a, b) => a + b) / basicMetrics.length
          : 0.0,
    );
  }

  /// Get overall performance summary
  Map<String, PerformanceStats> getAllStats() {
    final statsByOperation = <String, PerformanceStats>{};
    
    final operationIds = _metrics.map((m) => m.operationId).toSet();
    for (final operationId in operationIds) {
      statsByOperation[operationId] = getStats(operationId);
    }
    
    return statsByOperation;
  }

  /// Report performance metrics to debug console
  void _reportPerformanceMetrics() {
    if (_metrics.isEmpty) return;
    
    final stats = getAllStats();
    if (stats.isEmpty) return;
    
    debugPrint('📊 === LLM Performance Report ===');
    
    for (final entry in stats.entries) {
      final stat = entry.value;
      debugPrint('📊 ${entry.key}:');
      debugPrint('   Total: ${stat.totalCount} operations');
      debugPrint('   Average: ${stat.averageDurationMs.toStringAsFixed(1)}ms');
      debugPrint('   Range: ${stat.minDurationMs}ms - ${stat.maxDurationMs}ms');
      debugPrint('   Median: ${stat.medianDurationMs}ms');
      
      if (stat.enhancedReasoningCount > 0) {
        debugPrint('   Enhanced reasoning: ${stat.enhancedReasoningCount} ops, avg ${stat.enhancedAverageDurationMs.toStringAsFixed(1)}ms');
      }
      
      if (stat.basicReasoningCount > 0) {
        debugPrint('   Basic reasoning: ${stat.basicReasoningCount} ops, avg ${stat.basicAverageDurationMs.toStringAsFixed(1)}ms');
      }
      
      if (stat.enhancedReasoningCount > 0 && stat.basicReasoningCount > 0) {
        final improvement = ((stat.basicAverageDurationMs - stat.enhancedAverageDurationMs) / stat.basicAverageDurationMs * 100);
        debugPrint('   Performance change: ${improvement > 0 ? '+' : ''}${improvement.toStringAsFixed(1)}% vs basic');
      }
    }
    
    debugPrint('📊 ===============================');
  }

  /// Save performance data to preferences (for persistence)
  Future<void> savePerformanceData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _metrics.map((m) => m.toJson()).toList();
      await prefs.setString('llm_performance_metrics', jsonEncode(data));
    } catch (e) {
      debugPrint('❌ Failed to save performance data: $e');
    }
  }

  /// Load performance data from preferences
  Future<void> loadPerformanceData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataJson = prefs.getString('llm_performance_metrics');
      if (dataJson != null) {
        final data = jsonDecode(dataJson) as List<dynamic>;
        _metrics.clear();
        _metrics.addAll(data.map((json) => PerformanceMetric.fromJson(json)));
        debugPrint('📊 Loaded ${_metrics.length} performance metrics');
      }
    } catch (e) {
      debugPrint('❌ Failed to load performance data: $e');
    }
  }

  /// Clear all performance data
  void clearPerformanceData() {
    _metrics.clear();
    _activeTimers.clear();
    debugPrint('🗑️ Cleared all performance data');
  }

  /// Get current LLM reasoning timing estimate
  double getEstimatedReasoningTime(String mediaType, bool hasUserProfile) {
    final reasoningStats = getStats('llm_reasoning_generation');
    
    if (hasUserProfile && reasoningStats.enhancedReasoningCount > 0) {
      return reasoningStats.enhancedAverageDurationMs;
    } else if (!hasUserProfile && reasoningStats.basicReasoningCount > 0) {
      return reasoningStats.basicAverageDurationMs;
    } else if (reasoningStats.totalCount > 0) {
      return reasoningStats.averageDurationMs;
    }
    
    // Default estimates based on reasoning type
    return hasUserProfile ? 75.0 : 25.0; // Enhanced vs basic reasoning estimates
  }

  /// Dispose resources
  void dispose() {
    _reportTimer?.cancel();
    _activeTimers.clear();
    _metrics.clear();
  }
}

/// Individual performance metric
class PerformanceMetric {
  final String operationId;
  final int durationMs;
  final DateTime timestamp;
  final String? mediaType;
  final bool? usedUserProfile;
  final int? profileThemeCount;
  final int? profileArtistCount;
  final Map<String, dynamic>? additionalData;

  PerformanceMetric({
    required this.operationId,
    required this.durationMs,
    required this.timestamp,
    this.mediaType,
    this.usedUserProfile,
    this.profileThemeCount,
    this.profileArtistCount,
    this.additionalData,
  });

  Map<String, dynamic> toJson() {
    return {
      'operationId': operationId,
      'durationMs': durationMs,
      'timestamp': timestamp.toIso8601String(),
      'mediaType': mediaType,
      'usedUserProfile': usedUserProfile,
      'profileThemeCount': profileThemeCount,
      'profileArtistCount': profileArtistCount,
      'additionalData': additionalData,
    };
  }

  factory PerformanceMetric.fromJson(Map<String, dynamic> json) {
    return PerformanceMetric(
      operationId: json['operationId'],
      durationMs: json['durationMs'],
      timestamp: DateTime.parse(json['timestamp']),
      mediaType: json['mediaType'],
      usedUserProfile: json['usedUserProfile'],
      profileThemeCount: json['profileThemeCount'],
      profileArtistCount: json['profileArtistCount'],
      additionalData: json['additionalData'] != null 
          ? Map<String, dynamic>.from(json['additionalData'])
          : null,
    );
  }
}

/// Performance statistics for an operation
class PerformanceStats {
  final String operationId;
  final int totalCount;
  final double averageDurationMs;
  final int minDurationMs;
  final int maxDurationMs;
  final int medianDurationMs;
  final int enhancedReasoningCount;
  final int basicReasoningCount;
  final double enhancedAverageDurationMs;
  final double basicAverageDurationMs;

  PerformanceStats({
    required this.operationId,
    required this.totalCount,
    required this.averageDurationMs,
    required this.minDurationMs,
    required this.maxDurationMs,
    required this.medianDurationMs,
    required this.enhancedReasoningCount,
    required this.basicReasoningCount,
    required this.enhancedAverageDurationMs,
    required this.basicAverageDurationMs,
  });

  factory PerformanceStats.empty(String operationId) {
    return PerformanceStats(
      operationId: operationId,
      totalCount: 0,
      averageDurationMs: 0.0,
      minDurationMs: 0,
      maxDurationMs: 0,
      medianDurationMs: 0,
      enhancedReasoningCount: 0,
      basicReasoningCount: 0,
      enhancedAverageDurationMs: 0.0,
      basicAverageDurationMs: 0.0,
    );
  }
} 
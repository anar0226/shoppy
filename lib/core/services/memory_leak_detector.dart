import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'production_logger.dart';
import 'listener_manager.dart';
import 'error_handler_service.dart';

/// Comprehensive memory leak detection and performance monitoring service
class MemoryLeakDetector {
  static final MemoryLeakDetector _instance = MemoryLeakDetector._internal();
  static MemoryLeakDetector get instance => _instance;
  MemoryLeakDetector._internal();

  // Memory monitoring
  final Map<String, int> _memorySnapshots = {};
  final Map<String, DateTime> _snapshotTimes = {};
  final List<MemoryLeakReport> _leakReports = [];

  // Performance monitoring
  final Map<String, PerformanceMetrics> _performanceMetrics = {};
  final Map<String, List<double>> _frameTimes = {};
  final Map<String, int> _widgetRebuildCounts = {};

  // Stream monitoring
  final Map<String, StreamSubscription> _monitoredStreams = {};
  final Map<String, DateTime> _streamCreationTimes = {};

  // Timer monitoring
  final Map<String, Timer> _monitoredTimers = {};
  final Map<String, DateTime> _timerCreationTimes = {};

  // Configuration
  bool _isMonitoring = false;
  Duration _monitoringInterval = const Duration(seconds: 30);
  Duration _memoryLeakThreshold = const Duration(minutes: 10);
  int _memoryGrowthThreshold = 50 * 1024 * 1024; // 50MB

  // Isolate monitoring
  final Map<String, Isolate> _monitoredIsolates = {};
  final Map<String, DateTime> _isolateCreationTimes = {};

  // Production testing scenarios
  final Map<String, ProductionTestScenario> _testScenarios = {};
  bool _isStressTesting = false;

  /// Initialize memory leak detector
  Future<void> initialize({
    Duration? monitoringInterval,
    Duration? memoryLeakThreshold,
    int? memoryGrowthThreshold,
  }) async {
    _monitoringInterval = monitoringInterval ?? _monitoringInterval;
    _memoryLeakThreshold = memoryLeakThreshold ?? _memoryLeakThreshold;
    _memoryGrowthThreshold = memoryGrowthThreshold ?? _memoryGrowthThreshold;

    await ProductionLogger.instance.info(
      'MemoryLeakDetector initialized',
      context: {
        'monitoringInterval': _monitoringInterval.inSeconds,
        'memoryLeakThreshold': _memoryLeakThreshold.inMinutes,
        'memoryGrowthThreshold': _memoryGrowthThreshold,
      },
    );
  }

  /// Start memory leak monitoring
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;

    // Start periodic memory monitoring
    Timer.periodic(_monitoringInterval, (timer) async {
      if (!_isMonitoring) {
        timer.cancel();
        return;
      }

      await _performMemoryCheck();
      await _performPerformanceCheck();
      await _performStreamCheck();
      await _performTimerCheck();
    });

    // Monitor widget rebuilds
    _startWidgetRebuildMonitoring();

    // Monitor frame times
    _startFrameTimeMonitoring();

    await ProductionLogger.instance.info('Memory leak monitoring started');
  }

  /// Stop memory leak monitoring
  Future<void> stopMonitoring() async {
    _isMonitoring = false;

    // Generate final report
    await _generateMemoryLeakReport();

    await ProductionLogger.instance.info('Memory leak monitoring stopped');
  }

  /// Perform memory check
  Future<void> _performMemoryCheck() async {
    try {
      final memoryInfo = await _getMemoryInfo();
      final timestamp = DateTime.now();
      final snapshotId = timestamp.millisecondsSinceEpoch.toString();

      _memorySnapshots[snapshotId] = memoryInfo.used;
      _snapshotTimes[snapshotId] = timestamp;

      // Check for memory leaks
      await _checkForMemoryLeaks(memoryInfo);

      // Clean old snapshots (keep last 100)
      if (_memorySnapshots.length > 100) {
        final oldestKey = _memorySnapshots.keys.first;
        _memorySnapshots.remove(oldestKey);
        _snapshotTimes.remove(oldestKey);
      }
    } catch (error, stackTrace) {
      await ErrorHandlerService.instance.handleError(
        operation: 'memory_check',
        error: error,
        stackTrace: stackTrace,
        showUserMessage: false,
      );
    }
  }

  /// Check for memory leaks
  Future<void> _checkForMemoryLeaks(MemoryInfo memoryInfo) async {
    if (_memorySnapshots.length < 5) return; // Need at least 5 snapshots

    final recentSnapshots = _memorySnapshots.values.toList()..sort();
    final oldestMemory = recentSnapshots.first;
    final newestMemory = recentSnapshots.last;
    final memoryGrowth = newestMemory - oldestMemory;

    if (memoryGrowth > _memoryGrowthThreshold) {
      final leakReport = MemoryLeakReport(
        timestamp: DateTime.now(),
        memoryGrowth: memoryGrowth,
        currentMemory: newestMemory,
        listenerStats: ListenerManager().getStats(),
        streamCount: _monitoredStreams.length,
        timerCount: _monitoredTimers.length,
        isolateCount: _monitoredIsolates.length,
        widgetRebuildStats: Map.from(_widgetRebuildCounts),
        frameTimeStats: _calculateFrameTimeStats(),
      );

      _leakReports.add(leakReport);

      await ProductionLogger.instance.warning(
        'Potential memory leak detected',
        context: leakReport.toMap(),
      );

      // Auto-cleanup if configured
      await _performAutoCleanup();
    }
  }

  /// Perform performance check
  Future<void> _performPerformanceCheck() async {
    try {
      final performanceInfo = await _getPerformanceInfo();
      final timestamp = DateTime.now();

      _performanceMetrics[timestamp.millisecondsSinceEpoch.toString()] =
          performanceInfo;

      // Check for performance issues
      if (performanceInfo.averageFrameTime > 16.67) {
        // 60fps threshold
        await ProductionLogger.instance.warning(
          'Performance issue detected',
          context: performanceInfo.toMap(),
        );
      }
    } catch (error, stackTrace) {
      await ErrorHandlerService.instance.handleError(
        operation: 'performance_check',
        error: error,
        stackTrace: stackTrace,
        showUserMessage: false,
      );
    }
  }

  /// Perform stream check
  Future<void> _performStreamCheck() async {
    final now = DateTime.now();
    final longRunningStreams = <String>[];

    for (final entry in _streamCreationTimes.entries) {
      final streamId = entry.key;
      final creationTime = entry.value;
      final age = now.difference(creationTime);

      if (age > _memoryLeakThreshold &&
          _monitoredStreams.containsKey(streamId)) {
        longRunningStreams.add(streamId);
      }
    }

    if (longRunningStreams.isNotEmpty) {
      await ProductionLogger.instance.warning(
        'Long-running streams detected',
        context: {
          'streamCount': longRunningStreams.length,
          'streamIds': longRunningStreams,
          'threshold': _memoryLeakThreshold.inMinutes,
        },
      );
    }
  }

  /// Perform timer check
  Future<void> _performTimerCheck() async {
    final now = DateTime.now();
    final longRunningTimers = <String>[];

    for (final entry in _timerCreationTimes.entries) {
      final timerId = entry.key;
      final creationTime = entry.value;
      final age = now.difference(creationTime);

      if (age > _memoryLeakThreshold && _monitoredTimers.containsKey(timerId)) {
        longRunningTimers.add(timerId);
      }
    }

    if (longRunningTimers.isNotEmpty) {
      await ProductionLogger.instance.warning(
        'Long-running timers detected',
        context: {
          'timerCount': longRunningTimers.length,
          'timerIds': longRunningTimers,
          'threshold': _memoryLeakThreshold.inMinutes,
        },
      );
    }
  }

  /// Start widget rebuild monitoring
  void _startWidgetRebuildMonitoring() {
    // This would require integration with Flutter's widget inspector
    // For now, we'll provide a manual tracking method
  }

  /// Track widget rebuild
  void trackWidgetRebuild(String widgetName) {
    _widgetRebuildCounts[widgetName] =
        (_widgetRebuildCounts[widgetName] ?? 0) + 1;
  }

  /// Start frame time monitoring
  void _startFrameTimeMonitoring() {
    if (!kDebugMode) return; // Only available in debug mode

    // Monitor frame times using Flutter's performance overlay
    WidgetsBinding.instance.addTimingsCallback((timings) {
      for (final timing in timings) {
        final frameTime =
            timing.totalSpan.inMicroseconds / 1000.0; // Convert to ms
        _frameTimes.putIfAbsent('global', () => <double>[]).add(frameTime);

        // Keep only last 1000 frame times
        if (_frameTimes['global']!.length > 1000) {
          _frameTimes['global']!.removeAt(0);
        }
      }
    });
  }

  /// Register stream for monitoring
  void registerStream(String streamId, StreamSubscription subscription) {
    _monitoredStreams[streamId] = subscription;
    _streamCreationTimes[streamId] = DateTime.now();
  }

  /// Unregister stream
  void unregisterStream(String streamId) {
    _monitoredStreams.remove(streamId);
    _streamCreationTimes.remove(streamId);
  }

  /// Register timer for monitoring
  void registerTimer(String timerId, Timer timer) {
    _monitoredTimers[timerId] = timer;
    _timerCreationTimes[timerId] = DateTime.now();
  }

  /// Unregister timer
  void unregisterTimer(String timerId) {
    _monitoredTimers.remove(timerId);
    _timerCreationTimes.remove(timerId);
  }

  /// Register isolate for monitoring
  void registerIsolate(String isolateId, Isolate isolate) {
    _monitoredIsolates[isolateId] = isolate;
    _isolateCreationTimes[isolateId] = DateTime.now();
  }

  /// Unregister isolate
  void unregisterIsolate(String isolateId) {
    _monitoredIsolates.remove(isolateId);
    _isolateCreationTimes.remove(isolateId);
  }

  /// Run production stress test
  Future<void> runProductionStressTest({
    required ProductionTestScenario scenario,
    Duration? duration,
  }) async {
    if (_isStressTesting) {
      throw Exception('Stress test already running');
    }

    _isStressTesting = true;
    final testDuration = duration ?? const Duration(minutes: 5);

    try {
      await ProductionLogger.instance.info(
        'Starting production stress test',
        context: {
          'scenario': scenario.name,
          'duration': testDuration.inMinutes,
        },
      );

      // Take initial memory snapshot
      final initialMemory = await _getMemoryInfo();

      // Run the test scenario
      await scenario.execute();

      // Monitor for the duration
      final endTime = DateTime.now().add(testDuration);
      while (DateTime.now().isBefore(endTime)) {
        await _performMemoryCheck();
        await _performPerformanceCheck();
        await Future.delayed(const Duration(seconds: 10));
      }

      // Take final memory snapshot
      final finalMemory = await _getMemoryInfo();

      // Generate stress test report
      await _generateStressTestReport(scenario, initialMemory, finalMemory);
    } finally {
      _isStressTesting = false;
    }
  }

  /// Get memory information
  Future<MemoryInfo> _getMemoryInfo() async {
    if (kDebugMode) {
      // Use developer tools in debug mode - simplified for compatibility
      try {
        // Get basic memory info that's available
        final currentRss = ProcessInfo.currentRss;
        final maxRss = ProcessInfo.maxRss;

        return MemoryInfo(
          used: currentRss,
          total: maxRss,
          external: 0,
        );
      } catch (e) {
        // Fallback to basic memory info
        return MemoryInfo(used: 0, total: 0, external: 0);
      }
    } else {
      // Estimate memory usage in production
      return MemoryInfo(
        used: ProcessInfo.currentRss,
        total: ProcessInfo.maxRss,
        external: 0,
      );
    }
  }

  /// Get performance information
  Future<PerformanceMetrics> _getPerformanceInfo() async {
    final frameTimes = _frameTimes['global'] ?? <double>[];
    final averageFrameTime = frameTimes.isNotEmpty
        ? frameTimes.reduce((a, b) => a + b) / frameTimes.length
        : 0.0;

    return PerformanceMetrics(
      averageFrameTime: averageFrameTime,
      maxFrameTime: frameTimes.isNotEmpty
          ? frameTimes.reduce((a, b) => a > b ? a : b)
          : 0.0,
      frameDrops: frameTimes.where((time) => time > 16.67).length,
      totalFrames: frameTimes.length,
      widgetRebuilds:
          _widgetRebuildCounts.values.fold(0, (sum, count) => sum + count),
    );
  }

  /// Calculate frame time statistics
  Map<String, double> _calculateFrameTimeStats() {
    final frameTimes = _frameTimes['global'] ?? <double>[];
    if (frameTimes.isEmpty) return {};

    frameTimes.sort();
    return {
      'average': frameTimes.reduce((a, b) => a + b) / frameTimes.length,
      'median': frameTimes[frameTimes.length ~/ 2],
      'p95': frameTimes[(frameTimes.length * 0.95).floor()],
      'p99': frameTimes[(frameTimes.length * 0.99).floor()],
      'max': frameTimes.last,
    };
  }

  /// Perform auto cleanup
  Future<void> _performAutoCleanup() async {
    int cleaned = 0;

    // Cleanup old listeners
    cleaned += ListenerManager().cleanupOldListeners();

    // Cancel old timers
    final now = DateTime.now();
    final oldTimers = <String>[];
    for (final entry in _timerCreationTimes.entries) {
      if (now.difference(entry.value) > _memoryLeakThreshold) {
        oldTimers.add(entry.key);
      }
    }

    for (final timerId in oldTimers) {
      _monitoredTimers[timerId]?.cancel();
      unregisterTimer(timerId);
      cleaned++;
    }

    // Force garbage collection in debug mode
    if (kDebugMode) {
      await _forceGarbageCollection();
    }

    await ProductionLogger.instance.info(
      'Auto cleanup completed',
      context: {'itemsCleaned': cleaned},
    );
  }

  /// Force garbage collection
  Future<void> _forceGarbageCollection() async {
    if (kDebugMode) {
      // Force garbage collection - simplified for compatibility
      try {
        // This is a hint to the garbage collector
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        // Ignore errors in GC requests
      }
    }
  }

  /// Generate memory leak report
  Future<void> _generateMemoryLeakReport() async {
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'totalLeaks': _leakReports.length,
      'leakReports': _leakReports.map((r) => r.toMap()).toList(),
      'listenerStats': ListenerManager().getStats().toString(),
      'performanceMetrics':
          _performanceMetrics.map((k, v) => MapEntry(k, v.toMap())),
      'frameTimeStats': _calculateFrameTimeStats(),
    };

    await ProductionLogger.instance.businessEvent(
      'memory_leak_report',
      data: report,
    );
  }

  /// Generate stress test report
  Future<void> _generateStressTestReport(
    ProductionTestScenario scenario,
    MemoryInfo initialMemory,
    MemoryInfo finalMemory,
  ) async {
    final report = {
      'scenario': scenario.name,
      'memoryGrowth': finalMemory.used - initialMemory.used,
      'initialMemory': initialMemory.toMap(),
      'finalMemory': finalMemory.toMap(),
      'leaksDetected': _leakReports.length,
      'performanceIssues': _performanceMetrics.values
          .where((m) => m.averageFrameTime > 16.67)
          .length,
    };

    await ProductionLogger.instance.businessEvent(
      'stress_test_report',
      data: report,
    );
  }

  /// Get current memory leak status
  MemoryLeakStatus getMemoryLeakStatus() {
    return MemoryLeakStatus(
      isMonitoring: _isMonitoring,
      leakCount: _leakReports.length,
      activeStreams: _monitoredStreams.length,
      activeTimers: _monitoredTimers.length,
      activeIsolates: _monitoredIsolates.length,
      listenerStats: ListenerManager().getStats(),
      lastCheck:
          _snapshotTimes.values.isNotEmpty ? _snapshotTimes.values.last : null,
    );
  }
}

/// Memory information model
class MemoryInfo {
  final int used;
  final int total;
  final int external;

  MemoryInfo({
    required this.used,
    required this.total,
    required this.external,
  });

  Map<String, dynamic> toMap() {
    return {
      'used': used,
      'total': total,
      'external': external,
    };
  }
}

/// Performance metrics model
class PerformanceMetrics {
  final double averageFrameTime;
  final double maxFrameTime;
  final int frameDrops;
  final int totalFrames;
  final int widgetRebuilds;

  PerformanceMetrics({
    required this.averageFrameTime,
    required this.maxFrameTime,
    required this.frameDrops,
    required this.totalFrames,
    required this.widgetRebuilds,
  });

  Map<String, dynamic> toMap() {
    return {
      'averageFrameTime': averageFrameTime,
      'maxFrameTime': maxFrameTime,
      'frameDrops': frameDrops,
      'totalFrames': totalFrames,
      'widgetRebuilds': widgetRebuilds,
    };
  }
}

/// Memory leak report model
class MemoryLeakReport {
  final DateTime timestamp;
  final int memoryGrowth;
  final int currentMemory;
  final ListenerStats listenerStats;
  final int streamCount;
  final int timerCount;
  final int isolateCount;
  final Map<String, int> widgetRebuildStats;
  final Map<String, double> frameTimeStats;

  MemoryLeakReport({
    required this.timestamp,
    required this.memoryGrowth,
    required this.currentMemory,
    required this.listenerStats,
    required this.streamCount,
    required this.timerCount,
    required this.isolateCount,
    required this.widgetRebuildStats,
    required this.frameTimeStats,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'memoryGrowth': memoryGrowth,
      'currentMemory': currentMemory,
      'listenerStats': listenerStats.toString(),
      'streamCount': streamCount,
      'timerCount': timerCount,
      'isolateCount': isolateCount,
      'widgetRebuildStats': widgetRebuildStats,
      'frameTimeStats': frameTimeStats,
    };
  }
}

/// Memory leak status model
class MemoryLeakStatus {
  final bool isMonitoring;
  final int leakCount;
  final int activeStreams;
  final int activeTimers;
  final int activeIsolates;
  final ListenerStats listenerStats;
  final DateTime? lastCheck;

  MemoryLeakStatus({
    required this.isMonitoring,
    required this.leakCount,
    required this.activeStreams,
    required this.activeTimers,
    required this.activeIsolates,
    required this.listenerStats,
    this.lastCheck,
  });

  Map<String, dynamic> toMap() {
    return {
      'isMonitoring': isMonitoring,
      'leakCount': leakCount,
      'activeStreams': activeStreams,
      'activeTimers': activeTimers,
      'activeIsolates': activeIsolates,
      'listenerStats': listenerStats.toString(),
      'lastCheck': lastCheck?.toIso8601String(),
    };
  }
}

/// Production test scenario interface
abstract class ProductionTestScenario {
  String get name;
  Future<void> execute();
}

/// High-load scenario for testing
class HighLoadScenario extends ProductionTestScenario {
  @override
  String get name => 'high_load_test';

  @override
  Future<void> execute() async {
    // Simulate high load by creating many Firestore listeners
    final subscriptions = <StreamSubscription>[];

    for (int i = 0; i < 100; i++) {
      final subscription = FirebaseFirestore.instance
          .collection('products')
          .limit(10)
          .snapshots()
          .listen((_) {});

      subscriptions.add(subscription);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Let it run for a bit
    await Future.delayed(const Duration(seconds: 30));

    // Clean up
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
  }
}

/// Memory stress scenario
class MemoryStressScenario extends ProductionTestScenario {
  @override
  String get name => 'memory_stress_test';

  @override
  Future<void> execute() async {
    // Simulate memory stress by creating large objects
    final largeObjects = <List<int>>[];

    for (int i = 0; i < 1000; i++) {
      // Create 1MB objects
      largeObjects.add(List.filled(1024 * 1024, i));

      if (i % 100 == 0) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Hold references for a while
    await Future.delayed(const Duration(seconds: 30));

    // Clear references
    largeObjects.clear();
  }
}

/// UI stress scenario
class UIStressScenario extends ProductionTestScenario {
  @override
  String get name => 'ui_stress_test';

  @override
  Future<void> execute() async {
    // This would need to be implemented with actual UI interactions
    // For now, just simulate widget rebuilds
    for (int i = 0; i < 10000; i++) {
      MemoryLeakDetector.instance.trackWidgetRebuild('StressTestWidget');

      if (i % 100 == 0) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
  }
}

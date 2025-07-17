import 'dart:async';
import 'package:flutter/foundation.dart';
import 'memory_leak_detector.dart';
import 'production_performance_tester.dart';
import 'production_logger.dart';
import 'error_handler_service.dart';

/// Simple performance test runner for production scenarios
class PerformanceTestRunner {
  static final PerformanceTestRunner _instance =
      PerformanceTestRunner._internal();
  static PerformanceTestRunner get instance => _instance;
  PerformanceTestRunner._internal();

  bool _isRunning = false;
  Timer? _periodicTestTimer;

  /// Initialize the performance test runner
  Future<void> initialize() async {
    await MemoryLeakDetector.instance.initialize();
    await ProductionLogger.instance.initialize();

    await ProductionLogger.instance.info('PerformanceTestRunner initialized');
  }

  /// Start periodic performance monitoring
  Future<void> startPeriodicMonitoring({
    Duration interval = const Duration(hours: 1),
    Duration testDuration = const Duration(minutes: 5),
  }) async {
    if (_isRunning) {
      await ProductionLogger.instance
          .warning('Performance monitoring already running');
      return;
    }

    _isRunning = true;

    // Start memory leak monitoring
    await MemoryLeakDetector.instance.startMonitoring();

    // Start periodic tests
    _periodicTestTimer = Timer.periodic(interval, (timer) async {
      await _runPeriodicTest(testDuration);
    });

    await ProductionLogger.instance.info(
      'Started periodic performance monitoring',
      context: {
        'interval': interval.inMinutes,
        'testDuration': testDuration.inMinutes,
      },
    );
  }

  /// Stop periodic performance monitoring
  Future<void> stopPeriodicMonitoring() async {
    if (!_isRunning) return;

    _isRunning = false;
    _periodicTestTimer?.cancel();
    _periodicTestTimer = null;

    await MemoryLeakDetector.instance.stopMonitoring();

    await ProductionLogger.instance
        .info('Stopped periodic performance monitoring');
  }

  /// Run a quick performance check
  Future<QuickPerformanceReport> runQuickPerformanceCheck() async {
    final startTime = DateTime.now();

    try {
      await ProductionLogger.instance.info('Starting quick performance check');

      // Start memory monitoring
      await MemoryLeakDetector.instance.startMonitoring();

      // Run a subset of performance tests
      final report =
          await ProductionPerformanceTester.instance.runProductionTests(
        testTypes: [
          ProductionTestType.networkLatency,
          ProductionTestType.databaseLoad,
          ProductionTestType.cacheEfficiency,
        ],
        testDuration: const Duration(minutes: 1),
        enableMemoryMonitoring: false, // Already started
      );

      // Get memory status
      final memoryStatus = MemoryLeakDetector.instance.getMemoryLeakStatus();

      // Stop memory monitoring
      await MemoryLeakDetector.instance.stopMonitoring();

      final quickReport = QuickPerformanceReport(
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        networkLatency: report
                .testResults['networkLatency']?.metrics['averageLatency']
                ?.toDouble() ??
            0.0,
        databaseOperations: report
                .testResults['databaseLoad']?.metrics['readOperations']
                ?.toInt() ??
            0,
        cacheHitRatio: report
                .testResults['cacheEfficiency']?.metrics['cacheHitRatio']
                ?.toDouble() ??
            0.0,
        memoryLeaks: memoryStatus.leakCount,
        activeStreams: memoryStatus.activeStreams,
        overallHealth: _calculateOverallHealth(report, memoryStatus),
      );

      await ProductionLogger.instance.info(
        'Quick performance check completed',
        context: quickReport.toMap(),
      );

      return quickReport;
    } catch (error, stackTrace) {
      await ErrorHandlerService.instance.handleError(
        operation: 'quick_performance_check',
        error: error,
        stackTrace: stackTrace,
        showUserMessage: false,
      );

      // Return error report
      return QuickPerformanceReport(
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        networkLatency: -1,
        databaseOperations: -1,
        cacheHitRatio: -1,
        memoryLeaks: -1,
        activeStreams: -1,
        overallHealth: PerformanceHealth.error,
        error: error.toString(),
      );
    }
  }

  /// Run memory leak detection
  Future<MemoryLeakReport> runMemoryLeakDetection({
    Duration duration = const Duration(minutes: 5),
  }) async {
    final startTime = DateTime.now();

    try {
      await ProductionLogger.instance.info('Starting memory leak detection');

      // Start monitoring
      await MemoryLeakDetector.instance.startMonitoring();

      // Wait for the duration
      await Future.delayed(duration);

      // Get status
      final status = MemoryLeakDetector.instance.getMemoryLeakStatus();

      // Stop monitoring
      await MemoryLeakDetector.instance.stopMonitoring();

      final report = MemoryLeakReport(
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        leakCount: status.leakCount,
        activeStreams: status.activeStreams,
        activeTimers: status.activeTimers,
        listenerStats: status.listenerStats.toString(),
        recommendation: _getMemoryRecommendation(status),
      );

      await ProductionLogger.instance.info(
        'Memory leak detection completed',
        context: report.toMap(),
      );

      return report;
    } catch (error, stackTrace) {
      await ErrorHandlerService.instance.handleError(
        operation: 'memory_leak_detection',
        error: error,
        stackTrace: stackTrace,
        showUserMessage: false,
      );

      return MemoryLeakReport(
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        leakCount: -1,
        activeStreams: -1,
        activeTimers: -1,
        listenerStats: 'Error occurred',
        recommendation: 'Unable to analyze due to error: ${error.toString()}',
        error: error.toString(),
      );
    }
  }

  /// Run stress test
  Future<StressTestReport> runStressTest({
    StressTestType testType = StressTestType.memory,
    Duration duration = const Duration(minutes: 3),
  }) async {
    final startTime = DateTime.now();

    try {
      await ProductionLogger.instance.info(
        'Starting stress test',
        context: {'testType': testType.name, 'duration': duration.inMinutes},
      );

      ProductionTestScenario scenario;
      switch (testType) {
        case StressTestType.memory:
          scenario = MemoryStressScenario();
          break;
        case StressTestType.highLoad:
          scenario = HighLoadScenario();
          break;
        case StressTestType.ui:
          scenario = UIStressScenario();
          break;
      }

      // Run the stress test
      await MemoryLeakDetector.instance.runProductionStressTest(
        scenario: scenario,
        duration: duration,
      );

      // Get final status
      final memoryStatus = MemoryLeakDetector.instance.getMemoryLeakStatus();

      final report = StressTestReport(
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        testType: testType,
        memoryLeaks: memoryStatus.leakCount,
        activeStreams: memoryStatus.activeStreams,
        success: memoryStatus.leakCount == 0,
        recommendation: _getStressTestRecommendation(testType, memoryStatus),
      );

      await ProductionLogger.instance.info(
        'Stress test completed',
        context: report.toMap(),
      );

      return report;
    } catch (error, stackTrace) {
      await ErrorHandlerService.instance.handleError(
        operation: 'stress_test',
        error: error,
        stackTrace: stackTrace,
        showUserMessage: false,
      );

      return StressTestReport(
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        testType: testType,
        memoryLeaks: -1,
        activeStreams: -1,
        success: false,
        recommendation: 'Stress test failed: ${error.toString()}',
        error: error.toString(),
      );
    }
  }

  /// Run periodic test
  Future<void> _runPeriodicTest(Duration testDuration) async {
    try {
      await ProductionLogger.instance.info('Running periodic performance test');

      // Run quick performance check
      final quickReport = await runQuickPerformanceCheck();

      // Log results
      await ProductionLogger.instance.businessEvent(
        'periodic_performance_test',
        data: quickReport.toMap(),
      );

      // Check if action is needed
      if (quickReport.overallHealth == PerformanceHealth.poor) {
        await ProductionLogger.instance.warning(
          'Poor performance detected in periodic test',
          context: quickReport.toMap(),
        );
      }
    } catch (error, stackTrace) {
      await ErrorHandlerService.instance.handleError(
        operation: 'periodic_performance_test',
        error: error,
        stackTrace: stackTrace,
        showUserMessage: false,
      );
    }
  }

  /// Calculate overall health
  PerformanceHealth _calculateOverallHealth(
    ProductionTestReport report,
    MemoryLeakStatus memoryStatus,
  ) {
    // Check for memory leaks
    if (memoryStatus.leakCount > 0) {
      return PerformanceHealth.poor;
    }

    // Check test results
    final failedTests =
        report.testResults.values.where((r) => !r.success).length;
    if (failedTests > 0) {
      return PerformanceHealth.fair;
    }

    // Check performance metrics
    final networkLatency = report
            .testResults['networkLatency']?.metrics['averageLatency']
            ?.toDouble() ??
        0.0;
    if (networkLatency > 1000) {
      // More than 1 second
      return PerformanceHealth.fair;
    }

    return PerformanceHealth.good;
  }

  /// Get memory recommendation
  String _getMemoryRecommendation(MemoryLeakStatus status) {
    if (status.leakCount > 0) {
      return 'Memory leaks detected. Review stream and timer disposal in your code.';
    }

    if (status.activeStreams > 100) {
      return 'High number of active streams. Consider implementing stream pooling.';
    }

    if (status.activeTimers > 50) {
      return 'High number of active timers. Review timer usage and disposal.';
    }

    return 'Memory usage looks healthy.';
  }

  /// Get stress test recommendation
  String _getStressTestRecommendation(
      StressTestType testType, MemoryLeakStatus status) {
    switch (testType) {
      case StressTestType.memory:
        if (status.leakCount > 0) {
          return 'Memory stress test revealed leaks. Implement proper disposal patterns.';
        }
        return 'Memory stress test passed. Memory management is working well.';

      case StressTestType.highLoad:
        if (status.activeStreams > 200) {
          return 'High load test shows excessive stream usage. Consider connection pooling.';
        }
        return 'High load test passed. System handles load well.';

      case StressTestType.ui:
        return 'UI stress test completed. Check frame times for performance issues.';
    }
  }

  /// Get current status
  Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'hasPeriodicTimer': _periodicTestTimer != null,
      'memoryDetectorStatus':
          MemoryLeakDetector.instance.getMemoryLeakStatus().toMap(),
      'performanceTesterStatus':
          ProductionPerformanceTester.instance.getTestStatus(),
    };
  }
}

/// Quick performance report
class QuickPerformanceReport {
  final DateTime timestamp;
  final Duration duration;
  final double networkLatency;
  final int databaseOperations;
  final double cacheHitRatio;
  final int memoryLeaks;
  final int activeStreams;
  final PerformanceHealth overallHealth;
  final String? error;

  QuickPerformanceReport({
    required this.timestamp,
    required this.duration,
    required this.networkLatency,
    required this.databaseOperations,
    required this.cacheHitRatio,
    required this.memoryLeaks,
    required this.activeStreams,
    required this.overallHealth,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'duration': duration.inMilliseconds,
      'networkLatency': networkLatency,
      'databaseOperations': databaseOperations,
      'cacheHitRatio': cacheHitRatio,
      'memoryLeaks': memoryLeaks,
      'activeStreams': activeStreams,
      'overallHealth': overallHealth.name,
      'error': error,
    };
  }
}

/// Memory leak report
class MemoryLeakReport {
  final DateTime timestamp;
  final Duration duration;
  final int leakCount;
  final int activeStreams;
  final int activeTimers;
  final String listenerStats;
  final String recommendation;
  final String? error;

  MemoryLeakReport({
    required this.timestamp,
    required this.duration,
    required this.leakCount,
    required this.activeStreams,
    required this.activeTimers,
    required this.listenerStats,
    required this.recommendation,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'duration': duration.inMilliseconds,
      'leakCount': leakCount,
      'activeStreams': activeStreams,
      'activeTimers': activeTimers,
      'listenerStats': listenerStats,
      'recommendation': recommendation,
      'error': error,
    };
  }
}

/// Stress test report
class StressTestReport {
  final DateTime timestamp;
  final Duration duration;
  final StressTestType testType;
  final int memoryLeaks;
  final int activeStreams;
  final bool success;
  final String recommendation;
  final String? error;

  StressTestReport({
    required this.timestamp,
    required this.duration,
    required this.testType,
    required this.memoryLeaks,
    required this.activeStreams,
    required this.success,
    required this.recommendation,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'duration': duration.inMilliseconds,
      'testType': testType.name,
      'memoryLeaks': memoryLeaks,
      'activeStreams': activeStreams,
      'success': success,
      'recommendation': recommendation,
      'error': error,
    };
  }
}

/// Performance health levels
enum PerformanceHealth {
  good,
  fair,
  poor,
  error,
}

/// Stress test types
enum StressTestType {
  memory,
  highLoad,
  ui,
}

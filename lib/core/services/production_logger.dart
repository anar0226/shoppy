import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_performance/firebase_performance.dart';
import '../config/environment_config.dart';

/// Production-ready logging service with comprehensive error tracking
class ProductionLogger {
  static final ProductionLogger _instance = ProductionLogger._internal();
  static ProductionLogger get instance => _instance;
  ProductionLogger._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Device and app info
  Map<String, dynamic>? _deviceInfo;
  Map<String, dynamic>? _appInfo;

  // Performance tracking
  final Map<String, Trace> _activeTraces = {};
  final Map<String, DateTime> _operationStartTimes = {};

  // Rate limiting for logs
  final Map<String, DateTime> _lastLogTime = {};
  static const Duration _logCooldown = Duration(seconds: 1);

  bool _isInitialized = false;

  /// Initialize the logger with device and app information
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get device information
      _deviceInfo = await _getDeviceInfo();
      _appInfo = await _getAppInfo();

      // Start periodic log flushing
      _startPeriodicFlush();

      _isInitialized = true;

      // Log initialization
      await info('ProductionLogger initialized', context: {
        'appVersion': _appInfo?['version'],
        'buildNumber': _appInfo?['buildNumber'],
        'deviceModel': _deviceInfo?['model'],
        'platform': Platform.operatingSystem,
      });
    } catch (e) {
      debugPrint('ProductionLogger initialization failed: $e');
    }
  }

  /// Log an error with comprehensive context
  Future<void> error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    LogLevel level = LogLevel.error,
    bool isFatal = false,
  }) async {
    final logEntry = LogEntry(
      level: level,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
      context: {
        ...?context,
        'isFatal': isFatal,
        'userId': _auth.currentUser?.uid,
        'timestamp': DateTime.now().toIso8601String(),
        ...?_deviceInfo,
        'appVersion': _appInfo?['version'],
        'buildNumber': _appInfo?['buildNumber'],
      },
      timestamp: DateTime.now(),
      userId: _auth.currentUser?.uid,
    );

    await _addLogEntry(logEntry);

    // For fatal errors, flush immediately
    if (isFatal) {
      await flushLogs();
    }

    // In debug mode, also print to console
    if (kDebugMode) {
      debugPrint('🚨 ERROR: $message');
      if (error != null) debugPrint('   Error: $error');
      if (stackTrace != null) debugPrint('   Stack: $stackTrace');
    }
  }

  /// Log informational message
  Future<void> info(
    String message, {
    Map<String, dynamic>? context,
  }) async {
    final logEntry = LogEntry(
      level: LogLevel.info,
      message: message,
      context: {
        ...?context,
        'userId': _auth.currentUser?.uid,
        'timestamp': DateTime.now().toIso8601String(),
      },
      timestamp: DateTime.now(),
      userId: _auth.currentUser?.uid,
    );

    await _addLogEntry(logEntry);

    if (kDebugMode) {
      debugPrint('ℹ️  INFO: $message');
    }
  }

  /// Log warning message
  Future<void> warning(
    String message, {
    Map<String, dynamic>? context,
  }) async {
    final logEntry = LogEntry(
      level: LogLevel.warning,
      message: message,
      context: {
        ...?context,
        'userId': _auth.currentUser?.uid,
        'timestamp': DateTime.now().toIso8601String(),
      },
      timestamp: DateTime.now(),
      userId: _auth.currentUser?.uid,
    );

    await _addLogEntry(logEntry);

    if (kDebugMode) {
      debugPrint('⚠️  WARNING: $message');
    }
  }

  /// Log debug message (only in debug mode)
  Future<void> debug(
    String message, {
    Map<String, dynamic>? context,
  }) async {
    if (!kDebugMode) return;

    final logEntry = LogEntry(
      level: LogLevel.debug,
      message: message,
      context: {
        ...?context,
        'userId': _auth.currentUser?.uid,
        'timestamp': DateTime.now().toIso8601String(),
      },
      timestamp: DateTime.now(),
      userId: _auth.currentUser?.uid,
    );

    await _addLogEntry(logEntry);
    debugPrint('🐛 DEBUG: $message');
  }

  /// Log performance metrics
  Future<void> performance(
    String operation, {
    required Duration duration,
    Map<String, dynamic>? metrics,
  }) async {
    final logEntry = LogEntry(
      level: LogLevel.performance,
      message: 'Performance: $operation',
      context: {
        'operation': operation,
        'duration_ms': duration.inMilliseconds,
        'duration_seconds': duration.inSeconds,
        ...?metrics,
        'userId': _auth.currentUser?.uid,
        'timestamp': DateTime.now().toIso8601String(),
      },
      timestamp: DateTime.now(),
      userId: _auth.currentUser?.uid,
    );

    await _addLogEntry(logEntry);

    if (kDebugMode) {
      debugPrint(
          '📊 PERFORMANCE: $operation took ${duration.inMilliseconds}ms');
    }
  }

  /// Start performance tracing for an operation
  void startTrace(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();

    // Firebase Performance Monitoring
    if (EnvironmentConfig.enablePerformanceMonitoring) {
      final trace = FirebasePerformance.instance.newTrace(operationName);
      trace.start();
      _activeTraces[operationName] = trace;
    }
  }

  /// Stop performance tracing and log results
  Future<void> stopTrace(
    String operationName, {
    Map<String, dynamic>? attributes,
  }) async {
    final startTime = _operationStartTimes.remove(operationName);
    if (startTime == null) return;

    final duration = DateTime.now().difference(startTime);

    // Stop Firebase trace
    final trace = _activeTraces.remove(operationName);
    if (trace != null) {
      attributes?.forEach((key, value) {
        trace.putAttribute(key, value.toString());
      });
      trace.stop();
    }

    // Log performance
    await performance(operationName, duration: duration, metrics: attributes);
  }

  /// Log user action for analytics
  Future<void> userAction(
    String action, {
    Map<String, dynamic>? parameters,
  }) async {
    final logEntry = LogEntry(
      level: LogLevel.analytics,
      message: 'User Action: $action',
      context: {
        'action': action,
        'parameters': parameters,
        'userId': _auth.currentUser?.uid,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionId': _getSessionId(),
      },
      timestamp: DateTime.now(),
      userId: _auth.currentUser?.uid,
    );

    await _addLogEntry(logEntry);

    if (kDebugMode) {
      debugPrint('👤 USER ACTION: $action');
    }
  }

  /// Log business event for monitoring
  Future<void> businessEvent(
    String event, {
    Map<String, dynamic>? data,
  }) async {
    final logEntry = LogEntry(
      level: LogLevel.business,
      message: 'Business Event: $event',
      context: {
        'event': event,
        'data': data,
        'userId': _auth.currentUser?.uid,
        'timestamp': DateTime.now().toIso8601String(),
      },
      timestamp: DateTime.now(),
      userId: _auth.currentUser?.uid,
    );

    await _addLogEntry(logEntry);

    if (kDebugMode) {
      debugPrint('💼 BUSINESS: $event');
    }
  }

  /// Log security event
  Future<void> securityEvent(
    String event, {
    Map<String, dynamic>? details,
    SecurityEventType type = SecurityEventType.info,
  }) async {
    final logEntry = LogEntry(
      level: LogLevel.security,
      message: 'Security Event: $event',
      context: {
        'event': event,
        'type': type.name,
        'details': details,
        'userId': _auth.currentUser?.uid,
        'timestamp': DateTime.now().toIso8601String(),
        'ipAddress': await _getClientIP(),
      },
      timestamp: DateTime.now(),
      userId: _auth.currentUser?.uid,
    );

    await _addLogEntry(logEntry);

    // Security events are always flushed immediately
    await flushLogs();

    if (kDebugMode) {
      debugPrint('🔒 SECURITY: $event (${type.name})');
    }
  }

  /// Add log entry to buffer with rate limiting
  Future<void> _addLogEntry(LogEntry entry) async {
    // Rate limiting check
    final logKey = '${entry.level.name}:${entry.message}';
    final lastLog = _lastLogTime[logKey];
    if (lastLog != null && DateTime.now().difference(lastLog) < _logCooldown) {
      return;
    }
    _lastLogTime[logKey] = DateTime.now();

    // Log directly to Firestore (no offline buffering)
    _logDirectlyToFirestore(entry);
  }

  /// Log directly to Firestore (no offline buffering)
  void _logDirectlyToFirestore(LogEntry entry) {
    Timer.run(() async {
      try {
        final docRef = _firestore.collection('app_logs').doc();
        await docRef.set(entry.toMap());
        if (kDebugMode) {
          debugPrint('📤 Logged to Firestore: ${entry.message}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Failed to log to Firestore: $e');
        }

        // Fallback: Store failed log entries for retry
        _storeFailedLogForRetry(entry, e);
      }
    });
  }

  /// Flush logs (deprecated - logs are now sent directly)
  Future<void> flushLogs() async {
    // No-op since we log directly now
    if (kDebugMode) {
      debugPrint('📤 Direct logging enabled - no buffering');
    }
  }

  /// Start periodic operations (simplified - no buffering needed)
  void _startPeriodicFlush() {
    // No periodic flushing needed since we log directly
  }

  /// Get device information (simplified version without external dependencies)
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      'numberOfProcessors': Platform.numberOfProcessors,
    };
  }

  /// Get app information (simplified version without external dependencies)
  Future<Map<String, dynamic>> _getAppInfo() async {
    return {
      'version': EnvironmentConfig.appVersion,
      'buildNumber': EnvironmentConfig.buildNumber,
      'isProduction': EnvironmentConfig.isProduction,
      'isDebug': kDebugMode,
    };
  }

  /// Get session ID (simplified)
  String _getSessionId() {
    return _auth.currentUser?.uid ??
        'anonymous_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get client IP (placeholder - implement based on your backend)
  Future<String?> _getClientIP() async {
    // This would typically be obtained from your backend
    return null;
  }

  /// Get current log statistics
  Map<String, dynamic> getLogStats() {
    return {
      'loggingMode': 'direct',
      'isInitialized': _isInitialized,
      'activeTraces': _activeTraces.length,
    };
  }

  /// Clear operations (simplified - no buffer to clear)
  void clearBuffer() {
    // No buffer to clear since we log directly
  }

  /// Store failed log entries for retry (fallback mechanism)
  void _storeFailedLogForRetry(LogEntry entry, dynamic error) {
    // In production, you might want to store these in local storage
    // For now, we'll just log to debug console
    if (kDebugMode) {
      debugPrint('🔄 Storing failed log for retry: ${entry.message}');
      debugPrint('   Error: $error');
    }

    // Could implement local storage retry mechanism here
    // For example: SharedPreferences, SQLite, etc.
  }
}

/// Log entry model
class LogEntry {
  final LogLevel level;
  final String message;
  final String? error;
  final String? stackTrace;
  final Map<String, dynamic>? context;
  final DateTime timestamp;
  final String? userId;

  LogEntry({
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    this.context,
    required this.timestamp,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'level': level.name,
      'message': message,
      'error': error,
      'stackTrace': stackTrace,
      'context': context,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': FieldValue.serverTimestamp(),
      'userId': userId,
    };
  }
}

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
  performance,
  analytics,
  business,
  security,
}

/// Security event types
enum SecurityEventType {
  info,
  warning,
  threat,
  attack,
  breach,
}

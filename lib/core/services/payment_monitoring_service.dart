import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'qpay_service.dart';
import '../../features/notifications/notification_service.dart';

/// Payment Monitoring Configuration
class PaymentMonitoringConfig {
  final Duration monitoringInterval;
  final Duration healthCheckInterval;
  final bool enableRealTimeMonitoring;
  final bool enableAlerts;
  final bool enablePerformanceTracking;
  final int maxConcurrentMonitors;
  final Duration alertCooldown;
  final double successRateThreshold;
  final Duration responseTimeThreshold;

  const PaymentMonitoringConfig({
    this.monitoringInterval = const Duration(seconds: 30),
    this.healthCheckInterval = const Duration(minutes: 5),
    this.enableRealTimeMonitoring = true,
    this.enableAlerts = true,
    this.enablePerformanceTracking = true,
    this.maxConcurrentMonitors = 100,
    this.alertCooldown = const Duration(minutes: 10),
    this.successRateThreshold = 95.0,
    this.responseTimeThreshold = const Duration(seconds: 5),
  });
}

/// Payment Health Status
enum PaymentHealthStatus {
  healthy,
  warning,
  critical,
}

/// Payment Event Type
enum PaymentEventType {
  created,
  pending,
  processing,
  completed,
  failed,
  timeout,
  cancelled,
  refunded,
  disputed,
}

/// Payment Alert Type
enum PaymentAlertType {
  highFailureRate,
  slowResponseTime,
  apiDown,
  reconciliationFailure,
  suspiciousActivity,
  volumeSpike,
  systemError,
}

/// Payment Alert Severity
enum PaymentAlertSeverity {
  info,
  warning,
  error,
  critical,
}

/// Payment Event
class PaymentEvent {
  final String id;
  final String paymentId;
  final String orderId;
  final PaymentEventType type;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final String? userId;
  final String? storeId;
  final double? amount;
  final String? currency;
  final String? method;
  final String? status;
  final Duration? processingTime;
  final Map<String, dynamic>? metadata;

  const PaymentEvent({
    required this.id,
    required this.paymentId,
    required this.orderId,
    required this.type,
    required this.timestamp,
    required this.data,
    this.userId,
    this.storeId,
    this.amount,
    this.currency,
    this.method,
    this.status,
    this.processingTime,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paymentId': paymentId,
      'orderId': orderId,
      'type': type.toString(),
      'timestamp': Timestamp.fromDate(timestamp),
      'data': data,
      'userId': userId,
      'storeId': storeId,
      'amount': amount,
      'currency': currency,
      'method': method,
      'status': status,
      'processingTimeMs': processingTime?.inMilliseconds,
      'metadata': metadata,
    };
  }
}

/// Payment Alert
class PaymentAlert {
  final String id;
  final PaymentAlertType type;
  final PaymentAlertSeverity severity;
  final String title;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final bool acknowledged;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final String? resolution;
  final DateTime? resolvedAt;

  const PaymentAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.data,
    this.acknowledged = false,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.resolution,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'severity': severity.toString(),
      'title': title,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'data': data,
      'acknowledged': acknowledged,
      'acknowledgedBy': acknowledgedBy,
      'acknowledgedAt':
          acknowledgedAt != null ? Timestamp.fromDate(acknowledgedAt!) : null,
      'resolution': resolution,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }
}

/// Payment Health Report
class PaymentHealthReport {
  final DateTime timestamp;
  final PaymentHealthStatus status;
  final double successRate;
  final Duration averageResponseTime;
  final int totalPayments;
  final int successfulPayments;
  final int failedPayments;
  final int pendingPayments;
  final Map<String, dynamic> metrics;
  final List<PaymentAlert> activeAlerts;

  const PaymentHealthReport({
    required this.timestamp,
    required this.status,
    required this.successRate,
    required this.averageResponseTime,
    required this.totalPayments,
    required this.successfulPayments,
    required this.failedPayments,
    required this.pendingPayments,
    required this.metrics,
    required this.activeAlerts,
  });

  bool get isHealthy => status == PaymentHealthStatus.healthy;
  bool get hasWarnings =>
      activeAlerts.any((a) => a.severity == PaymentAlertSeverity.warning);
  bool get hasCriticalAlerts =>
      activeAlerts.any((a) => a.severity == PaymentAlertSeverity.critical);
}

/// Payment Performance Metrics
class PaymentPerformanceMetrics {
  final DateTime timestamp;
  final Duration monitoringPeriod;
  final int totalTransactions;
  final int successfulTransactions;
  final int failedTransactions;
  final double successRate;
  final double failureRate;
  final Duration averageProcessingTime;
  final Duration p95ProcessingTime;
  final Duration p99ProcessingTime;
  final double totalVolume;
  final double averageTransactionValue;
  final Map<String, int> errorBreakdown;
  final Map<String, int> methodBreakdown;
  final Map<String, double> performanceByMethod;

  const PaymentPerformanceMetrics({
    required this.timestamp,
    required this.monitoringPeriod,
    required this.totalTransactions,
    required this.successfulTransactions,
    required this.failedTransactions,
    required this.successRate,
    required this.failureRate,
    required this.averageProcessingTime,
    required this.p95ProcessingTime,
    required this.p99ProcessingTime,
    required this.totalVolume,
    required this.averageTransactionValue,
    required this.errorBreakdown,
    required this.methodBreakdown,
    required this.performanceByMethod,
  });
}

/// Payment Monitoring Service
class PaymentMonitoringService {
  static final PaymentMonitoringService _instance =
      PaymentMonitoringService._internal();
  factory PaymentMonitoringService() => _instance;
  PaymentMonitoringService._internal();

  final QPayService _qpayService = QPayService();
  final NotificationService _notificationService = NotificationService();

  PaymentMonitoringConfig _config = const PaymentMonitoringConfig();
  Timer? _monitoringTimer;
  Timer? _healthCheckTimer;

  final Map<String, StreamSubscription> _activeMonitors = {};
  final Map<String, DateTime> _paymentStartTimes = {};
  final Map<String, PaymentAlert> _activeAlerts = {};
  final Map<String, DateTime> _lastAlertTimes = {};

  final StreamController<PaymentEvent> _eventController =
      StreamController.broadcast();
  final StreamController<PaymentAlert> _alertController =
      StreamController.broadcast();
  final StreamController<PaymentHealthReport> _healthController =
      StreamController.broadcast();
  final StreamController<PaymentPerformanceMetrics> _performanceController =
      StreamController.broadcast();

  bool _isMonitoring = false;
  PaymentHealthStatus _currentHealthStatus = PaymentHealthStatus.healthy;

  /// Initialize the payment monitoring service
  Future<void> initialize({PaymentMonitoringConfig? config}) async {
    _config = config ?? const PaymentMonitoringConfig();

    log('PaymentMonitoringService: Initialized with config: '
        'interval=${_config.monitoringInterval.inSeconds}s, '
        'healthCheck=${_config.healthCheckInterval.inMinutes}min, '
        'realTime=${_config.enableRealTimeMonitoring}');

    if (_config.enableRealTimeMonitoring) {
      await _startRealTimeMonitoring();
    }

    // Start health checks
    _startHealthChecks();

    // Resume monitoring for existing payments
    await _resumeExistingMonitors();
  }

  /// Get payment events stream
  Stream<PaymentEvent> get paymentEvents => _eventController.stream;

  /// Get payment alerts stream
  Stream<PaymentAlert> get paymentAlerts => _alertController.stream;

  /// Get payment health reports stream
  Stream<PaymentHealthReport> get healthReports => _healthController.stream;

  /// Get payment performance metrics stream
  Stream<PaymentPerformanceMetrics> get performanceMetrics =>
      _performanceController.stream;

  /// Start monitoring a payment
  Future<void> startPaymentMonitoring({
    required String paymentId,
    required String orderId,
    required String qpayInvoiceId,
    required double amount,
    required String currency,
    required String method,
    required String userId,
    String? storeId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (_activeMonitors.length >= _config.maxConcurrentMonitors) {
        log('PaymentMonitoringService: Maximum concurrent monitors reached');
        return;
      }

      log('PaymentMonitoringService: Starting monitoring for payment $paymentId');

      // Record payment start time
      _paymentStartTimes[paymentId] = DateTime.now();

      // Emit creation event
      _emitPaymentEvent(PaymentEvent(
        id: 'event_${DateTime.now().millisecondsSinceEpoch}',
        paymentId: paymentId,
        orderId: orderId,
        type: PaymentEventType.created,
        timestamp: DateTime.now(),
        data: {
          'qpayInvoiceId': qpayInvoiceId,
          'amount': amount,
          'currency': currency,
          'method': method,
          'userId': userId,
          'storeId': storeId,
        },
        userId: userId,
        storeId: storeId,
        amount: amount,
        currency: currency,
        method: method,
        status: 'CREATED',
        metadata: metadata,
      ));

      // Create monitoring stream subscription
      final monitoringSubscription = Stream.periodic(_config.monitoringInterval)
          .asyncMap((_) => _monitorPaymentStatus(paymentId, qpayInvoiceId))
          .listen(
        (event) {
          if (event != null) {
            _handlePaymentStatusUpdate(event);
          }
        },
        onError: (error) {
          log('PaymentMonitoringService: Error monitoring payment $paymentId: $error');
          _handleMonitoringError(paymentId, error);
        },
      );

      _activeMonitors[paymentId] = monitoringSubscription;

      // Store monitoring record
      await _storeMonitoringRecord(paymentId, orderId, qpayInvoiceId, amount,
          currency, method, userId, storeId, metadata);
    } catch (e) {
      log('PaymentMonitoringService: Error starting payment monitoring: $e');
      throw Exception('Failed to start payment monitoring: $e');
    }
  }

  /// Stop monitoring a payment
  Future<void> stopPaymentMonitoring(String paymentId) async {
    try {
      log('PaymentMonitoringService: Stopping monitoring for payment $paymentId');

      // Cancel monitoring subscription
      _activeMonitors[paymentId]?.cancel();
      _activeMonitors.remove(paymentId);

      // Clean up tracking data
      _paymentStartTimes.remove(paymentId);

      // Update monitoring record
      await _updateMonitoringRecord(paymentId, {
        'monitoringStoppedAt': FieldValue.serverTimestamp(),
        'status': 'STOPPED',
      });
    } catch (e) {
      log('PaymentMonitoringService: Error stopping payment monitoring: $e');
    }
  }

  /// Monitor payment status
  Future<PaymentEvent?> _monitorPaymentStatus(
      String paymentId, String qpayInvoiceId) async {
    try {
      final startTime = DateTime.now();
      final paymentStatus =
          await _qpayService.checkPaymentStatus(qpayInvoiceId);
      final responseTime = DateTime.now().difference(startTime);

      if (paymentStatus.success) {
        final status = paymentStatus.status ?? 'UNKNOWN';
        final previousStatus = await _getLastPaymentStatus(paymentId);

        // Check if status has changed
        if (status != previousStatus) {
          final processingTime = _paymentStartTimes[paymentId] != null
              ? DateTime.now().difference(_paymentStartTimes[paymentId]!)
              : null;

          final eventType = _mapStatusToEventType(status);

          final event = PaymentEvent(
            id: 'event_${DateTime.now().millisecondsSinceEpoch}',
            paymentId: paymentId,
            orderId: await _getOrderIdForPayment(paymentId),
            type: eventType,
            timestamp: DateTime.now(),
            data: {
              'qpayInvoiceId': qpayInvoiceId,
              'previousStatus': previousStatus,
              'newStatus': status,
              'responseTime': responseTime.inMilliseconds,
              'paidAmount': paymentStatus.paidAmount,
              'paidDate': paymentStatus.paidDate?.toIso8601String(),
              'paymentMethod': paymentStatus.paymentMethod,
              'currency': paymentStatus.currency,
            },
            amount: paymentStatus.paidAmount,
            currency: paymentStatus.currency,
            method: paymentStatus.paymentMethod,
            status: status,
            processingTime: processingTime,
          );

          // Update last status
          await _updateLastPaymentStatus(paymentId, status);

          // Handle final states
          if (_isFinalState(status)) {
            await stopPaymentMonitoring(paymentId);
          }

          return event;
        }
      } else {
        // Payment status check failed
        await _handlePaymentStatusError(
            paymentId, paymentStatus.error ?? 'Unknown error');
      }

      return null;
    } catch (e) {
      log('PaymentMonitoringService: Error monitoring payment status: $e');
      return null;
    }
  }

  /// Handle payment status update
  void _handlePaymentStatusUpdate(PaymentEvent event) {
    // Emit event
    _emitPaymentEvent(event);

    // Check for alerts
    _checkForAlerts(event);

    // Update performance metrics
    if (_config.enablePerformanceTracking) {
      _updatePerformanceMetrics(event);
    }
  }

  /// Handle monitoring error
  void _handleMonitoringError(String paymentId, dynamic error) {
    // Emit error event
    _emitPaymentEvent(PaymentEvent(
      id: 'error_${DateTime.now().millisecondsSinceEpoch}',
      paymentId: paymentId,
      orderId: '',
      type: PaymentEventType.failed,
      timestamp: DateTime.now(),
      data: {
        'error': error.toString(),
        'errorType': 'MONITORING_ERROR',
      },
      status: 'ERROR',
    ));

    // Create alert
    _createAlert(
      type: PaymentAlertType.systemError,
      severity: PaymentAlertSeverity.error,
      title: 'Payment Monitoring Error',
      message: 'Error monitoring payment $paymentId: $error',
      data: {
        'paymentId': paymentId,
        'error': error.toString(),
      },
    );
  }

  /// Check for alerts
  void _checkForAlerts(PaymentEvent event) {
    if (!_config.enableAlerts) return;

    // Check for high failure rate
    _checkFailureRateAlert();

    // Check for slow response times
    _checkResponseTimeAlert(event);

    // Check for suspicious activity
    _checkSuspiciousActivity(event);
  }

  /// Check failure rate alert
  void _checkFailureRateAlert() {
    // Get recent payment statistics
    _getRecentPaymentStats().then((stats) {
      if (stats['successRate'] < _config.successRateThreshold) {
        _createAlert(
          type: PaymentAlertType.highFailureRate,
          severity: PaymentAlertSeverity.critical,
          title: 'High Payment Failure Rate',
          message:
              'Payment success rate is ${stats['successRate'].toStringAsFixed(1)}%, below threshold of ${_config.successRateThreshold}%',
          data: stats,
        );
      }
    });
  }

  /// Check response time alert
  void _checkResponseTimeAlert(PaymentEvent event) {
    if (event.processingTime != null &&
        event.processingTime! > _config.responseTimeThreshold) {
      _createAlert(
        type: PaymentAlertType.slowResponseTime,
        severity: PaymentAlertSeverity.warning,
        title: 'Slow Payment Response Time',
        message:
            'Payment ${event.paymentId} took ${event.processingTime!.inSeconds} seconds to process',
        data: {
          'paymentId': event.paymentId,
          'processingTime': event.processingTime!.inMilliseconds,
          'threshold': _config.responseTimeThreshold.inMilliseconds,
        },
      );
    }
  }

  /// Check suspicious activity
  void _checkSuspiciousActivity(PaymentEvent event) {
    // Check for rapid payment attempts from same user
    if (event.userId != null) {
      _getRecentPaymentsByUser(event.userId!).then((recentPayments) {
        if (recentPayments.length > 10) {
          _createAlert(
            type: PaymentAlertType.suspiciousActivity,
            severity: PaymentAlertSeverity.warning,
            title: 'Suspicious Payment Activity',
            message:
                'User ${event.userId} has made ${recentPayments.length} payment attempts in the last hour',
            data: {
              'userId': event.userId,
              'recentPayments': recentPayments.length,
              'timeWindow': '1 hour',
            },
          );
        }
      });
    }
  }

  /// Create alert
  void _createAlert({
    required PaymentAlertType type,
    required PaymentAlertSeverity severity,
    required String title,
    required String message,
    required Map<String, dynamic> data,
  }) {
    final alertId = 'alert_${DateTime.now().millisecondsSinceEpoch}';
    final typeString = type.toString();

    // Check alert cooldown
    if (_lastAlertTimes.containsKey(typeString)) {
      final lastAlert = _lastAlertTimes[typeString]!;
      if (DateTime.now().difference(lastAlert) < _config.alertCooldown) {
        return; // Skip alert due to cooldown
      }
    }

    final alert = PaymentAlert(
      id: alertId,
      type: type,
      severity: severity,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      data: data,
    );

    // Store alert
    _storeAlert(alert);

    // Add to active alerts
    _activeAlerts[alertId] = alert;

    // Update last alert time
    _lastAlertTimes[typeString] = DateTime.now();

    // Emit alert
    _alertController.add(alert);

    // Send notification for critical alerts
    if (severity == PaymentAlertSeverity.critical) {
      _sendCriticalAlertNotification(alert);
    }
  }

  /// Start real-time monitoring
  Future<void> _startRealTimeMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(_config.monitoringInterval, (timer) {
      _performSystemHealthCheck();
    });

    log('PaymentMonitoringService: Real-time monitoring started');
  }

  /// Start health checks
  void _startHealthChecks() {
    _healthCheckTimer = Timer.periodic(_config.healthCheckInterval, (timer) {
      _performHealthCheck();
    });
  }

  /// Perform system health check
  void _performSystemHealthCheck() {
    // Check QPay API health
    _qpayService.debugQPayConnection().then((debug) {
      final isHealthy = debug['authSuccess'] == true;
      if (!isHealthy) {
        _createAlert(
          type: PaymentAlertType.apiDown,
          severity: PaymentAlertSeverity.critical,
          title: 'QPay API Down',
          message: 'QPay API is not responding or authentication failed',
          data: debug,
        );
      }
    });

    // Check active monitors
    final activeMonitorCount = _activeMonitors.length;
    if (activeMonitorCount > _config.maxConcurrentMonitors * 0.8) {
      _createAlert(
        type: PaymentAlertType.systemError,
        severity: PaymentAlertSeverity.warning,
        title: 'High Monitor Usage',
        message:
            'Active monitors: $activeMonitorCount/${_config.maxConcurrentMonitors}',
        data: {
          'activeMonitors': activeMonitorCount,
          'maxMonitors': _config.maxConcurrentMonitors,
        },
      );
    }
  }

  /// Perform health check
  void _performHealthCheck() {
    _generateHealthReport().then((report) {
      // Update current health status
      _currentHealthStatus = report.status;

      // Emit health report
      _healthController.add(report);

      // Store health report
      _storeHealthReport(report);
    });
  }

  /// Generate health report
  Future<PaymentHealthReport> _generateHealthReport() async {
    final now = DateTime.now();
    final stats = await _getRecentPaymentStats();

    // Determine health status
    PaymentHealthStatus status = PaymentHealthStatus.healthy;
    if (stats['successRate'] < 90) {
      status = PaymentHealthStatus.critical;
    } else if (stats['successRate'] < 95) {
      status = PaymentHealthStatus.warning;
    }

    // Get active alerts
    final activeAlerts =
        _activeAlerts.values.where((alert) => !alert.acknowledged).toList();

    return PaymentHealthReport(
      timestamp: now,
      status: status,
      successRate: stats['successRate'],
      averageResponseTime: Duration(milliseconds: stats['averageResponseTime']),
      totalPayments: stats['totalPayments'],
      successfulPayments: stats['successfulPayments'],
      failedPayments: stats['failedPayments'],
      pendingPayments: stats['pendingPayments'],
      metrics: {
        'activeMonitors': _activeMonitors.length,
        'activeAlerts': activeAlerts.length,
        'systemUptime': _getSystemUptime(),
        'qpayApiHealth':
            true, // This would be determined by actual health check
      },
      activeAlerts: activeAlerts,
    );
  }

  /// Get recent payment statistics
  Future<Map<String, dynamic>> _getRecentPaymentStats() async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('payment_events')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();

      final events = snapshot.docs.map((doc) => doc.data()).toList();

      final totalPayments =
          events.where((e) => e['type'] == 'PaymentEventType.created').length;
      final successfulPayments =
          events.where((e) => e['type'] == 'PaymentEventType.completed').length;
      final failedPayments =
          events.where((e) => e['type'] == 'PaymentEventType.failed').length;
      final pendingPayments =
          totalPayments - successfulPayments - failedPayments;

      final successRate =
          totalPayments > 0 ? (successfulPayments / totalPayments) * 100 : 0.0;

      final responseTimes = events
          .where((e) => e['data']['responseTime'] != null)
          .map((e) => e['data']['responseTime'] as int)
          .toList();

      final averageResponseTime = responseTimes.isNotEmpty
          ? responseTimes.reduce((a, b) => a + b) / responseTimes.length
          : 0;

      return {
        'totalPayments': totalPayments,
        'successfulPayments': successfulPayments,
        'failedPayments': failedPayments,
        'pendingPayments': pendingPayments,
        'successRate': successRate,
        'averageResponseTime': averageResponseTime,
      };
    } catch (e) {
      log('PaymentMonitoringService: Error getting recent payment stats: $e');
      return {
        'totalPayments': 0,
        'successfulPayments': 0,
        'failedPayments': 0,
        'pendingPayments': 0,
        'successRate': 0.0,
        'averageResponseTime': 0,
      };
    }
  }

  /// Get recent payments by user
  Future<List<Map<String, dynamic>>> _getRecentPaymentsByUser(
      String userId) async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('payment_events')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      log('PaymentMonitoringService: Error getting recent payments by user: $e');
      return [];
    }
  }

  /// Helper methods
  PaymentEventType _mapStatusToEventType(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
      case 'COMPLETED':
        return PaymentEventType.completed;
      case 'FAILED':
      case 'DECLINED':
        return PaymentEventType.failed;
      case 'PENDING':
        return PaymentEventType.pending;
      case 'PROCESSING':
        return PaymentEventType.processing;
      case 'CANCELLED':
        return PaymentEventType.cancelled;
      case 'REFUNDED':
        return PaymentEventType.refunded;
      default:
        return PaymentEventType.pending;
    }
  }

  bool _isFinalState(String status) {
    return ['PAID', 'COMPLETED', 'FAILED', 'DECLINED', 'CANCELLED', 'REFUNDED']
        .contains(status.toUpperCase());
  }

  /// Emit payment event
  void _emitPaymentEvent(PaymentEvent event) {
    _eventController.add(event);
    _storePaymentEvent(event);
  }

  /// Store payment event
  Future<void> _storePaymentEvent(PaymentEvent event) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_events')
          .doc(event.id)
          .set(event.toMap());
    } catch (e) {
      log('PaymentMonitoringService: Error storing payment event: $e');
    }
  }

  /// Store monitoring record
  Future<void> _storeMonitoringRecord(
    String paymentId,
    String orderId,
    String qpayInvoiceId,
    double amount,
    String currency,
    String method,
    String userId,
    String? storeId,
    Map<String, dynamic>? metadata,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_monitoring')
          .doc(paymentId)
          .set({
        'paymentId': paymentId,
        'orderId': orderId,
        'qpayInvoiceId': qpayInvoiceId,
        'amount': amount,
        'currency': currency,
        'method': method,
        'userId': userId,
        'storeId': storeId,
        'metadata': metadata,
        'status': 'MONITORING',
        'startedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('PaymentMonitoringService: Error storing monitoring record: $e');
    }
  }

  /// Update monitoring record
  Future<void> _updateMonitoringRecord(
      String paymentId, Map<String, dynamic> updates) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_monitoring')
          .doc(paymentId)
          .update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('PaymentMonitoringService: Error updating monitoring record: $e');
    }
  }

  /// Store alert
  Future<void> _storeAlert(PaymentAlert alert) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_alerts')
          .doc(alert.id)
          .set(alert.toMap());
    } catch (e) {
      log('PaymentMonitoringService: Error storing alert: $e');
    }
  }

  /// Store health report
  Future<void> _storeHealthReport(PaymentHealthReport report) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_health_reports')
          .doc('report_${report.timestamp.millisecondsSinceEpoch}')
          .set({
        'timestamp': Timestamp.fromDate(report.timestamp),
        'status': report.status.toString(),
        'successRate': report.successRate,
        'averageResponseTime': report.averageResponseTime.inMilliseconds,
        'totalPayments': report.totalPayments,
        'successfulPayments': report.successfulPayments,
        'failedPayments': report.failedPayments,
        'pendingPayments': report.pendingPayments,
        'metrics': report.metrics,
        'activeAlertsCount': report.activeAlerts.length,
      });
    } catch (e) {
      log('PaymentMonitoringService: Error storing health report: $e');
    }
  }

  /// Send critical alert notification
  Future<void> _sendCriticalAlertNotification(PaymentAlert alert) async {
    try {
      await _notificationService.sendNotification(
        userId: 'admin',
        title: 'Critical Payment Alert',
        message: alert.message,
        type: 'critical_alert',
        data: {
          'alertId': alert.id,
          'alertType': alert.type.toString(),
          'severity': alert.severity.toString(),
          'data': alert.data,
        },
      );
    } catch (e) {
      log('PaymentMonitoringService: Error sending critical alert notification: $e');
    }
  }

  /// Get system uptime
  Duration _getSystemUptime() {
    // This would track when the monitoring service started
    return const Duration(hours: 1); // Placeholder
  }

  /// Get last payment status
  Future<String> _getLastPaymentStatus(String paymentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('payment_monitoring')
          .doc(paymentId)
          .get();

      return doc.exists ? doc.data()!['lastStatus'] ?? 'UNKNOWN' : 'UNKNOWN';
    } catch (e) {
      return 'UNKNOWN';
    }
  }

  /// Update last payment status
  Future<void> _updateLastPaymentStatus(String paymentId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_monitoring')
          .doc(paymentId)
          .update({
        'lastStatus': status,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('PaymentMonitoringService: Error updating last payment status: $e');
    }
  }

  /// Get order ID for payment
  Future<String> _getOrderIdForPayment(String paymentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('payment_monitoring')
          .doc(paymentId)
          .get();

      return doc.exists ? doc.data()!['orderId'] ?? '' : '';
    } catch (e) {
      return '';
    }
  }

  /// Handle payment status error
  Future<void> _handlePaymentStatusError(String paymentId, String error) async {
    log('PaymentMonitoringService: Payment status error for $paymentId: $error');

    // Update monitoring record
    await _updateMonitoringRecord(paymentId, {
      'lastError': error,
      'lastErrorAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update performance metrics
  void _updatePerformanceMetrics(PaymentEvent event) {
    // This would update internal performance tracking
    // Implementation depends on specific metrics storage
  }

  /// Resume existing monitors
  Future<void> _resumeExistingMonitors() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payment_monitoring')
          .where('status', isEqualTo: 'MONITORING')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final paymentId = data['paymentId'] as String;
        final qpayInvoiceId = data['qpayInvoiceId'] as String;

        // Resume monitoring
        await startPaymentMonitoring(
          paymentId: paymentId,
          orderId: data['orderId'] ?? '',
          qpayInvoiceId: qpayInvoiceId,
          amount: (data['amount'] ?? 0).toDouble(),
          currency: data['currency'] ?? 'MNT',
          method: data['method'] ?? 'qpay',
          userId: data['userId'] ?? '',
          storeId: data['storeId'],
          metadata: data['metadata'],
        );
      }
    } catch (e) {
      log('PaymentMonitoringService: Error resuming existing monitors: $e');
    }
  }

  /// Get current health status
  PaymentHealthStatus get currentHealthStatus => _currentHealthStatus;

  /// Get active monitors count
  int get activeMonitorsCount => _activeMonitors.length;

  /// Get active alerts count
  int get activeAlertsCount => _activeAlerts.length;

  /// Acknowledge alert
  Future<void> acknowledgeAlert(String alertId, String acknowledgedBy) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_alerts')
          .doc(alertId)
          .update({
        'acknowledged': true,
        'acknowledgedBy': acknowledgedBy,
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });

      // Update local alert
      if (_activeAlerts.containsKey(alertId)) {
        _activeAlerts.remove(alertId);
      }
    } catch (e) {
      log('PaymentMonitoringService: Error acknowledging alert: $e');
    }
  }

  /// Get monitoring analytics
  Future<Map<String, dynamic>> getMonitoringAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = FirebaseFirestore.instance.collection('payment_events');

      if (startDate != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      final events = snapshot.docs.map((doc) => doc.data()).toList();

      final totalEvents = events.length;
      final eventsByType = <String, int>{};
      final eventsByStatus = <String, int>{};

      for (final event in events) {
        final eventData = event as Map<String, dynamic>?;
        final type = eventData?['type'] as String?;
        final status = eventData?['status'] as String?;

        if (type != null) {
          eventsByType[type] = (eventsByType[type] ?? 0) + 1;
        }

        if (status != null) {
          eventsByStatus[status] = (eventsByStatus[status] ?? 0) + 1;
        }
      }

      return {
        'totalEvents': totalEvents,
        'eventsByType': eventsByType,
        'eventsByStatus': eventsByStatus,
        'activeMonitors': _activeMonitors.length,
        'activeAlerts': _activeAlerts.length,
        'healthStatus': _currentHealthStatus.toString(),
        'period': {
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
        },
      };
    } catch (e) {
      log('PaymentMonitoringService: Error getting monitoring analytics: $e');
      return {};
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _isMonitoring = false;

    // Cancel timers
    _monitoringTimer?.cancel();
    _healthCheckTimer?.cancel();

    // Cancel all monitoring subscriptions
    for (final subscription in _activeMonitors.values) {
      await subscription.cancel();
    }
    _activeMonitors.clear();

    // Clear tracking data
    _paymentStartTimes.clear();
    _activeAlerts.clear();
    _lastAlertTimes.clear();

    // Close controllers
    await _eventController.close();
    await _alertController.close();
    await _healthController.close();
    await _performanceController.close();
  }
}

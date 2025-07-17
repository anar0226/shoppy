import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'qpay_service.dart';
import 'database_service.dart';
import '../../features/notifications/notification_service.dart';

/// Payment Timeout Configuration
class PaymentTimeoutConfig {
  final Duration defaultTimeout;
  final Duration warningThreshold;
  final Duration criticalThreshold;
  final int maxRetryAttempts;
  final Duration retryInterval;
  final bool enableAutomaticCancellation;
  final bool enableUserNotifications;

  const PaymentTimeoutConfig({
    this.defaultTimeout = const Duration(minutes: 30),
    this.warningThreshold = const Duration(minutes: 5),
    this.criticalThreshold = const Duration(minutes: 2),
    this.maxRetryAttempts = 3,
    this.retryInterval = const Duration(seconds: 30),
    this.enableAutomaticCancellation = true,
    this.enableUserNotifications = true,
  });
}

/// Payment Timeout Status
enum PaymentTimeoutStatus {
  active,
  warning,
  critical,
  expired,
  cancelled,
  completed,
  failed,
}

/// Payment Timeout Event
class PaymentTimeoutEvent {
  final String paymentId;
  final String orderId;
  final PaymentTimeoutStatus status;
  final DateTime timestamp;
  final Duration remainingTime;
  final String? message;
  final Map<String, dynamic>? metadata;

  const PaymentTimeoutEvent({
    required this.paymentId,
    required this.orderId,
    required this.status,
    required this.timestamp,
    required this.remainingTime,
    this.message,
    this.metadata,
  });
}

/// Payment Timeout Handler Service
class PaymentTimeoutHandler {
  static final PaymentTimeoutHandler _instance =
      PaymentTimeoutHandler._internal();
  factory PaymentTimeoutHandler() => _instance;
  PaymentTimeoutHandler._internal();

  final QPayService _qpayService = QPayService();
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  PaymentTimeoutConfig _config = const PaymentTimeoutConfig();
  final Map<String, Timer> _activeTimeouts = {};
  final Map<String, PaymentTimeoutEvent> _timeoutEvents = {};
  final StreamController<PaymentTimeoutEvent> _eventController =
      StreamController.broadcast();
  final Map<String, int> _retryAttempts = {};

  /// Initialize the timeout handler with configuration
  Future<void> initialize({PaymentTimeoutConfig? config}) async {
    _config = config ?? const PaymentTimeoutConfig();

    log('PaymentTimeoutHandler: Initialized with config: '
        'defaultTimeout=${_config.defaultTimeout.inMinutes}min, '
        'warningThreshold=${_config.warningThreshold.inMinutes}min, '
        'criticalThreshold=${_config.criticalThreshold.inMinutes}min');

    // Resume monitoring for existing payments
    await _resumeActiveTimeouts();
  }

  /// Get timeout events stream
  Stream<PaymentTimeoutEvent> get timeoutEvents => _eventController.stream;

  /// Start timeout monitoring for a payment
  Future<void> startTimeout({
    required String paymentId,
    required String orderId,
    required String qpayInvoiceId,
    required double amount,
    required String customerUserId,
    Duration? customTimeout,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final timeout = customTimeout ?? _config.defaultTimeout;

      log('PaymentTimeoutHandler: Starting timeout for payment $paymentId, '
          'order $orderId, timeout: ${timeout.inMinutes}min');

      // Cancel existing timeout if any
      await cancelTimeout(paymentId);

      // Store timeout information in database
      await _storeTimeoutRecord(
        paymentId: paymentId,
        orderId: orderId,
        qpayInvoiceId: qpayInvoiceId,
        amount: amount,
        customerUserId: customerUserId,
        timeoutDuration: timeout,
        metadata: metadata,
      );

      // Start timeout monitoring
      await _startTimeoutMonitoring(
        paymentId: paymentId,
        orderId: orderId,
        qpayInvoiceId: qpayInvoiceId,
        customerUserId: customerUserId,
        timeout: timeout,
        metadata: metadata,
      );

      // Emit active event
      _emitTimeoutEvent(PaymentTimeoutEvent(
        paymentId: paymentId,
        orderId: orderId,
        status: PaymentTimeoutStatus.active,
        timestamp: DateTime.now(),
        remainingTime: timeout,
        message: 'Payment timeout monitoring started',
        metadata: metadata,
      ));
    } catch (e) {
      log('PaymentTimeoutHandler: Error starting timeout for payment $paymentId: $e');
      throw Exception('Failed to start payment timeout: $e');
    }
  }

  /// Start timeout monitoring with progressive notifications
  Future<void> _startTimeoutMonitoring({
    required String paymentId,
    required String orderId,
    required String qpayInvoiceId,
    required String customerUserId,
    required Duration timeout,
    Map<String, dynamic>? metadata,
  }) async {
    final startTime = DateTime.now();
    final endTime = startTime.add(timeout);

    // Create periodic timer for monitoring
    _activeTimeouts[paymentId] = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        try {
          final now = DateTime.now();
          final remaining = endTime.difference(now);

          if (remaining <= Duration.zero) {
            // Timeout expired
            await _handleTimeoutExpired(
              paymentId: paymentId,
              orderId: orderId,
              qpayInvoiceId: qpayInvoiceId,
              customerUserId: customerUserId,
              metadata: metadata,
            );
            timer.cancel();
            return;
          }

          // Check payment status
          final paymentStatus = await _checkPaymentStatus(qpayInvoiceId);
          if (paymentStatus != null) {
            if (paymentStatus.isPaid) {
              await _handlePaymentCompleted(
                paymentId: paymentId,
                orderId: orderId,
                customerUserId: customerUserId,
                metadata: metadata,
              );
              timer.cancel();
              return;
            } else if (paymentStatus.isFailed || paymentStatus.isCanceled) {
              await _handlePaymentFailed(
                paymentId: paymentId,
                orderId: orderId,
                customerUserId: customerUserId,
                status: paymentStatus.status ?? 'FAILED',
                metadata: metadata,
              );
              timer.cancel();
              return;
            }
          }

          // Handle progressive timeout warnings
          await _handleProgressiveTimeoutWarnings(
            paymentId: paymentId,
            orderId: orderId,
            customerUserId: customerUserId,
            remainingTime: remaining,
            metadata: metadata,
          );
        } catch (e) {
          log('PaymentTimeoutHandler: Error in timeout monitoring for payment $paymentId: $e');
        }
      },
    );

    // Schedule warning notifications
    _scheduleWarningNotifications(
      paymentId: paymentId,
      orderId: orderId,
      customerUserId: customerUserId,
      timeout: timeout,
      metadata: metadata,
    );
  }

  /// Handle progressive timeout warnings
  Future<void> _handleProgressiveTimeoutWarnings({
    required String paymentId,
    required String orderId,
    required String customerUserId,
    required Duration remainingTime,
    Map<String, dynamic>? metadata,
  }) async {
    PaymentTimeoutStatus status = PaymentTimeoutStatus.active;
    String? message;

    if (remainingTime <= _config.criticalThreshold) {
      status = PaymentTimeoutStatus.critical;
      message = 'Payment expires in ${remainingTime.inMinutes} minutes';

      if (_config.enableUserNotifications) {
        await _sendTimeoutNotification(
          customerUserId: customerUserId,
          title: 'Payment Expiring Soon',
          message:
              'Your payment for order $orderId expires in ${remainingTime.inMinutes} minutes',
          type: 'critical',
        );
      }
    } else if (remainingTime <= _config.warningThreshold) {
      status = PaymentTimeoutStatus.warning;
      message = 'Payment expires in ${remainingTime.inMinutes} minutes';

      if (_config.enableUserNotifications) {
        await _sendTimeoutNotification(
          customerUserId: customerUserId,
          title: 'Payment Reminder',
          message:
              'Complete your payment for order $orderId within ${remainingTime.inMinutes} minutes',
          type: 'warning',
        );
      }
    }

    // Emit timeout event
    _emitTimeoutEvent(PaymentTimeoutEvent(
      paymentId: paymentId,
      orderId: orderId,
      status: status,
      timestamp: DateTime.now(),
      remainingTime: remainingTime,
      message: message,
      metadata: metadata,
    ));
  }

  /// Schedule warning notifications
  void _scheduleWarningNotifications({
    required String paymentId,
    required String orderId,
    required String customerUserId,
    required Duration timeout,
    Map<String, dynamic>? metadata,
  }) {
    if (!_config.enableUserNotifications) return;

    // Schedule warning notification
    final warningTime = timeout - _config.warningThreshold;
    if (warningTime > Duration.zero) {
      Timer(warningTime, () async {
        await _sendTimeoutNotification(
          customerUserId: customerUserId,
          title: 'Payment Reminder',
          message:
              'Complete your payment for order $orderId within ${_config.warningThreshold.inMinutes} minutes',
          type: 'warning',
        );
      });
    }

    // Schedule critical notification
    final criticalTime = timeout - _config.criticalThreshold;
    if (criticalTime > Duration.zero) {
      Timer(criticalTime, () async {
        await _sendTimeoutNotification(
          customerUserId: customerUserId,
          title: 'Payment Expiring Soon',
          message:
              'Your payment for order $orderId expires in ${_config.criticalThreshold.inMinutes} minutes',
          type: 'critical',
        );
      });
    }
  }

  /// Handle timeout expiration
  Future<void> _handleTimeoutExpired({
    required String paymentId,
    required String orderId,
    required String qpayInvoiceId,
    required String customerUserId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      log('PaymentTimeoutHandler: Timeout expired for payment $paymentId, order $orderId');

      // Final payment status check
      final paymentStatus = await _checkPaymentStatus(qpayInvoiceId);
      if (paymentStatus != null && paymentStatus.isPaid) {
        // Payment completed at the last moment
        await _handlePaymentCompleted(
          paymentId: paymentId,
          orderId: orderId,
          customerUserId: customerUserId,
          metadata: metadata,
        );
        return;
      }

      // Cancel payment if automatic cancellation is enabled
      if (_config.enableAutomaticCancellation) {
        await _cancelExpiredPayment(
          paymentId: paymentId,
          orderId: orderId,
          qpayInvoiceId: qpayInvoiceId,
          customerUserId: customerUserId,
          metadata: metadata,
        );
      }

      // Update timeout record
      await _updateTimeoutRecord(
        paymentId: paymentId,
        status: PaymentTimeoutStatus.expired,
        completedAt: DateTime.now(),
      );

      // Emit expired event
      _emitTimeoutEvent(PaymentTimeoutEvent(
        paymentId: paymentId,
        orderId: orderId,
        status: PaymentTimeoutStatus.expired,
        timestamp: DateTime.now(),
        remainingTime: Duration.zero,
        message: 'Payment timeout expired',
        metadata: metadata,
      ));

      // Send notification
      if (_config.enableUserNotifications) {
        await _sendTimeoutNotification(
          customerUserId: customerUserId,
          title: 'Payment Expired',
          message:
              'Your payment for order $orderId has expired. Please try again.',
          type: 'expired',
        );
      }
    } catch (e) {
      log('PaymentTimeoutHandler: Error handling timeout expiration for payment $paymentId: $e');
    } finally {
      // Clean up
      _activeTimeouts.remove(paymentId);
      _timeoutEvents.remove(paymentId);
      _retryAttempts.remove(paymentId);
    }
  }

  /// Cancel expired payment
  Future<void> _cancelExpiredPayment({
    required String paymentId,
    required String orderId,
    required String qpayInvoiceId,
    required String customerUserId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      log('PaymentTimeoutHandler: Cancelling expired payment $paymentId');

      // Cancel payment through QPay
      final cancelResult = await _qpayService.cancelPayment(qpayInvoiceId);

      if (cancelResult.success) {
        log('PaymentTimeoutHandler: Successfully cancelled payment $paymentId');

        // Update order status
        await _updateOrderStatus(orderId, 'cancelled', {
          'cancellationReason': 'Payment timeout expired',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': 'system',
        });

        // Clean up temporary order data
        await _cleanupTemporaryOrder(orderId);
      } else {
        log('PaymentTimeoutHandler: Failed to cancel payment $paymentId: ${cancelResult.error}');

        // Still update order status locally
        await _updateOrderStatus(orderId, 'payment_expired', {
          'cancellationReason':
              'Payment timeout expired (QPay cancellation failed)',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': 'system',
        });
      }
    } catch (e) {
      log('PaymentTimeoutHandler: Error cancelling expired payment $paymentId: $e');
    }
  }

  /// Handle payment completion
  Future<void> _handlePaymentCompleted({
    required String paymentId,
    required String orderId,
    required String customerUserId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      log('PaymentTimeoutHandler: Payment completed for payment $paymentId, order $orderId');

      // Update timeout record
      await _updateTimeoutRecord(
        paymentId: paymentId,
        status: PaymentTimeoutStatus.completed,
        completedAt: DateTime.now(),
      );

      // Emit completed event
      _emitTimeoutEvent(PaymentTimeoutEvent(
        paymentId: paymentId,
        orderId: orderId,
        status: PaymentTimeoutStatus.completed,
        timestamp: DateTime.now(),
        remainingTime: Duration.zero,
        message: 'Payment completed successfully',
        metadata: metadata,
      ));

      // Send success notification
      if (_config.enableUserNotifications) {
        await _sendTimeoutNotification(
          customerUserId: customerUserId,
          title: 'Payment Successful',
          message:
              'Your payment for order $orderId has been completed successfully',
          type: 'success',
        );
      }
    } catch (e) {
      log('PaymentTimeoutHandler: Error handling payment completion for payment $paymentId: $e');
    } finally {
      // Clean up
      _activeTimeouts.remove(paymentId);
      _timeoutEvents.remove(paymentId);
      _retryAttempts.remove(paymentId);
    }
  }

  /// Handle payment failure
  Future<void> _handlePaymentFailed({
    required String paymentId,
    required String orderId,
    required String customerUserId,
    required String status,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      log('PaymentTimeoutHandler: Payment failed for payment $paymentId, order $orderId, status: $status');

      // Update timeout record
      await _updateTimeoutRecord(
        paymentId: paymentId,
        status: PaymentTimeoutStatus.failed,
        completedAt: DateTime.now(),
      );

      // Emit failed event
      _emitTimeoutEvent(PaymentTimeoutEvent(
        paymentId: paymentId,
        orderId: orderId,
        status: PaymentTimeoutStatus.failed,
        timestamp: DateTime.now(),
        remainingTime: Duration.zero,
        message: 'Payment failed: $status',
        metadata: metadata,
      ));

      // Update order status
      await _updateOrderStatus(orderId, 'payment_failed', {
        'paymentFailureReason': status,
        'failedAt': FieldValue.serverTimestamp(),
      });

      // Send failure notification
      if (_config.enableUserNotifications) {
        await _sendTimeoutNotification(
          customerUserId: customerUserId,
          title: 'Payment Failed',
          message:
              'Your payment for order $orderId has failed. Please try again.',
          type: 'failed',
        );
      }
    } catch (e) {
      log('PaymentTimeoutHandler: Error handling payment failure for payment $paymentId: $e');
    } finally {
      // Clean up
      _activeTimeouts.remove(paymentId);
      _timeoutEvents.remove(paymentId);
      _retryAttempts.remove(paymentId);
    }
  }

  /// Cancel timeout monitoring
  Future<void> cancelTimeout(String paymentId) async {
    try {
      log('PaymentTimeoutHandler: Cancelling timeout for payment $paymentId');

      // Cancel timer
      _activeTimeouts[paymentId]?.cancel();
      _activeTimeouts.remove(paymentId);

      // Update timeout record
      await _updateTimeoutRecord(
        paymentId: paymentId,
        status: PaymentTimeoutStatus.cancelled,
        completedAt: DateTime.now(),
      );

      // Clean up
      _timeoutEvents.remove(paymentId);
      _retryAttempts.remove(paymentId);
    } catch (e) {
      log('PaymentTimeoutHandler: Error cancelling timeout for payment $paymentId: $e');
    }
  }

  /// Get timeout status for a payment
  Future<PaymentTimeoutEvent?> getTimeoutStatus(String paymentId) async {
    try {
      // Check in-memory first
      if (_timeoutEvents.containsKey(paymentId)) {
        return _timeoutEvents[paymentId];
      }

      // Check database
      final timeoutRecord = await _getTimeoutRecord(paymentId);
      if (timeoutRecord != null) {
        return PaymentTimeoutEvent(
          paymentId: paymentId,
          orderId: timeoutRecord['orderId'] ?? '',
          status: _parseTimeoutStatus(timeoutRecord['status']),
          timestamp: (timeoutRecord['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          remainingTime: Duration.zero,
          message: timeoutRecord['lastMessage'],
          metadata: timeoutRecord['metadata'],
        );
      }

      return null;
    } catch (e) {
      log('PaymentTimeoutHandler: Error getting timeout status for payment $paymentId: $e');
      return null;
    }
  }

  /// Resume active timeouts after app restart
  Future<void> _resumeActiveTimeouts() async {
    try {
      log('PaymentTimeoutHandler: Resuming active timeouts');

      final activeTimeouts = await _getActiveTimeoutRecords();

      for (final timeoutRecord in activeTimeouts) {
        final paymentId = timeoutRecord['paymentId'] as String;
        final orderId = timeoutRecord['orderId'] as String;
        final qpayInvoiceId = timeoutRecord['qpayInvoiceId'] as String;
        final customerUserId = timeoutRecord['customerUserId'] as String;
        final createdAt = (timeoutRecord['createdAt'] as Timestamp).toDate();
        final timeoutDuration = Duration(
          milliseconds: timeoutRecord['timeoutDurationMs'] as int,
        );

        final elapsed = DateTime.now().difference(createdAt);
        final remaining = timeoutDuration - elapsed;

        if (remaining > Duration.zero) {
          // Resume timeout monitoring
          await _startTimeoutMonitoring(
            paymentId: paymentId,
            orderId: orderId,
            qpayInvoiceId: qpayInvoiceId,
            customerUserId: customerUserId,
            timeout: remaining,
            metadata: timeoutRecord['metadata'],
          );
        } else {
          // Handle expired timeout
          await _handleTimeoutExpired(
            paymentId: paymentId,
            orderId: orderId,
            qpayInvoiceId: qpayInvoiceId,
            customerUserId: customerUserId,
            metadata: timeoutRecord['metadata'],
          );
        }
      }
    } catch (e) {
      log('PaymentTimeoutHandler: Error resuming active timeouts: $e');
    }
  }

  /// Store timeout record in database
  Future<void> _storeTimeoutRecord({
    required String paymentId,
    required String orderId,
    required String qpayInvoiceId,
    required double amount,
    required String customerUserId,
    required Duration timeoutDuration,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_timeouts')
          .doc(paymentId)
          .set({
        'paymentId': paymentId,
        'orderId': orderId,
        'qpayInvoiceId': qpayInvoiceId,
        'amount': amount,
        'customerUserId': customerUserId,
        'timeoutDurationMs': timeoutDuration.inMilliseconds,
        'status': PaymentTimeoutStatus.active.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      });
    } catch (e) {
      log('PaymentTimeoutHandler: Error storing timeout record: $e');
      throw e;
    }
  }

  /// Update timeout record
  Future<void> _updateTimeoutRecord({
    required String paymentId,
    required PaymentTimeoutStatus status,
    DateTime? completedAt,
    String? lastMessage,
  }) async {
    try {
      final updateData = {
        'status': status.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (completedAt != null) {
        updateData['completedAt'] = Timestamp.fromDate(completedAt);
      }

      if (lastMessage != null) {
        updateData['lastMessage'] = lastMessage;
      }

      await FirebaseFirestore.instance
          .collection('payment_timeouts')
          .doc(paymentId)
          .update(updateData);
    } catch (e) {
      log('PaymentTimeoutHandler: Error updating timeout record: $e');
    }
  }

  /// Get timeout record from database
  Future<Map<String, dynamic>?> _getTimeoutRecord(String paymentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('payment_timeouts')
          .doc(paymentId)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      log('PaymentTimeoutHandler: Error getting timeout record: $e');
      return null;
    }
  }

  /// Get active timeout records
  Future<List<Map<String, dynamic>>> _getActiveTimeoutRecords() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payment_timeouts')
          .where('status', isEqualTo: PaymentTimeoutStatus.active.toString())
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      log('PaymentTimeoutHandler: Error getting active timeout records: $e');
      return [];
    }
  }

  /// Check payment status
  Future<QPayPaymentStatus?> _checkPaymentStatus(String qpayInvoiceId) async {
    try {
      final status = await _qpayService.checkPaymentStatus(qpayInvoiceId);
      return status.success ? status : null;
    } catch (e) {
      log('PaymentTimeoutHandler: Error checking payment status: $e');
      return null;
    }
  }

  /// Update order status
  Future<void> _updateOrderStatus(
    String orderId,
    String status,
    Map<String, dynamic>? additionalData,
  ) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(updateData);
    } catch (e) {
      log('PaymentTimeoutHandler: Error updating order status: $e');
    }
  }

  /// Clean up temporary order data
  Future<void> _cleanupTemporaryOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('temporary_orders')
          .doc(orderId)
          .delete();
    } catch (e) {
      log('PaymentTimeoutHandler: Error cleaning up temporary order: $e');
    }
  }

  /// Send timeout notification
  Future<void> _sendTimeoutNotification({
    required String customerUserId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      await _notificationService.sendNotification(
        userId: customerUserId,
        title: title,
        message: message,
        type: type,
        data: {
          'type': 'payment_timeout',
          'notification_type': type,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      log('PaymentTimeoutHandler: Error sending timeout notification: $e');
    }
  }

  /// Emit timeout event
  void _emitTimeoutEvent(PaymentTimeoutEvent event) {
    _timeoutEvents[event.paymentId] = event;
    _eventController.add(event);
  }

  /// Parse timeout status from string
  PaymentTimeoutStatus _parseTimeoutStatus(String? status) {
    switch (status) {
      case 'PaymentTimeoutStatus.active':
        return PaymentTimeoutStatus.active;
      case 'PaymentTimeoutStatus.warning':
        return PaymentTimeoutStatus.warning;
      case 'PaymentTimeoutStatus.critical':
        return PaymentTimeoutStatus.critical;
      case 'PaymentTimeoutStatus.expired':
        return PaymentTimeoutStatus.expired;
      case 'PaymentTimeoutStatus.cancelled':
        return PaymentTimeoutStatus.cancelled;
      case 'PaymentTimeoutStatus.completed':
        return PaymentTimeoutStatus.completed;
      case 'PaymentTimeoutStatus.failed':
        return PaymentTimeoutStatus.failed;
      default:
        return PaymentTimeoutStatus.active;
    }
  }

  /// Get timeout analytics
  Future<Map<String, dynamic>> getTimeoutAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = FirebaseFirestore.instance.collection('payment_timeouts');

      if (startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      final records = snapshot.docs.map((doc) => doc.data()).toList();

      final totalTimeouts = records.length;
      final completedTimeouts = records
          .where((r) =>
              (r as Map<String, dynamic>?)?['status'] ==
              PaymentTimeoutStatus.completed.toString())
          .length;
      final expiredTimeouts = records
          .where((r) =>
              (r as Map<String, dynamic>?)?['status'] ==
              PaymentTimeoutStatus.expired.toString())
          .length;
      final cancelledTimeouts = records
          .where((r) =>
              (r as Map<String, dynamic>?)?['status'] ==
              PaymentTimeoutStatus.cancelled.toString())
          .length;
      final failedTimeouts = records
          .where((r) =>
              (r as Map<String, dynamic>?)?['status'] ==
              PaymentTimeoutStatus.failed.toString())
          .length;

      final successRate =
          totalTimeouts > 0 ? (completedTimeouts / totalTimeouts) * 100 : 0.0;
      final timeoutRate =
          totalTimeouts > 0 ? (expiredTimeouts / totalTimeouts) * 100 : 0.0;

      return {
        'totalTimeouts': totalTimeouts,
        'completedTimeouts': completedTimeouts,
        'expiredTimeouts': expiredTimeouts,
        'cancelledTimeouts': cancelledTimeouts,
        'failedTimeouts': failedTimeouts,
        'successRate': successRate,
        'timeoutRate': timeoutRate,
        'period': {
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
        },
      };
    } catch (e) {
      log('PaymentTimeoutHandler: Error getting timeout analytics: $e');
      return {};
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    // Cancel all active timeouts
    for (final timer in _activeTimeouts.values) {
      timer.cancel();
    }
    _activeTimeouts.clear();
    _timeoutEvents.clear();
    _retryAttempts.clear();

    // Close event controller
    await _eventController.close();
  }
}

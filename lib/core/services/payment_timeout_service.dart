import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'qpay_service.dart';
import 'error_handler_service.dart';

/// Payment timeout service to handle 10-minute timeouts for QPay payments
/// This prevents inventory complications and ensures proper order management
class PaymentTimeoutService {
  static const Duration _timeoutDuration = Duration(minutes: 10);
  static const Duration _checkInterval = Duration(seconds: 30);

  final QPayService _qpayService = QPayService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Track active timeouts
  final Map<String, Timer> _activeTimeouts = {};
  final Map<String, Timer> _checkTimers = {};

  /// Start timeout monitoring for a payment
  Future<void> startTimeoutMonitoring({
    required String orderId,
    required String qpayInvoiceId,
    required String customerUserId,
    required Map<String, dynamic> orderData,
    required String customerEmail,
    required Map<String, dynamic> deliveryAddress,
  }) async {
    try {
      // Create temporary order record
      await _createTemporaryOrder(
        orderId: orderId,
        qpayInvoiceId: qpayInvoiceId,
        customerUserId: customerUserId,
        orderData: orderData,
        customerEmail: customerEmail,
        deliveryAddress: deliveryAddress,
      );

      // Start timeout timer
      final timeoutTimer = Timer(_timeoutDuration, () {
        _handleTimeoutExpired(orderId, qpayInvoiceId, customerUserId);
      });

      // Start payment status checking
      final checkTimer = Timer.periodic(_checkInterval, (timer) {
        _checkPaymentStatus(orderId, qpayInvoiceId, timer);
      });

      // Store timers
      _activeTimeouts[orderId] = timeoutTimer;
      _checkTimers[orderId] = checkTimer;

      // Log timeout start
      await _logTimeoutEvent(orderId, 'timeout_started', {
        'timeoutDuration': _timeoutDuration.inMinutes,
        'checkInterval': _checkInterval.inSeconds,
      });
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'start_timeout_monitoring',
        error: e,
        showUserMessage: false,
      );
    }
  }

  /// Create temporary order in Firestore
  Future<void> _createTemporaryOrder({
    required String orderId,
    required String qpayInvoiceId,
    required String customerUserId,
    required Map<String, dynamic> orderData,
    required String customerEmail,
    required Map<String, dynamic> deliveryAddress,
  }) async {
    try {
      await _firestore.collection('temporary_orders').doc(orderId).set({
        'orderId': orderId,
        'qpayInvoiceId': qpayInvoiceId,
        'userId': customerUserId,
        'customerEmail': customerEmail,
        'orderData': orderData,
        'deliveryAddress': deliveryAddress,
        'status': 'pending_payment',
        'createdAt': FieldValue.serverTimestamp(),
        'timeoutAt': FieldValue.serverTimestamp(),
        'timeoutDuration': _timeoutDuration.inMinutes,
      });

      // Log temporary order creation
      await _logTimeoutEvent(orderId, 'temporary_order_created', {
        'qpayInvoiceId': qpayInvoiceId,
        'customerEmail': customerEmail,
      });
    } catch (e) {
      throw Exception('Failed to create temporary order: $e');
    }
  }

  /// Check payment status periodically
  Future<void> _checkPaymentStatus(
      String orderId, String qpayInvoiceId, Timer timer) async {
    try {
      final status = await _qpayService.checkPaymentStatus(qpayInvoiceId);
      final paymentStatus = status['payment_status'];

      if (paymentStatus == 'PAID') {
        // Payment successful - cancel timeout and create order
        await _handlePaymentSuccess(orderId, qpayInvoiceId, status);
        _cancelTimers(orderId);
      } else if (paymentStatus == 'FAILED' ||
          paymentStatus == 'CANCELLED' ||
          paymentStatus == 'EXPIRED') {
        // Payment failed - cancel timeout and clean up
        await _handlePaymentFailure(orderId, qpayInvoiceId, paymentStatus);
        _cancelTimers(orderId);
      }
      // For 'NEW' status, continue monitoring
    } catch (e) {
      // Log error but continue monitoring
      await _logTimeoutEvent(orderId, 'payment_check_error', {
        'error': e.toString(),
      });
    }
  }

  /// Handle timeout expiration
  Future<void> _handleTimeoutExpired(
      String orderId, String qpayInvoiceId, String customerUserId) async {
    try {
      // Final payment status check
      final status = await _qpayService.checkPaymentStatus(qpayInvoiceId);
      final paymentStatus = status['payment_status'];

      if (paymentStatus == 'PAID') {
        // Payment completed at the last moment
        await _handlePaymentSuccess(orderId, qpayInvoiceId, status);
      } else {
        // Timeout expired - clean up
        await _handleTimeoutCleanup(orderId, qpayInvoiceId, customerUserId);
      }

      _cancelTimers(orderId);
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'handle_timeout_expired',
        error: e,
        showUserMessage: false,
      );
    }
  }

  /// Handle successful payment
  Future<void> _handlePaymentSuccess(
      String orderId, String qpayInvoiceId, Map<String, dynamic> status) async {
    try {
      // Update temporary order status
      await _firestore.collection('temporary_orders').doc(orderId).update({
        'status': 'payment_successful',
        'paidAt': FieldValue.serverTimestamp(),
        'paymentStatus': status,
      });

      // Log success
      await _logTimeoutEvent(orderId, 'payment_success', {
        'qpayInvoiceId': qpayInvoiceId,
        'paymentStatus': status,
      });
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'handle_payment_success',
        error: e,
        showUserMessage: false,
      );
    }
  }

  /// Handle payment failure
  Future<void> _handlePaymentFailure(
      String orderId, String qpayInvoiceId, String status) async {
    try {
      // Update temporary order status
      await _firestore.collection('temporary_orders').doc(orderId).update({
        'status': 'payment_failed',
        'failedAt': FieldValue.serverTimestamp(),
        'failureReason': status,
      });

      // Log failure
      await _logTimeoutEvent(orderId, 'payment_failed', {
        'qpayInvoiceId': qpayInvoiceId,
        'status': status,
      });
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'handle_payment_failure',
        error: e,
        showUserMessage: false,
      );
    }
  }

  /// Handle timeout cleanup
  Future<void> _handleTimeoutCleanup(
      String orderId, String qpayInvoiceId, String customerUserId) async {
    try {
      // Update temporary order status
      await _firestore.collection('temporary_orders').doc(orderId).update({
        'status': 'timeout_expired',
        'expiredAt': FieldValue.serverTimestamp(),
      });

      // Log timeout
      await _logTimeoutEvent(orderId, 'timeout_expired', {
        'qpayInvoiceId': qpayInvoiceId,
        'timeoutDuration': _timeoutDuration.inMinutes,
      });
    } catch (e) {
      await ErrorHandlerService.instance.handleError(
        operation: 'handle_timeout_cleanup',
        error: e,
        showUserMessage: false,
      );
    }
  }

  /// Cancel timers for an order
  void _cancelTimers(String orderId) {
    _activeTimeouts[orderId]?.cancel();
    _checkTimers[orderId]?.cancel();
    _activeTimeouts.remove(orderId);
    _checkTimers.remove(orderId);
  }

  /// Log timeout events
  Future<void> _logTimeoutEvent(
      String orderId, String eventType, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('payment_timeout_logs').add({
        'orderId': orderId,
        'eventType': eventType,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Don't throw error for logging failures
      debugPrint('Failed to log timeout event: $e');
    }
  }

  /// Cancel timeout for a specific order
  void cancelTimeout(String orderId) {
    _cancelTimers(orderId);
  }

  /// Get remaining time for an order
  Duration? getRemainingTime(String orderId) {
    final timer = _activeTimeouts[orderId];
    if (timer == null) return null;

    // This is a simplified calculation - in a real implementation,
    // you'd track the start time and calculate remaining time
    return const Duration(minutes: 10);
  }

  /// Check if timeout is active for an order
  bool isTimeoutActive(String orderId) {
    return _activeTimeouts.containsKey(orderId);
  }

  /// Get all active timeouts
  List<String> getActiveTimeouts() {
    return _activeTimeouts.keys.toList();
  }

  /// Clean up all timeouts (for app shutdown)
  void dispose() {
    for (final timer in _activeTimeouts.values) {
      timer.cancel();
    }
    for (final timer in _checkTimers.values) {
      timer.cancel();
    }
    _activeTimeouts.clear();
    _checkTimers.clear();
  }
}

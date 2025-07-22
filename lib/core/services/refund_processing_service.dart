import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'qpay_service.dart';
import '../../features/notifications/notification_service.dart';

/// Refund Processing Configuration
class RefundProcessingConfig {
  final Duration processingTimeout;
  final Duration statusCheckInterval;
  final int maxRetryAttempts;
  final Duration retryInterval;
  final bool enableAutomaticApproval;
  final bool enableCustomerNotifications;
  final double autoApprovalThreshold;
  final List<String> autoApprovalReasons;

  const RefundProcessingConfig({
    this.processingTimeout = const Duration(minutes: 30),
    this.statusCheckInterval = const Duration(minutes: 2),
    this.maxRetryAttempts = 3,
    this.retryInterval = const Duration(minutes: 5),
    this.enableAutomaticApproval = true,
    this.enableCustomerNotifications = true,
    this.autoApprovalThreshold = 1000.0, // MNT
    this.autoApprovalReasons = const [
      'duplicate_payment',
      'cancelled_order',
      'product_unavailable',
      'system_error',
    ],
  });
}

/// Refund Status
enum RefundStatus {
  pending,
  approved,
  processing,
  completed,
  failed,
  cancelled,
  disputed,
  partiallyRefunded,
  requiresManualReview,
}

/// Refund Type
enum RefundType {
  full,
  partial,
  shipping,
  tax,
  fee,
  chargeback,
  goodwill,
}

/// Refund Reason
enum RefundReason {
  customerRequest,
  cancelledOrder,
  productUnavailable,
  duplicatePayment,
  systemError,
  fraudulent,
  chargeback,
  qualityIssue,
  deliveryFailed,
  other,
}

/// Refund Priority
enum RefundPriority {
  low,
  normal,
  high,
  urgent,
}

/// Refund Request
class RefundRequest {
  final String id;
  final String orderId;
  final String paymentId;
  final String customerUserId;
  final RefundType type;
  final RefundReason reason;
  final RefundPriority priority;
  final double requestedAmount;
  final double originalAmount;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime requestedAt;
  final String? requestedBy;
  final List<String> attachments;

  const RefundRequest({
    required this.id,
    required this.orderId,
    required this.paymentId,
    required this.customerUserId,
    required this.type,
    required this.reason,
    this.priority = RefundPriority.normal,
    required this.requestedAmount,
    required this.originalAmount,
    required this.description,
    this.metadata = const {},
    required this.requestedAt,
    this.requestedBy,
    this.attachments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'paymentId': paymentId,
      'customerUserId': customerUserId,
      'type': type.toString(),
      'reason': reason.toString(),
      'priority': priority.toString(),
      'requestedAmount': requestedAmount,
      'originalAmount': originalAmount,
      'description': description,
      'metadata': metadata,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'requestedBy': requestedBy,
      'attachments': attachments,
    };
  }

  factory RefundRequest.fromMap(Map<String, dynamic> map) {
    return RefundRequest(
      id: map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      paymentId: map['paymentId'] ?? '',
      customerUserId: map['customerUserId'] ?? '',
      type: _parseRefundType(map['type']),
      reason: _parseRefundReason(map['reason']),
      priority: _parseRefundPriority(map['priority']),
      requestedAmount: (map['requestedAmount'] ?? 0).toDouble(),
      originalAmount: (map['originalAmount'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      metadata: map['metadata'] ?? {},
      requestedAt:
          (map['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      requestedBy: map['requestedBy'],
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }

  static RefundType _parseRefundType(String? type) {
    switch (type) {
      case 'RefundType.full':
        return RefundType.full;
      case 'RefundType.partial':
        return RefundType.partial;
      case 'RefundType.shipping':
        return RefundType.shipping;
      case 'RefundType.tax':
        return RefundType.tax;
      case 'RefundType.fee':
        return RefundType.fee;
      case 'RefundType.chargeback':
        return RefundType.chargeback;
      case 'RefundType.goodwill':
        return RefundType.goodwill;
      default:
        return RefundType.full;
    }
  }

  static RefundReason _parseRefundReason(String? reason) {
    switch (reason) {
      case 'RefundReason.customerRequest':
        return RefundReason.customerRequest;
      case 'RefundReason.cancelledOrder':
        return RefundReason.cancelledOrder;
      case 'RefundReason.productUnavailable':
        return RefundReason.productUnavailable;
      case 'RefundReason.duplicatePayment':
        return RefundReason.duplicatePayment;
      case 'RefundReason.systemError':
        return RefundReason.systemError;
      case 'RefundReason.fraudulent':
        return RefundReason.fraudulent;
      case 'RefundReason.chargeback':
        return RefundReason.chargeback;
      case 'RefundReason.qualityIssue':
        return RefundReason.qualityIssue;
      case 'RefundReason.deliveryFailed':
        return RefundReason.deliveryFailed;
      default:
        return RefundReason.other;
    }
  }

  static RefundPriority _parseRefundPriority(String? priority) {
    switch (priority) {
      case 'RefundPriority.low':
        return RefundPriority.low;
      case 'RefundPriority.normal':
        return RefundPriority.normal;
      case 'RefundPriority.high':
        return RefundPriority.high;
      case 'RefundPriority.urgent':
        return RefundPriority.urgent;
      default:
        return RefundPriority.normal;
    }
  }
}

/// Refund Processing Result
class RefundProcessingResult {
  final String refundId;
  final RefundStatus status;
  final double processedAmount;
  final String? qpayRefundId;
  final String? transactionId;
  final String message;
  final DateTime processedAt;
  final Map<String, dynamic> details;
  final String? errorCode;
  final String? errorMessage;

  const RefundProcessingResult({
    required this.refundId,
    required this.status,
    required this.processedAmount,
    this.qpayRefundId,
    this.transactionId,
    required this.message,
    required this.processedAt,
    this.details = const {},
    this.errorCode,
    this.errorMessage,
  });

  bool get isSuccess =>
      status == RefundStatus.completed || status == RefundStatus.processing;
  bool get isFailure => status == RefundStatus.failed;
  bool get requiresManualReview => status == RefundStatus.requiresManualReview;
}

/// Refund Processing Service
class RefundProcessingService {
  static final RefundProcessingService _instance =
      RefundProcessingService._internal();
  factory RefundProcessingService() => _instance;
  RefundProcessingService._internal();

  final QPayService _qpayService = QPayService();
  final NotificationService _notificationService = NotificationService();

  RefundProcessingConfig _config = const RefundProcessingConfig();
  final Map<String, Timer> _processingTimers = {};
  final Map<String, Timer> _statusCheckTimers = {};
  final StreamController<RefundProcessingResult> _resultController =
      StreamController.broadcast();
  final StreamController<RefundRequest> _requestController =
      StreamController.broadcast();

  /// Initialize the refund processing service
  Future<void> initialize({RefundProcessingConfig? config}) async {
    _config = config ?? const RefundProcessingConfig();

    log('RefundProcessingService: Initialized with config: '
        'timeout=${_config.processingTimeout.inMinutes}min, '
        'autoApproval=${_config.enableAutomaticApproval}, '
        'threshold=${_config.autoApprovalThreshold}');

    // Resume pending refunds
    await _resumePendingRefunds();
  }

  /// Get refund processing results stream
  Stream<RefundProcessingResult> get processingResults =>
      _resultController.stream;

  /// Get refund request events stream
  Stream<RefundRequest> get refundRequests => _requestController.stream;

  /// Submit refund request
  Future<String> submitRefundRequest(RefundRequest request) async {
    try {
      log('RefundProcessingService: Submitting refund request ${request.id} for order ${request.orderId}');

      // Validate refund request
      await _validateRefundRequest(request);

      // Store refund request
      await _storeRefundRequest(request);

      // Emit request event
      _requestController.add(request);

      // Check if eligible for automatic approval
      if (_config.enableAutomaticApproval) {
        final autoApproved = await _checkAutoApprovalEligibility(request);
        if (autoApproved) {
          // Process immediately
          await _processRefundAutomatically(request);
        } else {
          // Mark for manual review
          await _markForManualReview(request);
        }
      } else {
        // All refunds require manual approval
        await _markForManualReview(request);
      }

      // Send notification to customer
      if (_config.enableCustomerNotifications) {
        await _sendRefundRequestNotification(request);
      }

      return request.id;
    } catch (e) {
      log('RefundProcessingService: Error submitting refund request ${request.id}: $e');
      throw Exception('Failed to submit refund request: $e');
    }
  }

  /// Approve refund request
  Future<RefundProcessingResult> approveRefund({
    required String refundId,
    required String approvedBy,
    String? approvalNotes,
  }) async {
    try {
      log('RefundProcessingService: Approving refund $refundId by $approvedBy');

      // Get refund request
      final request = await _getRefundRequest(refundId);
      if (request == null) {
        throw Exception('Refund request not found');
      }

      // Update refund status
      await _updateRefundStatus(refundId, RefundStatus.approved, {
        'approvedBy': approvedBy,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvalNotes': approvalNotes,
      });

      // Process refund
      return await _processRefund(request);
    } catch (e) {
      log('RefundProcessingService: Error approving refund $refundId: $e');
      throw Exception('Failed to approve refund: $e');
    }
  }

  /// Reject refund request
  Future<void> rejectRefund({
    required String refundId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    try {
      log('RefundProcessingService: Rejecting refund $refundId by $rejectedBy');

      // Get refund request
      final request = await _getRefundRequest(refundId);
      if (request == null) {
        throw Exception('Refund request not found');
      }

      // Update refund status
      await _updateRefundStatus(refundId, RefundStatus.cancelled, {
        'rejectedBy': rejectedBy,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': rejectionReason,
      });

      // Send notification to customer
      if (_config.enableCustomerNotifications) {
        await _sendRefundRejectionNotification(request, rejectionReason);
      }

      // Create result
      final result = RefundProcessingResult(
        refundId: refundId,
        status: RefundStatus.cancelled,
        processedAmount: 0,
        message: 'Refund request rejected: $rejectionReason',
        processedAt: DateTime.now(),
        details: {
          'rejectedBy': rejectedBy,
          'rejectionReason': rejectionReason,
        },
      );

      _resultController.add(result);
    } catch (e) {
      log('RefundProcessingService: Error rejecting refund $refundId: $e');
      throw Exception('Failed to reject refund: $e');
    }
  }

  /// Process refund automatically
  Future<void> _processRefundAutomatically(RefundRequest request) async {
    try {
      log('RefundProcessingService: Processing refund ${request.id} automatically');

      // Update status to approved
      await _updateRefundStatus(request.id, RefundStatus.approved, {
        'approvedBy': 'system',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvalNotes': 'Automatically approved based on criteria',
      });

      // Process refund
      await _processRefund(request);
    } catch (e) {
      log('RefundProcessingService: Error processing refund ${request.id} automatically: $e');
      rethrow;
    }
  }

  /// Process refund
  Future<RefundProcessingResult> _processRefund(RefundRequest request) async {
    try {
      log('RefundProcessingService: Processing refund ${request.id} for amount ${request.requestedAmount}');

      // Update status to processing
      await _updateRefundStatus(request.id, RefundStatus.processing, {
        'processingStartedAt': FieldValue.serverTimestamp(),
      });

      // Start processing timeout timer
      _startProcessingTimer(request);

      // Process refund through QPay
      final qpayResult = await _qpayService.processRefund(
        paymentId: request.paymentId,
        refundAmount: request.requestedAmount,
        reason: request.description,
        callbackUrl:
            'https://us-central1-shoppy-6d81f.cloudfunctions.net/refundWebhook',
        note: 'Refund for order ${request.orderId}',
      );

      RefundProcessingResult result;

      if (qpayResult.success) {
        // Refund initiated successfully
        result = RefundProcessingResult(
          refundId: request.id,
          status: RefundStatus.processing,
          processedAmount: request.requestedAmount,
          qpayRefundId: qpayResult.refundId,
          transactionId: qpayResult.paymentId,
          message: qpayResult.message ?? 'Refund processing initiated',
          processedAt: DateTime.now(),
          details: {
            'qpayStatus': qpayResult.status,
            'refundDate': qpayResult.refundDate?.toIso8601String(),
          },
        );

        // Update refund record
        await _updateRefundStatus(request.id, RefundStatus.processing, {
          'qpayRefundId': qpayResult.refundId,
          'qpayStatus': qpayResult.status,
          'processingAmount': request.requestedAmount,
          'processingStartedAt': FieldValue.serverTimestamp(),
        });

        // Start status monitoring
        _startStatusMonitoring(request.id, qpayResult.refundId ?? '');

        // Send processing notification
        if (_config.enableCustomerNotifications) {
          await _sendRefundProcessingNotification(request);
        }
      } else {
        // Refund failed
        result = RefundProcessingResult(
          refundId: request.id,
          status: RefundStatus.failed,
          processedAmount: 0,
          message: qpayResult.error ?? 'Refund processing failed',
          processedAt: DateTime.now(),
          errorCode: 'QPAY_REFUND_FAILED',
          errorMessage: qpayResult.error,
        );

        // Update refund record
        await _updateRefundStatus(request.id, RefundStatus.failed, {
          'failedAt': FieldValue.serverTimestamp(),
          'failureReason': qpayResult.error,
        });

        // Send failure notification
        if (_config.enableCustomerNotifications) {
          await _sendRefundFailureNotification(
              request, qpayResult.error ?? 'Unknown error');
        }
      }

      // Clean up processing timer
      _processingTimers[request.id]?.cancel();
      _processingTimers.remove(request.id);

      // Emit result
      _resultController.add(result);

      return result;
    } catch (e) {
      log('RefundProcessingService: Error processing refund ${request.id}: $e');

      // Update refund record
      await _updateRefundStatus(request.id, RefundStatus.failed, {
        'failedAt': FieldValue.serverTimestamp(),
        'failureReason': 'System error: $e',
      });

      // Clean up timers
      _processingTimers[request.id]?.cancel();
      _processingTimers.remove(request.id);

      final result = RefundProcessingResult(
        refundId: request.id,
        status: RefundStatus.failed,
        processedAmount: 0,
        message: 'Refund processing failed due to system error',
        processedAt: DateTime.now(),
        errorCode: 'SYSTEM_ERROR',
        errorMessage: e.toString(),
      );

      _resultController.add(result);
      return result;
    }
  }

  /// Start processing timeout timer
  void _startProcessingTimer(RefundRequest request) {
    _processingTimers[request.id] = Timer(_config.processingTimeout, () async {
      log('RefundProcessingService: Processing timeout for refund ${request.id}');

      // Mark refund as failed due to timeout
      await _updateRefundStatus(request.id, RefundStatus.failed, {
        'failedAt': FieldValue.serverTimestamp(),
        'failureReason': 'Processing timeout',
      });

      // Send timeout notification
      if (_config.enableCustomerNotifications) {
        await _sendRefundTimeoutNotification(request);
      }

      // Emit timeout result
      final result = RefundProcessingResult(
        refundId: request.id,
        status: RefundStatus.failed,
        processedAmount: 0,
        message: 'Refund processing timed out',
        processedAt: DateTime.now(),
        errorCode: 'PROCESSING_TIMEOUT',
        errorMessage: 'Refund processing exceeded timeout limit',
      );

      _resultController.add(result);
    });
  }

  /// Start status monitoring
  void _startStatusMonitoring(String refundId, String qpayRefundId) {
    _statusCheckTimers[refundId] = Timer.periodic(
      _config.statusCheckInterval,
      (timer) async {
        try {
          // Check refund status with QPay
          final statusResult =
              await _qpayService.checkPaymentStatus(qpayRefundId);

          if (statusResult.success) {
            if (statusResult.status == 'REFUNDED') {
              // Refund completed
              await _handleRefundCompleted(refundId, statusResult);
              timer.cancel();
              _statusCheckTimers.remove(refundId);
            } else if (statusResult.status == 'FAILED') {
              // Refund failed
              await _handleRefundFailed(refundId, 'QPay refund failed');
              timer.cancel();
              _statusCheckTimers.remove(refundId);
            }
          }
        } catch (e) {
          log('RefundProcessingService: Error checking refund status for $refundId: $e');
        }
      },
    );
  }

  /// Handle refund completed
  Future<void> _handleRefundCompleted(
      String refundId, QPayPaymentStatus status) async {
    try {
      log('RefundProcessingService: Refund $refundId completed');

      // Update refund record
      await _updateRefundStatus(refundId, RefundStatus.completed, {
        'completedAt': FieldValue.serverTimestamp(),
        'completedAmount': status.paidAmount ?? 0,
        'qpayStatus': status.status,
        'transactionId': status.paymentId,
      });

      // Get refund request
      final request = await _getRefundRequest(refundId);
      if (request != null) {
        // Update order status
        await _updateOrderAfterRefund(
            request.orderId, request.type, status.paidAmount ?? 0);

        // Send completion notification
        if (_config.enableCustomerNotifications) {
          await _sendRefundCompletionNotification(
              request, status.paidAmount ?? 0);
        }
      }

      // Emit completion result
      final result = RefundProcessingResult(
        refundId: refundId,
        status: RefundStatus.completed,
        processedAmount: status.paidAmount ?? 0,
        qpayRefundId: status.paymentId,
        transactionId: status.paymentId,
        message: 'Refund completed successfully',
        processedAt: DateTime.now(),
        details: {
          'completedAmount': status.paidAmount ?? 0,
          'qpayStatus': status.status,
        },
      );

      _resultController.add(result);
    } catch (e) {
      log('RefundProcessingService: Error handling refund completion for $refundId: $e');
    }
  }

  /// Handle refund failed
  Future<void> _handleRefundFailed(String refundId, String reason) async {
    try {
      log('RefundProcessingService: Refund $refundId failed: $reason');

      // Update refund record
      await _updateRefundStatus(refundId, RefundStatus.failed, {
        'failedAt': FieldValue.serverTimestamp(),
        'failureReason': reason,
      });

      // Get refund request
      final request = await _getRefundRequest(refundId);
      if (request != null) {
        // Send failure notification
        if (_config.enableCustomerNotifications) {
          await _sendRefundFailureNotification(request, reason);
        }
      }

      // Emit failure result
      final result = RefundProcessingResult(
        refundId: refundId,
        status: RefundStatus.failed,
        processedAmount: 0,
        message: 'Refund failed: $reason',
        processedAt: DateTime.now(),
        errorCode: 'REFUND_FAILED',
        errorMessage: reason,
      );

      _resultController.add(result);
    } catch (e) {
      log('RefundProcessingService: Error handling refund failure for $refundId: $e');
    }
  }

  /// Validate refund request
  Future<void> _validateRefundRequest(RefundRequest request) async {
    // Check if order exists
    final orderDoc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(request.orderId)
        .get();

    if (!orderDoc.exists) {
      throw Exception('Order not found');
    }

    final orderData = orderDoc.data()!;
    final orderTotal = (orderData['total'] as num?)?.toDouble() ?? 0;

    // Check if refund amount is valid
    if (request.requestedAmount <= 0) {
      throw Exception('Refund amount must be greater than 0');
    }

    if (request.requestedAmount > orderTotal) {
      throw Exception('Refund amount cannot exceed order total');
    }

    // Check if order is refundable
    final orderStatus = orderData['status'] as String?;
    if (orderStatus == 'cancelled' || orderStatus == 'refunded') {
      throw Exception('Order is not refundable');
    }

    // Check for existing refunds
    final existingRefundsSnapshot = await FirebaseFirestore.instance
        .collection('refunds')
        .where('orderId', isEqualTo: request.orderId)
        .where('status',
            whereIn: ['pending', 'approved', 'processing', 'completed']).get();

    final existingRefundAmount = existingRefundsSnapshot.docs.fold<double>(
      0,
      (total, doc) =>
          total + ((doc.data()['requestedAmount'] as num?)?.toDouble() ?? 0),
    );

    if (existingRefundAmount + request.requestedAmount > orderTotal) {
      throw Exception('Total refund amount would exceed order total');
    }
  }

  /// Check auto-approval eligibility
  Future<bool> _checkAutoApprovalEligibility(RefundRequest request) async {
    // Check amount threshold
    if (request.requestedAmount > _config.autoApprovalThreshold) {
      return false;
    }

    // Check if reason is in auto-approval list
    final reasonString = request.reason.toString().split('.').last;
    if (!_config.autoApprovalReasons.contains(reasonString)) {
      return false;
    }

    // Check customer history (optional)
    final customerRefundHistory =
        await _getCustomerRefundHistory(request.customerUserId);
    if (customerRefundHistory.length > 5) {
      // Too many refunds, require manual review
      return false;
    }

    return true;
  }

  /// Get customer refund history
  Future<List<Map<String, dynamic>>> _getCustomerRefundHistory(
      String customerUserId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('refunds')
          .where('customerUserId', isEqualTo: customerUserId)
          .orderBy('requestedAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      log('RefundProcessingService: Error getting customer refund history: $e');
      return [];
    }
  }

  /// Store refund request
  Future<void> _storeRefundRequest(RefundRequest request) async {
    try {
      await FirebaseFirestore.instance
          .collection('refunds')
          .doc(request.id)
          .set({
        ...request.toMap(),
        'status': RefundStatus.pending.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('RefundProcessingService: Error storing refund request: $e');
      rethrow;
    }
  }

  /// Update refund status
  Future<void> _updateRefundStatus(
    String refundId,
    RefundStatus status,
    Map<String, dynamic> additionalData,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('refunds')
          .doc(refundId)
          .update({
        'status': status.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        ...additionalData,
      });
    } catch (e) {
      log('RefundProcessingService: Error updating refund status: $e');
      rethrow;
    }
  }

  /// Get refund request
  Future<RefundRequest?> _getRefundRequest(String refundId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('refunds')
          .doc(refundId)
          .get();

      return doc.exists ? RefundRequest.fromMap(doc.data()!) : null;
    } catch (e) {
      log('RefundProcessingService: Error getting refund request: $e');
      return null;
    }
  }

  /// Mark for manual review
  Future<void> _markForManualReview(RefundRequest request) async {
    await _updateRefundStatus(request.id, RefundStatus.requiresManualReview, {
      'reviewRequiredAt': FieldValue.serverTimestamp(),
      'reviewReason': 'Does not meet auto-approval criteria',
    });
  }

  /// Update order after refund
  Future<void> _updateOrderAfterRefund(
      String orderId, RefundType type, double amount) async {
    try {
      final orderRef =
          FirebaseFirestore.instance.collection('orders').doc(orderId);
      final orderDoc = await orderRef.get();

      if (orderDoc.exists) {
        Map<String, dynamic> updates = {
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (type == RefundType.full) {
          updates['status'] = 'refunded';
          updates['refundedAmount'] = amount;
          updates['refundedAt'] = FieldValue.serverTimestamp();
        } else {
          updates['status'] = 'partially_refunded';
          updates['refundedAmount'] = FieldValue.increment(amount);
          updates['partialRefundAt'] = FieldValue.serverTimestamp();
        }

        await orderRef.update(updates);
      }
    } catch (e) {
      log('RefundProcessingService: Error updating order after refund: $e');
    }
  }

  /// Send refund request notification
  Future<void> _sendRefundRequestNotification(RefundRequest request) async {
    try {
      await _notificationService.sendNotification(
        userId: request.customerUserId,
        title: 'Refund Request Received',
        message:
            'We have received your refund request for order ${request.orderId}',
        type: 'refund_request',
        data: {
          'refundId': request.id,
          'orderId': request.orderId,
          'amount': request.requestedAmount,
          'type': request.type.toString(),
        },
      );
    } catch (e) {
      log('RefundProcessingService: Error sending refund request notification: $e');
    }
  }

  /// Send refund processing notification
  Future<void> _sendRefundProcessingNotification(RefundRequest request) async {
    try {
      await _notificationService.sendNotification(
        userId: request.customerUserId,
        title: 'Refund Processing',
        message: 'Your refund for order ${request.orderId} is being processed',
        type: 'refund_processing',
        data: {
          'refundId': request.id,
          'orderId': request.orderId,
          'amount': request.requestedAmount,
        },
      );
    } catch (e) {
      log('RefundProcessingService: Error sending refund processing notification: $e');
    }
  }

  /// Send refund completion notification
  Future<void> _sendRefundCompletionNotification(
      RefundRequest request, double amount) async {
    try {
      await _notificationService.sendNotification(
        userId: request.customerUserId,
        title: 'Refund Completed',
        message:
            'Your refund of ₮${amount.toStringAsFixed(0)} for order ${request.orderId} has been completed',
        type: 'refund_completed',
        data: {
          'refundId': request.id,
          'orderId': request.orderId,
          'amount': amount,
        },
      );
    } catch (e) {
      log('RefundProcessingService: Error sending refund completion notification: $e');
    }
  }

  /// Send refund failure notification
  Future<void> _sendRefundFailureNotification(
      RefundRequest request, String reason) async {
    try {
      await _notificationService.sendNotification(
        userId: request.customerUserId,
        title: 'Refund Failed',
        message:
            'Your refund for order ${request.orderId} could not be processed. Reason: $reason',
        type: 'refund_failed',
        data: {
          'refundId': request.id,
          'orderId': request.orderId,
          'reason': reason,
        },
      );
    } catch (e) {
      log('RefundProcessingService: Error sending refund failure notification: $e');
    }
  }

  /// Send refund rejection notification
  Future<void> _sendRefundRejectionNotification(
      RefundRequest request, String reason) async {
    try {
      await _notificationService.sendNotification(
        userId: request.customerUserId,
        title: 'Refund Request Rejected',
        message:
            'Your refund request for order ${request.orderId} has been rejected. Reason: $reason',
        type: 'refund_rejected',
        data: {
          'refundId': request.id,
          'orderId': request.orderId,
          'reason': reason,
        },
      );
    } catch (e) {
      log('RefundProcessingService: Error sending refund rejection notification: $e');
    }
  }

  /// Send refund timeout notification
  Future<void> _sendRefundTimeoutNotification(RefundRequest request) async {
    try {
      await _notificationService.sendNotification(
        userId: request.customerUserId,
        title: 'Refund Processing Timeout',
        message:
            'Your refund for order ${request.orderId} encountered a timeout. Please contact support.',
        type: 'refund_timeout',
        data: {
          'refundId': request.id,
          'orderId': request.orderId,
        },
      );
    } catch (e) {
      log('RefundProcessingService: Error sending refund timeout notification: $e');
    }
  }

  /// Resume pending refunds
  Future<void> _resumePendingRefunds() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('refunds')
          .where('status', whereIn: ['pending', 'processing']).get();

      for (final doc in snapshot.docs) {
        final refundData = doc.data();
        final refundId = doc.id;
        final status = refundData['status'] as String?;

        if (status == 'processing') {
          // Resume status monitoring
          final qpayRefundId = refundData['qpayRefundId'] as String?;
          if (qpayRefundId != null) {
            _startStatusMonitoring(refundId, qpayRefundId);
          }
        }
      }
    } catch (e) {
      log('RefundProcessingService: Error resuming pending refunds: $e');
    }
  }

  /// Get refund analytics
  Future<Map<String, dynamic>> getRefundAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = FirebaseFirestore.instance.collection('refunds');

      if (startDate != null) {
        query = query.where('requestedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('requestedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      final refunds = snapshot.docs.map((doc) => doc.data()).toList();

      final totalRefunds = refunds.length;
      final completedRefunds = refunds
          .where((r) =>
              (r as Map<String, dynamic>?)?['status'] ==
              RefundStatus.completed.toString())
          .length;
      final failedRefunds = refunds
          .where((r) =>
              (r as Map<String, dynamic>?)?['status'] ==
              RefundStatus.failed.toString())
          .length;
      final pendingRefunds = refunds
          .where((r) =>
              (r as Map<String, dynamic>?)?['status'] ==
              RefundStatus.pending.toString())
          .length;

      final totalAmount = refunds.fold<double>(
          0,
          (total, r) =>
              total +
              (((r as Map<String, dynamic>?)?['requestedAmount'] as num?)
                      ?.toDouble() ??
                  0));
      final completedAmount = refunds
          .where((r) =>
              (r as Map<String, dynamic>?)?['status'] ==
              RefundStatus.completed.toString())
          .fold<double>(
              0,
              (total, r) =>
                  total +
                  (((r as Map<String, dynamic>?)?['requestedAmount'] as num?)
                          ?.toDouble() ??
                      0));

      final successRate =
          totalRefunds > 0 ? (completedRefunds / totalRefunds) * 100 : 0.0;
      final failureRate =
          totalRefunds > 0 ? (failedRefunds / totalRefunds) * 100 : 0.0;

      return {
        'totalRefunds': totalRefunds,
        'completedRefunds': completedRefunds,
        'failedRefunds': failedRefunds,
        'pendingRefunds': pendingRefunds,
        'totalAmount': totalAmount,
        'completedAmount': completedAmount,
        'successRate': successRate,
        'failureRate': failureRate,
        'averageRefundAmount':
            totalRefunds > 0 ? totalAmount / totalRefunds : 0,
        'period': {
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
        },
      };
    } catch (e) {
      log('RefundProcessingService: Error getting refund analytics: $e');
      return {};
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    // Cancel all timers
    for (final timer in _processingTimers.values) {
      timer.cancel();
    }
    _processingTimers.clear();

    for (final timer in _statusCheckTimers.values) {
      timer.cancel();
    }
    _statusCheckTimers.clear();

    // Close controllers
    await _resultController.close();
    await _requestController.close();
  }
}

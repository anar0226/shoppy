import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'qpay_service.dart';
import '../../features/notifications/notification_service.dart';

/// Reconciliation Configuration
class ReconciliationConfig {
  final Duration reconciliationInterval;
  final Duration reconciliationWindow;
  final bool enableAutomaticResolution;
  final bool enableNotifications;
  final double amountTolerancePercentage;
  final int maxRetryAttempts;
  final Duration retryInterval;

  const ReconciliationConfig({
    this.reconciliationInterval = const Duration(minutes: 15),
    this.reconciliationWindow = const Duration(hours: 24),
    this.enableAutomaticResolution = true,
    this.enableNotifications = true,
    this.amountTolerancePercentage = 0.01, // 1% tolerance
    this.maxRetryAttempts = 3,
    this.retryInterval = const Duration(minutes: 5),
  });
}

/// Reconciliation Status
enum ReconciliationStatus {
  pending,
  inProgress,
  completed,
  failed,
  partiallyReconciled,
  requiresManualReview,
}

/// Discrepancy Type
enum DiscrepancyType {
  missingPayment,
  extraPayment,
  amountMismatch,
  statusMismatch,
  timingMismatch,
  duplicatePayment,
  refundMismatch,
}

/// Discrepancy Severity
enum DiscrepancySeverity {
  low,
  medium,
  high,
  critical,
}

/// Resolution Status
enum ResolutionStatus {
  pending,
  inProgress,
  resolved,
  failed,
  requiresManualIntervention,
}

/// Payment Discrepancy
class PaymentDiscrepancy {
  final String id;
  final String paymentId;
  final String orderId;
  final DiscrepancyType type;
  final DiscrepancySeverity severity;
  final String description;
  final double expectedAmount;
  final double actualAmount;
  final String expectedStatus;
  final String actualStatus;
  final DateTime detectedAt;
  final Map<String, dynamic> metadata;
  final ResolutionStatus resolutionStatus;
  final String? resolutionDetails;
  final DateTime? resolvedAt;

  const PaymentDiscrepancy({
    required this.id,
    required this.paymentId,
    required this.orderId,
    required this.type,
    required this.severity,
    required this.description,
    required this.expectedAmount,
    required this.actualAmount,
    required this.expectedStatus,
    required this.actualStatus,
    required this.detectedAt,
    required this.metadata,
    this.resolutionStatus = ResolutionStatus.pending,
    this.resolutionDetails,
    this.resolvedAt,
  });

  PaymentDiscrepancy copyWith({
    ResolutionStatus? resolutionStatus,
    String? resolutionDetails,
    DateTime? resolvedAt,
  }) {
    return PaymentDiscrepancy(
      id: id,
      paymentId: paymentId,
      orderId: orderId,
      type: type,
      severity: severity,
      description: description,
      expectedAmount: expectedAmount,
      actualAmount: actualAmount,
      expectedStatus: expectedStatus,
      actualStatus: actualStatus,
      detectedAt: detectedAt,
      metadata: metadata,
      resolutionStatus: resolutionStatus ?? this.resolutionStatus,
      resolutionDetails: resolutionDetails ?? this.resolutionDetails,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

/// Reconciliation Report
class ReconciliationReport {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final ReconciliationStatus status;
  final int totalPayments;
  final int reconciledPayments;
  final int discrepancies;
  final double totalAmount;
  final double reconciledAmount;
  final double discrepancyAmount;
  final List<PaymentDiscrepancy> discrepanciesList;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> statistics;

  const ReconciliationReport({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.totalPayments,
    required this.reconciledPayments,
    required this.discrepancies,
    required this.totalAmount,
    required this.reconciledAmount,
    required this.discrepancyAmount,
    required this.discrepanciesList,
    required this.summary,
    required this.statistics,
  });

  double get reconciliationRate =>
      totalPayments > 0 ? (reconciledPayments / totalPayments) * 100 : 0.0;

  double get discrepancyRate =>
      totalPayments > 0 ? (discrepancies / totalPayments) * 100 : 0.0;

  double get amountAccuracy =>
      totalAmount > 0 ? (reconciledAmount / totalAmount) * 100 : 0.0;
}

/// Payment Reconciliation Service
class PaymentReconciliationService {
  static final PaymentReconciliationService _instance =
      PaymentReconciliationService._internal();
  factory PaymentReconciliationService() => _instance;
  PaymentReconciliationService._internal();

  final QPayService _qpayService = QPayService();
  final NotificationService _notificationService = NotificationService();

  ReconciliationConfig _config = const ReconciliationConfig();
  Timer? _reconciliationTimer;
  final Map<String, PaymentDiscrepancy> _activeDiscrepancies = {};
  final StreamController<ReconciliationReport> _reportController =
      StreamController.broadcast();
  final StreamController<PaymentDiscrepancy> _discrepancyController =
      StreamController.broadcast();

  /// Initialize the reconciliation service
  Future<void> initialize({ReconciliationConfig? config}) async {
    _config = config ?? const ReconciliationConfig();

    log('PaymentReconciliationService: Initialized with config: '
        'interval=${_config.reconciliationInterval.inMinutes}min, '
        'window=${_config.reconciliationWindow.inHours}h');

    // Start periodic reconciliation
    _startPeriodicReconciliation();

    // Resume pending reconciliations
    await _resumePendingReconciliations();
  }

  /// Get reconciliation reports stream
  Stream<ReconciliationReport> get reconciliationReports =>
      _reportController.stream;

  /// Get discrepancy events stream
  Stream<PaymentDiscrepancy> get discrepancyEvents =>
      _discrepancyController.stream;

  /// Start periodic reconciliation
  void _startPeriodicReconciliation() {
    _reconciliationTimer?.cancel();
    _reconciliationTimer =
        Timer.periodic(_config.reconciliationInterval, (timer) {
      _performAutomaticReconciliation();
    });
  }

  /// Perform automatic reconciliation
  Future<void> _performAutomaticReconciliation() async {
    try {
      log('PaymentReconciliationService: Starting automatic reconciliation');

      final endTime = DateTime.now();
      final startTime = endTime.subtract(_config.reconciliationWindow);

      await performReconciliation(
        startTime: startTime,
        endTime: endTime,
        automatic: true,
      );
    } catch (e) {
      log('PaymentReconciliationService: Error in automatic reconciliation: $e');
    }
  }

  /// Perform manual reconciliation
  Future<ReconciliationReport> performReconciliation({
    required DateTime startTime,
    required DateTime endTime,
    bool automatic = false,
    String? objectType,
    String? objectId,
  }) async {
    final reportId = 'reconciliation_${DateTime.now().millisecondsSinceEpoch}';

    try {
      log('PaymentReconciliationService: Starting reconciliation $reportId '
          'from ${startTime.toIso8601String()} to ${endTime.toIso8601String()}');

      // Create reconciliation record
      await _createReconciliationRecord(
        reportId: reportId,
        startTime: startTime,
        endTime: endTime,
        automatic: automatic,
        objectType: objectType,
        objectId: objectId,
      );

      // Get local payments from database
      final localPayments = await _getLocalPayments(startTime, endTime);

      // Get QPay payments
      final qpayPayments =
          await _getQPayPayments(startTime, endTime, objectType, objectId);

      // Perform reconciliation analysis
      final reconciliationResult = await _analyzePayments(
        localPayments: localPayments,
        qpayPayments: qpayPayments,
        startTime: startTime,
        endTime: endTime,
      );

      // Process discrepancies
      await _processDiscrepancies(
        reportId: reportId,
        discrepancies: reconciliationResult['discrepancies'],
        automatic: automatic,
      );

      // Create reconciliation report
      final report = ReconciliationReport(
        id: reportId,
        startTime: startTime,
        endTime: endTime,
        status: reconciliationResult['status'],
        totalPayments: reconciliationResult['totalPayments'],
        reconciledPayments: reconciliationResult['reconciledPayments'],
        discrepancies: reconciliationResult['discrepancies'].length,
        totalAmount: reconciliationResult['totalAmount'],
        reconciledAmount: reconciliationResult['reconciledAmount'],
        discrepancyAmount: reconciliationResult['discrepancyAmount'],
        discrepanciesList: reconciliationResult['discrepancies'],
        summary: reconciliationResult['summary'],
        statistics: reconciliationResult['statistics'],
      );

      // Store report
      await _storeReconciliationReport(report);

      // Send notifications if enabled
      if (_config.enableNotifications) {
        await _sendReconciliationNotifications(report);
      }

      // Emit report
      _reportController.add(report);

      log('PaymentReconciliationService: Reconciliation $reportId completed with '
          '${report.discrepancies} discrepancies');

      return report;
    } catch (e) {
      log('PaymentReconciliationService: Error in reconciliation $reportId: $e');

      // Create error report
      final errorReport = ReconciliationReport(
        id: reportId,
        startTime: startTime,
        endTime: endTime,
        status: ReconciliationStatus.failed,
        totalPayments: 0,
        reconciledPayments: 0,
        discrepancies: 0,
        totalAmount: 0,
        reconciledAmount: 0,
        discrepancyAmount: 0,
        discrepanciesList: [],
        summary: {'error': e.toString()},
        statistics: {},
      );

      await _storeReconciliationReport(errorReport);
      _reportController.add(errorReport);

      throw Exception('Reconciliation failed: $e');
    }
  }

  /// Analyze payments for reconciliation
  Future<Map<String, dynamic>> _analyzePayments({
    required List<Map<String, dynamic>> localPayments,
    required List<QPayPaymentRecord> qpayPayments,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final discrepancies = <PaymentDiscrepancy>[];
    final reconciledPayments = <Map<String, dynamic>>[];

    double totalAmount = 0;
    double reconciledAmount = 0;
    double discrepancyAmount = 0;

    // Create lookup maps for efficient matching
    final localPaymentMap = <String, Map<String, dynamic>>{};
    final qpayPaymentMap = <String, QPayPaymentRecord>{};

    for (final payment in localPayments) {
      final paymentId =
          payment['paymentId'] as String? ?? payment['id'] as String;
      localPaymentMap[paymentId] = payment;
      totalAmount += (payment['amount'] as num?)?.toDouble() ?? 0;
    }

    for (final payment in qpayPayments) {
      qpayPaymentMap[payment.paymentId] = payment;
    }

    // Check for missing payments in QPay
    for (final localPayment in localPayments) {
      final paymentId =
          localPayment['paymentId'] as String? ?? localPayment['id'] as String;
      final qpayPayment = qpayPaymentMap[paymentId];

      if (qpayPayment == null) {
        // Missing payment in QPay
        discrepancies.add(PaymentDiscrepancy(
          id: 'missing_qpay_$paymentId',
          paymentId: paymentId,
          orderId: localPayment['orderId'] as String? ?? '',
          type: DiscrepancyType.missingPayment,
          severity: DiscrepancySeverity.high,
          description: 'Payment found in local database but missing in QPay',
          expectedAmount: (localPayment['amount'] as num?)?.toDouble() ?? 0,
          actualAmount: 0,
          expectedStatus: localPayment['status'] as String? ?? 'UNKNOWN',
          actualStatus: 'MISSING',
          detectedAt: DateTime.now(),
          metadata: {
            'localPayment': localPayment,
            'reconciliationPeriod':
                '${startTime.toIso8601String()} - ${endTime.toIso8601String()}',
          },
        ));

        discrepancyAmount += (localPayment['amount'] as num?)?.toDouble() ?? 0;
      } else {
        // Payment found in both systems, check for discrepancies
        final localAmount = (localPayment['amount'] as num?)?.toDouble() ?? 0;
        final qpayAmount = qpayPayment.amount;
        final localStatus = localPayment['status'] as String? ?? 'UNKNOWN';
        final qpayStatus = qpayPayment.status;

        bool hasDiscrepancy = false;
        final discrepancyReasons = <String>[];

        // Check amount discrepancy
        if ((localAmount - qpayAmount).abs() >
            localAmount * _config.amountTolerancePercentage) {
          hasDiscrepancy = true;
          discrepancyReasons
              .add('Amount mismatch: local=$localAmount, qpay=$qpayAmount');
        }

        // Check status discrepancy
        if (_normalizeStatus(localStatus) != _normalizeStatus(qpayStatus)) {
          hasDiscrepancy = true;
          discrepancyReasons
              .add('Status mismatch: local=$localStatus, qpay=$qpayStatus');
        }

        if (hasDiscrepancy) {
          discrepancies.add(PaymentDiscrepancy(
            id: 'mismatch_$paymentId',
            paymentId: paymentId,
            orderId: localPayment['orderId'] as String? ?? '',
            type: discrepancyReasons.length > 1
                ? DiscrepancyType.amountMismatch
                : discrepancyReasons.first.contains('Amount')
                    ? DiscrepancyType.amountMismatch
                    : DiscrepancyType.statusMismatch,
            severity: discrepancyReasons.first.contains('Amount')
                ? DiscrepancySeverity.high
                : DiscrepancySeverity.medium,
            description: discrepancyReasons.join(', '),
            expectedAmount: localAmount,
            actualAmount: qpayAmount,
            expectedStatus: localStatus,
            actualStatus: qpayStatus,
            detectedAt: DateTime.now(),
            metadata: {
              'localPayment': localPayment,
              'qpayPayment': {
                'paymentId': qpayPayment.paymentId,
                'amount': qpayPayment.amount,
                'status': qpayPayment.status,
                'currency': qpayPayment.currency,
                'paymentMethod': qpayPayment.paymentMethod,
                'paymentDate': qpayPayment.paymentDate?.toIso8601String(),
              },
              'discrepancyReasons': discrepancyReasons,
            },
          ));

          discrepancyAmount += (localAmount - qpayAmount).abs();
        } else {
          // Payment reconciled successfully
          reconciledPayments.add(localPayment);
          reconciledAmount += localAmount;
        }
      }
    }

    // Check for extra payments in QPay
    for (final qpayPayment in qpayPayments) {
      if (!localPaymentMap.containsKey(qpayPayment.paymentId)) {
        discrepancies.add(PaymentDiscrepancy(
          id: 'extra_qpay_${qpayPayment.paymentId}',
          paymentId: qpayPayment.paymentId,
          orderId: qpayPayment.objectId,
          type: DiscrepancyType.extraPayment,
          severity: DiscrepancySeverity.medium,
          description: 'Payment found in QPay but missing in local database',
          expectedAmount: 0,
          actualAmount: qpayPayment.amount,
          expectedStatus: 'MISSING',
          actualStatus: qpayPayment.status,
          detectedAt: DateTime.now(),
          metadata: {
            'qpayPayment': {
              'paymentId': qpayPayment.paymentId,
              'amount': qpayPayment.amount,
              'status': qpayPayment.status,
              'currency': qpayPayment.currency,
              'paymentMethod': qpayPayment.paymentMethod,
              'paymentDate': qpayPayment.paymentDate?.toIso8601String(),
            },
            'reconciliationPeriod':
                '${startTime.toIso8601String()} - ${endTime.toIso8601String()}',
          },
        ));

        discrepancyAmount += qpayPayment.amount;
      }
    }

    // Determine reconciliation status
    ReconciliationStatus status;
    if (discrepancies.isEmpty) {
      status = ReconciliationStatus.completed;
    } else if (discrepancies
        .any((d) => d.severity == DiscrepancySeverity.critical)) {
      status = ReconciliationStatus.requiresManualReview;
    } else if (reconciledPayments.isNotEmpty) {
      status = ReconciliationStatus.partiallyReconciled;
    } else {
      status = ReconciliationStatus.failed;
    }

    // Create summary
    final summary = {
      'reconciliationRate': reconciledPayments.length /
          (localPayments.isNotEmpty ? localPayments.length : 1) *
          100,
      'discrepancyRate': discrepancies.length /
          (localPayments.isNotEmpty ? localPayments.length : 1) *
          100,
      'amountAccuracy':
          totalAmount > 0 ? (reconciledAmount / totalAmount) * 100 : 0,
      'discrepancyByType': _groupDiscrepanciesByType(discrepancies),
      'discrepancyBySeverity': _groupDiscrepanciesBySeverity(discrepancies),
    };

    // Create statistics
    final statistics = {
      'processingTime': DateTime.now().millisecondsSinceEpoch,
      'localPaymentsCount': localPayments.length,
      'qpayPaymentsCount': qpayPayments.length,
      'matchedPayments': reconciledPayments.length,
      'unmatchedPayments': discrepancies.length,
      'totalAmountProcessed': totalAmount,
      'reconciledAmountProcessed': reconciledAmount,
      'discrepancyAmountProcessed': discrepancyAmount,
    };

    return {
      'status': status,
      'totalPayments': localPayments.length,
      'reconciledPayments': reconciledPayments.length,
      'discrepancies': discrepancies,
      'totalAmount': totalAmount,
      'reconciledAmount': reconciledAmount,
      'discrepancyAmount': discrepancyAmount,
      'summary': summary,
      'statistics': statistics,
    };
  }

  /// Process discrepancies
  Future<void> _processDiscrepancies({
    required String reportId,
    required List<PaymentDiscrepancy> discrepancies,
    required bool automatic,
  }) async {
    for (final discrepancy in discrepancies) {
      try {
        // Store discrepancy
        await _storeDiscrepancy(discrepancy);

        // Add to active discrepancies
        _activeDiscrepancies[discrepancy.id] = discrepancy;

        // Emit discrepancy event
        _discrepancyController.add(discrepancy);

        // Attempt automatic resolution if enabled
        if (_config.enableAutomaticResolution && automatic) {
          await _attemptAutomaticResolution(discrepancy);
        }
      } catch (e) {
        log('PaymentReconciliationService: Error processing discrepancy ${discrepancy.id}: $e');
      }
    }
  }

  /// Attempt automatic resolution
  Future<void> _attemptAutomaticResolution(
      PaymentDiscrepancy discrepancy) async {
    try {
      log('PaymentReconciliationService: Attempting automatic resolution for discrepancy ${discrepancy.id}');

      switch (discrepancy.type) {
        case DiscrepancyType.missingPayment:
          await _resolveMissingPayment(discrepancy);
          break;
        case DiscrepancyType.extraPayment:
          await _resolveExtraPayment(discrepancy);
          break;
        case DiscrepancyType.amountMismatch:
          await _resolveAmountMismatch(discrepancy);
          break;
        case DiscrepancyType.statusMismatch:
          await _resolveStatusMismatch(discrepancy);
          break;
        default:
          log('PaymentReconciliationService: No automatic resolution available for discrepancy type ${discrepancy.type}');
      }
    } catch (e) {
      log('PaymentReconciliationService: Error in automatic resolution for discrepancy ${discrepancy.id}: $e');

      // Update discrepancy status
      await _updateDiscrepancyStatus(
        discrepancy.id,
        ResolutionStatus.failed,
        'Automatic resolution failed: $e',
      );
    }
  }

  /// Resolve missing payment discrepancy
  Future<void> _resolveMissingPayment(PaymentDiscrepancy discrepancy) async {
    // Check if payment exists in QPay with different identifier
    final qpayPayments = await _qpayService.getPaymentHistory(
      objectType: 'INVOICE',
      objectId: discrepancy.orderId,
      pageLimit: 50,
    );

    if (qpayPayments.success && qpayPayments.payments != null) {
      final matchingPayment = qpayPayments.payments!.firstWhere(
        (p) =>
            (p.amount - discrepancy.expectedAmount).abs() <
            discrepancy.expectedAmount * _config.amountTolerancePercentage,
        orElse: () => QPayPaymentRecord.empty(),
      );

      if (matchingPayment.paymentId.isNotEmpty) {
        // Found matching payment, update local record
        await _updateLocalPaymentRecord(
          discrepancy.paymentId,
          matchingPayment.paymentId,
        );

        await _updateDiscrepancyStatus(
          discrepancy.id,
          ResolutionStatus.resolved,
          'Found matching payment in QPay with ID: ${matchingPayment.paymentId}',
        );

        log('PaymentReconciliationService: Resolved missing payment discrepancy ${discrepancy.id}');
      } else {
        await _updateDiscrepancyStatus(
          discrepancy.id,
          ResolutionStatus.requiresManualIntervention,
          'Payment not found in QPay - requires manual investigation',
        );
      }
    }
  }

  /// Resolve extra payment discrepancy
  Future<void> _resolveExtraPayment(PaymentDiscrepancy discrepancy) async {
    // Check if there's a corresponding local order
    final localOrder =
        await _findLocalOrderByQPayPayment(discrepancy.paymentId);

    if (localOrder != null) {
      // Create local payment record
      await _createLocalPaymentRecord(
        discrepancy.paymentId,
        localOrder,
        discrepancy.actualAmount,
        discrepancy.actualStatus,
      );

      await _updateDiscrepancyStatus(
        discrepancy.id,
        ResolutionStatus.resolved,
        'Created local payment record for QPay payment',
      );

      log('PaymentReconciliationService: Resolved extra payment discrepancy ${discrepancy.id}');
    } else {
      await _updateDiscrepancyStatus(
        discrepancy.id,
        ResolutionStatus.requiresManualIntervention,
        'No corresponding local order found - requires manual investigation',
      );
    }
  }

  /// Resolve amount mismatch discrepancy
  Future<void> _resolveAmountMismatch(PaymentDiscrepancy discrepancy) async {
    // Check if the discrepancy is within acceptable tolerance after fees
    final qpayPayment = await _getQPayPaymentDetails(discrepancy.paymentId);

    if (qpayPayment != null) {
      // Check if difference is due to fees or currency conversion
      final feeAmount = discrepancy.expectedAmount * 0.02; // Assume 2% fee
      final adjustedAmount = discrepancy.expectedAmount - feeAmount;

      if ((adjustedAmount - discrepancy.actualAmount).abs() <
          discrepancy.expectedAmount * _config.amountTolerancePercentage) {
        // Update local record with fee adjustment
        await _updateLocalPaymentAmount(
          discrepancy.paymentId,
          discrepancy.actualAmount,
          'Adjusted for payment gateway fees',
        );

        await _updateDiscrepancyStatus(
          discrepancy.id,
          ResolutionStatus.resolved,
          'Amount difference resolved - payment gateway fees applied',
        );

        log('PaymentReconciliationService: Resolved amount mismatch discrepancy ${discrepancy.id}');
      } else {
        await _updateDiscrepancyStatus(
          discrepancy.id,
          ResolutionStatus.requiresManualIntervention,
          'Amount difference exceeds tolerance - requires manual review',
        );
      }
    }
  }

  /// Resolve status mismatch discrepancy
  Future<void> _resolveStatusMismatch(PaymentDiscrepancy discrepancy) async {
    // Get latest payment status from QPay
    final qpayStatus =
        await _qpayService.checkPaymentStatus(discrepancy.paymentId);

    if (qpayStatus.success && qpayStatus.status != null) {
      // Update local payment status
      await _updateLocalPaymentStatus(
        discrepancy.paymentId,
        qpayStatus.status!,
        'Updated from QPay status check',
      );

      await _updateDiscrepancyStatus(
        discrepancy.id,
        ResolutionStatus.resolved,
        'Status synchronized with QPay: ${qpayStatus.status}',
      );

      log('PaymentReconciliationService: Resolved status mismatch discrepancy ${discrepancy.id}');
    } else {
      await _updateDiscrepancyStatus(
        discrepancy.id,
        ResolutionStatus.failed,
        'Failed to get payment status from QPay',
      );
    }
  }

  /// Get local payments
  Future<List<Map<String, dynamic>>> _getLocalPayments(
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
          .where('payment.method', isEqualTo: 'qpay')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'paymentId': data['payment']?['qpayPaymentId'] ?? doc.id,
          'orderId': doc.id,
          'amount': data['total'] ?? 0,
          'status': data['payment']?['status'] ?? 'UNKNOWN',
          'createdAt': data['createdAt'],
          'paymentData': data['payment'],
        };
      }).toList();
    } catch (e) {
      log('PaymentReconciliationService: Error getting local payments: $e');
      return [];
    }
  }

  /// Get QPay payments
  Future<List<QPayPaymentRecord>> _getQPayPayments(
    DateTime startTime,
    DateTime endTime,
    String? objectType,
    String? objectId,
  ) async {
    try {
      // For comprehensive reconciliation, get all payments
      final result = await _qpayService.getPaymentHistory(
        objectType: objectType ?? 'MERCHANT',
        objectId: objectId ?? 'default',
        pageLimit: 1000,
      );

      if (result.success && result.payments != null) {
        // Filter by date range
        return result.payments!.where((payment) {
          final paymentDate = payment.paymentDate;
          return paymentDate != null &&
              paymentDate.isAfter(startTime) &&
              paymentDate.isBefore(endTime);
        }).toList();
      }

      return [];
    } catch (e) {
      log('PaymentReconciliationService: Error getting QPay payments: $e');
      return [];
    }
  }

  /// Normalize payment status
  String _normalizeStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
      case 'COMPLETED':
      case 'SUCCESS':
        return 'PAID';
      case 'FAILED':
      case 'DECLINED':
      case 'ERROR':
        return 'FAILED';
      case 'PENDING':
      case 'PROCESSING':
        return 'PENDING';
      case 'CANCELLED':
      case 'CANCELED':
        return 'CANCELLED';
      case 'REFUNDED':
        return 'REFUNDED';
      default:
        return status.toUpperCase();
    }
  }

  /// Group discrepancies by type
  Map<String, int> _groupDiscrepanciesByType(
      List<PaymentDiscrepancy> discrepancies) {
    final groups = <String, int>{};
    for (final discrepancy in discrepancies) {
      groups[discrepancy.type.toString()] =
          (groups[discrepancy.type.toString()] ?? 0) + 1;
    }
    return groups;
  }

  /// Group discrepancies by severity
  Map<String, int> _groupDiscrepanciesBySeverity(
      List<PaymentDiscrepancy> discrepancies) {
    final groups = <String, int>{};
    for (final discrepancy in discrepancies) {
      groups[discrepancy.severity.toString()] =
          (groups[discrepancy.severity.toString()] ?? 0) + 1;
    }
    return groups;
  }

  /// Store reconciliation record
  Future<void> _createReconciliationRecord({
    required String reportId,
    required DateTime startTime,
    required DateTime endTime,
    required bool automatic,
    String? objectType,
    String? objectId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_reconciliations')
          .doc(reportId)
          .set({
        'reportId': reportId,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'automatic': automatic,
        'objectType': objectType,
        'objectId': objectId,
        'status': ReconciliationStatus.inProgress.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('PaymentReconciliationService: Error creating reconciliation record: $e');
      rethrow;
    }
  }

  /// Store reconciliation report
  Future<void> _storeReconciliationReport(ReconciliationReport report) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_reconciliations')
          .doc(report.id)
          .update({
        'status': report.status.toString(),
        'totalPayments': report.totalPayments,
        'reconciledPayments': report.reconciledPayments,
        'discrepancies': report.discrepancies,
        'totalAmount': report.totalAmount,
        'reconciledAmount': report.reconciledAmount,
        'discrepancyAmount': report.discrepancyAmount,
        'reconciliationRate': report.reconciliationRate,
        'discrepancyRate': report.discrepancyRate,
        'amountAccuracy': report.amountAccuracy,
        'summary': report.summary,
        'statistics': report.statistics,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('PaymentReconciliationService: Error storing reconciliation report: $e');
      rethrow;
    }
  }

  /// Store discrepancy
  Future<void> _storeDiscrepancy(PaymentDiscrepancy discrepancy) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_discrepancies')
          .doc(discrepancy.id)
          .set({
        'id': discrepancy.id,
        'paymentId': discrepancy.paymentId,
        'orderId': discrepancy.orderId,
        'type': discrepancy.type.toString(),
        'severity': discrepancy.severity.toString(),
        'description': discrepancy.description,
        'expectedAmount': discrepancy.expectedAmount,
        'actualAmount': discrepancy.actualAmount,
        'expectedStatus': discrepancy.expectedStatus,
        'actualStatus': discrepancy.actualStatus,
        'detectedAt': Timestamp.fromDate(discrepancy.detectedAt),
        'metadata': discrepancy.metadata,
        'resolutionStatus': discrepancy.resolutionStatus.toString(),
        'resolutionDetails': discrepancy.resolutionDetails,
        'resolvedAt': discrepancy.resolvedAt != null
            ? Timestamp.fromDate(discrepancy.resolvedAt!)
            : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('PaymentReconciliationService: Error storing discrepancy: $e');
      rethrow;
    }
  }

  /// Update discrepancy status
  Future<void> _updateDiscrepancyStatus(
    String discrepancyId,
    ResolutionStatus status,
    String details,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_discrepancies')
          .doc(discrepancyId)
          .update({
        'resolutionStatus': status.toString(),
        'resolutionDetails': details,
        'resolvedAt': status == ResolutionStatus.resolved
            ? FieldValue.serverTimestamp()
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update in-memory record
      if (_activeDiscrepancies.containsKey(discrepancyId)) {
        _activeDiscrepancies[discrepancyId] =
            _activeDiscrepancies[discrepancyId]!.copyWith(
          resolutionStatus: status,
          resolutionDetails: details,
          resolvedAt:
              status == ResolutionStatus.resolved ? DateTime.now() : null,
        );
      }
    } catch (e) {
      log('PaymentReconciliationService: Error updating discrepancy status: $e');
      rethrow;
    }
  }

  /// Helper methods for resolution
  Future<void> _updateLocalPaymentRecord(
      String paymentId, String qpayPaymentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .where('payment.qpayPaymentId', isEqualTo: paymentId)
          .get()
          .then((snapshot) async {
        for (final doc in snapshot.docs) {
          await doc.reference.update({
            'payment.qpayPaymentId': qpayPaymentId,
            'payment.updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      log('PaymentReconciliationService: Error updating local payment record: $e');
    }
  }

  Future<Map<String, dynamic>?> _findLocalOrderByQPayPayment(
      String paymentId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('payment.qpayPaymentId', isEqualTo: paymentId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }
      return null;
    } catch (e) {
      log('PaymentReconciliationService: Error finding local order: $e');
      return null;
    }
  }

  Future<void> _createLocalPaymentRecord(
    String paymentId,
    Map<String, dynamic> order,
    double amount,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order['id'])
          .update({
        'payment.qpayPaymentId': paymentId,
        'payment.amount': amount,
        'payment.status': status,
        'payment.method': 'qpay',
        'payment.createdAt': FieldValue.serverTimestamp(),
        'payment.updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('PaymentReconciliationService: Error creating local payment record: $e');
    }
  }

  Future<QPayPaymentRecord?> _getQPayPaymentDetails(String paymentId) async {
    try {
      final status = await _qpayService.checkPaymentStatus(paymentId);
      if (status.success) {
        return QPayPaymentRecord(
          paymentId: paymentId,
          status: status.status ?? 'UNKNOWN',
          amount: status.paidAmount ?? 0,
          currency: status.currency ?? 'MNT',
          paymentMethod: status.paymentMethod ?? 'UNKNOWN',
          paymentDate: status.paidDate,
          objectType: 'INVOICE',
          objectId: paymentId,
        );
      }
      return null;
    } catch (e) {
      log('PaymentReconciliationService: Error getting QPay payment details: $e');
      return null;
    }
  }

  Future<void> _updateLocalPaymentAmount(
    String paymentId,
    double amount,
    String reason,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .where('payment.qpayPaymentId', isEqualTo: paymentId)
          .get()
          .then((snapshot) async {
        for (final doc in snapshot.docs) {
          await doc.reference.update({
            'payment.amount': amount,
            'payment.adjustmentReason': reason,
            'payment.updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      log('PaymentReconciliationService: Error updating local payment amount: $e');
    }
  }

  Future<void> _updateLocalPaymentStatus(
    String paymentId,
    String status,
    String reason,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .where('payment.qpayPaymentId', isEqualTo: paymentId)
          .get()
          .then((snapshot) async {
        for (final doc in snapshot.docs) {
          await doc.reference.update({
            'payment.status': status,
            'payment.statusReason': reason,
            'payment.updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      log('PaymentReconciliationService: Error updating local payment status: $e');
    }
  }

  /// Send reconciliation notifications
  Future<void> _sendReconciliationNotifications(
      ReconciliationReport report) async {
    try {
      // Send notifications to relevant stakeholders
      if (report.discrepancies > 0) {
        await _notificationService.sendNotification(
          userId: 'admin',
          title: 'Payment Reconciliation Alert',
          message:
              'Found ${report.discrepancies} payment discrepancies requiring attention',
          type: 'reconciliation_alert',
          data: {
            'reportId': report.id,
            'discrepancies': report.discrepancies,
            'discrepancyAmount': report.discrepancyAmount,
            'reconciliationRate': report.reconciliationRate,
          },
        );
      }
    } catch (e) {
      log('PaymentReconciliationService: Error sending reconciliation notifications: $e');
    }
  }

  /// Resume pending reconciliations
  Future<void> _resumePendingReconciliations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payment_reconciliations')
          .where('status',
              isEqualTo: ReconciliationStatus.inProgress.toString())
          .get();

      for (final doc in snapshot.docs) {
        // Resume or mark as failed based on age
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null &&
            DateTime.now().difference(createdAt).inHours > 1) {
          // Mark as failed if older than 1 hour
          await doc.reference.update({
            'status': ReconciliationStatus.failed.toString(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      log('PaymentReconciliationService: Error resuming pending reconciliations: $e');
    }
  }

  /// Get reconciliation analytics
  Future<Map<String, dynamic>> getReconciliationAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query =
          FirebaseFirestore.instance.collection('payment_reconciliations');

      if (startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      final reports = snapshot.docs.map((doc) => doc.data()).toList();

      final totalReconciliations = reports.length;
      final completedReconciliations = reports
          .where((r) =>
              (r as Map<String, dynamic>?)?['status'] ==
              ReconciliationStatus.completed.toString())
          .length;
      final totalDiscrepancies = reports.fold<int>(
          0,
          (accumulator, r) =>
              accumulator +
              ((r as Map<String, dynamic>?)?['discrepancies'] as int? ?? 0));
      final totalAmount = reports.fold<double>(
          0,
          (accumulator, r) =>
              accumulator +
              ((r as Map<String, dynamic>?)?['totalAmount'] as double? ?? 0));
      final reconciledAmount = reports.fold<double>(
          0,
          (accumulator, r) =>
              accumulator +
              ((r as Map<String, dynamic>?)?['reconciledAmount'] as double? ??
                  0));

      final successRate = totalReconciliations > 0
          ? (completedReconciliations / totalReconciliations) * 100
          : 0.0;
      final overallReconciliationRate =
          totalAmount > 0 ? (reconciledAmount / totalAmount) * 100 : 0.0;

      return {
        'totalReconciliations': totalReconciliations,
        'completedReconciliations': completedReconciliations,
        'totalDiscrepancies': totalDiscrepancies,
        'totalAmount': totalAmount,
        'reconciledAmount': reconciledAmount,
        'successRate': successRate,
        'overallReconciliationRate': overallReconciliationRate,
        'averageDiscrepanciesPerReconciliation': totalReconciliations > 0
            ? totalDiscrepancies / totalReconciliations
            : 0,
        'period': {
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
        },
      };
    } catch (e) {
      log('PaymentReconciliationService: Error getting reconciliation analytics: $e');
      return {};
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _reconciliationTimer?.cancel();
    _activeDiscrepancies.clear();

    await _reportController.close();
    await _discrepancyController.close();
  }
}

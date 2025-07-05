import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payout_model.dart';

/// Service for managing vendor payouts and financial operations
class PayoutService {
  static final PayoutService _instance = PayoutService._internal();
  factory PayoutService() => _instance;
  PayoutService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // **PAYOUT REQUEST MANAGEMENT**

  /// Create a payout request for a vendor
  Future<String> createPayoutRequest({
    required String vendorId,
    required String storeId,
    required double amount,
    required PayoutMethod method,
    String? bankAccount,
    String? mobileWallet,
    String? notes,
    List<String>? specificTransactionIds,
  }) async {
    try {
      // Validate vendor eligibility
      final profile = await getVendorFinancialProfile(vendorId);
      if (!profile.isEligibleForPayouts) {
        throw Exception(
            'Vendor is not eligible for payouts: ${profile.blockedReasons.join(', ')}');
      }

      if (amount < profile.minimumPayoutThreshold) {
        throw Exception(
            'Amount below minimum payout threshold (${profile.minimumPayoutThreshold})');
      }

      if (amount > profile.availableBalance) {
        throw Exception(
            'Insufficient available balance (${profile.availableBalance})');
      }

      // Get commission transactions to include in payout
      final transactionIds = specificTransactionIds ??
          await _getUnpaidCommissionTransactions(vendorId, amount);

      // Calculate platform fee (typically 2-3% of payout)
      final platformFee = amount * 0.025; // 2.5% platform fee
      final netAmount = amount - platformFee;

      // Create payout request
      final payoutRequest = PayoutRequest(
        id: '', // Will be set by Firestore
        vendorId: vendorId,
        storeId: storeId,
        amount: amount,
        platformFee: platformFee,
        netAmount: netAmount,
        currency: 'MNT',
        status: PayoutStatus.pending,
        method: method,
        bankAccount: bankAccount,
        mobileWallet: mobileWallet,
        transactionIds: transactionIds,
        requestDate: DateTime.now(),
        notes: notes,
        metadata: {
          'requestedBy': _auth.currentUser?.uid,
          'automaticPayout': specificTransactionIds == null,
        },
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection('payout_requests')
          .add(payoutRequest.toFirestore());

      // Update vendor financial profile
      await _updateVendorFinancialProfile(vendorId, {
        'pendingBalance': FieldValue.increment(amount),
        'availableBalance': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mark commission transactions as pending payout
      await _markTransactionsAsPendingPayout(transactionIds, docRef.id);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create payout request: $e');
    }
  }

  /// Get payout requests for a vendor
  Future<List<PayoutRequest>> getVendorPayoutRequests(String vendorId) async {
    try {
      final querySnapshot = await _firestore
          .collection('payout_requests')
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('requestDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PayoutRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get payout requests: $e');
    }
  }

  /// Get all payout requests (Super Admin)
  Future<List<PayoutRequest>> getAllPayoutRequests({
    PayoutStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection('payout_requests');

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      if (startDate != null) {
        query = query.where('requestDate', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('requestDate', isLessThanOrEqualTo: endDate);
      }

      final querySnapshot = await query
          .orderBy('requestDate', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => PayoutRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get payout requests: $e');
    }
  }

  /// Process payout request (mark as completed/failed)
  Future<void> processPayoutRequest(
    String payoutId, {
    required PayoutStatus status,
    String? failureReason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.name,
        'processedDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (failureReason != null) {
        updateData['failureReason'] = failureReason;
      }

      if (metadata != null) {
        updateData['metadata'] = metadata;
      }

      await _firestore
          .collection('payout_requests')
          .doc(payoutId)
          .update(updateData);

      // Update related data based on status
      if (status == PayoutStatus.completed) {
        await _handleSuccessfulPayout(payoutId);
      } else if (status.isFailed) {
        await _handleFailedPayout(payoutId);
      }
    } catch (e) {
      throw Exception('Failed to process payout request: $e');
    }
  }

  // **PAYOUT SCHEDULING**

  /// Create payout schedule for automated payments
  Future<String> createPayoutSchedule({
    required String vendorId,
    required String storeId,
    required PayoutFrequency frequency,
    required int dayOfWeek,
    required int dayOfMonth,
    required double minimumAmount,
    required PayoutMethod method,
    String? bankAccount,
    String? mobileWallet,
  }) async {
    try {
      final schedule = PayoutSchedule(
        id: '',
        vendorId: vendorId,
        storeId: storeId,
        frequency: frequency,
        dayOfWeek: dayOfWeek,
        dayOfMonth: dayOfMonth,
        minimumAmount: minimumAmount,
        method: method,
        bankAccount: bankAccount,
        mobileWallet: mobileWallet,
        isActive: true,
        createdAt: DateTime.now(),
        nextPayoutDate:
            _calculateNextPayoutDate(frequency, dayOfWeek, dayOfMonth),
      );

      final docRef = await _firestore
          .collection('payout_schedules')
          .add(schedule.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create payout schedule: $e');
    }
  }

  /// Get payout schedule for vendor
  Future<PayoutSchedule?> getVendorPayoutSchedule(String vendorId) async {
    try {
      final querySnapshot = await _firestore
          .collection('payout_schedules')
          .where('vendorId', isEqualTo: vendorId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return PayoutSchedule.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to get payout schedule: $e');
    }
  }

  /// Process scheduled payouts (called by Cloud Function)
  Future<List<String>> processScheduledPayouts() async {
    try {
      final now = DateTime.now();
      final processedPayouts = <String>[];

      // Get all active schedules that are due
      final querySnapshot = await _firestore
          .collection('payout_schedules')
          .where('isActive', isEqualTo: true)
          .where('nextPayoutDate', isLessThanOrEqualTo: now)
          .get();

      for (final doc in querySnapshot.docs) {
        try {
          final schedule = PayoutSchedule.fromFirestore(doc);
          final profile = await getVendorFinancialProfile(schedule.vendorId);

          // Check if vendor has sufficient balance
          if (profile.availableBalance >= schedule.minimumAmount) {
            // Create automatic payout request
            final payoutId = await createPayoutRequest(
              vendorId: schedule.vendorId,
              storeId: schedule.storeId,
              amount: profile.availableBalance,
              method: schedule.method,
              bankAccount: schedule.bankAccount,
              mobileWallet: schedule.mobileWallet,
              notes: 'Automatic scheduled payout',
            );

            processedPayouts.add(payoutId);

            // Update next payout date
            final nextDate = _calculateNextPayoutDate(
              schedule.frequency,
              schedule.dayOfWeek,
              schedule.dayOfMonth,
            );

            await doc.reference.update({
              'lastPayoutDate': FieldValue.serverTimestamp(),
              'nextPayoutDate': Timestamp.fromDate(nextDate),
            });
          }
        } catch (e) {
          print('Error processing schedule ${doc.id}: $e');
        }
      }

      return processedPayouts;
    } catch (e) {
      throw Exception('Failed to process scheduled payouts: $e');
    }
  }

  // **VENDOR FINANCIAL MANAGEMENT**

  /// Get vendor financial profile
  Future<VendorFinancialProfile> getVendorFinancialProfile(
      String vendorId) async {
    try {
      final doc = await _firestore
          .collection('vendor_financial_profiles')
          .doc(vendorId)
          .get();

      if (!doc.exists) {
        // Create default profile if doesn't exist
        return await _createDefaultFinancialProfile(vendorId);
      }

      return VendorFinancialProfile.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get vendor financial profile: $e');
    }
  }

  /// Update vendor financial profile
  Future<void> updateVendorFinancialProfile(
    String vendorId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _updateVendorFinancialProfile(vendorId, {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update vendor financial profile: $e');
    }
  }

  // **PAYOUT ANALYTICS**

  /// Get payout analytics for platform (Super Admin)
  Future<PayoutAnalytics> getPayoutAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('payout_requests');

      if (startDate != null) {
        query = query.where('requestDate', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('requestDate', isLessThanOrEqualTo: endDate);
      }

      final querySnapshot = await query.get();
      final payouts = querySnapshot.docs
          .map((doc) => PayoutRequest.fromFirestore(doc))
          .toList();

      // Calculate analytics
      double totalPayouts = 0;
      double pendingPayouts = 0;
      double completedPayouts = 0;
      double failedPayouts = 0;
      double platformFeesCollected = 0;

      int totalRequests = payouts.length;
      int pendingRequests = 0;
      int completedRequests = 0;
      int failedRequests = 0;

      final payoutsByMethod = <String, double>{};
      final payoutsByFrequency = <String, double>{};

      for (final payout in payouts) {
        totalPayouts += payout.amount;
        platformFeesCollected += payout.platformFee;

        switch (payout.status) {
          case PayoutStatus.completed:
            completedPayouts += payout.amount;
            completedRequests++;
            break;
          case PayoutStatus.pending:
          case PayoutStatus.scheduled:
          case PayoutStatus.processing:
            pendingPayouts += payout.amount;
            pendingRequests++;
            break;
          case PayoutStatus.failed:
          case PayoutStatus.cancelled:
            failedPayouts += payout.amount;
            failedRequests++;
            break;
          default:
            break;
        }

        // Group by method
        final methodName = payout.method.displayName;
        payoutsByMethod[methodName] =
            (payoutsByMethod[methodName] ?? 0) + payout.amount;
      }

      final averagePayoutAmount =
          totalRequests > 0 ? (totalPayouts / totalRequests).toDouble() : 0.0;

      return PayoutAnalytics(
        totalPayouts: totalPayouts,
        pendingPayouts: pendingPayouts,
        completedPayouts: completedPayouts,
        failedPayouts: failedPayouts,
        totalRequests: totalRequests,
        pendingRequests: pendingRequests,
        completedRequests: completedRequests,
        failedRequests: failedRequests,
        averagePayoutAmount: averagePayoutAmount,
        platformFeesCollected: platformFeesCollected,
        payoutsByMethod: payoutsByMethod,
        payoutsByFrequency: payoutsByFrequency,
        trends: [], // Will be calculated separately
      );
    } catch (e) {
      throw Exception('Failed to get payout analytics: $e');
    }
  }

  // **PRIVATE HELPER METHODS**

  Future<List<String>> _getUnpaidCommissionTransactions(
      String vendorId, double maxAmount) async {
    final querySnapshot = await _firestore
        .collection('commission_transactions')
        .where('vendorId', isEqualTo: vendorId)
        .where('status', isEqualTo: 'calculated')
        .orderBy('createdAt')
        .get();

    final transactionIds = <String>[];
    double totalAmount = 0;

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final vendorAmount = (data['vendorAmount'] ?? 0).toDouble();

      if (totalAmount + vendorAmount <= maxAmount) {
        transactionIds.add(doc.id);
        totalAmount += vendorAmount;
      } else {
        break;
      }
    }

    return transactionIds;
  }

  Future<void> _markTransactionsAsPendingPayout(
      List<String> transactionIds, String payoutId) async {
    final batch = _firestore.batch();

    for (final transactionId in transactionIds) {
      final ref =
          _firestore.collection('commission_transactions').doc(transactionId);
      batch.update(ref, {
        'status': 'pending_payout',
        'payoutId': payoutId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> _updateVendorFinancialProfile(
      String vendorId, Map<String, dynamic> updates) async {
    await _firestore
        .collection('vendor_financial_profiles')
        .doc(vendorId)
        .update(updates);
  }

  Future<VendorFinancialProfile> _createDefaultFinancialProfile(
      String vendorId) async {
    // Get store ID for vendor
    final storeQuery = await _firestore
        .collection('stores')
        .where('ownerId', isEqualTo: vendorId)
        .limit(1)
        .get();

    final storeId = storeQuery.docs.isNotEmpty ? storeQuery.docs.first.id : '';

    final profile = VendorFinancialProfile(
      vendorId: vendorId,
      storeId: storeId,
      totalEarned: 0,
      totalWithdrawn: 0,
      pendingBalance: 0,
      availableBalance: 0,
      minimumPayoutThreshold: 50, // $50 minimum
      preferredMethod: PayoutMethod.bankTransfer,
      isEligibleForPayouts: true,
      blockedReasons: [],
      lastPayoutDate: DateTime.now().subtract(const Duration(days: 365)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection('vendor_financial_profiles')
        .doc(vendorId)
        .set(profile.toFirestore());

    return profile;
  }

  DateTime _calculateNextPayoutDate(
      PayoutFrequency frequency, int dayOfWeek, int dayOfMonth) {
    final now = DateTime.now();

    switch (frequency) {
      case PayoutFrequency.daily:
        return DateTime(now.year, now.month, now.day + 1);

      case PayoutFrequency.weekly:
        final daysUntilTarget = (dayOfWeek - now.weekday + 7) % 7;
        final nextDate =
            now.add(Duration(days: daysUntilTarget == 0 ? 7 : daysUntilTarget));
        return DateTime(nextDate.year, nextDate.month, nextDate.day);

      case PayoutFrequency.monthly:
        var nextMonth = now.month + 1;
        var nextYear = now.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        final targetDay =
            dayOfMonth.clamp(1, DateTime(nextYear, nextMonth + 1, 0).day);
        return DateTime(nextYear, nextMonth, targetDay);

      case PayoutFrequency.quarterly:
        var nextQuarter = ((now.month - 1) ~/ 3 + 1) * 3 + 1;
        var nextYear = now.year;
        if (nextQuarter > 12) {
          nextQuarter = 1;
          nextYear++;
        }
        return DateTime(nextYear, nextQuarter, dayOfMonth.clamp(1, 28));

      default:
        return now.add(const Duration(days: 30)); // Default to monthly
    }
  }

  Future<void> _handleSuccessfulPayout(String payoutId) async {
    try {
      // Get payout details
      final payoutDoc =
          await _firestore.collection('payout_requests').doc(payoutId).get();
      final payout = PayoutRequest.fromFirestore(payoutDoc);

      // Update vendor financial profile
      await _updateVendorFinancialProfile(payout.vendorId, {
        'totalWithdrawn': FieldValue.increment(payout.amount),
        'pendingBalance': FieldValue.increment(-payout.amount),
        'lastPayoutDate': FieldValue.serverTimestamp(),
      });

      // Mark commission transactions as paid
      final batch = _firestore.batch();
      for (final transactionId in payout.transactionIds) {
        final ref =
            _firestore.collection('commission_transactions').doc(transactionId);
        batch.update(ref, {
          'status': 'paid',
          'paidAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error handling successful payout: $e');
    }
  }

  Future<void> _handleFailedPayout(String payoutId) async {
    try {
      // Get payout details
      final payoutDoc =
          await _firestore.collection('payout_requests').doc(payoutId).get();
      final payout = PayoutRequest.fromFirestore(payoutDoc);

      // Restore vendor balance
      await _updateVendorFinancialProfile(payout.vendorId, {
        'pendingBalance': FieldValue.increment(-payout.amount),
        'availableBalance': FieldValue.increment(payout.amount),
      });

      // Mark commission transactions as calculated again
      final batch = _firestore.batch();
      for (final transactionId in payout.transactionIds) {
        final ref =
            _firestore.collection('commission_transactions').doc(transactionId);
        batch.update(ref, {
          'status': 'calculated',
          'payoutId': FieldValue.delete(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error handling failed payout: $e');
    }
  }
}

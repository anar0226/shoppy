import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/commission_model.dart';

class CommissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final CommissionService _instance = CommissionService._internal();
  factory CommissionService() => _instance;
  CommissionService._internal();

  static const String _rulesCollection = 'commission_rules';
  static const String _transactionsCollection = 'commission_transactions';

  // **COMMISSION RULES MANAGEMENT**

  /// Create a new commission rule
  Future<String> createCommissionRule(CommissionRule rule) async {
    try {
      final docRef =
          await _firestore.collection(_rulesCollection).add(rule.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create commission rule: $e');
    }
  }

  /// Update an existing commission rule
  Future<void> updateCommissionRule(String ruleId, CommissionRule rule) async {
    try {
      await _firestore
          .collection(_rulesCollection)
          .doc(ruleId)
          .update(rule.toMap());
    } catch (e) {
      throw Exception('Failed to update commission rule: $e');
    }
  }

  /// Delete a commission rule
  Future<void> deleteCommissionRule(String ruleId) async {
    try {
      await _firestore.collection(_rulesCollection).doc(ruleId).update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to delete commission rule: $e');
    }
  }

  /// Get all commission rules
  Stream<List<CommissionRule>> getCommissionRules({bool activeOnly = true}) {
    Query query = _firestore.collection(_rulesCollection);

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => CommissionRule.fromFirestore(doc))
            .toList());
  }

  /// Get commission rules for a specific store
  Stream<List<CommissionRule>> getStoreCommissionRules(String storeId) {
    return _firestore
        .collection(_rulesCollection)
        .where('isActive', isEqualTo: true)
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommissionRule.fromFirestore(doc))
            .toList());
  }

  /// Get the applicable commission rule for an order
  Future<CommissionRule?> getApplicableCommissionRule({
    required String storeId,
    required String category,
    required double orderValue,
  }) async {
    try {
      // Priority order: Store-specific > Category-specific > Global

      // 1. Check for store-specific rule
      final storeRules = await _firestore
          .collection(_rulesCollection)
          .where('isActive', isEqualTo: true)
          .where('storeId', isEqualTo: storeId)
          .where('minOrderValue', isLessThanOrEqualTo: orderValue)
          .orderBy('minOrderValue', descending: true)
          .limit(1)
          .get();

      if (storeRules.docs.isNotEmpty) {
        return CommissionRule.fromFirestore(storeRules.docs.first);
      }

      // 2. Check for category-specific rule
      final categoryRules = await _firestore
          .collection(_rulesCollection)
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category)
          .where('storeId', isNull: true)
          .where('minOrderValue', isLessThanOrEqualTo: orderValue)
          .orderBy('minOrderValue', descending: true)
          .limit(1)
          .get();

      if (categoryRules.docs.isNotEmpty) {
        return CommissionRule.fromFirestore(categoryRules.docs.first);
      }

      // 3. Check for global rule
      final globalRules = await _firestore
          .collection(_rulesCollection)
          .where('isActive', isEqualTo: true)
          .where('storeId', isNull: true)
          .where('category', isNull: true)
          .where('minOrderValue', isLessThanOrEqualTo: orderValue)
          .orderBy('minOrderValue', descending: true)
          .limit(1)
          .get();

      if (globalRules.docs.isNotEmpty) {
        return CommissionRule.fromFirestore(globalRules.docs.first);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to get applicable commission rule: $e');
    }
  }

  // **COMMISSION TRANSACTIONS**

  /// Create a commission transaction for an order
  Future<String> createCommissionTransaction({
    required String orderId,
    required String storeId,
    required String vendorId,
    required double orderTotal,
    required String category,
  }) async {
    try {
      // Get applicable commission rule
      final rule = await getApplicableCommissionRule(
        storeId: storeId,
        category: category,
        orderValue: orderTotal,
      );

      if (rule == null) {
        throw Exception('No applicable commission rule found');
      }

      // Calculate commission
      final commissionAmount = rule.calculateCommission(orderTotal);
      final vendorAmount = orderTotal - commissionAmount;

      // Create transaction
      final transaction = CommissionTransaction(
        id: '', // Will be set by Firestore
        orderId: orderId,
        storeId: storeId,
        vendorId: vendorId,
        ruleId: rule.id,
        orderTotal: orderTotal,
        commissionAmount: commissionAmount,
        vendorAmount: vendorAmount,
        status: CommissionStatus.calculated,
        createdAt: DateTime.now(),
        metadata: {
          'commissionRule': {
            'type': rule.type.toString().split('.').last,
            'value': rule.value,
            'category': rule.category,
          },
        },
      );

      final docRef = await _firestore
          .collection(_transactionsCollection)
          .add(transaction.toMap());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create commission transaction: $e');
    }
  }

  /// Update commission transaction status
  Future<void> updateCommissionTransactionStatus({
    required String transactionId,
    required CommissionStatus status,
    String? paymentReference,
  }) async {
    try {
      final updateData = {
        'status': status.toString().split('.').last,
        'updatedAt': Timestamp.now(),
      };

      if (status == CommissionStatus.paid) {
        updateData['paidAt'] = Timestamp.now();
        if (paymentReference != null) {
          updateData['paymentReference'] = paymentReference;
        }
      }

      await _firestore
          .collection(_transactionsCollection)
          .doc(transactionId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update commission transaction: $e');
    }
  }

  /// Get commission transactions for a store
  Stream<List<CommissionTransaction>> getStoreCommissionTransactions(
    String storeId, {
    CommissionStatus? status,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection(_transactionsCollection)
        .where('storeId', isEqualTo: storeId);

    if (status != null) {
      query =
          query.where('status', isEqualTo: status.toString().split('.').last);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommissionTransaction.fromFirestore(doc))
            .toList());
  }

  /// Get all commission transactions (Super Admin)
  Stream<List<CommissionTransaction>> getAllCommissionTransactions({
    CommissionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) {
    Query query = _firestore.collection(_transactionsCollection);

    if (status != null) {
      query =
          query.where('status', isEqualTo: status.toString().split('.').last);
    }

    if (startDate != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommissionTransaction.fromFirestore(doc))
            .toList());
  }

  // **COMMISSION ANALYTICS**

  /// Get commission summary for a period
  Future<CommissionSummary> getCommissionSummary({
    String? storeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      Query query = _firestore.collection(_transactionsCollection);

      if (storeId != null) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      query = query
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));

      final snapshot = await query.get();

      double totalCommissionEarned = 0.0;
      double totalVendorPayouts = 0.0;
      double pendingCommissions = 0.0;
      double paidCommissions = 0.0;
      int totalTransactions = 0;
      int pendingTransactions = 0;

      for (final doc in snapshot.docs) {
        final transaction = CommissionTransaction.fromFirestore(doc);

        totalCommissionEarned += transaction.commissionAmount;
        totalVendorPayouts += transaction.vendorAmount;
        totalTransactions++;

        if (transaction.status == CommissionStatus.pending) {
          pendingCommissions += transaction.commissionAmount;
          pendingTransactions++;
        } else if (transaction.status == CommissionStatus.paid) {
          paidCommissions += transaction.commissionAmount;
        }
      }

      return CommissionSummary(
        totalCommissionEarned: totalCommissionEarned,
        totalVendorPayouts: totalVendorPayouts,
        pendingCommissions: pendingCommissions,
        paidCommissions: paidCommissions,
        totalTransactions: totalTransactions,
        pendingTransactions: pendingTransactions,
        periodStart: start,
        periodEnd: end,
      );
    } catch (e) {
      throw Exception('Failed to get commission summary: $e');
    }
  }

  /// Get commission trends over time
  Future<List<Map<String, dynamic>>> getCommissionTrends({
    String? storeId,
    DateTime? startDate,
    DateTime? endDate,
    String granularity = 'daily', // daily, weekly, monthly
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      Query query = _firestore.collection(_transactionsCollection);

      if (storeId != null) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      query = query
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('createdAt');

      final snapshot = await query.get();

      // Group transactions by period
      final groupedData = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final transaction = CommissionTransaction.fromFirestore(doc);
        final date = transaction.createdAt;

        String periodKey;
        switch (granularity) {
          case 'weekly':
            final weekStart = date.subtract(Duration(days: date.weekday - 1));
            periodKey = '${weekStart.year}-W${_getWeekNumber(weekStart)}';
            break;
          case 'monthly':
            periodKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
            break;
          default: // daily
            periodKey =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }

        if (!groupedData.containsKey(periodKey)) {
          groupedData[periodKey] = {
            'period': periodKey,
            'date': date,
            'commission': 0.0,
            'transactions': 0,
            'vendorPayouts': 0.0,
          };
        }

        groupedData[periodKey]!['commission'] += transaction.commissionAmount;
        groupedData[periodKey]!['transactions'] += 1;
        groupedData[periodKey]!['vendorPayouts'] += transaction.vendorAmount;
      }

      return groupedData.values.toList()
        ..sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    } catch (e) {
      throw Exception('Failed to get commission trends: $e');
    }
  }

  /// Get top earning stores by commission
  Future<List<Map<String, dynamic>>> getTopEarningStores({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 10,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final storeCommissions = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final transaction = CommissionTransaction.fromFirestore(doc);

        if (!storeCommissions.containsKey(transaction.storeId)) {
          storeCommissions[transaction.storeId] = {
            'storeId': transaction.storeId,
            'totalCommission': 0.0,
            'totalOrders': 0,
            'totalRevenue': 0.0,
            'averageCommission': 0.0,
          };
        }

        final store = storeCommissions[transaction.storeId]!;
        store['totalCommission'] += transaction.commissionAmount;
        store['totalOrders'] += 1;
        store['totalRevenue'] += transaction.orderTotal;
      }

      // Calculate averages and sort
      final result = storeCommissions.values.toList();
      for (final store in result) {
        store['averageCommission'] = store['totalOrders'] > 0
            ? store['totalCommission'] / store['totalOrders']
            : 0.0;
      }

      result.sort((a, b) => (b['totalCommission'] as double)
          .compareTo(a['totalCommission'] as double));

      return result.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get top earning stores: $e');
    }
  }

  // **HELPER METHODS**

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday) / 7).ceil();
  }

  /// Get commission transaction by order ID
  Future<CommissionTransaction?> getCommissionTransactionByOrderId(
      String orderId) async {
    try {
      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return CommissionTransaction.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to get commission transaction: $e');
    }
  }

  /// Create default commission rules for new marketplace
  Future<void> createDefaultCommissionRules(String superAdminId) async {
    try {
      // Default global rule: 5% commission
      final globalRule = CommissionRule(
        id: '',
        type: CommissionType.percentage,
        value: 5.0, // 5%
        minOrderValue: 0.0,
        maxCommission: 100.0, // $100 cap
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: superAdminId,
      );

      await createCommissionRule(globalRule);
    } catch (e) {
      throw Exception('Failed to create default commission rules: $e');
    }
  }
}

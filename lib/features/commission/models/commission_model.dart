import 'package:cloud_firestore/cloud_firestore.dart';

enum CommissionType {
  percentage,
  fixedAmount,
  tiered,
}

enum CommissionStatus {
  pending,
  calculated,
  paid,
  disputed,
}

class CommissionRule {
  final String id;
  final String? storeId; // null = global rule
  final String? category; // null = all categories
  final CommissionType type;
  final double value; // percentage (0-100) or fixed amount
  final double minOrderValue;
  final double maxCommission; // cap for percentage commissions
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy; // Super Admin ID
  final Map<String, dynamic>? tieredRates; // For tiered commission structure

  CommissionRule({
    required this.id,
    this.storeId,
    this.category,
    required this.type,
    required this.value,
    this.minOrderValue = 0.0,
    this.maxCommission = double.infinity,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.tieredRates,
  });

  factory CommissionRule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommissionRule(
      id: doc.id,
      storeId: data['storeId'],
      category: data['category'],
      type: CommissionType.values.firstWhere(
        (e) => e.toString() == 'CommissionType.${data['type']}',
        orElse: () => CommissionType.percentage,
      ),
      value: (data['value'] ?? 0).toDouble(),
      minOrderValue: (data['minOrderValue'] ?? 0).toDouble(),
      maxCommission: (data['maxCommission'] ?? double.infinity).toDouble(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      tieredRates: data['tieredRates'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'category': category,
      'type': type.toString().split('.').last,
      'value': value,
      'minOrderValue': minOrderValue,
      'maxCommission': maxCommission,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'tieredRates': tieredRates,
    };
  }

  // Calculate commission for a given order value
  double calculateCommission(double orderValue) {
    if (orderValue < minOrderValue) return 0.0;

    switch (type) {
      case CommissionType.percentage:
        final commission = orderValue * (value / 100);
        return commission > maxCommission ? maxCommission : commission;

      case CommissionType.fixedAmount:
        return value;

      case CommissionType.tiered:
        return _calculateTieredCommission(orderValue);
    }
  }

  double _calculateTieredCommission(double orderValue) {
    if (tieredRates == null) return 0.0;

    double commission = 0.0;
    double remaining = orderValue;

    // Sort tiers by threshold
    final sortedTiers = (tieredRates!['tiers'] as List)
        .cast<Map<String, dynamic>>()
        .where((tier) => tier['threshold'] != null && tier['rate'] != null)
        .toList()
      ..sort(
          (a, b) => (a['threshold'] as num).compareTo(b['threshold'] as num));

    for (int i = 0; i < sortedTiers.length; i++) {
      final tier = sortedTiers[i];
      final threshold = (tier['threshold'] as num).toDouble();
      final rate = (tier['rate'] as num).toDouble();

      if (remaining <= 0) break;

      double tierAmount;
      if (i == sortedTiers.length - 1) {
        // Last tier - use all remaining
        tierAmount = remaining;
      } else {
        final nextThreshold =
            (sortedTiers[i + 1]['threshold'] as num).toDouble();
        tierAmount = remaining > (nextThreshold - threshold)
            ? (nextThreshold - threshold)
            : remaining;
      }

      commission += tierAmount * (rate / 100);
      remaining -= tierAmount;
    }

    return commission > maxCommission ? maxCommission : commission;
  }
}

class CommissionTransaction {
  final String id;
  final String orderId;
  final String storeId;
  final String vendorId;
  final String ruleId;
  final double orderTotal;
  final double commissionAmount;
  final double vendorAmount; // orderTotal - commissionAmount
  final CommissionStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? paymentReference;
  final Map<String, dynamic>? metadata;

  CommissionTransaction({
    required this.id,
    required this.orderId,
    required this.storeId,
    required this.vendorId,
    required this.ruleId,
    required this.orderTotal,
    required this.commissionAmount,
    required this.vendorAmount,
    this.status = CommissionStatus.pending,
    required this.createdAt,
    this.paidAt,
    this.paymentReference,
    this.metadata,
  });

  factory CommissionTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommissionTransaction(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      storeId: data['storeId'] ?? '',
      vendorId: data['vendorId'] ?? '',
      ruleId: data['ruleId'] ?? '',
      orderTotal: (data['orderTotal'] ?? 0).toDouble(),
      commissionAmount: (data['commissionAmount'] ?? 0).toDouble(),
      vendorAmount: (data['vendorAmount'] ?? 0).toDouble(),
      status: CommissionStatus.values.firstWhere(
        (e) => e.toString() == 'CommissionStatus.${data['status']}',
        orElse: () => CommissionStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      paidAt: data['paidAt'] != null
          ? (data['paidAt'] as Timestamp).toDate()
          : null,
      paymentReference: data['paymentReference'],
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'storeId': storeId,
      'vendorId': vendorId,
      'ruleId': ruleId,
      'orderTotal': orderTotal,
      'commissionAmount': commissionAmount,
      'vendorAmount': vendorAmount,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'paymentReference': paymentReference,
      'metadata': metadata,
    };
  }

  // Helper methods
  double get commissionPercentage =>
      orderTotal > 0 ? (commissionAmount / orderTotal) * 100 : 0;
  String get formattedCommissionAmount =>
      '\$${commissionAmount.toStringAsFixed(2)}';
  String get formattedVendorAmount => '\$${vendorAmount.toStringAsFixed(2)}';
  String get formattedOrderTotal => '\$${orderTotal.toStringAsFixed(2)}';
  bool get isPaid => status == CommissionStatus.paid;
  bool get isPending => status == CommissionStatus.pending;
}

class CommissionSummary {
  final double totalCommissionEarned;
  final double totalVendorPayouts;
  final double pendingCommissions;
  final double paidCommissions;
  final int totalTransactions;
  final int pendingTransactions;
  final DateTime periodStart;
  final DateTime periodEnd;

  CommissionSummary({
    this.totalCommissionEarned = 0.0,
    this.totalVendorPayouts = 0.0,
    this.pendingCommissions = 0.0,
    this.paidCommissions = 0.0,
    this.totalTransactions = 0,
    this.pendingTransactions = 0,
    required this.periodStart,
    required this.periodEnd,
  });

  factory CommissionSummary.fromMap(Map<String, dynamic> map) {
    return CommissionSummary(
      totalCommissionEarned: (map['totalCommissionEarned'] ?? 0).toDouble(),
      totalVendorPayouts: (map['totalVendorPayouts'] ?? 0).toDouble(),
      pendingCommissions: (map['pendingCommissions'] ?? 0).toDouble(),
      paidCommissions: (map['paidCommissions'] ?? 0).toDouble(),
      totalTransactions: map['totalTransactions'] ?? 0,
      pendingTransactions: map['pendingTransactions'] ?? 0,
      periodStart: map['periodStart'] is DateTime
          ? map['periodStart']
          : (map['periodStart'] as Timestamp).toDate(),
      periodEnd: map['periodEnd'] is DateTime
          ? map['periodEnd']
          : (map['periodEnd'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalCommissionEarned': totalCommissionEarned,
      'totalVendorPayouts': totalVendorPayouts,
      'pendingCommissions': pendingCommissions,
      'paidCommissions': paidCommissions,
      'totalTransactions': totalTransactions,
      'pendingTransactions': pendingTransactions,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
    };
  }

  // Helper methods
  String get formattedTotalCommission =>
      '\$${totalCommissionEarned.toStringAsFixed(2)}';
  String get formattedPendingCommissions =>
      '\$${pendingCommissions.toStringAsFixed(2)}';
  String get formattedPaidCommissions =>
      '\$${paidCommissions.toStringAsFixed(2)}';
  double get averageCommissionPerTransaction =>
      totalTransactions > 0 ? totalCommissionEarned / totalTransactions : 0;
}

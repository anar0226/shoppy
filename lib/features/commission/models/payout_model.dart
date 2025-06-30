import 'package:cloud_firestore/cloud_firestore.dart';

/// Payout request model for vendor payments
class PayoutRequest {
  final String id;
  final String vendorId;
  final String storeId;
  final double amount;
  final double platformFee;
  final double netAmount;
  final String currency;
  final PayoutStatus status;
  final PayoutMethod method;
  final String? bankAccount;
  final String? mobileWallet;
  final List<String> transactionIds; // Commission transactions included
  final DateTime requestDate;
  final DateTime? processedDate;
  final DateTime? scheduledDate;
  final String? notes;
  final String? failureReason;
  final Map<String, dynamic>? metadata;

  PayoutRequest({
    required this.id,
    required this.vendorId,
    required this.storeId,
    required this.amount,
    required this.platformFee,
    required this.netAmount,
    required this.currency,
    required this.status,
    required this.method,
    this.bankAccount,
    this.mobileWallet,
    required this.transactionIds,
    required this.requestDate,
    this.processedDate,
    this.scheduledDate,
    this.notes,
    this.failureReason,
    this.metadata,
  });

  factory PayoutRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PayoutRequest(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      storeId: data['storeId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      platformFee: (data['platformFee'] ?? 0).toDouble(),
      netAmount: (data['netAmount'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'MNT',
      status: PayoutStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => PayoutStatus.pending,
      ),
      method: PayoutMethod.values.firstWhere(
        (m) => m.name == data['method'],
        orElse: () => PayoutMethod.bankTransfer,
      ),
      bankAccount: data['bankAccount'],
      mobileWallet: data['mobileWallet'],
      transactionIds: List<String>.from(data['transactionIds'] ?? []),
      requestDate: (data['requestDate'] as Timestamp).toDate(),
      processedDate: data['processedDate'] != null
          ? (data['processedDate'] as Timestamp).toDate()
          : null,
      scheduledDate: data['scheduledDate'] != null
          ? (data['scheduledDate'] as Timestamp).toDate()
          : null,
      notes: data['notes'],
      failureReason: data['failureReason'],
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'storeId': storeId,
      'amount': amount,
      'platformFee': platformFee,
      'netAmount': netAmount,
      'currency': currency,
      'status': status.name,
      'method': method.name,
      'bankAccount': bankAccount,
      'mobileWallet': mobileWallet,
      'transactionIds': transactionIds,
      'requestDate': Timestamp.fromDate(requestDate),
      'processedDate':
          processedDate != null ? Timestamp.fromDate(processedDate!) : null,
      'scheduledDate':
          scheduledDate != null ? Timestamp.fromDate(scheduledDate!) : null,
      'notes': notes,
      'failureReason': failureReason,
      'metadata': metadata,
    };
  }
}

/// Payout schedule for automated vendor payments
class PayoutSchedule {
  final String id;
  final String vendorId;
  final String storeId;
  final PayoutFrequency frequency;
  final int dayOfWeek; // 1-7 for weekly (1=Monday)
  final int dayOfMonth; // 1-28 for monthly
  final double minimumAmount;
  final PayoutMethod method;
  final String? bankAccount;
  final String? mobileWallet;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastPayoutDate;
  final DateTime? nextPayoutDate;

  PayoutSchedule({
    required this.id,
    required this.vendorId,
    required this.storeId,
    required this.frequency,
    required this.dayOfWeek,
    required this.dayOfMonth,
    required this.minimumAmount,
    required this.method,
    this.bankAccount,
    this.mobileWallet,
    required this.isActive,
    required this.createdAt,
    this.lastPayoutDate,
    this.nextPayoutDate,
  });

  factory PayoutSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PayoutSchedule(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      storeId: data['storeId'] ?? '',
      frequency: PayoutFrequency.values.firstWhere(
        (f) => f.name == data['frequency'],
        orElse: () => PayoutFrequency.weekly,
      ),
      dayOfWeek: data['dayOfWeek'] ?? 1,
      dayOfMonth: data['dayOfMonth'] ?? 1,
      minimumAmount: (data['minimumAmount'] ?? 0).toDouble(),
      method: PayoutMethod.values.firstWhere(
        (m) => m.name == data['method'],
        orElse: () => PayoutMethod.bankTransfer,
      ),
      bankAccount: data['bankAccount'],
      mobileWallet: data['mobileWallet'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastPayoutDate: data['lastPayoutDate'] != null
          ? (data['lastPayoutDate'] as Timestamp).toDate()
          : null,
      nextPayoutDate: data['nextPayoutDate'] != null
          ? (data['nextPayoutDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'storeId': storeId,
      'frequency': frequency.name,
      'dayOfWeek': dayOfWeek,
      'dayOfMonth': dayOfMonth,
      'minimumAmount': minimumAmount,
      'method': method.name,
      'bankAccount': bankAccount,
      'mobileWallet': mobileWallet,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastPayoutDate':
          lastPayoutDate != null ? Timestamp.fromDate(lastPayoutDate!) : null,
      'nextPayoutDate':
          nextPayoutDate != null ? Timestamp.fromDate(nextPayoutDate!) : null,
    };
  }
}

/// Payout analytics model for financial reporting
class PayoutAnalytics {
  final double totalPayouts;
  final double pendingPayouts;
  final double completedPayouts;
  final double failedPayouts;
  final int totalRequests;
  final int pendingRequests;
  final int completedRequests;
  final int failedRequests;
  final double averagePayoutAmount;
  final double platformFeesCollected;
  final Map<String, double> payoutsByMethod;
  final Map<String, double> payoutsByFrequency;
  final List<PayoutTrend> trends;

  PayoutAnalytics({
    required this.totalPayouts,
    required this.pendingPayouts,
    required this.completedPayouts,
    required this.failedPayouts,
    required this.totalRequests,
    required this.pendingRequests,
    required this.completedRequests,
    required this.failedRequests,
    required this.averagePayoutAmount,
    required this.platformFeesCollected,
    required this.payoutsByMethod,
    required this.payoutsByFrequency,
    required this.trends,
  });

  double get successRate =>
      totalRequests > 0 ? (completedRequests / totalRequests) * 100 : 0;
  double get failureRate =>
      totalRequests > 0 ? (failedRequests / totalRequests) * 100 : 0;
}

/// Payout trend data for charts
class PayoutTrend {
  final DateTime date;
  final double amount;
  final int count;

  PayoutTrend({
    required this.date,
    required this.amount,
    required this.count,
  });
}

/// Vendor financial profile for payout eligibility
class VendorFinancialProfile {
  final String vendorId;
  final String storeId;
  final double totalEarned;
  final double totalWithdrawn;
  final double pendingBalance;
  final double availableBalance;
  final double minimumPayoutThreshold;
  final PayoutMethod preferredMethod;
  final String? bankAccount;
  final String? mobileWallet;
  final bool isEligibleForPayouts;
  final List<String> blockedReasons;
  final DateTime lastPayoutDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  VendorFinancialProfile({
    required this.vendorId,
    required this.storeId,
    required this.totalEarned,
    required this.totalWithdrawn,
    required this.pendingBalance,
    required this.availableBalance,
    required this.minimumPayoutThreshold,
    required this.preferredMethod,
    this.bankAccount,
    this.mobileWallet,
    required this.isEligibleForPayouts,
    required this.blockedReasons,
    required this.lastPayoutDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorFinancialProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VendorFinancialProfile(
      vendorId: data['vendorId'] ?? '',
      storeId: data['storeId'] ?? '',
      totalEarned: (data['totalEarned'] ?? 0).toDouble(),
      totalWithdrawn: (data['totalWithdrawn'] ?? 0).toDouble(),
      pendingBalance: (data['pendingBalance'] ?? 0).toDouble(),
      availableBalance: (data['availableBalance'] ?? 0).toDouble(),
      minimumPayoutThreshold: (data['minimumPayoutThreshold'] ?? 50).toDouble(),
      preferredMethod: PayoutMethod.values.firstWhere(
        (m) => m.name == data['preferredMethod'],
        orElse: () => PayoutMethod.bankTransfer,
      ),
      bankAccount: data['bankAccount'],
      mobileWallet: data['mobileWallet'],
      isEligibleForPayouts: data['isEligibleForPayouts'] ?? true,
      blockedReasons: List<String>.from(data['blockedReasons'] ?? []),
      lastPayoutDate: (data['lastPayoutDate'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'storeId': storeId,
      'totalEarned': totalEarned,
      'totalWithdrawn': totalWithdrawn,
      'pendingBalance': pendingBalance,
      'availableBalance': availableBalance,
      'minimumPayoutThreshold': minimumPayoutThreshold,
      'preferredMethod': preferredMethod.name,
      'bankAccount': bankAccount,
      'mobileWallet': mobileWallet,
      'isEligibleForPayouts': isEligibleForPayouts,
      'blockedReasons': blockedReasons,
      'lastPayoutDate': Timestamp.fromDate(lastPayoutDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// **ENUMS**

enum PayoutStatus {
  pending,
  scheduled,
  processing,
  completed,
  failed,
  cancelled,
  disputed,
}

enum PayoutMethod {
  bankTransfer,
  mobileWallet,
  digitalWallet,
  check,
  paypal,
  qpay, // For Mongolia
}

enum PayoutFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  quarterly,
  manual,
}

// **EXTENSIONS**

extension PayoutStatusExtension on PayoutStatus {
  String get displayName {
    switch (this) {
      case PayoutStatus.pending:
        return 'Pending';
      case PayoutStatus.scheduled:
        return 'Scheduled';
      case PayoutStatus.processing:
        return 'Processing';
      case PayoutStatus.completed:
        return 'Completed';
      case PayoutStatus.failed:
        return 'Failed';
      case PayoutStatus.cancelled:
        return 'Cancelled';
      case PayoutStatus.disputed:
        return 'Disputed';
    }
  }

  bool get isCompleted => this == PayoutStatus.completed;
  bool get isPending =>
      this == PayoutStatus.pending || this == PayoutStatus.scheduled;
  bool get isFailed =>
      this == PayoutStatus.failed || this == PayoutStatus.cancelled;
}

extension PayoutMethodExtension on PayoutMethod {
  String get displayName {
    switch (this) {
      case PayoutMethod.bankTransfer:
        return 'Bank Transfer';
      case PayoutMethod.mobileWallet:
        return 'Mobile Wallet';
      case PayoutMethod.digitalWallet:
        return 'Digital Wallet';
      case PayoutMethod.check:
        return 'Check';
      case PayoutMethod.paypal:
        return 'PayPal';
      case PayoutMethod.qpay:
        return 'QPay';
    }
  }
}

extension PayoutFrequencyExtension on PayoutFrequency {
  String get displayName {
    switch (this) {
      case PayoutFrequency.daily:
        return 'Daily';
      case PayoutFrequency.weekly:
        return 'Weekly';
      case PayoutFrequency.biweekly:
        return 'Bi-weekly';
      case PayoutFrequency.monthly:
        return 'Monthly';
      case PayoutFrequency.quarterly:
        return 'Quarterly';
      case PayoutFrequency.manual:
        return 'Manual';
    }
  }
}

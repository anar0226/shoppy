import 'package:cloud_firestore/cloud_firestore.dart';

/// Payment status for subscription payments
enum PaymentStatus {
  pending('Pending', 'Хүлээгдэж буй'),
  completed('Completed', 'Амжилттай'),
  failed('Failed', 'Амжилтгүй'),
  cancelled('Cancelled', 'Цуцлагдсан'),
  refunded('Refunded', 'Буцаагдсан');

  const PaymentStatus(this.englishName, this.mongolianName);

  final String englishName;
  final String mongolianName;

  String get displayName => '$englishName ($mongolianName)';
}

/// Payment method for subscription payments
enum PaymentMethod {
  qpay('QPay', 'QPay'),
  bankTransfer('Bank Transfer', 'Банкны шилжүүлэг'),
  cash('Cash', 'Бэлнээр');

  const PaymentMethod(this.englishName, this.mongolianName);

  final String englishName;
  final String mongolianName;

  String get displayName => '$englishName ($mongolianName)';
}

class PaymentModel {
  final String id;
  final String storeId;
  final String userId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final PaymentMethod paymentMethod;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String description;
  final String? invoiceUrl;
  final String? failureReason;
  final Map<String, dynamic>? metadata;

  PaymentModel({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.amount,
    this.currency = 'MNT',
    required this.status,
    required this.paymentMethod,
    this.transactionId,
    required this.createdAt,
    this.processedAt,
    required this.description,
    this.invoiceUrl,
    this.failureReason,
    this.metadata,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'MNT',
      status: PaymentStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (method) => method.name == data['paymentMethod'],
        orElse: () => PaymentMethod.qpay,
      ),
      transactionId: data['transactionId'],
      createdAt: _parseTimestamp(data['createdAt']),
      processedAt: data['processedAt'] != null
          ? _parseTimestamp(data['processedAt'])
          : null,
      description: data['description'] ?? '',
      invoiceUrl: data['invoiceUrl'],
      failureReason: data['failureReason'],
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'paymentMethod': paymentMethod.name,
      'transactionId': transactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt':
          processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'description': description,
      'invoiceUrl': invoiceUrl,
      'failureReason': failureReason,
      'metadata': metadata,
    };
  }

  PaymentModel copyWith({
    String? id,
    String? storeId,
    String? userId,
    double? amount,
    String? currency,
    PaymentStatus? status,
    PaymentMethod? paymentMethod,
    String? transactionId,
    DateTime? createdAt,
    DateTime? processedAt,
    String? description,
    String? invoiceUrl,
    String? failureReason,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      description: description ?? this.description,
      invoiceUrl: invoiceUrl ?? this.invoiceUrl,
      failureReason: failureReason ?? this.failureReason,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if payment is successful
  bool get isSuccessful => status == PaymentStatus.completed;

  /// Check if payment is pending
  bool get isPending => status == PaymentStatus.pending;

  /// Check if payment failed
  bool get isFailed => status == PaymentStatus.failed;

  /// Get payment status display text
  String get statusDisplay {
    switch (status) {
      case PaymentStatus.pending:
        return 'Хүлээгдэж буй';
      case PaymentStatus.completed:
        return 'Амжилттай';
      case PaymentStatus.failed:
        return 'Амжилтгүй';
      case PaymentStatus.cancelled:
        return 'Цуцлагдсан';
      case PaymentStatus.refunded:
        return 'Буцаагдсан';
    }
  }

  /// Get formatted amount with currency
  String get formattedAmount {
    return '${amount.toStringAsFixed(0)} $currency';
  }

  /// Get payment method display text
  String get paymentMethodDisplay {
    switch (paymentMethod) {
      case PaymentMethod.qpay:
        return 'QPay';
      case PaymentMethod.bankTransfer:
        return 'Банкны шилжүүлэг';
      case PaymentMethod.cash:
        return 'Бэлнээр';
    }
  }

  /// Create a new payment for subscription
  factory PaymentModel.createSubscriptionPayment({
    required String storeId,
    required String userId,
    required double amount,
    PaymentMethod paymentMethod = PaymentMethod.qpay,
    String? transactionId,
    String? invoiceUrl,
  }) {
    return PaymentModel(
      id: '', // Will be set by Firestore
      storeId: storeId,
      userId: userId,
      amount: amount,
      currency: 'MNT',
      status: PaymentStatus.pending,
      paymentMethod: paymentMethod,
      transactionId: transactionId,
      createdAt: DateTime.now(),
      description: 'Сарын төлбөр - Shoppy дэлгүүр',
      invoiceUrl: invoiceUrl,
    );
  }

  static DateTime _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    return DateTime.now();
  }
}

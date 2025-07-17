import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'qpay_service.dart';

/// QPay Payment Result (for order fulfillment)
class QPayPaymentResult {
  final bool success;
  final String? error;
  final QPayInvoice? invoice;

  const QPayPaymentResult({
    required this.success,
    this.error,
    this.invoice,
  });

  factory QPayPaymentResult.success(QPayInvoice invoice) {
    return QPayPaymentResult(success: true, invoice: invoice);
  }

  factory QPayPaymentResult.error(String error) {
    return QPayPaymentResult(success: false, error: error);
  }
}

/// Order Fulfillment Status
enum FulfillmentStatus {
  pending,
  paymentProcessing,
  paymentConfirmed,
  orderConfirmed,
  preparing,
  readyForPickup,
  shipped,
  delivered,
  completed,
  failed,
  cancelled,
}

/// Order Fulfillment Result
class OrderFulfillmentResult {
  final bool success;
  final String? error;
  final String? orderId;
  final QPayInvoice? paymentInvoice;

  const OrderFulfillmentResult({
    required this.success,
    this.error,
    this.orderId,
    this.paymentInvoice,
  });

  factory OrderFulfillmentResult.success({
    required String orderId,
    QPayInvoice? paymentInvoice,
  }) {
    return OrderFulfillmentResult(
      success: true,
      orderId: orderId,
      paymentInvoice: paymentInvoice,
    );
  }

  factory OrderFulfillmentResult.error(String error) {
    return OrderFulfillmentResult(success: false, error: error);
  }
}

/// Simplified Order Fulfillment Service - Payment processing only
/// Store owners handle shipping/delivery themselves
class OrderFulfillmentService {
  static final OrderFulfillmentService _instance =
      OrderFulfillmentService._internal();
  factory OrderFulfillmentService() => _instance;
  OrderFulfillmentService._internal();

  final QPayService _qpayService = QPayService();

  /// Initialize the fulfillment service
  Future<void> initialize({
    required String qpayUsername,
    required String qpayPassword,
  }) async {
    debugPrint(
        'OrderFulfillmentService: Initialized for payment processing only');
  }

  /// Process order payment and create order record
  /// Store owners handle shipping/delivery themselves
  Future<OrderFulfillmentResult> processOrder({
    required Map<String, dynamic> orderData,
    required String customerEmail,
    required String customerPhone,
    required Map<String, dynamic> deliveryAddress,
  }) async {
    try {
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      // Step 1: Create initial order record
      await _createInitialOrder(
          orderId, orderData, customerEmail, customerPhone, deliveryAddress);

      // Step 2: Process payment with QPay
      final paymentResult =
          await _processPayment(orderId, orderData, customerEmail);

      if (!paymentResult.success) {
        await _updateOrderStatus(orderId, FulfillmentStatus.failed,
            error: paymentResult.error);
        return OrderFulfillmentResult.error(
            'Payment failed: ${paymentResult.error}');
      }

      // Step 3: Update order status to payment confirmed
      await _updateOrderStatus(orderId, FulfillmentStatus.paymentConfirmed);

      return OrderFulfillmentResult.success(
        orderId: orderId,
        paymentInvoice: paymentResult.invoice!,
      );
    } catch (e) {
      debugPrint('Order processing error: $e');
      return OrderFulfillmentResult.error('Order processing failed: $e');
    }
  }

  /// Create initial order record in Firestore
  Future<void> _createInitialOrder(
    String orderId,
    Map<String, dynamic> orderData,
    String customerEmail,
    String customerPhone,
    Map<String, dynamic> deliveryAddress,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final orderRecord = {
      'orderId': orderId,
      'userId': user.uid,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'items': orderData['items'],
      'storeId': orderData['storeId'],
      'vendorId': orderData['vendorId'],
      'subtotal': orderData['subtotal'],
      'tax': orderData['tax'],
      'shipping': orderData['shipping'],
      'total': orderData['total'],
      'deliveryAddress': deliveryAddress,
      'fulfillmentStatus': FulfillmentStatus.pending.name,
      'paymentStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // Analytics fields
      'month': DateTime.now().month,
      'week': ((DateTime.now().day - 1) / 7).floor() + 1,
      'day': DateTime.now().day,
    };

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .set(orderRecord);
  }

  /// Process payment with QPay
  Future<QPayPaymentResult> _processPayment(
    String orderId,
    Map<String, dynamic> orderData,
    String customerEmail,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get store information for payment description
    final storeDoc = await FirebaseFirestore.instance
        .collection('stores')
        .doc(orderData['storeId'])
        .get();

    final storeName =
        storeDoc.exists ? storeDoc.data()!['name'] ?? 'Store' : 'Store';
    final itemsCount = (orderData['items'] as List).length;

    // Create QPay invoice
    final description = 'Order #$orderId from $storeName ($itemsCount items)';

    final qpayResult = await _qpayService.createInvoice(
      orderId: orderId,
      amount: (orderData['total'] as num).toDouble(),
      description: description,
      customerEmail: customerEmail.replaceAll('@', '_').replaceAll('.', '_'),
    );

    if (qpayResult.success && qpayResult.invoice != null) {
      return QPayPaymentResult.success(qpayResult.invoice!);
    } else {
      return QPayPaymentResult.error(
          qpayResult.error ?? 'Payment creation failed');
    }
  }

  /// Update order status in Firestore
  Future<void> _updateOrderStatus(
    String orderId,
    FulfillmentStatus status, {
    String? error,
  }) async {
    final updateData = {
      'fulfillmentStatus': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (error != null) {
      updateData['error'] = error;
    }

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update(updateData);
  }

  /// Get order by ID
  Future<Map<String, dynamic>?> getOrder(String orderId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting order: $e');
      return null;
    }
  }

  /// Update order status (for store owners)
  Future<bool> updateOrderStatus(
    String orderId,
    FulfillmentStatus status, {
    String? notes,
  }) async {
    try {
      final updateData = {
        'fulfillmentStatus': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (notes != null) {
        updateData['statusNotes'] = notes;
      }

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(updateData);

      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  /// Get orders for a store
  Stream<QuerySnapshot> getStoreOrders(String storeId) {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get orders for a user
  Stream<QuerySnapshot> getUserOrders(String userId) {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}

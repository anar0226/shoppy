import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'qpay_service.dart';
import '../utils/order_id_generator.dart';

/// QPay Payment Result (for order fulfillment)
class QPayPaymentResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? invoice;

  const QPayPaymentResult({
    required this.success,
    this.error,
    this.invoice,
  });

  factory QPayPaymentResult.success(Map<String, dynamic> invoice) {
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
  final Map<String, dynamic>? paymentInvoice;

  const OrderFulfillmentResult({
    required this.success,
    this.error,
    this.orderId,
    this.paymentInvoice,
  });

  factory OrderFulfillmentResult.success({
    required String orderId,
    Map<String, dynamic>? paymentInvoice,
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
      final orderId = OrderIdGenerator.generate();

      // Create order record in Firestore
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'orderId': orderId,
        'storeId': orderData['storeId'],
        'customerEmail': customerEmail,
        'customerPhone': customerPhone,
        'deliveryAddress': deliveryAddress,
        'items': orderData['items'],
        'total': orderData['total'],
        'fulfillmentStatus': FulfillmentStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Process payment
      final paymentResult = await _processPayment(
        orderId: orderId,
        orderData: orderData,
        customerEmail: customerEmail,
      );

      if (paymentResult.success) {
        // Update order status to payment confirmed
        await _updateOrderStatus(orderId, FulfillmentStatus.paymentConfirmed);

        return OrderFulfillmentResult.success(
          orderId: orderId,
          paymentInvoice: paymentResult.invoice,
        );
      } else {
        // Update order status to failed
        await _updateOrderStatus(
          orderId,
          FulfillmentStatus.failed,
          error: paymentResult.error,
        );

        return OrderFulfillmentResult.error(
            paymentResult.error ?? 'Payment processing failed');
      }
    } catch (e) {
      debugPrint('Order processing error: $e');
      return OrderFulfillmentResult.error('Order processing failed: $e');
    }
  }

  /// Process payment using QPay
  Future<QPayPaymentResult> _processPayment({
    required String orderId,
    required Map<String, dynamic> orderData,
    required String customerEmail,
  }) async {
    try {
      // Get store information
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
        customerCode: customerEmail.replaceAll('@', '_').replaceAll('.', '_'),
      );

      return QPayPaymentResult.success(qpayResult);
    } catch (e) {
      debugPrint('Payment processing error: $e');
      return QPayPaymentResult.error('Payment processing failed: $e');
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

  /// Get orders for a customer
  Stream<QuerySnapshot> getCustomerOrders(String customerEmail) {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('customerEmail', isEqualTo: customerEmail)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Cancel order
  Future<bool> cancelOrder(String orderId, {String? reason}) async {
    try {
      final updateData = {
        'fulfillmentStatus': FulfillmentStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (reason != null) {
        updateData['cancellationReason'] = reason;
      }

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(updateData);

      return true;
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      return false;
    }
  }
}

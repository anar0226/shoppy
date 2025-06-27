import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'qpay_service.dart';
import 'ubcab_service.dart';
import '../utils/type_utils.dart';

/// Order Fulfillment Status
enum FulfillmentStatus {
  pending,
  paymentProcessing,
  paymentConfirmed,
  deliveryRequested,
  driverAssigned,
  pickedUp,
  inTransit,
  delivered,
  completed,
  failed,
  cancelled,
}

/// Order Fulfillment Service - Orchestrates QPay + UBCab automation
class OrderFulfillmentService {
  static final OrderFulfillmentService _instance =
      OrderFulfillmentService._internal();
  factory OrderFulfillmentService() => _instance;
  OrderFulfillmentService._internal();

  final QPayService _qpayService = QPayService();
  final UBCabService _ubcabService = UBCabService();

  /// Initialize the fulfillment service
  Future<void> initialize({
    // QPay Configuration
    required String qpayUsername,
    required String qpayPassword,
    QPayEnvironment qpayEnvironment = QPayEnvironment.sandbox,

    // UBCab Configuration
    required String ubcabApiKey,
    required String ubcabMerchantId,
    bool ubcabProduction = false,
  }) async {
    await _qpayService.initialize(
      username: qpayUsername,
      password: qpayPassword,
      environment: qpayEnvironment,
    );

    await _ubcabService.initialize(
      apiKey: ubcabApiKey,
      merchantId: ubcabMerchantId,
      isProduction: ubcabProduction,
    );
  }

  /// Complete end-to-end order processing: Payment → Delivery
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

      // Step 3: Wait for payment confirmation (this would be handled by webhook in production)
      // For now, we'll simulate immediate confirmation
      await _updateOrderStatus(orderId, FulfillmentStatus.paymentConfirmed);

      // Step 4: Request delivery from UBCab
      final deliveryResult =
          await _requestDelivery(orderId, orderData, deliveryAddress);

      if (!deliveryResult.success) {
        await _updateOrderStatus(orderId, FulfillmentStatus.failed,
            error: deliveryResult.error);
        return OrderFulfillmentResult.error(
            'Delivery request failed: ${deliveryResult.error}');
      }

      await _updateOrderStatus(orderId, FulfillmentStatus.deliveryRequested);

      return OrderFulfillmentResult.success(
        orderId: orderId,
        paymentInvoice: paymentResult.invoice!,
        deliveryTrackingId: deliveryResult.trackingId!,
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
      'deliveryStatus': 'pending',
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

    return await _qpayService.createInvoice(
      orderId: orderId,
      amount: (orderData['total'] as num).toDouble(),
      customerName:
          user.displayName ?? user.email?.split('@').first ?? 'Customer',
      customerEmail: customerEmail,
      description: '$itemsCount item(s) from $storeName',
      currency: 'MNT',
      expiry: const Duration(hours: 2), // 2 hour expiry for payment
    );
  }

  /// Request delivery from UBCab
  Future<UBCabDeliveryResult> _requestDelivery(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> deliveryAddress,
  ) async {
    // Get store location information
    final storeDoc = await FirebaseFirestore.instance
        .collection('stores')
        .doc(orderData['storeId'])
        .get();

    if (!storeDoc.exists) {
      throw Exception('Store not found');
    }

    final storeData = storeDoc.data()!;

    final pickupAddress = UBCabAddress(
      address: storeData['address'] ?? 'Store Location',
      latitude: (storeData['latitude'] ?? 47.9184).toDouble(),
      longitude: (storeData['longitude'] ?? 106.9177).toDouble(),
      landmark: storeData['landmark'],
      contactName: storeData['ownerName'] ?? storeData['name'] ?? 'Store Owner',
      contactPhone: storeData['phone'] ?? '77807780',
    );

    final customerAddress = UBCabAddress(
      address:
          deliveryAddress['fullAddress'] ?? deliveryAddress['address'] ?? '',
      latitude: (deliveryAddress['latitude'] ?? 47.9184).toDouble(),
      longitude: (deliveryAddress['longitude'] ?? 106.9177).toDouble(),
      landmark: deliveryAddress['landmark'],
      contactName: deliveryAddress['recipientName'] ?? 'Customer',
      contactPhone: deliveryAddress['phone'],
    );

    // Convert order items to delivery items
    final items = (orderData['items'] as List)
        .map((item) => OrderItem(
              productId: item['productId'] ?? '',
              name: item['name'] ?? 'Product',
              quantity: item['quantity'] ?? 1,
              price: (item['price'] ?? 0).toDouble(),
              imageUrl: item['imageUrl'],
              variant: item['variant'],
            ))
        .toList();

    return await _ubcabService.requestDelivery(
      orderId: orderId,
      customerId: orderData['userId'] ?? '',
      storeId: orderData['storeId'] ?? '',
      pickupAddress: pickupAddress,
      deliveryAddress: customerAddress,
      items: items,
      totalAmount: (orderData['total'] as num).toDouble(),
      specialInstructions: deliveryAddress['instructions'],
    );
  }

  /// Update order fulfillment status
  Future<void> _updateOrderStatus(
    String orderId,
    FulfillmentStatus status, {
    String? error,
    Map<String, dynamic>? additionalData,
  }) async {
    final updateData = <String, dynamic>{
      'fulfillmentStatus': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (error != null) {
      updateData['error'] = error;
      updateData['failedAt'] = FieldValue.serverTimestamp();
    }

    if (additionalData != null) {
      updateData.addAll(additionalData);
    }

    // Update specific status fields based on fulfillment status
    switch (status) {
      case FulfillmentStatus.paymentProcessing:
        updateData['paymentStatus'] = 'processing';
        break;
      case FulfillmentStatus.paymentConfirmed:
        updateData['paymentStatus'] = 'paid';
        updateData['paidAt'] = FieldValue.serverTimestamp();
        break;
      case FulfillmentStatus.deliveryRequested:
        updateData['deliveryStatus'] = 'requested';
        break;
      case FulfillmentStatus.driverAssigned:
        updateData['deliveryStatus'] = 'driver_assigned';
        break;
      case FulfillmentStatus.delivered:
        updateData['deliveryStatus'] = 'delivered';
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
        break;
      case FulfillmentStatus.completed:
        updateData['completedAt'] = FieldValue.serverTimestamp();
        break;
      default:
        break;
    }

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update(updateData);
  }

  /// Handle QPay payment webhook
  Future<void> handlePaymentWebhook(Map<String, dynamic> webhookData) async {
    try {
      final success = await _qpayService.processCallback(webhookData);

      if (success) {
        final invoiceId = webhookData['invoice_id']?.toString();
        if (invoiceId != null) {
          // Find order by invoice ID
          final orderQuery = await FirebaseFirestore.instance
              .collection('orders')
              .where('paymentInvoiceId', isEqualTo: invoiceId)
              .limit(1)
              .get();

          if (orderQuery.docs.isNotEmpty) {
            final orderId = orderQuery.docs.first.id;
            await _updateOrderStatus(
                orderId, FulfillmentStatus.paymentConfirmed);

            // Automatically proceed with delivery if payment is confirmed
            await _continueOrderFulfillment(orderId);
          }
        }
      }
    } catch (e) {
      debugPrint('Payment webhook error: $e');
    }
  }

  /// Handle UBCab delivery webhook
  Future<void> handleDeliveryWebhook(Map<String, dynamic> webhookData) async {
    try {
      final success = await _ubcabService.processDeliveryCallback(webhookData);

      if (success) {
        final orderId = webhookData['order_reference']?.toString();
        final status = webhookData['status']?.toString();

        if (orderId != null && status != null) {
          FulfillmentStatus fulfillmentStatus;

          switch (status.toLowerCase()) {
            case 'driver_assigned':
              fulfillmentStatus = FulfillmentStatus.driverAssigned;
              break;
            case 'pickup_confirmed':
              fulfillmentStatus = FulfillmentStatus.pickedUp;
              break;
            case 'in_transit':
              fulfillmentStatus = FulfillmentStatus.inTransit;
              break;
            case 'delivered':
              fulfillmentStatus = FulfillmentStatus.delivered;
              break;
            default:
              return;
          }

          await _updateOrderStatus(orderId, fulfillmentStatus);

          // Mark as completed if delivered
          if (fulfillmentStatus == FulfillmentStatus.delivered) {
            await _updateOrderStatus(orderId, FulfillmentStatus.completed);
          }
        }
      }
    } catch (e) {
      debugPrint('Delivery webhook error: $e');
    }
  }

  /// Continue order fulfillment after payment confirmation
  Future<void> _continueOrderFulfillment(String orderId) async {
    try {
      // Get order details
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;

      // Request delivery if not already requested
      if (orderData['deliveryStatus'] == 'pending') {
        final deliveryResult = await _requestDelivery(
          orderId,
          orderData,
          orderData['deliveryAddress'],
        );

        if (deliveryResult.success) {
          await _updateOrderStatus(orderId, FulfillmentStatus.deliveryRequested,
              additionalData: {
                'deliveryTrackingId': deliveryResult.trackingId,
              });
        } else {
          await _updateOrderStatus(orderId, FulfillmentStatus.failed,
              error: deliveryResult.error);
        }
      }
    } catch (e) {
      debugPrint('Continue order fulfillment error: $e');
      await _updateOrderStatus(orderId, FulfillmentStatus.failed,
          error: e.toString());
    }
  }

  /// Get order status with real-time tracking
  Future<OrderStatusResult> getOrderStatus(String orderId) async {
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        return OrderStatusResult.error('Order not found');
      }

      final orderData = orderDoc.data()!;
      final trackingId = orderData['deliveryTrackingId']?.toString();

      UBCabDeliveryOrder? deliveryInfo;
      if (trackingId != null) {
        deliveryInfo = await _ubcabService.trackDelivery(trackingId);
      }

      return OrderStatusResult.success(
        orderId: orderId,
        fulfillmentStatus: FulfillmentStatus.values.firstWhere(
          (status) => status.name == orderData['fulfillmentStatus'],
          orElse: () => FulfillmentStatus.pending,
        ),
        paymentStatus: orderData['paymentStatus'] ?? 'pending',
        deliveryStatus: orderData['deliveryStatus'] ?? 'pending',
        orderData: orderData,
        deliveryInfo: deliveryInfo,
      );
    } catch (e) {
      debugPrint('Get order status error: $e');
      return OrderStatusResult.error('Failed to get order status: $e');
    }
  }

  /// Cancel order (before delivery)
  Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) return false;

      final orderData = orderDoc.data()!;
      final fulfillmentStatus = orderData['fulfillmentStatus'] ?? '';

      // Only allow cancellation before pickup
      if (fulfillmentStatus == FulfillmentStatus.pickedUp.name ||
          fulfillmentStatus == FulfillmentStatus.inTransit.name ||
          fulfillmentStatus == FulfillmentStatus.delivered.name) {
        return false; // Cannot cancel after pickup
      }

      // Cancel delivery if requested
      final trackingId = orderData['deliveryTrackingId']?.toString();
      if (trackingId != null) {
        await _ubcabService.cancelDelivery(trackingId, reason);
      }

      // Update order status
      await _updateOrderStatus(orderId, FulfillmentStatus.cancelled,
          additionalData: {
            'cancellationReason': reason,
            'cancelledAt': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      debugPrint('Cancel order error: $e');
      return false;
    }
  }
}

/// Order Fulfillment Result
class OrderFulfillmentResult {
  final bool success;
  final String message;
  final String? orderId;
  final QPayInvoice? paymentInvoice;
  final String? deliveryTrackingId;
  final String? error;

  const OrderFulfillmentResult({
    required this.success,
    required this.message,
    this.orderId,
    this.paymentInvoice,
    this.deliveryTrackingId,
    this.error,
  });

  factory OrderFulfillmentResult.success({
    required String orderId,
    required QPayInvoice paymentInvoice,
    required String deliveryTrackingId,
  }) {
    return OrderFulfillmentResult(
      success: true,
      message: 'Order processed successfully',
      orderId: orderId,
      paymentInvoice: paymentInvoice,
      deliveryTrackingId: deliveryTrackingId,
    );
  }

  factory OrderFulfillmentResult.error(String error) {
    return OrderFulfillmentResult(
      success: false,
      message: 'Order processing failed',
      error: error,
    );
  }
}

/// Order Status Result
class OrderStatusResult {
  final bool success;
  final String message;
  final String? orderId;
  final FulfillmentStatus? fulfillmentStatus;
  final String? paymentStatus;
  final String? deliveryStatus;
  final Map<String, dynamic>? orderData;
  final UBCabDeliveryOrder? deliveryInfo;
  final String? error;

  const OrderStatusResult({
    required this.success,
    required this.message,
    this.orderId,
    this.fulfillmentStatus,
    this.paymentStatus,
    this.deliveryStatus,
    this.orderData,
    this.deliveryInfo,
    this.error,
  });

  factory OrderStatusResult.success({
    required String orderId,
    required FulfillmentStatus fulfillmentStatus,
    required String paymentStatus,
    required String deliveryStatus,
    required Map<String, dynamic> orderData,
    UBCabDeliveryOrder? deliveryInfo,
  }) {
    return OrderStatusResult(
      success: true,
      message: 'Order status retrieved successfully',
      orderId: orderId,
      fulfillmentStatus: fulfillmentStatus,
      paymentStatus: paymentStatus,
      deliveryStatus: deliveryStatus,
      orderData: orderData,
      deliveryInfo: deliveryInfo,
    );
  }

  factory OrderStatusResult.error(String error) {
    return OrderStatusResult(
      success: false,
      message: 'Failed to get order status',
      error: error,
    );
  }
}

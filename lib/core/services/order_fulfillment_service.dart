import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'qpay_service.dart';
import 'ubcab_service.dart';

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
    // Bank Transfer Configuration (placeholder for TDB integration)
    required String
        qpayUsername, // Placeholder - will be removed when TDB is integrated
    required String
        qpayPassword, // Placeholder - will be removed when TDB is integrated

    // UBCab Configuration
    required String ubcabApiKey,
    required String ubcabMerchantId,
    bool ubcabProduction = false,
  }) async {
    // Bank transfer setup - no initialization needed for now
    debugPrint('Using bank transfer payment method');

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

    // Create QPay invoice
    final description = 'Order #$orderId from $storeName ($itemsCount items)';

    final qpayResult = await _qpayService.createInvoice(
      orderId: orderId,
      amount: (orderData['total'] as num).toDouble(),
      description: description,
      // Use a unique string for customerEmail (invoice_receiver_code)
      customerEmail: customerEmail.replaceAll('@', '_').replaceAll('.', '_'),
      // Do not pass metadata
    );

    if (qpayResult.success && qpayResult.invoice != null) {
      // Create pending payment record
      final pendingPayment = {
        'orderId': orderId,
        'userId': user.uid,
        'amount': orderData['total'],
        'subtotal': orderData['subtotal'],
        'tax': orderData['tax'],
        'shippingCost': orderData['shipping'],
        'email': customerEmail,
        'item': orderData['items'][0], // First item for demo
        'shippingAddress': orderData['deliveryAddress'],
        'status': 'pending',
        'qpayInvoiceId': qpayResult.invoice!.qpayInvoiceId,
        'invoiceId': qpayResult.invoice!.id,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('pending_payments')
          .doc(orderId)
          .set(pendingPayment);

      return QPayPaymentResult.success(qpayResult.invoice!);
    } else {
      return QPayPaymentResult.error(
          qpayResult.error ?? 'Failed to create QPay invoice');
    }
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

  /// Handle bank transfer payment confirmation (placeholder for TDB integration)
  Future<void> handlePaymentWebhook(Map<String, dynamic> webhookData) async {
    try {
      // For bank transfers, we'll manually confirm payments
      // This will be replaced with TDB webhook integration
      final invoiceId = webhookData['invoice_id']?.toString();
      final orderId = webhookData['order_id']?.toString();

      if (orderId != null) {
        await _updateOrderStatus(orderId, FulfillmentStatus.paymentConfirmed);

        // Automatically proceed with delivery if payment is confirmed
        await _continueOrderFulfillment(orderId);
      }

      debugPrint('Bank transfer payment confirmed for order: $orderId');
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

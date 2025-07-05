import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// UBCab Service Types
enum UBCabServiceType {
  taxi,
  express,
  rent,
  eats,
}

/// Delivery Status
enum DeliveryStatus {
  requested,
  driverAssigned,
  pickupConfirmed,
  inTransit,
  delivered,
  cancelled,
  failed,
}

/// UBCab Address Model
class UBCabAddress {
  final String address;
  final double latitude;
  final double longitude;
  final String? landmark;
  final String? contactName;
  final String? contactPhone;

  const UBCabAddress({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.landmark,
    this.contactName,
    this.contactPhone,
  });

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'landmark': landmark,
      'contact_name': contactName,
      'contact_phone': contactPhone,
    };
  }

  factory UBCabAddress.fromJson(Map<String, dynamic> json) {
    return UBCabAddress(
      address: json['address']?.toString() ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      landmark: json['landmark']?.toString(),
      contactName: json['contact_name']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
    );
  }
}

/// UBCab Delivery Order
class UBCabDeliveryOrder {
  final String orderId;
  final String customerId;
  final String storeId;
  final UBCabAddress pickupAddress;
  final UBCabAddress deliveryAddress;
  final List<OrderItem> items;
  final double totalAmount;
  final String? specialInstructions;
  final DeliveryStatus status;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final String? trackingId;

  const UBCabDeliveryOrder({
    required this.orderId,
    required this.customerId,
    required this.storeId,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.items,
    required this.totalAmount,
    this.specialInstructions,
    required this.status,
    this.driverId,
    this.driverName,
    this.driverPhone,
    required this.createdAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.trackingId,
  });

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'customer_id': customerId,
      'store_id': storeId,
      'pickup_address': pickupAddress.toJson(),
      'delivery_address': deliveryAddress.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'total_amount': totalAmount,
      'special_instructions': specialInstructions,
      'status': status.name,
      'driver_id': driverId,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'created_at': createdAt.toIso8601String(),
      'assigned_at': assignedAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'tracking_id': trackingId,
    };
  }

  factory UBCabDeliveryOrder.fromJson(Map<String, dynamic> json) {
    return UBCabDeliveryOrder(
      orderId: json['order_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      storeId: json['store_id']?.toString() ?? '',
      pickupAddress: UBCabAddress.fromJson(json['pickup_address'] ?? {}),
      deliveryAddress: UBCabAddress.fromJson(json['delivery_address'] ?? {}),
      items: (json['items'] as List? ?? [])
          .map((item) => OrderItem.fromJson(item))
          .toList(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      specialInstructions: json['special_instructions']?.toString(),
      status: _parseDeliveryStatus(json['status']?.toString()),
      driverId: json['driver_id']?.toString(),
      driverName: json['driver_name']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'].toString())
          : null,
      pickedUpAt: json['picked_up_at'] != null
          ? DateTime.tryParse(json['picked_up_at'].toString())
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'].toString())
          : null,
      trackingId: json['tracking_id']?.toString(),
    );
  }

  static DeliveryStatus _parseDeliveryStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'driver_assigned':
        return DeliveryStatus.driverAssigned;
      case 'pickup_confirmed':
        return DeliveryStatus.pickupConfirmed;
      case 'in_transit':
        return DeliveryStatus.inTransit;
      case 'delivered':
        return DeliveryStatus.delivered;
      case 'cancelled':
        return DeliveryStatus.cancelled;
      case 'failed':
        return DeliveryStatus.failed;
      default:
        return DeliveryStatus.requested;
    }
  }
}

/// Order Item Model
class OrderItem {
  final String productId;
  final String name;
  final int quantity;
  final double price;
  final String? imageUrl;
  final String? variant;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    this.imageUrl,
    this.variant,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'quantity': quantity,
      'price': price,
      'image_url': imageUrl,
      'variant': variant,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: json['image_url']?.toString(),
      variant: json['variant']?.toString(),
    );
  }
}

/// UBCab Delivery Result
class UBCabDeliveryResult {
  final bool success;
  final String message;
  final UBCabDeliveryOrder? order;
  final String? trackingId;
  final String? error;

  const UBCabDeliveryResult({
    required this.success,
    required this.message,
    this.order,
    this.trackingId,
    this.error,
  });

  factory UBCabDeliveryResult.success(
      UBCabDeliveryOrder order, String trackingId) {
    return UBCabDeliveryResult(
      success: true,
      message: 'Delivery request created successfully',
      order: order,
      trackingId: trackingId,
    );
  }

  factory UBCabDeliveryResult.error(String error) {
    return UBCabDeliveryResult(
      success: false,
      message: 'Delivery request failed',
      error: error,
    );
  }
}

/// UBCab Integration Service
class UBCabService {
  static final UBCabService _instance = UBCabService._internal();
  factory UBCabService() => _instance;
  UBCabService._internal();

  late Dio _dio;
  String? _apiKey;
  String? _merchantId;

  /// Initialize UBCab service
  Future<void> initialize({
    required String apiKey,
    required String merchantId,
    bool isProduction = false,
  }) async {
    _apiKey = apiKey;
    _merchantId = merchantId;

    _dio = Dio(BaseOptions(
      baseUrl: isProduction
          ? 'https://api.ubcab.mn/v1' // Production URL (hypothetical)
          : 'https://api-dev.ubcab.mn/v1', // Development URL (hypothetical)
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'X-Merchant-ID': merchantId,
      },
    ));

    // Add request/response interceptors for debugging
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }
  }

  /// Request delivery from store to customer
  Future<UBCabDeliveryResult> requestDelivery({
    required String orderId,
    required String customerId,
    required String storeId,
    required UBCabAddress pickupAddress,
    required UBCabAddress deliveryAddress,
    required List<OrderItem> items,
    required double totalAmount,
    String? specialInstructions,
    DateTime? scheduledTime,
  }) async {
    try {
      final payload = {
        'service_type': 'express', // Using UBCab Express for delivery
        'order_reference': orderId,
        'customer_id': customerId,
        'merchant_id': _merchantId,
        'pickup': {
          'address': pickupAddress.address,
          'latitude': pickupAddress.latitude,
          'longitude': pickupAddress.longitude,
          'landmark': pickupAddress.landmark,
          'contact_name': pickupAddress.contactName ?? 'Store Owner',
          'contact_phone': pickupAddress.contactPhone ?? '77807780',
          'instructions': 'Pickup order from store',
        },
        'delivery': {
          'address': deliveryAddress.address,
          'latitude': deliveryAddress.latitude,
          'longitude': deliveryAddress.longitude,
          'landmark': deliveryAddress.landmark,
          'contact_name': deliveryAddress.contactName ?? 'Customer',
          'contact_phone': deliveryAddress.contactPhone,
          'instructions': specialInstructions ?? 'Standard delivery',
        },
        'items': items
            .map((item) => {
                  'name': item.name,
                  'quantity': item.quantity,
                  'description': item.variant != null
                      ? '${item.name} - ${item.variant}'
                      : item.name,
                })
            .toList(),
        'payment': {
          'amount': totalAmount,
          'currency': 'MNT',
          'method': 'prepaid', // Customer already paid via QPay
        },
        'scheduled_time': scheduledTime?.toIso8601String(),
        'priority': 'standard',
        'require_signature': true,
      };

      final response = await _dio.post('/delivery/request', data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final trackingId = data['tracking_id']?.toString() ?? '';

        final deliveryOrder = UBCabDeliveryOrder(
          orderId: orderId,
          customerId: customerId,
          storeId: storeId,
          pickupAddress: pickupAddress,
          deliveryAddress: deliveryAddress,
          items: items,
          totalAmount: totalAmount,
          specialInstructions: specialInstructions,
          status: DeliveryStatus.requested,
          createdAt: DateTime.now(),
          trackingId: trackingId,
        );

        // Store delivery order in Firestore for tracking
        await _storeDeliveryOrder(deliveryOrder);

        return UBCabDeliveryResult.success(deliveryOrder, trackingId);
      } else {
        return UBCabDeliveryResult.error(
            'Failed to request delivery: ${response.statusMessage}');
      }
    } catch (e) {
      debugPrint('UBCab delivery request error: $e');
      return UBCabDeliveryResult.error('Failed to request delivery: $e');
    }
  }

  /// Track delivery status
  Future<UBCabDeliveryOrder?> trackDelivery(String trackingId) async {
    try {
      final response = await _dio.get('/delivery/track/$trackingId');

      if (response.statusCode == 200) {
        final data = response.data;
        return UBCabDeliveryOrder.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Track delivery error: $e');
      return null;
    }
  }

  /// Cancel delivery
  Future<bool> cancelDelivery(String trackingId, String reason) async {
    try {
      final response = await _dio.post('/delivery/cancel/$trackingId', data: {
        'reason': reason,
        'cancelled_by': 'merchant',
      });

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Cancel delivery error: $e');
      return false;
    }
  }

  /// Get delivery estimate (time and cost)
  Future<Map<String, dynamic>?> getDeliveryEstimate({
    required UBCabAddress pickupAddress,
    required UBCabAddress deliveryAddress,
  }) async {
    try {
      final response = await _dio.post('/delivery/estimate', data: {
        'pickup': {
          'latitude': pickupAddress.latitude,
          'longitude': pickupAddress.longitude,
        },
        'delivery': {
          'latitude': deliveryAddress.latitude,
          'longitude': deliveryAddress.longitude,
        },
        'service_type': 'express',
      });

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('Get delivery estimate error: $e');
      return null;
    }
  }

  /// Store delivery order in Firestore
  Future<void> _storeDeliveryOrder(UBCabDeliveryOrder order) async {
    try {
      await FirebaseFirestore.instance
          .collection('delivery_orders')
          .doc(order.orderId)
          .set(order.toJson());
    } catch (e) {
      debugPrint('Store delivery order error: $e');
    }
  }

  /// Update delivery status
  Future<void> updateDeliveryStatus(
    String orderId,
    DeliveryStatus status, {
    String? driverId,
    String? driverName,
    String? driverPhone,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.name,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (status == DeliveryStatus.driverAssigned) {
        updateData['assigned_at'] = FieldValue.serverTimestamp();
        if (driverId != null) updateData['driver_id'] = driverId;
        if (driverName != null) updateData['driver_name'] = driverName;
        if (driverPhone != null) updateData['driver_phone'] = driverPhone;
      } else if (status == DeliveryStatus.pickupConfirmed) {
        updateData['picked_up_at'] = FieldValue.serverTimestamp();
      } else if (status == DeliveryStatus.delivered) {
        updateData['delivered_at'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('delivery_orders')
          .doc(orderId)
          .update(updateData);

      // Also update the main order status
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'delivery_status': status.name,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Update delivery status error: $e');
    }
  }

  /// Handle delivery webhook/callback
  Future<bool> processDeliveryCallback(
      Map<String, dynamic> callbackData) async {
    try {
      final trackingId = callbackData['tracking_id']?.toString();
      final status = callbackData['status']?.toString();
      final orderId = callbackData['order_reference']?.toString();

      if (trackingId == null || orderId == null) {
        return false;
      }

      final deliveryStatus = UBCabDeliveryOrder._parseDeliveryStatus(status);

      await updateDeliveryStatus(
        orderId,
        deliveryStatus,
        driverId: callbackData['driver_id']?.toString(),
        driverName: callbackData['driver_name']?.toString(),
        driverPhone: callbackData['driver_phone']?.toString(),
      );

      // Send notifications based on status
      await _sendDeliveryNotification(orderId, deliveryStatus);

      return true;
    } catch (e) {
      debugPrint('Process delivery callback error: $e');
      return false;
    }
  }

  /// Send notification for delivery status updates
  Future<void> _sendDeliveryNotification(
      String orderId, DeliveryStatus status) async {
    try {
      // Get order details
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final userId = orderData['userId'];

      String title;
      String message;

      switch (status) {
        case DeliveryStatus.driverAssigned:
          title = 'Driver Assigned';
          message = 'A driver has been assigned to deliver your order.';
          break;
        case DeliveryStatus.pickupConfirmed:
          title = 'Order Picked Up';
          message = 'Your order has been picked up and is on the way!';
          break;
        case DeliveryStatus.delivered:
          title = 'Order Delivered';
          message = 'Your order has been successfully delivered!';
          break;
        case DeliveryStatus.cancelled:
          title = 'Delivery Cancelled';
          message =
              'Your order delivery has been cancelled. Please contact support.';
          break;
        default:
          return;
      }

      // Send notification (implement with your notification service)
      // await NotificationService().sendNotificationToUser(userId, title, message);
    } catch (e) {
      debugPrint('Send delivery notification error: $e');
    }
  }
}

/// Helper function to convert Firestore order to UBCab delivery request
extension OrderToDelivery on Map<String, dynamic> {
  UBCabDeliveryOrder toUBCabDeliveryOrder() {
    return UBCabDeliveryOrder(
      orderId: this['orderId'] ?? '',
      customerId: this['userId'] ?? '',
      storeId: this['storeId'] ?? '',
      pickupAddress: UBCabAddress(
        address: this['storeAddress'] ?? '',
        latitude: (this['storeLatitude'] ?? 0).toDouble(),
        longitude: (this['storeLongitude'] ?? 0).toDouble(),
        contactName: this['storeName'] ?? 'Store',
        contactPhone: this['storePhone'] ?? '77807780',
      ),
      deliveryAddress: UBCabAddress(
        address: this['shippingAddress'] ?? '',
        latitude: (this['deliveryLatitude'] ?? 0).toDouble(),
        longitude: (this['deliveryLongitude'] ?? 0).toDouble(),
        contactName: this['customerName'] ?? 'Customer',
        contactPhone: this['customerPhone'],
      ),
      items: ((this['items'] as List?) ?? [])
          .map((item) => OrderItem.fromJson(item))
          .toList(),
      totalAmount: (this['total'] ?? 0).toDouble(),
      specialInstructions: this['deliveryInstructions'],
      status: DeliveryStatus.requested,
      createdAt: DateTime.now(),
    );
  }
}

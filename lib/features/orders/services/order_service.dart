// ignore_for_file: prefer_const_declarations

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../products/models/product_model.dart';
import '../../stores/models/store_model.dart';
import '../../cart/models/cart_item.dart';

import '../../../admin_panel/services/notification_service.dart';
import '../../../core/services/error_handler_service.dart';
import '../../../core/services/production_logger.dart';
import '../../../core/utils/order_id_generator.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Date range helpers
  DateTime get _today => DateTime.now();
  DateTime get _last30Days => _today.subtract(const Duration(days: 30));

  // **ORDER ARCHIVAL CONSTANTS**
  static const int _archiveAfterDays = 30; // Archive after 30 days
  static const int _compressAfterDays = 90; // Compress after 90 days
  static const int _deleteAfterDays = 365; // Delete after 1 year

  // **CORE ORDER FUNCTIONALITY**

  /// Create order with automatic inventory adjustment
  Future<String> createOrder({
    required User user,
    required double subtotal,
    required double shipping,
    required double tax,
    required List<CartItem> cart,
    required StoreModel store,
    String? discountCode,
    double discountAmount = 0,
    Map<String, dynamic>? deliveryAddress,
    String paymentMethod = 'card',
    String? paymentIntentId,
    String? reservationId,
  }) async {
    try {
      // Generate order ID using the new generator
      final orderId = OrderIdGenerator.generate();

      // Calculate total
      final total = subtotal + shipping + tax - discountAmount;

      // Create order document
      final orderData = {
        'orderId': orderId,
        'userId': user.uid,
        'userEmail': user.email,
        'storeId': store.id,
        'storeName': store.name,
        'items': cart
            .map((item) => {
                  'productId': item.product.id,
                  'name': item.product.name,
                  'price': item.product.price,
                  'quantity': item.quantity,
                  'selectedVariants': item.selectedVariants,
                  'imageUrl': item.product.images.isNotEmpty
                      ? item.product.images.first
                      : '',
                })
            .toList(),
        'subtotal': subtotal,
        'shipping': shipping,
        'tax': tax,
        'discountAmount': discountAmount,
        'discountCode': discountCode,
        'total': total,
        'status': 'placed',
        'paymentMethod': paymentMethod,
        'paymentIntentId': paymentIntentId,
        'deliveryAddress': deliveryAddress,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Execute order creation with inventory adjustment in transaction
      await _firestore.runTransaction((transaction) async {
        // Create order in global orders collection
        final orderRef = _firestore.collection('orders').doc(orderId);
        transaction.set(orderRef, orderData);

        // Create order in user's orders collection
        final userOrderRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('orders')
            .doc(orderId);
        transaction.set(userOrderRef, orderData);

        // Create order in store's orders collection
        final storeOrderRef = _firestore
            .collection('stores')
            .doc(store.id)
            .collection('orders')
            .doc(orderId);
        transaction.set(storeOrderRef, orderData);

        // Adjust inventory for each item (confirm reservation or deduct stock)
        for (final item in cart) {
          await _adjustInventoryForOrderItem(
            transaction,
            item,
            orderId,
            user.uid,
            reservationId,
          );
        }

        // If there was a reservation, confirm it
        if (reservationId != null) {
          final reservationRef = _firestore
              .collection('inventory_reservations')
              .doc(reservationId);
          transaction.update(reservationRef, {
            'status': 'confirmed',
            'orderId': orderId,
            'confirmedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Send notifications asynchronously
      _sendOrderNotifications(store, orderId, user.email ?? '', total);

      // Create inventory adjustment audit trail
      await _createInventoryAuditTrail(orderId, cart, user.uid, store.id);

      return orderId;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  /// Adjust inventory for a single order item
  Future<void> _adjustInventoryForOrderItem(
    Transaction transaction,
    CartItem item,
    String orderId,
    String userId,
    String? reservationId,
  ) async {
    try {
      final productRef = _firestore.collection('products').doc(item.product.id);
      final productSnap = await transaction.get(productRef);

      if (!productSnap.exists) {
        throw Exception('Product ${item.product.id} not found');
      }

      final product = ProductModel.fromFirestore(productSnap);

      // If reservation exists, inventory was already adjusted during reservation
      // We just need to confirm the reservation
      if (reservationId != null) {
        return;
      }

      // Otherwise, adjust inventory now
      if (item.selectedVariants != null && item.selectedVariants!.isNotEmpty) {
        // Adjust variant inventory
        await _adjustVariantInventory(
          transaction,
          productRef,
          product,
          item.selectedVariants!,
          item.quantity,
          orderId,
          userId,
        );
      } else {
        // Adjust simple product inventory
        await _adjustSimpleProductInventory(
          transaction,
          productRef,
          product,
          item.quantity,
          orderId,
          userId,
        );
      }
    } catch (e) {
      throw Exception('Failed to adjust inventory: $e');
    }
  }

  /// Adjust simple product inventory
  Future<void> _adjustSimpleProductInventory(
    Transaction transaction,
    DocumentReference productRef,
    ProductModel product,
    int quantity,
    String orderId,
    String userId,
  ) async {
    final newStock = (product.stock - quantity).clamp(0, 999999);

    transaction.update(productRef, {
      'stock': newStock,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastOrderId': orderId,
    });

    // Publish inventory adjustment event
    await _publishInventoryAdjustmentEvent(
      product.id,
      product.name,
      product.storeId,
      product.stock,
      newStock,
      quantity,
      'order_fulfillment',
      orderId,
      userId,
    );
  }

  /// Adjust variant inventory
  Future<void> _adjustVariantInventory(
    Transaction transaction,
    DocumentReference productRef,
    ProductModel product,
    Map<String, String> selectedVariants,
    int quantity,
    String orderId,
    String userId,
  ) async {
    final updatedVariants = const <Map<String, dynamic>>[];

    for (final variant in product.variants) {
      final selectedOption = selectedVariants[variant.name];
      final variantMap = variant.toMap();

      if (selectedOption != null && variant.trackInventory) {
        final currentStock = variant.getStockForOption(selectedOption);
        final newStock = (currentStock - quantity).clamp(0, 999999);

        final updatedStockByOption =
            Map<String, int>.from(variant.stockByOption);
        updatedStockByOption[selectedOption] = newStock;
        variantMap['stockByOption'] = updatedStockByOption;

        // Publish inventory adjustment event for variant
        await _publishInventoryAdjustmentEvent(
          product.id,
          '${product.name} - ${variant.name}: $selectedOption',
          product.storeId,
          currentStock,
          newStock,
          quantity,
          'order_fulfillment',
          orderId,
          userId,
        );
      }

      updatedVariants.add(variantMap);
    }

    transaction.update(productRef, {
      'variants': updatedVariants,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastOrderId': orderId,
    });
  }

  /// Publish inventory adjustment event
  Future<void> _publishInventoryAdjustmentEvent(
    String productId,
    String productName,
    String storeId,
    int previousStock,
    int newStock,
    int adjustment,
    String reason,
    String orderId,
    String userId,
  ) async {
    try {
      await _firestore.collection('inventory_events').add({
        'type': 'adjustment',
        'productId': productId,
        'productName': productName,
        'storeId': storeId,
        'previousStock': previousStock,
        'newStock': newStock,
        'adjustment': -adjustment, // Negative for order fulfillment
        'reason': reason,
        'orderId': orderId,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Error publishing inventory adjustment event
    }
  }

  /// Create inventory audit trail
  Future<void> _createInventoryAuditTrail(
    String orderId,
    List<CartItem> cart,
    String userId,
    String storeId,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final item in cart) {
        final auditRef = _firestore.collection('inventory_audit_log').doc();
        final auditData = {
          'productId': item.product.id,
          'productName': item.product.name,
          'storeId': storeId,
          'adjustment': -item.quantity,
          'reason': 'order_fulfillment',
          'orderId': orderId,
          'userId': userId,
          'selectedVariants': item.selectedVariants,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'order_fulfillment',
        };

        batch.set(auditRef, auditData);
      }

      await batch.commit();
    } catch (e) {
      // Error creating inventory audit trail
    }
  }

  /// Send order notifications
  void _sendOrderNotifications(
    StoreModel store,
    String orderId,
    String customerEmail,
    double total,
  ) {
    // Send notification to store owner
    NotificationService().notifyNewOrder(
      storeId: store.id,
      ownerId: store.ownerId,
      orderId: orderId,
      customerEmail: customerEmail,
      total: total,
    );
  }

  /// Update order status with inventory restock if cancelled
  Future<void> updateOrderStatus(
    String orderId,
    String newStatus, {
    String? reason,
    bool restockInventory = false,
  }) async {
    try {
      // Get the current user's store ID
      final ownerId = FirebaseAuth.instance.currentUser?.uid;
      if (ownerId == null) {
        throw Exception('User not authenticated');
      }

      // Find the store ID for the current user
      final storeSnapshot = await _firestore
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (storeSnapshot.docs.isEmpty) {
        throw Exception('Store not found for current user');
      }

      final storeId = storeSnapshot.docs.first.id;

      // Update order status
      final updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (reason != null) {
        updateData['statusReason'] = reason;
      }

      // Update in store's orders collection (which store owners have permission to update)
      final storeOrderRef = _firestore
          .collection('stores')
          .doc(storeId)
          .collection('orders')
          .doc(orderId);
      await storeOrderRef.update(updateData);

      // Also try to update in global orders collection for consistency
      try {
        final orderRef = _firestore.collection('orders').doc(orderId);
        await orderRef.update(updateData);
      } catch (e) {
        // If we don't have permission to update global orders, that's okay
        // The store orders collection is the primary source for store owners
        debugPrint('Note: Could not update global orders collection: $e');
      }

      // Note: Inventory restocking for cancelled orders is temporarily disabled
      // to avoid transaction complexity. This can be re-enabled later if needed.
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Restock inventory for cancelled/refunded order
  Future<void> _restockInventoryForOrder(
    Transaction transaction,
    List<Map<String, dynamic>> items,
    String orderId,
    String userId,
  ) async {
    try {
      for (final itemData in items) {
        final productId = itemData['productId'] as String;
        final quantity = itemData['quantity'] as int;
        final selectedVariants =
            itemData['selectedVariants'] as Map<String, String>?;

        final productRef = _firestore.collection('products').doc(productId);
        final productSnap = await transaction.get(productRef);

        if (!productSnap.exists) continue;

        final product = ProductModel.fromFirestore(productSnap);

        if (selectedVariants != null && selectedVariants.isNotEmpty) {
          // Restock variant inventory
          await _restockVariantInventory(
            transaction,
            productRef,
            product,
            selectedVariants,
            quantity,
            orderId,
            userId,
          );
        } else {
          // Restock simple product inventory
          await _restockSimpleProductInventory(
            transaction,
            productRef,
            product,
            quantity,
            orderId,
            userId,
          );
        }
      }
    } catch (e) {
      // Error restocking inventory
    }
  }

  /// Restock simple product inventory
  Future<void> _restockSimpleProductInventory(
    Transaction transaction,
    DocumentReference productRef,
    ProductModel product,
    int quantity,
    String orderId,
    String userId,
  ) async {
    final newStock = product.stock + quantity;

    transaction.update(productRef, {
      'stock': newStock,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastRestockOrderId': orderId,
    });

    // Publish inventory adjustment event
    await _publishInventoryAdjustmentEvent(
      product.id,
      product.name,
      product.storeId,
      product.stock,
      newStock,
      quantity,
      'order_cancellation',
      orderId,
      userId,
    );
  }

  /// Restock variant inventory
  Future<void> _restockVariantInventory(
    Transaction transaction,
    DocumentReference productRef,
    ProductModel product,
    Map<String, String> selectedVariants,
    int quantity,
    String orderId,
    String userId,
  ) async {
    final updatedVariants = const <Map<String, dynamic>>[];

    for (final variant in product.variants) {
      final selectedOption = selectedVariants[variant.name];
      final variantMap = variant.toMap();

      if (selectedOption != null && variant.trackInventory) {
        final currentStock = variant.getStockForOption(selectedOption);
        final newStock = currentStock + quantity;

        final updatedStockByOption =
            Map<String, int>.from(variant.stockByOption);
        updatedStockByOption[selectedOption] = newStock;
        variantMap['stockByOption'] = updatedStockByOption;

        // Publish inventory adjustment event for variant
        await _publishInventoryAdjustmentEvent(
          product.id,
          '${product.name} - ${variant.name}: $selectedOption',
          product.storeId,
          currentStock,
          newStock,
          quantity,
          'order_cancellation',
          orderId,
          userId,
        );
      }

      updatedVariants.add(variantMap);
    }

    transaction.update(productRef, {
      'variants': updatedVariants,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastRestockOrderId': orderId,
    });
  }

  // **ORDER ANALYTICS METHODS**

  Future<Map<String, dynamic>> getOrderAnalytics(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? _last30Days;
      final end = endDate ?? _today;

      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final orders = ordersSnapshot.docs;
      final statusCounts = <String, int>{};
      double totalRevenue = 0.0;
      double totalSubtotal = 0.0;
      double totalShipping = 0.0;
      double totalTax = 0.0;
      int totalItems = 0;

      for (final order in orders) {
        final data = order.data();
        final status = _getStatusAsString(data['status']);
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        final safeStatus = _getStatusAsString(status);
        if (safeStatus != 'canceled') {
          totalRevenue += (data['total'] ?? 0).toDouble();
          totalSubtotal += (data['subtotal'] ?? 0).toDouble();
          totalShipping += (data['shippingCost'] ?? 0).toDouble();
          totalTax += (data['tax'] ?? 0).toDouble();
          totalItems += (data['itemCount'] ?? 0) as int;
        }
      }

      return {
        'totalOrders': orders.length,
        'totalRevenue': totalRevenue,
        'totalSubtotal': totalSubtotal,
        'totalShipping': totalShipping,
        'totalTax': totalTax,
        'totalItems': totalItems,
        'statusDistribution': statusCounts,
        'averageOrderValue':
            orders.isNotEmpty ? totalRevenue / orders.length : 0.0,
        'averageItemsPerOrder':
            orders.isNotEmpty ? totalItems / orders.length : 0.0,
      };
    } catch (e) {
      throw Exception('Failed to get order analytics: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getOrderTrendData(
    String storeId, {
    String period = 'daily',
    int days = 30,
  }) async {
    try {
      final trends = <Map<String, dynamic>>[];
      final now = DateTime.now();

      if (period == 'daily') {
        for (int i = days - 1; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final startOfDay = DateTime(date.year, date.month, date.day);
          final endOfDay = startOfDay.add(const Duration(days: 1));

          final snapshot = await _firestore
              .collection('orders')
              .where('storeId', isEqualTo: storeId)
              .where('createdAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
              .get();

          double dayRevenue = 0.0;
          int dayOrders = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = _getStatusAsString(data['status']);
            if (status != 'canceled') {
              dayRevenue += (data['total'] ?? 0).toDouble();
              dayOrders++;
            }
          }

          trends.add({
            'date': startOfDay,
            'period': '${date.month}/${date.day}',
            'revenue': dayRevenue,
            'orders': dayOrders,
            'averageOrderValue': dayOrders > 0 ? dayRevenue / dayOrders : 0.0,
          });
        }
      } else if (period == 'weekly') {
        for (int i = 7; i >= 0; i--) {
          final endDate = now.subtract(Duration(days: i * 7));
          final startDate = endDate.subtract(const Duration(days: 7));

          final snapshot = await _firestore
              .collection('orders')
              .where('storeId', isEqualTo: storeId)
              .where('createdAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .where('createdAt', isLessThan: Timestamp.fromDate(endDate))
              .get();

          double weekRevenue = 0.0;
          int weekOrders = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = _getStatusAsString(data['status']);
            if (status != 'canceled') {
              weekRevenue += (data['total'] ?? 0).toDouble();
              weekOrders++;
            }
          }

          trends.add({
            'date': startDate,
            'period': 'Week ${_getWeekOfYear(startDate)}',
            'revenue': weekRevenue,
            'orders': weekOrders,
            'averageOrderValue':
                weekOrders > 0 ? weekRevenue / weekOrders : 0.0,
          });
        }
      }

      return trends;
    } catch (e) {
      throw Exception('Failed to get order trend data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentOrders(String storeId,
      {int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'userEmail': data['userEmail'] ?? '',
          'total': data['total'] ?? 0.0,
          'status': _getStatusAsString(data['status']),
          'createdAt': data['createdAt'],
          'itemCount': data['itemCount'] ?? 0,
          'items': data['items'] ?? [],
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get recent orders: $e');
    }
  }

  Future<Map<String, int>> getOrderStatusCounts(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? _last30Days;
      final end = endDate ?? _today;

      final snapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      const statusCounts = <String, int>{
        'placed': 0,
        'processing': 0,
        'shipped': 0,
        'delivered': 0,
        'canceled': 0,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = _getStatusAsString(data['status']);
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      return statusCounts;
    } catch (e) {
      throw Exception('Failed to get order status counts: $e');
    }
  }

  Future<Map<String, double>> getRevenueByPeriod(
    String storeId, {
    String period = 'monthly',
    int periods = 12,
  }) async {
    try {
      final revenueData = <String, double>{};
      final now = DateTime.now();

      if (period == 'monthly') {
        for (int i = periods - 1; i >= 0; i--) {
          final monthStart = DateTime(now.year, now.month - i, 1);
          final monthEnd = DateTime(now.year, now.month - i + 1, 1);

          final snapshot = await _firestore
              .collection('orders')
              .where('storeId', isEqualTo: storeId)
              .where('createdAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
              .where('createdAt', isLessThan: Timestamp.fromDate(monthEnd))
              .get();

          double monthRevenue = 0.0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = _getStatusAsString(data['status']);
            if (status != 'canceled') {
              monthRevenue += (data['total'] ?? 0).toDouble();
            }
          }

          final monthKey =
              '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}';
          revenueData[monthKey] = monthRevenue;
        }
      } else if (period == 'daily') {
        for (int i = periods - 1; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final dayStart = DateTime(date.year, date.month, date.day);
          final dayEnd = dayStart.add(const Duration(days: 1));

          final snapshot = await _firestore
              .collection('orders')
              .where('storeId', isEqualTo: storeId)
              .where('createdAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
              .where('createdAt', isLessThan: Timestamp.fromDate(dayEnd))
              .get();

          double dayRevenue = 0.0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = _getStatusAsString(data['status']);
            if (status != 'canceled') {
              dayRevenue += (data['total'] ?? 0).toDouble();
            }
          }

          final dayKey = '${date.month}/${date.day}';
          revenueData[dayKey] = dayRevenue;
        }
      }

      return revenueData;
    } catch (e) {
      throw Exception('Failed to get revenue by period: $e');
    }
  }

  // **ORDER MANAGEMENT METHODS**

  // **ORDER ANALYTICS METHODS**

  Future<Map<String, dynamic>> getOrderAnalyticsDetailed(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? _last30Days;
      final end = endDate ?? _today;

      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final orders = ordersSnapshot.docs;
      final statusCounts = <String, int>{};
      double totalRevenue = 0.0;
      double totalSubtotal = 0.0;
      double totalShipping = 0.0;
      double totalTax = 0.0;
      int totalItems = 0;

      for (final order in orders) {
        final data = order.data();
        final status = _getStatusAsString(data['status']);
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        final safeStatus = _getStatusAsString(status);
        if (safeStatus != 'canceled') {
          totalRevenue += (data['total'] ?? 0).toDouble();
          totalSubtotal += (data['subtotal'] ?? 0).toDouble();
          totalShipping += (data['shippingCost'] ?? 0).toDouble();
          totalTax += (data['tax'] ?? 0).toDouble();
          totalItems += (data['itemCount'] ?? 0) as int;
        }
      }

      return {
        'totalOrders': orders.length,
        'totalRevenue': totalRevenue,
        'totalSubtotal': totalSubtotal,
        'totalShipping': totalShipping,
        'totalTax': totalTax,
        'totalItems': totalItems,
        'statusDistribution': statusCounts,
        'averageOrderValue':
            orders.isNotEmpty ? totalRevenue / orders.length : 0.0,
        'averageItemsPerOrder':
            orders.isNotEmpty ? totalItems / orders.length : 0.0,
      };
    } catch (e) {
      throw Exception('Failed to get order analytics: $e');
    }
  }

  /// Get inventory impact from orders
  Future<Map<String, dynamic>> getInventoryImpact(String storeId) async {
    try {
      final auditLogs = await _firestore
          .collection('inventory_audit_log')
          .where('storeId', isEqualTo: storeId)
          .where('type', isEqualTo: 'order_fulfillment')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final Map<String, int> inventoryChanges = {};
      int totalAdjustments = 0;

      for (final logDoc in auditLogs.docs) {
        final data = logDoc.data();
        final productId = data['productId'] as String;
        final adjustment = data['adjustment'] as int;

        inventoryChanges[productId] =
            (inventoryChanges[productId] ?? 0) + adjustment.abs();
        totalAdjustments += adjustment.abs();
      }

      return {
        'totalAdjustments': totalAdjustments,
        'inventoryChanges': inventoryChanges,
        'mostAffectedProducts': inventoryChanges.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
      };
    } catch (e) {
      // Error getting inventory impact
      return {};
    }
  }

  // **HELPER METHODS**

  int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay - date.weekday + 10) / 7).floor();
  }

  Future<Map<String, dynamic>> getOrderSummary(String storeId) async {
    try {
      // Get today's orders
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todaySnapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      // Get pending orders (placed + processing)
      final pendingSnapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('status', whereIn: ['placed', 'processing']).get();

      // Get this month's orders
      final monthStart = DateTime(today.year, today.month, 1);
      final monthSnapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .get();

      double monthlyRevenue = 0.0;
      for (final doc in monthSnapshot.docs) {
        final data = doc.data();
        final status = _getStatusAsString(data['status']);
        if (status != 'canceled') {
          monthlyRevenue += (data['total'] ?? 0).toDouble();
        }
      }

      return {
        'todayOrders': todaySnapshot.docs.length,
        'pendingOrders': pendingSnapshot.docs.length,
        'monthlyOrders': monthSnapshot.docs.length,
        'monthlyRevenue': monthlyRevenue,
      };
    } catch (e) {
      throw Exception('Failed to get order summary: $e');
    }
  }

  // Helper method to safely convert status field to string
  String _getStatusAsString(dynamic status) {
    if (status == null) return 'placed';
    if (status is String) return status;
    if (status is bool) {
      // Handle cases where status might be stored as boolean
      return status ? 'active' : 'inactive';
    }
    return status.toString();
  }

  // **ORDER ARCHIVAL AND CLEANUP METHODS**

  /// Archive delivered orders older than specified days
  Future<void> archiveOldOrders() async {
    try {
      final cutoffDate =
          _today.subtract(const Duration(days: _archiveAfterDays));

      // Get orders to archive
      final ordersToArchive = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('updatedAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(100) // Process in batches
          .get();

      final batch = _firestore.batch();

      for (final doc in ordersToArchive.docs) {
        final orderData = doc.data();

        // Create archived version with reduced data
        final archivedData = _createArchivedOrderData(orderData);

        // Add to archived collection
        final archivedRef =
            _firestore.collection('archived_orders').doc(doc.id);
        batch.set(archivedRef, archivedData);

        // Mark as archived in original collection
        batch.update(doc.reference, {
          'archived': true,
          'archivedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await ProductionLogger.instance.info(
        'Archived ${ordersToArchive.docs.length} orders',
        context: {'count': ordersToArchive.docs.length},
      );
    } catch (error, stackTrace) {
      await ErrorHandlerService.instance.handleFirebaseError(
        operation: 'archive_orders',
        error: error,
        stackTrace: stackTrace,
        showUserMessage: false, // Background operation
        additionalContext: {
          'orderCount': null, // Variable not available in catch block
        },
      );
    }
  }

  /// Compress archived orders older than specified days
  Future<void> compressOldArchivedOrders() async {
    try {
      final cutoffDate =
          _today.subtract(const Duration(days: _compressAfterDays));

      // Get archived orders to compress
      final ordersToCompress = await _firestore
          .collection('archived_orders')
          .where('deliveredAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(100) // Process in batches
          .get();

      final batch = _firestore.batch();

      for (final doc in ordersToCompress.docs) {
        final orderData = doc.data();

        // Create compressed version with minimal data
        final compressedData = _createCompressedOrderData(orderData);

        // Add to historical collection
        final historicalRef =
            _firestore.collection('historical_orders').doc(doc.id);
        batch.set(historicalRef, compressedData);

        // Delete from archived collection
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      // Error compressing archived orders
    }
  }

  /// Delete historical orders older than specified days
  Future<void> deleteOldHistoricalOrders() async {
    try {
      final cutoffDate =
          _today.subtract(const Duration(days: _deleteAfterDays));

      // Get historical orders to delete
      final ordersToDelete = await _firestore
          .collection('historical_orders')
          .where('deliveredAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(100) // Process in batches
          .get();

      final batch = _firestore.batch();

      for (final doc in ordersToDelete.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      // Error deleting historical orders
    }
  }

  /// Create archived order data with reduced fields
  Map<String, dynamic> _createArchivedOrderData(
      Map<String, dynamic> originalData) {
    return {
      'orderId': originalData['id'] ?? '',
      'status': originalData['status'] ?? 'delivered',
      'total': originalData['total'] ?? 0.0,
      'subtotal': originalData['subtotal'] ?? 0.0,
      'shippingCost': originalData['shippingCost'] ?? 0.0,
      'tax': originalData['tax'] ?? 0.0,
      'storeId': originalData['storeId'] ?? '',
      'storeName': originalData['storeName'] ?? '',
      'vendorId': originalData['vendorId'] ?? '',
      'userId': originalData['userId'] ?? '',
      'userEmail': originalData['userEmail'] ?? '',
      'customerName': originalData['customerName'] ?? '',
      'createdAt': originalData['createdAt'],
      'deliveredAt': originalData['updatedAt'],
      'archivedAt': FieldValue.serverTimestamp(),
      'itemCount': originalData['itemCount'] ?? 0,
      'items': _compressOrderItems(originalData['items'] ?? []),
      // Keep analytics data
      'analytics': originalData['analytics'] ?? {},
    };
  }

  /// Create compressed order data with minimal fields for analytics
  Map<String, dynamic> _createCompressedOrderData(
      Map<String, dynamic> archivedData) {
    return {
      'orderId': archivedData['orderId'] ?? '',
      'status': archivedData['status'] ?? 'delivered',
      'total': archivedData['total'] ?? 0.0,
      'storeId': archivedData['storeId'] ?? '',
      'vendorId': archivedData['vendorId'] ?? '',
      'userId': archivedData['userId'] ?? '',
      'createdAt': archivedData['createdAt'],
      'deliveredAt': archivedData['deliveredAt'],
      'compressedAt': FieldValue.serverTimestamp(),
      'itemCount': archivedData['itemCount'] ?? 0,
      // Keep only essential analytics data
      'analytics': archivedData['analytics'] ?? {},
    };
  }

  /// Compress order items to reduce storage
  List<Map<String, dynamic>> _compressOrderItems(List<dynamic> items) {
    return items.map<Map<String, dynamic>>((item) {
      if (item is Map<String, dynamic>) {
        return {
          'name': item['name'] ?? '',
          'price': item['price'] ?? 0.0,
          'quantity': item['quantity'] ?? 1,
          'variant': item['variant'] ?? '',
          // Remove imageUrl to save space
        };
      }
      return {};
    }).toList();
  }

  /// Get orders for a store from all collections
  Future<List<Map<String, dynamic>>> getStoreOrders(
    String storeId, {
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final List<Map<String, dynamic>> allOrders = [];

    try {
      // Get from main orders collection
      Query mainQuery =
          _firestore.collection('orders').where('storeId', isEqualTo: storeId);
      if (status != null) {
        mainQuery = mainQuery.where('status', isEqualTo: status);
      }
      if (startDate != null) {
        mainQuery = mainQuery.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        mainQuery = mainQuery.where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final mainOrders =
          await mainQuery.orderBy('createdAt', descending: true).get();
      allOrders.addAll(
          mainOrders.docs.map((doc) => doc.data() as Map<String, dynamic>));

      // Get from archived orders collection (if within date range)
      if (startDate == null ||
          startDate.isAfter(
              _today.subtract(const Duration(days: _archiveAfterDays)))) {
        Query archivedQuery = _firestore
            .collection('archived_orders')
            .where('storeId', isEqualTo: storeId);
        if (status != null) {
          archivedQuery = archivedQuery.where('status', isEqualTo: status);
        }
        if (startDate != null) {
          archivedQuery = archivedQuery.where('deliveredAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        }
        if (endDate != null) {
          archivedQuery = archivedQuery.where('deliveredAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate));
        }

        final archivedOrders =
            await archivedQuery.orderBy('deliveredAt', descending: true).get();
        allOrders.addAll(archivedOrders.docs
            .map((doc) => doc.data() as Map<String, dynamic>));
      }

      // Sort all orders by date
      allOrders.sort((a, b) {
        final aDate = (a['createdAt'] ?? a['deliveredAt']) as Timestamp?;
        final bDate = (b['createdAt'] ?? b['deliveredAt']) as Timestamp?;
        if (aDate == null || bDate == null) return 0;
        return bDate.compareTo(aDate);
      });

      return allOrders;
    } catch (e) {
      // Error fetching store orders
      return [];
    }
  }

  /// Run complete cleanup process
  Future<void> runOrderCleanup() async {
    await archiveOldOrders();
    await compressOldArchivedOrders();
    await deleteOldHistoricalOrders();
  }
}

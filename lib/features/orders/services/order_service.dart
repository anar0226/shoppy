import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:avii/features/cart/models/cart_item.dart';
import 'package:avii/features/stores/models/store_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../admin_panel/services/notification_service.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;

  // Date range helpers
  DateTime get _today => DateTime.now();
  DateTime get _last7Days => _today.subtract(const Duration(days: 7));
  DateTime get _last30Days => _today.subtract(const Duration(days: 30));

  // **ORDER ARCHIVAL CONSTANTS**
  static const int _archiveAfterDays = 30; // Archive after 30 days
  static const int _compressAfterDays = 90; // Compress after 90 days
  static const int _deleteAfterDays = 365; // Delete after 1 year

  // **CORE ORDER FUNCTIONALITY**

  Future<String> createOrder({
    required User user,
    required double subtotal,
    required double shipping,
    required double tax,
    required List<CartItem> cart,
    required StoreModel store,
  }) async {
    final now = DateTime.now();
    final items = cart
        .map((c) => {
              'productId': c.product.id,
              'name': c.product.name,
              'imageUrl':
                  c.product.images.isNotEmpty ? c.product.images.first : '',
              'price': c.product.price,
              'variant': c.variantDisplayText,
              'quantity': c.quantity,
            })
        .toList();

    // Get customer name from user profile or fallback to display name or email
    String customerName = 'Үйлчлүүлэгч';
    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        customerName = userData?['displayName'] ??
            userData?['firstName'] ??
            userData?['name'] ??
            user.displayName ??
            user.email?.split('@').first ??
            'Үйлчлүүлэгч';
      } else {
        customerName =
            user.displayName ?? user.email?.split('@').first ?? 'Үйлчлүүлэгч';
      }
    } catch (e) {
      // Fallback if user data fetch fails
      customerName =
          user.displayName ?? user.email?.split('@').first ?? 'Үйлчлүүлэгч';
    }

    final orderData = {
      'status': 'placed',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'subtotal': subtotal,
      'shippingCost': shipping,
      'tax': tax,
      'total': subtotal + shipping + tax,
      'items': items,
      'storeId': store.id,
      'storeName': store.name,
      'vendorId': store.ownerId, // Add vendor ID for admin panel queries
      'userId': user.uid,
      'userEmail': user.email ?? '',
      'customerName': customerName, // Add customer name
      // Enhanced fields for analytics
      'analytics': {
        'month': '${now.year}-${now.month.toString().padLeft(2, '0')}',
        'week':
            '${now.year}-W${_getWeekOfYear(now).toString().padLeft(2, '0')}',
        'day':
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      },
      'itemCount': items.fold<int>(
          0, (sum, item) => sum + ((item['quantity'] ?? 0) as int)),
    };

    // Create the order in main collection first to get the order ID
    final orderDoc = await _db.collection('orders').add(orderData);

    // Add the main order ID reference and save to user's collection
    final userOrderData = Map<String, dynamic>.from(orderData);
    userOrderData['mainOrderId'] = orderDoc.id;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .add(userOrderData);

    // Send notification to store owner about new order
    try {
      await NotificationService.notifyStoreOwnerNewOrder(
        storeId: store.id,
        ownerId: store.ownerId,
        orderId: orderDoc.id,
        customerEmail: user.email ?? '',
        total: subtotal + shipping + tax,
        items: items,
      );
    } catch (e) {
      // Don't fail order creation if notification fails
      // Failed to send order notification
    }

    return orderDoc.id;
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

      final ordersSnapshot = await _db
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

          final snapshot = await _db
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

          final snapshot = await _db
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
      final snapshot = await _db
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

      final snapshot = await _db
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final statusCounts = <String, int>{
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

          final snapshot = await _db
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

          final snapshot = await _db
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

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add specific timestamp for status changes
      if (newStatus == 'shipped') {
        updateData['shippedAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'delivered') {
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'canceled') {
        updateData['canceledAt'] = FieldValue.serverTimestamp();
      }

      // Update main orders collection
      await _db.collection('orders').doc(orderId).update(updateData);

      // Also update user's personal orders collection for mobile app sync
      await _updateUserOrderStatus(orderId, updateData);
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Update the user's personal orders collection to sync with mobile app
  Future<void> _updateUserOrderStatus(
      String orderId, Map<String, dynamic> updateData) async {
    try {
      // First get the order to find the user ID
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final userId = orderData['userId'] as String?;

      if (userId != null && userId.isNotEmpty) {
        // Add the main order ID to the update data for future reference
        final enhancedUpdateData = Map<String, dynamic>.from(updateData);
        enhancedUpdateData['mainOrderId'] = orderId;

        // Find matching order in user's collection using multiple criteria
        final userOrdersQuery = await _db
            .collection('users')
            .doc(userId)
            .collection('orders')
            .get();

        DocumentSnapshot? matchingUserOrder;

        // Try to find by stored main order ID first (for future orders)
        for (final userOrderDoc in userOrdersQuery.docs) {
          final userOrderData = userOrderDoc.data();

          if (userOrderData['mainOrderId'] == orderId) {
            matchingUserOrder = userOrderDoc;
            break;
          }
        }

        // If not found by order ID, try to match by order details
        if (matchingUserOrder == null) {
          final orderCreatedAt = orderData['createdAt'] as Timestamp?;
          final orderTotal = orderData['total'];
          final orderStoreId = orderData['storeId'];

          for (final userOrderDoc in userOrdersQuery.docs) {
            final userOrderData = userOrderDoc.data();

            final userOrderCreatedAt = userOrderData['createdAt'] as Timestamp?;
            final userOrderTotal = userOrderData['total'];
            final userOrderStoreId = userOrderData['storeId'];

            // Match by creation time, total amount, and store ID
            if (orderCreatedAt != null &&
                userOrderCreatedAt != null &&
                orderStoreId == userOrderStoreId &&
                orderTotal == userOrderTotal &&
                (orderCreatedAt.seconds - userOrderCreatedAt.seconds).abs() <=
                    2) {
              matchingUserOrder = userOrderDoc;
              break;
            }
          }
        }

        // Update the matching user order
        if (matchingUserOrder != null) {
          await _db
              .collection('users')
              .doc(userId)
              .collection('orders')
              .doc(matchingUserOrder.id)
              .update(enhancedUpdateData);
          print(
              '✅ Successfully synced order status to mobile app: ${matchingUserOrder.id} -> ${updateData['status']}');
        } else {
          print('⚠️ Could not find matching user order for $orderId');
        }
      }
    } catch (e) {
      // Don't fail the main update if user order sync fails
      print('❌ Failed to sync user order status: $e');
    }
  }

  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    try {
      // First try main orders collection
      final mainOrder = await _db.collection('orders').doc(orderId).get();
      if (mainOrder.exists) {
        return mainOrder.data();
      }

      // Try archived orders
      final archivedOrder =
          await _db.collection('archived_orders').doc(orderId).get();
      if (archivedOrder.exists) {
        return archivedOrder.data();
      }

      // Try historical orders
      final historicalOrder =
          await _db.collection('historical_orders').doc(orderId).get();
      if (historicalOrder.exists) {
        return historicalOrder.data();
      }

      return null;
    } catch (e) {
      print('Error fetching order $orderId: $e');
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> getOrdersStream(
    String storeId, {
    String? status,
    int limit = 50,
  }) {
    try {
      Query query = _db
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .orderBy('createdAt', descending: true);

      if (status != null && status != 'all') {
        query = query.where('status', isEqualTo: status);
      }

      query = query.limit(limit);

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      throw Exception('Failed to get orders stream: $e');
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

      final todaySnapshot = await _db
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      // Get pending orders (placed + processing)
      final pendingSnapshot = await _db
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('status', whereIn: ['placed', 'processing']).get();

      // Get this month's orders
      final monthStart = DateTime(today.year, today.month, 1);
      final monthSnapshot = await _db
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

  // Helper method to safely get boolean from dynamic value
  bool _getBooleanValue(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value.toLowerCase() == 'active';
    }
    if (value is int) return value != 0;
    return defaultValue;
  }

  // **ORDER ARCHIVAL AND CLEANUP METHODS**

  /// Archive delivered orders older than specified days
  Future<void> archiveOldOrders() async {
    try {
      final cutoffDate = _today.subtract(Duration(days: _archiveAfterDays));

      // Get orders to archive
      final ordersToArchive = await _db
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('updatedAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(100) // Process in batches
          .get();

      final batch = _db.batch();

      for (final doc in ordersToArchive.docs) {
        final orderData = doc.data();

        // Create archived version with reduced data
        final archivedData = _createArchivedOrderData(orderData);

        // Add to archived collection
        final archivedRef = _db.collection('archived_orders').doc(doc.id);
        batch.set(archivedRef, archivedData);

        // Mark as archived in original collection
        batch.update(doc.reference, {
          'archived': true,
          'archivedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      print('Archived ${ordersToArchive.docs.length} orders');
    } catch (e) {
      print('Error archiving orders: $e');
    }
  }

  /// Compress archived orders older than specified days
  Future<void> compressOldArchivedOrders() async {
    try {
      final cutoffDate = _today.subtract(Duration(days: _compressAfterDays));

      // Get archived orders to compress
      final ordersToCompress = await _db
          .collection('archived_orders')
          .where('deliveredAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(100) // Process in batches
          .get();

      final batch = _db.batch();

      for (final doc in ordersToCompress.docs) {
        final orderData = doc.data();

        // Create compressed version with minimal data
        final compressedData = _createCompressedOrderData(orderData);

        // Add to historical collection
        final historicalRef = _db.collection('historical_orders').doc(doc.id);
        batch.set(historicalRef, compressedData);

        // Delete from archived collection
        batch.delete(doc.reference);
      }

      await batch.commit();

      print('Compressed ${ordersToCompress.docs.length} archived orders');
    } catch (e) {
      print('Error compressing archived orders: $e');
    }
  }

  /// Delete historical orders older than specified days
  Future<void> deleteOldHistoricalOrders() async {
    try {
      final cutoffDate = _today.subtract(Duration(days: _deleteAfterDays));

      // Get historical orders to delete
      final ordersToDelete = await _db
          .collection('historical_orders')
          .where('deliveredAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(100) // Process in batches
          .get();

      final batch = _db.batch();

      for (final doc in ordersToDelete.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      print('Deleted ${ordersToDelete.docs.length} historical orders');
    } catch (e) {
      print('Error deleting historical orders: $e');
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
          _db.collection('orders').where('storeId', isEqualTo: storeId);
      if (status != null)
        mainQuery = mainQuery.where('status', isEqualTo: status);
      if (startDate != null)
        mainQuery = mainQuery.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      if (endDate != null)
        mainQuery = mainQuery.where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));

      final mainOrders =
          await mainQuery.orderBy('createdAt', descending: true).get();
      allOrders.addAll(
          mainOrders.docs.map((doc) => doc.data() as Map<String, dynamic>));

      // Get from archived orders collection (if within date range)
      if (startDate == null ||
          startDate
              .isAfter(_today.subtract(Duration(days: _archiveAfterDays)))) {
        Query archivedQuery = _db
            .collection('archived_orders')
            .where('storeId', isEqualTo: storeId);
        if (status != null)
          archivedQuery = archivedQuery.where('status', isEqualTo: status);
        if (startDate != null)
          archivedQuery = archivedQuery.where('deliveredAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        if (endDate != null)
          archivedQuery = archivedQuery.where('deliveredAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate));

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
      print('Error fetching store orders: $e');
      return [];
    }
  }

  /// Run complete cleanup process
  Future<void> runOrderCleanup() async {
    print('Starting order cleanup process...');

    await archiveOldOrders();
    await compressOldArchivedOrders();
    await deleteOldHistoricalOrders();

    print('Order cleanup process completed');
  }
}

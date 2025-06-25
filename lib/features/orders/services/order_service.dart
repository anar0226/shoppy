import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shoppy/features/cart/models/cart_item.dart';
import 'package:shoppy/features/stores/models/store_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;

  // Date range helpers
  DateTime get _today => DateTime.now();
  DateTime get _last7Days => _today.subtract(const Duration(days: 7));
  DateTime get _last30Days => _today.subtract(const Duration(days: 30));

  // **CORE ORDER FUNCTIONALITY**

  Future<void> createOrder({
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
              'variant': c.variant ?? '',
              'quantity': c.quantity,
            })
        .toList();

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
      'userId': user.uid,
      'userEmail': user.email ?? '',
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

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .add(orderData);
    await _db.collection('orders').add(orderData);
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
        final status = data['status'] ?? 'unknown';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        if (status != 'canceled') {
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
            if (data['status'] != 'canceled') {
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
            if (data['status'] != 'canceled') {
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
          'status': data['status'] ?? 'placed',
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
        final status = data['status'] ?? 'placed';
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
            if (data['status'] != 'canceled') {
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
            if (data['status'] != 'canceled') {
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

      await _db.collection('orders').doc(orderId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get order: $e');
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
        if (data['status'] != 'canceled') {
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
}

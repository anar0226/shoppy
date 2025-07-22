import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/analytics_metrics.dart';
import '../models/revenue_trend.dart';
import '../models/top_product.dart';
import '../models/customer_segment.dart';
import '../models/conversion_funnel.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Date range helper properties
  DateTime get _today => DateTime.now();
  DateTime get _last7Days => _today.subtract(const Duration(days: 7));
  DateTime get _last30Days => _today.subtract(const Duration(days: 30));

  // **REVENUE & SALES ANALYTICS**

  Future<AnalyticsMetrics> getRevenueAnalytics(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
    String period = 'last30days',
  }) async {
    try {
      final dateRange = _getDateRange(period, startDate, endDate);
      final currentStart = dateRange['current']!['start']!;
      final currentEnd = dateRange['current']!['end']!;
      final previousStart = dateRange['previous']!['start']!;
      final previousEnd = dateRange['previous']!['end']!;

      // Get current period data
      final currentMetrics =
          await _getMetricsForPeriod(storeId, currentStart, currentEnd);

      // Get previous period data for comparison
      final previousMetrics =
          await _getMetricsForPeriod(storeId, previousStart, previousEnd);

      // Get product count
      final productMetrics = await _getProductMetrics(storeId);

      return AnalyticsMetrics(
        totalRevenue: currentMetrics['revenue'] ?? 0.0,
        previousRevenue: previousMetrics['revenue'] ?? 0.0,
        totalOrders: currentMetrics['orders'] ?? 0,
        previousOrders: previousMetrics['orders'] ?? 0,
        totalCustomers: currentMetrics['customers'] ?? 0,
        previousCustomers: previousMetrics['customers'] ?? 0,
        averageOrderValue: currentMetrics['averageOrderValue'] ?? 0.0,
        previousAverageOrderValue: previousMetrics['averageOrderValue'] ?? 0.0,
        totalProducts: productMetrics['total'] ?? 0,
        lowStockProducts: productMetrics['lowStock'] ?? 0,
      );
    } catch (e) {
      throw Exception('Failed to get revenue analytics: $e');
    }
  }

  Future<List<RevenueTrend>> getRevenueTrends(
    String storeId, {
    String period = 'last30days',
    String granularity = 'daily',
  }) async {
    try {
      final trends = <RevenueTrend>[];
      final now = DateTime.now();

      if (granularity == 'daily') {
        // Get daily trends for the last 30 days
        for (int i = 29; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final startOfDay = DateTime(date.year, date.month, date.day);
          final endOfDay = startOfDay.add(const Duration(days: 1));

          final metrics =
              await _getMetricsForPeriod(storeId, startOfDay, endOfDay);

          trends.add(RevenueTrend(
            period: '${date.month}/${date.day}',
            date: date,
            revenue: metrics['revenue'] ?? 0.0,
            orders: metrics['orders'] ?? 0,
            customers: metrics['customers'] ?? 0,
            averageOrderValue: metrics['averageOrderValue'] ?? 0.0,
          ));
        }
      } else if (granularity == 'monthly') {
        // Get monthly trends for the last 12 months
        for (int i = 11; i >= 0; i--) {
          final date = DateTime(now.year, now.month - i, 1);
          final endOfMonth = DateTime(date.year, date.month + 1, 1);

          final metrics = await _getMetricsForPeriod(storeId, date, endOfMonth);

          trends.add(RevenueTrend(
            period: '${date.year}-${date.month.toString().padLeft(2, '0')}',
            date: date,
            revenue: metrics['revenue'] ?? 0.0,
            orders: metrics['orders'] ?? 0,
            customers: metrics['customers'] ?? 0,
            averageOrderValue: metrics['averageOrderValue'] ?? 0.0,
          ));
        }
      }

      return trends;
    } catch (e) {
      throw Exception('Failed to get revenue trends: $e');
    }
  }

  // **ORDER ANALYTICS**

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

      for (final order in orders) {
        final data = order.data();
        final status = _getStatusAsString(data['status']);
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        if (status != 'canceled') {
          totalRevenue += (data['total'] ?? 0).toDouble();
        }
      }

      return {
        'totalOrders': orders.length,
        'totalRevenue': totalRevenue,
        'statusDistribution': statusCounts,
        'averageOrderValue':
            orders.isNotEmpty ? totalRevenue / orders.length : 0.0,
      };
    } catch (e) {
      throw Exception('Failed to get order analytics: $e');
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
          'status': data['status'] ?? 'placed',
          'createdAt': data['createdAt'],
          'itemCount': (data['items'] as List?)?.length ?? 0,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get recent orders: $e');
    }
  }

  // **PRODUCT ANALYTICS**

  Future<List<TopProduct>> getTopSellingProducts(
    String storeId, {
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? _last30Days;
      final end = endDate ?? _today;

      // Get all orders in the date range
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      // Aggregate product sales data
      final productSales = <String, Map<String, dynamic>>{};

      for (final orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();

        // Safe type checking for order status to filter out canceled orders
        final orderStatus = _getStatusAsString(orderData['status']);
        if (orderStatus == 'canceled') continue;

        final items = orderData['items'] as List<dynamic>? ?? [];

        for (final item in items) {
          // Skip if item data is malformed
          if (item == null || item is! Map<String, dynamic>) continue;

          final productId = item['productId'] ?? '';
          if (productId.isEmpty) continue;

          final quantity = item['quantity'] ?? 0;
          final price = (item['price'] ?? 0).toDouble();
          final revenue = price * quantity;

          if (productSales.containsKey(productId)) {
            productSales[productId]!['unitsSold'] += quantity;
            productSales[productId]!['revenue'] += revenue;
          } else {
            productSales[productId] = {
              'id': productId,
              'name': item['name'] ?? '',
              'imageUrl': item['imageUrl'] ?? '',
              'price': price,
              'unitsSold': quantity,
              'revenue': revenue,
            };
          }
        }
      }

      // Convert to TopProduct objects and sort by units sold
      final topProducts = productSales.values
          .map((data) => TopProduct.fromMap(data))
          .toList()
        ..sort((a, b) => b.unitsSold.compareTo(a.unitsSold));

      // Add ranks and return top N
      for (int i = 0; i < topProducts.length; i++) {
        topProducts[i] = TopProduct(
          id: topProducts[i].id,
          name: topProducts[i].name,
          imageUrl: topProducts[i].imageUrl,
          unitsSold: topProducts[i].unitsSold,
          revenue: topProducts[i].revenue,
          price: topProducts[i].price,
          category: topProducts[i].category,
          rank: i + 1,
          conversionRate: topProducts[i].conversionRate,
        );
      }

      return topProducts.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get top selling products: $e');
    }
  }

  Future<List<CategoryPerformance>> getCategoryPerformance(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? _last30Days;
      final end = endDate ?? _today;

      // Get products for this store (only active products)
      final productsSnapshot = await _firestore
          .collection('products')
          .where('storeId', isEqualTo: storeId)
          .get();

      final products = <String, Map<String, dynamic>>{};
      final categories = <String, CategoryPerformance>{};

      // Build product lookup and initialize categories
      for (final doc in productsSnapshot.docs) {
        final data = doc.data();

        // Safe type checking for isActive field
        final isActive = _getBooleanValue(data['isActive'], defaultValue: true);

        // Only include active products
        if (!isActive) continue;

        products[doc.id] = data;

        final category = data['category'] ?? 'Uncategorized';
        if (!categories.containsKey(category)) {
          categories[category] = CategoryPerformance(
            category: category,
            productCount: 0,
            totalUnitsSold: 0,
            totalRevenue: 0.0,
            averagePrice: 0.0,
            conversionRate: 0.0,
          );
        }
        categories[category] = CategoryPerformance(
          category: category,
          productCount: categories[category]!.productCount + 1,
          totalUnitsSold: categories[category]!.totalUnitsSold,
          totalRevenue: categories[category]!.totalRevenue,
          averagePrice: categories[category]!.averagePrice,
          conversionRate: categories[category]!.conversionRate,
        );
      }

      // Get order data to calculate sales per category
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final categorySales = <String, Map<String, dynamic>>{};

      for (final orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final items = orderData['items'] as List<dynamic>? ?? [];

        for (final item in items) {
          final productId = item['productId'] ?? '';
          final quantity = item['quantity'] ?? 0;
          final price = (item['price'] ?? 0).toDouble();
          final revenue = price * quantity;

          final productData = products[productId];
          final category = productData?['category'] ?? 'Uncategorized';

          if (categorySales.containsKey(category)) {
            categorySales[category]!['unitsSold'] += quantity;
            categorySales[category]!['revenue'] += revenue;
          } else {
            categorySales[category] = {
              'unitsSold': quantity,
              'revenue': revenue,
            };
          }
        }
      }

      // Update categories with sales data
      for (final category in categories.keys) {
        final salesData = categorySales[category];
        if (salesData != null) {
          final productCount = categories[category]!.productCount;
          categories[category] = CategoryPerformance(
            category: category,
            productCount: productCount,
            totalUnitsSold: salesData['unitsSold'] ?? 0,
            totalRevenue: (salesData['revenue'] ?? 0).toDouble(),
            averagePrice: productCount > 0
                ? (salesData['revenue'] ?? 0) / productCount
                : 0.0,
            conversionRate: 0.0, // Would need additional data to calculate
          );
        }
      }

      return categories.values.toList()
        ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    } catch (e) {
      throw Exception('Failed to get category performance: $e');
    }
  }

  // **CUSTOMER ANALYTICS**

  Future<CustomerAnalytics> getCustomerAnalytics(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Get all orders for the store (ignoring date range for customer segmentation)
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .get();

      final customerOrderHistory = <String, List<Map<String, dynamic>>>{};

      // Group orders by customer
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] ?? '';
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        // Safe type checking for status field
        final status = _getStatusAsString(data['status']);

        if (!customerOrderHistory.containsKey(userId)) {
          customerOrderHistory[userId] = [];
        }
        customerOrderHistory[userId]!.add({
          'createdAt': createdAt,
          'total': (data['total'] ?? 0).toDouble(),
          'status': status,
        });
      }

      // Analyze customer segments
      int newCustomers = 0;
      int returningCustomers = 0;
      int vipCustomers = 0;
      int atRiskCustomers = 0;
      int lostCustomers = 0;

      final now = DateTime.now();
      final threeMonthsAgo = now.subtract(const Duration(days: 90));
      final sixMonthsAgo = now.subtract(const Duration(days: 180));

      for (final userId in customerOrderHistory.keys) {
        final orders = customerOrderHistory[userId]!;
        final totalSpent =
            orders.fold<double>(0, (total, order) => total + order['total']);
        final lastOrderDate = orders
            .map((o) => o['createdAt'] as DateTime)
            .reduce((a, b) => a.isAfter(b) ? a : b);

        if (orders.length == 1) {
          newCustomers++;
        } else if (orders.length > 1) {
          returningCustomers++;

          if (totalSpent > 500) {
            // VIP threshold
            vipCustomers++;
          }
        }

        if (lastOrderDate.isBefore(threeMonthsAgo) &&
            lastOrderDate.isAfter(sixMonthsAgo)) {
          atRiskCustomers++;
        } else if (lastOrderDate.isBefore(sixMonthsAgo)) {
          lostCustomers++;
        }
      }

      final totalCustomers = customerOrderHistory.length;

      return CustomerAnalytics(
        totalCustomers: totalCustomers,
        newCustomers: newCustomers,
        returningCustomers: returningCustomers,
        vipCustomers: vipCustomers,
        atRiskCustomers: atRiskCustomers,
        lostCustomers: lostCustomers,
        customerRetentionRate: totalCustomers > 0
            ? (returningCustomers / totalCustomers) * 100
            : 0.0,
        customerAcquisitionCost: 0.0, // Would need marketing data
        customerLifetimeValue: 0.0, // Would need additional calculations
      );
    } catch (e) {
      throw Exception('Failed to get customer analytics: $e');
    }
  }

  // **CONVERSION ANALYTICS**

  Future<ConversionFunnel> getConversionFunnel(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? _last30Days;
      final end = endDate ?? _today;

      // For now, we'll create mock funnel data since we don't track store visits
      // In a real implementation, you'd track these events
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final ordersCompleted = ordersSnapshot.docs.length;

      // Estimate funnel based on typical e-commerce conversion rates
      final storeVisitors =
          (ordersCompleted * 25).round(); // Assume 4% conversion rate
      final productViews = (storeVisitors * 0.8).round();
      final cartAdditions = (productViews * 0.3).round();
      final checkoutStarted = (cartAdditions * 0.7).round();

      return ConversionFunnel.create(
        storeVisitors: storeVisitors,
        productViews: productViews,
        cartAdditions: cartAdditions,
        checkoutStarted: checkoutStarted,
        ordersCompleted: ordersCompleted,
        startDate: start,
        endDate: end,
      );
    } catch (e) {
      throw Exception('Failed to get conversion funnel: $e');
    }
  }

  Future<List<TrafficSource>> getTrafficSources(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Mock traffic sources data since we don't track referrers
      // In a real implementation, you'd track these
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('createdAt',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(startDate ?? _last30Days))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate ?? _today))
          .get();

      final totalOrders = ordersSnapshot.docs.length;
      final totalRevenue = ordersSnapshot.docs.fold<double>(
          0, (total, doc) => total + ((doc.data()['total'] ?? 0).toDouble()));

      // Mock distribution
      return [
        TrafficSource(
          source: 'Direct',
          visitors: (totalOrders * 15).round(),
          percentage: 45.0,
          conversions: (totalOrders * 0.45).round(),
          conversionRate: 3.0,
          revenue: totalRevenue * 0.45,
        ),
        TrafficSource(
          source: 'Social Media',
          visitors: (totalOrders * 10).round(),
          percentage: 30.0,
          conversions: (totalOrders * 0.30).round(),
          conversionRate: 3.0,
          revenue: totalRevenue * 0.30,
        ),
        TrafficSource(
          source: 'Search',
          visitors: (totalOrders * 6).round(),
          percentage: 20.0,
          conversions: (totalOrders * 0.20).round(),
          conversionRate: 3.3,
          revenue: totalRevenue * 0.20,
        ),
        TrafficSource(
          source: 'Referral',
          visitors: (totalOrders * 2).round(),
          percentage: 5.0,
          conversions: (totalOrders * 0.05).round(),
          conversionRate: 2.5,
          revenue: totalRevenue * 0.05,
        ),
      ];
    } catch (e) {
      throw Exception('Failed to get traffic sources: $e');
    }
  }

  // **HELPER METHODS**

  Map<String, Map<String, DateTime>> _getDateRange(
      String period, DateTime? startDate, DateTime? endDate) {
    switch (period) {
      case 'today':
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        return {
          'current': {'start': todayStart, 'end': today},
          'previous': {'start': yesterdayStart, 'end': todayStart},
        };
      case 'last7days':
        final end = endDate ?? _today;
        final start = startDate ?? _last7Days;
        final duration = end.difference(start);
        final previousEnd = start;
        final previousStart = previousEnd.subtract(duration);
        return {
          'current': {'start': start, 'end': end},
          'previous': {'start': previousStart, 'end': previousEnd},
        };
      case 'last30days':
      default:
        final end = endDate ?? _today;
        final start = startDate ?? _last30Days;
        final duration = end.difference(start);
        final previousEnd = start;
        final previousStart = previousEnd.subtract(duration);
        return {
          'current': {'start': start, 'end': end},
          'previous': {'start': previousStart, 'end': previousEnd},
        };
    }
  }

  Future<Map<String, dynamic>> _getMetricsForPeriod(
      String storeId, DateTime start, DateTime end) async {
    final snapshot = await _firestore
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();

    final orders = snapshot.docs;
    double totalRevenue = 0.0;
    final customerIds = <String>{};

    for (final doc in orders) {
      final data = doc.data();

      // Safe type checking for status field
      final status = _getStatusAsString(data['status']);

      if (status != 'canceled') {
        totalRevenue += (data['total'] ?? 0).toDouble();
      }
      customerIds.add(data['userId'] ?? '');
    }

    final averageOrderValue =
        orders.isNotEmpty ? totalRevenue / orders.length : 0.0;

    return {
      'revenue': totalRevenue,
      'orders': orders.length,
      'customers': customerIds.length,
      'averageOrderValue': averageOrderValue,
      'conversionRate': 0.0, // Would need visitor data
    };
  }

  Future<Map<String, int>> _getProductMetrics(String storeId) async {
    final snapshot = await _firestore
        .collection('products')
        .where('storeId', isEqualTo: storeId)
        .get();

    int lowStockCount = 0;
    int activeProductCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      // Safe type checking for isActive field
      final isActive = _getBooleanValue(data['isActive'], defaultValue: true);

      // Only count active products
      if (!isActive) continue;

      activeProductCount++;

      final stock = data['stock'] ?? 0;
      if (stock < 10) {
        // Low stock threshold
        lowStockCount++;
      }
    }

    return {
      'total': activeProductCount,
      'lowStock': lowStockCount,
    };
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

  // **EXPORT FUNCTIONALITY**

  Future<Map<String, dynamic>> exportAnalyticsData(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
    String period = 'last30days',
  }) async {
    try {
      final analytics = await getRevenueAnalytics(storeId,
          startDate: startDate, endDate: endDate, period: period);
      final trends = await getRevenueTrends(storeId, period: period);
      final topProducts = await getTopSellingProducts(storeId,
          startDate: startDate, endDate: endDate);
      final customerAnalytics = await getCustomerAnalytics(storeId,
          startDate: startDate, endDate: endDate);
      final conversionFunnel = await getConversionFunnel(storeId,
          startDate: startDate, endDate: endDate);

      return {
        'generatedAt': DateTime.now().toIso8601String(),
        'storeId': storeId,
        'period': period,
        'dateRange': {
          'start': (startDate ??
                  _getDateRange(period, null, null)['current']!['start']!)
              .toIso8601String(),
          'end':
              (endDate ?? _getDateRange(period, null, null)['current']!['end']!)
                  .toIso8601String(),
        },
        'metrics': analytics.toMap(),
        'trends': trends.map((t) => t.toMap()).toList(),
        'topProducts': topProducts.map((p) => p.toMap()).toList(),
        'customerAnalytics': customerAnalytics.toMap(),
        'conversionFunnel': conversionFunnel.toMap(),
      };
    } catch (e) {
      throw Exception('Failed to export analytics data: $e');
    }
  }
}

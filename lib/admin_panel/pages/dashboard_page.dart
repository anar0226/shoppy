import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';
import '../widgets/stat_card.dart';
import '../widgets/charts/charts.dart';
import '../widgets/store_setup_dialog.dart';
import '../auth/auth_service.dart';
import '../services/notification_service.dart';
import 'package:provider/provider.dart';
import '../../features/analytics/analytics.dart';
import '../../features/orders/services/order_service.dart';
import '../../features/settings/themes/app_themes.dart';
import '../../features/settings/providers/app_settings_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final OrderService _orderService = OrderService();

  // State variables
  bool _isLoading = true;
  String? _error;
  String? _currentStoreId;

  // Dashboard data
  AnalyticsMetrics? _metrics;
  List<RevenueTrend> _revenueTrends = [];
  List<TopProduct> _topProducts = [];
  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _recentActivity = [];
  int _storeSessions = 0;
  double _sessionsDelta = 0.0;
  bool _sessionsIncreased = true;

  @override
  void initState() {
    super.initState();
    _checkStoreSetup();
  }

  @override
  void dispose() {
    // Cancel any pending operations or timers if needed
    super.dispose();
  }

  Future<void> _checkStoreSetup() async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) {
      if (mounted) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final storeData = snap.docs.first.data();
        final status = storeData['status'] ?? '';

        if (mounted) {
          setState(() {
            _currentStoreId = snap.docs.first.id;
          });
        }

        if (status == 'setup_pending' && mounted) {
          // Show setup dialog
          final result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => StoreSetupDialog(storeId: snap.docs.first.id),
          );

          // If setup was completed, refresh the page
          if (result == true && mounted) {
            setState(() {});
          }
        }

        await _loadDashboardData();
      } else {
        if (mounted) {
          setState(() {
            _error = 'No store found for this user';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load store: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDashboardData() async {
    if (_currentStoreId == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      // Load all dashboard data in parallel
      final results = await Future.wait([
        _analyticsService.getRevenueAnalytics(_currentStoreId!,
            period: 'last30days'),
        _analyticsService.getRevenueTrends(_currentStoreId!,
            period: 'last30days'),
        _analyticsService.getTopSellingProducts(_currentStoreId!, limit: 5),
        _orderService.getRecentOrders(_currentStoreId!, limit: 5),
        _loadRecentActivity(),
      ]);

      // Calculate sessions data separately
      final currentSessions = await _loadStoreSessions();
      final previousSessions = await _loadPreviousStoreSessions();

      final sessionsDelta = previousSessions > 0
          ? ((currentSessions - previousSessions) / previousSessions * 100)
          : 0.0;

      if (mounted) {
        setState(() {
          _metrics = results[0] as AnalyticsMetrics;
          _revenueTrends = results[1] as List<RevenueTrend>;
          _topProducts = results[2] as List<TopProduct>;
          _recentOrders = results[3] as List<Map<String, dynamic>>;
          _recentActivity = results[4] as List<Map<String, dynamic>>;
          _storeSessions = currentSessions;
          _sessionsDelta = sessionsDelta;
          _sessionsIncreased = sessionsDelta >= 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load dashboard data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentActivity() async {
    if (_currentStoreId == null) return [];

    try {
      final recentActivity = <Map<String, dynamic>>[];

      // Recent orders
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('storeId', isEqualTo: _currentStoreId)
          .orderBy('createdAt', descending: true)
          .limit(2)
          .get();

      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final userEmail = data['userEmail'] ?? data['customerEmail'] ?? '';
        final customerName = userEmail.isNotEmpty
            ? userEmail
                .split('@')
                .first
                .replaceAll('.', ' ')
                .split(' ')
                .map((word) => word.isNotEmpty
                    ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                    : word)
                .join(' ')
            : 'Customer';

        recentActivity.add({
          'type': 'order',
          'icon': Icons.shopping_cart_outlined,
          'color': Colors.green,
          'title':
              'New order #${doc.id.substring(0, 4).toUpperCase()} received from $customerName',
          'time': _formatTime(data['createdAt']),
          'timestamp': data['createdAt'],
        });
      }

      // Recent product updates
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('storeId', isEqualTo: _currentStoreId)
          .orderBy('updatedAt', descending: true)
          .limit(2)
          .get();

      for (final doc in productsSnapshot.docs) {
        final data = doc.data();
        recentActivity.add({
          'type': 'product',
          'icon': Icons.inventory_2_outlined,
          'color': Colors.blue,
          'title': 'Product ${data['name'] ?? 'Unknown'} inventory updated',
          'time': _formatTime(data['updatedAt'] ?? data['createdAt']),
          'timestamp': data['updatedAt'] ?? data['createdAt'],
        });
      }

      // Add shipped orders
      final shippedOrdersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('storeId', isEqualTo: _currentStoreId)
          .where('status', isEqualTo: 'shipped')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      for (final doc in shippedOrdersSnapshot.docs) {
        final data = doc.data();
        final userEmail = data['userEmail'] ?? data['customerEmail'] ?? '';
        final customerName = userEmail.isNotEmpty
            ? userEmail
                .split('@')
                .first
                .replaceAll('.', ' ')
                .split(' ')
                .map((word) => word.isNotEmpty
                    ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                    : word)
                .join(' ')
            : 'Customer';

        recentActivity.add({
          'type': 'shipping',
          'icon': Icons.local_shipping_outlined,
          'color': Colors.orange,
          'title':
              'Order #${doc.id.substring(0, 4).toUpperCase()} shipped to $customerName',
          'time': _formatTime(data['updatedAt'] ?? data['createdAt']),
          'timestamp': data['updatedAt'] ?? data['createdAt'],
        });
      }

      // Sort by timestamp (most recent first)
      recentActivity.sort((a, b) {
        final aTime = a['timestamp'];
        final bTime = b['timestamp'];
        if (aTime == null || bTime == null) return 0;

        final aDate = aTime is Timestamp ? aTime.toDate() : aTime as DateTime;
        final bDate = bTime is Timestamp ? bTime.toDate() : bTime as DateTime;

        return bDate.compareTo(aDate);
      });

      return recentActivity.take(4).toList();
    } catch (e) {
      return [];
    }
  }

  Future<int> _loadStoreSessions() async {
    try {
      // Get real session data from analytics events or estimate from orders
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('storeId', isEqualTo: _currentStoreId)
          .where('createdAt',
              isGreaterThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 30))))
          .get();

      // Estimate sessions based on unique customers in orders
      final uniqueUsers = <String>{};
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final userEmail = data['customerEmail'] ?? data['userEmail'] ?? '';
        if (userEmail.isNotEmpty) {
          uniqueUsers.add(userEmail);
        }
      }

      // Estimate 3-5 sessions per unique customer
      return (uniqueUsers.length * 4).round();
    } catch (e) {
      return 0;
    }
  }

  Future<int> _loadPreviousStoreSessions() async {
    try {
      // Get previous session data from analytics events or estimate from orders
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('storeId', isEqualTo: _currentStoreId)
          .where('createdAt',
              isLessThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 60))))
          .get();

      // Estimate sessions based on unique customers in orders
      final uniqueUsers = <String>{};
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final userEmail = data['customerEmail'] ?? data['userEmail'] ?? '';
        if (userEmail.isNotEmpty) {
          uniqueUsers.add(userEmail);
        }
      }

      // Estimate 3-5 sessions per unique customer
      return (uniqueUsers.length * 4).round();
    } catch (e) {
      return 0;
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    final date =
        timestamp is Timestamp ? timestamp.toDate() : timestamp as DateTime;

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() > 1 ? 's' : ''} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Home'),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? _buildErrorState()
                          : _buildDashboardContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Нүүр хуудас уншиx явцад алдаа гарлаа',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            label: const Text('Дахин оролдоx'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildChartsRow(),
          const SizedBox(height: 24),
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Нийт борлуулалт',
            value: '₮${_metrics?.totalRevenue.toStringAsFixed(0) ?? '0'}',
            delta: '${_metrics?.revenueChange.toStringAsFixed(1) ?? '0.0'}%',
            deltaUp: _metrics?.revenueIncreased ?? true,
            icon: Icons.attach_money,
            iconBg: Colors.green,
            periodLabel: 'Сүүлийн 30 хоног',
            comparisonLabel: 'өмнөх үе',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: 'Захиалгууд',
            value: '${_metrics?.totalOrders ?? 0}',
            delta: '${_metrics?.ordersChange.toStringAsFixed(1) ?? '0.0'}%',
            deltaUp: _metrics?.ordersIncreased ?? true,
            icon: Icons.shopping_cart_outlined,
            iconBg: Colors.blue,
            periodLabel: 'Сүүлийн 30 хоног',
            comparisonLabel: 'өмнөх үе',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: 'Дэлгүүрийн сешн',
            value: '$_storeSessions',
            delta: '${_sessionsDelta.toStringAsFixed(1)}%',
            deltaUp: _sessionsIncreased,
            icon: Icons.people_outline,
            iconBg: Colors.purple,
            periodLabel: 'Сүүлийн 30 хоног',
            comparisonLabel: 'өмнөх үе',
          ),
        ),
      ],
    );
  }

  Widget _buildChartsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sales over time chart
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: AppThemes.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemes.getBorderColor(context)),
            ),
            child: RevenueLineChart(
              data: _revenueTrends,
              height: 320,
              title: 'Орлого ба захиалгууд',
              lineColor: Colors.green,
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Top products
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppThemes.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemes.getBorderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Шилдэг бүтээгдэхүүн',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to full products analytics
                      },
                      child: const Text('Бүгдийг харах'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 260,
                  child: _topProducts.isEmpty
                      ? const Center(
                          child: Text(
                            'Бүтээгдэхүүний мэдээлэл байхгүй',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _topProducts.length,
                          itemBuilder: (context, index) {
                            final product = _topProducts[index];
                            return _buildTopProductItem(product);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductItem(TopProduct product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Product image placeholder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: product.imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image_not_supported,
                          color: Colors.grey.shade400,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.grey.shade400,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'SKU: ${product.id.substring(0, 8).toUpperCase()}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.unitsSold} зарагдсан',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                product.formattedRevenue,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent orders
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppThemes.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemes.getBorderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Сүүлийн үеийн захиалгууд',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to orders page
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        'Бүгдийг харах',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildRecentOrdersTable(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Recent activity
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppThemes.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemes.getBorderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to full activity log
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecentActivityList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrdersTable() {
    if (_recentOrders.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Захиалга байхгүй',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Table header
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text(
                  'Захиалгийн дугаар',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
              const Expanded(
                flex: 3,
                child: Text(
                  'Үйлчлүүлэгч',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  'Үнийн дүн',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  'Статус',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Table rows
        ...(_recentOrders.map((order) => _buildOrderRow(order))),
      ],
    );
  }

  Widget _buildOrderRow(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'placed';
    final statusInfo = _getStatusInfo(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '#${order['id']?.toString().substring(0, 4).toUpperCase() ?? '1024'}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              order['userEmail']?.toString().split('@').first ?? 'Customer',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₮${order['total']?.toStringAsFixed(0) ?? '0'}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusInfo['backgroundColor'],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                statusInfo['label'],
                style: TextStyle(
                  color: statusInfo['textColor'],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityList() {
    if (_recentActivity.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No recent activity',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: ListView.separated(
        itemCount: _recentActivity.length,
        separatorBuilder: (context, index) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          final activity = _recentActivity[index];
          return _buildActivityItem(activity);
        },
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (activity['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            activity['icon'] as IconData,
            size: 20,
            color: activity['color'] as Color,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity['title']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                activity['time']?.toString() ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return {
          'label': 'Paid',
          'backgroundColor': Colors.green.withOpacity(0.1),
          'textColor': Colors.green,
        };
      case 'pending':
        return {
          'label': 'Pending',
          'backgroundColor': Colors.orange.withOpacity(0.1),
          'textColor': Colors.orange,
        };
      case 'shipped':
        return {
          'label': 'Shipped',
          'backgroundColor': Colors.blue.withOpacity(0.1),
          'textColor': Colors.blue,
        };
      case 'delivered':
        return {
          'label': 'Delivered',
          'backgroundColor': Colors.green.withOpacity(0.1),
          'textColor': Colors.green,
        };
      case 'canceled':
        return {
          'label': 'Canceled',
          'backgroundColor': Colors.red.withOpacity(0.1),
          'textColor': Colors.red,
        };
      default:
        return {
          'label': 'Unknown',
          'backgroundColor': Colors.grey.withOpacity(0.1),
          'textColor': Colors.grey,
        };
    }
  }
}

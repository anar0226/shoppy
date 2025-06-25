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

  @override
  void initState() {
    super.initState();
    _checkStoreSetup();
  }

  Future<void> _checkStoreSetup() async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) {
      setState(() {
        _error = 'User not authenticated';
        _isLoading = false;
      });
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

        setState(() {
          _currentStoreId = snap.docs.first.id;
        });

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
        setState(() {
          _error = 'No store found for this user';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load store: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    if (_currentStoreId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

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
        _loadStoreSessions(),
      ]);

      setState(() {
        _metrics = results[0] as AnalyticsMetrics;
        _revenueTrends = results[1] as List<RevenueTrend>;
        _topProducts = results[2] as List<TopProduct>;
        _recentOrders = results[3] as List<Map<String, dynamic>>;
        _recentActivity = results[4] as List<Map<String, dynamic>>;
        _storeSessions = results[5] as int;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load dashboard data: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentActivity() async {
    if (_currentStoreId == null) return [];

    try {
      // Get recent product updates, orders, and customer activities
      final recentActivity = <Map<String, dynamic>>[];

      // Recent orders
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('storeId', isEqualTo: _currentStoreId)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        recentActivity.add({
          'type': 'order',
          'icon': Icons.shopping_cart,
          'color': Colors.green,
          'title':
              'New order #${doc.id.substring(0, 6)} received from ${data['userEmail'] ?? 'Customer'}',
          'time': _formatTime(data['createdAt']),
        });
      }

      // Recent product updates (mock for now)
      if (_topProducts.isNotEmpty) {
        recentActivity.add({
          'type': 'product',
          'icon': Icons.inventory,
          'color': Colors.blue,
          'title': 'Product ${_topProducts.first.name} inventory updated',
          'time': '59 minutes ago',
        });
      }

      // Recent customers (mock for now)
      recentActivity.add({
        'type': 'customer',
        'icon': Icons.person_add,
        'color': Colors.purple,
        'title': 'New customer registered',
        'time': '1 hour ago',
      });

      // Sort by time and return latest
      return recentActivity.take(6).toList();
    } catch (e) {
      return [];
    }
  }

  Future<int> _loadStoreSessions() async {
    // Mock store sessions data - in a real app, you'd track page views
    // For now, estimate based on orders
    final totalOrders = _metrics?.totalOrders ?? 0;
    return (totalOrders * 12).round(); // Estimate 12 sessions per order
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    final date =
        timestamp is Timestamp ? timestamp.toDate() : timestamp as DateTime;

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
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
            'Error Loading Dashboard',
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
            label: const Text('Retry'),
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
    return Consumer<AppSettingsProvider>(
      builder: (context, settings, child) {
        final isEnglish = settings.languageCode == 'en';

        return Row(
          children: [
            Expanded(
              child: StatCard(
                title: isEnglish ? 'Total sales' : '[MN] Total sales',
                value:
                    '\$${_metrics?.totalRevenue.toStringAsFixed(2) ?? '0.00'}',
                delta:
                    '${_metrics?.revenueChange.toStringAsFixed(1) ?? '0.0'}%',
                deltaUp: _metrics?.revenueIncreased ?? true,
                icon: Icons.attach_money,
                iconBg: Colors.green,
                periodLabel: 'Last 30 days',
                comparisonLabel: 'vs previous period',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: isEnglish ? 'Orders' : '[MN] Orders',
                value: '${_metrics?.totalOrders ?? 0}',
                delta: '${_metrics?.ordersChange.toStringAsFixed(1) ?? '0.0'}%',
                deltaUp: _metrics?.ordersIncreased ?? true,
                icon: Icons.shopping_cart_outlined,
                iconBg: Colors.blue,
                periodLabel: 'Last 30 days',
                comparisonLabel: 'vs previous period',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: isEnglish ? 'Store sessions' : '[MN] Store sessions',
                value: '$_storeSessions',
                delta: '+15.2%',
                deltaUp: true,
                icon: Icons.people_outline,
                iconBg: Colors.purple,
                periodLabel: 'Last 30 days',
                comparisonLabel: 'vs previous period',
              ),
            ),
          ],
        );
      },
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
              title: 'Sales over time',
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
                      'Top products by units sold',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to full products analytics
                      },
                      child: const Text('View all'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 260,
                  child: _topProducts.isEmpty
                      ? const Center(
                          child: Text(
                            'No product data available',
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
                '${product.unitsSold} sold',
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
                      'Recent orders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to orders page
                      },
                      child: const Text('View all orders'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to full activity log
                      },
                      child: const Text('View all'),
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
            'No recent orders',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              Expanded(
                  flex: 2,
                  child: Text('Order',
                      style: TextStyle(fontWeight: FontWeight.w600))),
              Expanded(
                  child: Text('Customer',
                      style: TextStyle(fontWeight: FontWeight.w600))),
              Expanded(
                  child: Text('Total',
                      style: TextStyle(fontWeight: FontWeight.w600))),
              Expanded(
                  child: Text('Status',
                      style: TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Table rows
        ...(_recentOrders.map((order) => _buildOrderRow(order))),
      ],
    );
  }

  Widget _buildOrderRow(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'placed';
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '#${order['id']?.toString().substring(0, 6) ?? 'Unknown'}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              order['userEmail']?.toString() ?? 'Unknown',
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              '\$${order['total']?.toStringAsFixed(2) ?? '0.00'}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
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
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: ListView.builder(
        itemCount: _recentActivity.length,
        itemBuilder: (context, index) {
          final activity = _recentActivity[index];
          return _buildActivityItem(activity);
        },
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (activity['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              activity['icon'] as IconData,
              size: 16,
              color: activity['color'] as Color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity['time']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'shipped':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

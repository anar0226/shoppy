import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/stat_card.dart';
import '../widgets/charts/charts.dart';
import '../../features/analytics/analytics.dart';
import '../../features/orders/services/order_service.dart';
import '../auth/auth_service.dart';
import '../../features/settings/providers/app_settings_provider.dart';
import '../../features/settings/themes/app_themes.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final OrderService _orderService = OrderService();

  // State variables
  String _selectedPeriod = 'Last 30 days';
  bool _isLoading = true;
  String? _error;
  String? _currentStoreId;

  // Analytics data
  AnalyticsMetrics? _metrics;
  List<RevenueTrend> _revenueTrends = [];
  List<TopProduct> _topProducts = [];
  CustomerAnalytics? _customerAnalytics;
  ConversionFunnel? _conversionFunnel;
  List<Map<String, dynamic>> _orderTrends = [];

  @override
  void initState() {
    super.initState();
    _loadStoreId();
  }

  Future<void> _loadStoreId() async {
    try {
      final ownerId = AuthService.instance.currentUser?.uid;
      if (ownerId == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        setState(() {
          _currentStoreId = snap.docs.first.id;
        });
        await _loadAnalyticsData();
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

  Future<void> _loadAnalyticsData() async {
    if (_currentStoreId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load all analytics data in parallel
      final results = await Future.wait([
        _analyticsService.getRevenueAnalytics(_currentStoreId!,
            period: _getPeriodForAPI()),
        _analyticsService.getRevenueTrends(_currentStoreId!,
            period: _getPeriodForAPI()),
        _analyticsService.getTopSellingProducts(_currentStoreId!, limit: 5),
        _analyticsService.getCustomerAnalytics(_currentStoreId!),
        _analyticsService.getConversionFunnel(_currentStoreId!),
        _orderService.getOrderTrendData(_currentStoreId!,
            period: 'daily', days: 30),
      ]);

      setState(() {
        _metrics = results[0] as AnalyticsMetrics;
        _revenueTrends = results[1] as List<RevenueTrend>;
        _topProducts = results[2] as List<TopProduct>;
        _customerAnalytics = results[3] as CustomerAnalytics;
        _conversionFunnel = results[4] as ConversionFunnel;
        _orderTrends = results[5] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load analytics: $e';
        _isLoading = false;
      });
    }
  }

  String _getPeriodForAPI() {
    switch (_selectedPeriod) {
      case 'Last 7 days':
        return 'last7days';
      case 'Last 30 days':
      default:
        return 'last30days';
    }
  }

  Future<void> _handlePeriodChange(String? newPeriod) async {
    if (newPeriod != null && newPeriod != _selectedPeriod) {
      setState(() {
        _selectedPeriod = newPeriod;
      });
      await _loadAnalyticsData();
    }
  }

  Future<void> _exportData() async {
    if (_currentStoreId == null) return;

    try {
      final exportData = await _analyticsService.exportAnalyticsData(
        _currentStoreId!,
        period: _getPeriodForAPI(),
      );

      // Log export success for debugging
      debugPrint('Analytics data exported: ${exportData.length} records');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analytics data exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Analytics'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Analytics'),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? _buildErrorState()
                          : _buildAnalyticsContent(),
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
            'Error Loading Analytics',
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
            onPressed: _loadAnalyticsData,
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

  Widget _buildAnalyticsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildRevenueChart(),
          const SizedBox(height: 24),
          _buildSecondaryCharts(),
          const SizedBox(height: 24),
          _buildBottomCharts(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('Track your store performance and insights'),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                value: _selectedPeriod,
                items: const [
                  DropdownMenuItem(
                    value: 'Last 30 days',
                    child: Text('Last 30 days'),
                  ),
                  DropdownMenuItem(
                    value: 'Last 7 days',
                    child: Text('Last 7 days'),
                  ),
                ],
                onChanged: _handlePeriodChange,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _exportData,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Export'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    if (_metrics == null) return Container();

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        StatCard(
          title: 'Total Revenue',
          value: '\$${_metrics!.totalRevenue.toStringAsFixed(2)}',
          delta: '${_metrics!.revenueChange.toStringAsFixed(1)}%',
          deltaUp: _metrics!.revenueIncreased,
          icon: Icons.attach_money,
          iconBg: Colors.green,
          periodLabel: _selectedPeriod,
          comparisonLabel: 'vs previous period',
        ),
        StatCard(
          title: 'Orders',
          value: _metrics!.totalOrders.toString(),
          delta: '${_metrics!.ordersChange.toStringAsFixed(1)}%',
          deltaUp: _metrics!.ordersIncreased,
          icon: Icons.shopping_cart_outlined,
          iconBg: Colors.blue,
          periodLabel: _selectedPeriod,
          comparisonLabel: 'vs previous period',
        ),
        StatCard(
          title: 'Customers',
          value: _metrics!.totalCustomers.toString(),
          delta: '${_metrics!.customersChange.toStringAsFixed(1)}%',
          deltaUp: _metrics!.customersIncreased,
          icon: Icons.person_outline,
          iconBg: Colors.purple,
          periodLabel: _selectedPeriod,
          comparisonLabel: 'vs previous period',
        ),
        StatCard(
          title: 'Avg Order Value',
          value: '\$${_metrics!.averageOrderValue.toStringAsFixed(2)}',
          delta: '${_metrics!.averageOrderValueChange.toStringAsFixed(1)}%',
          deltaUp: _metrics!.averageOrderValueIncreased,
          icon: Icons.bar_chart,
          iconBg: Colors.orange,
          periodLabel: _selectedPeriod,
          comparisonLabel: 'vs previous period',
        ),
      ],
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppThemes.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.getBorderColor(context)),
      ),
      child: RevenueLineChart(
        data: _revenueTrends,
        height: 320,
        title: 'Revenue Trend',
        lineColor: Colors.green,
      ),
    );
  }

  Widget _buildSecondaryCharts() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                const Text(
                  'Top Products',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ...(_topProducts.take(5).map((product) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTopProductRow(product),
                    ))),
                if (_topProducts.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No product sales data available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Customer segments
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppThemes.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemes.getBorderColor(context)),
            ),
            child: _customerAnalytics != null
                ? CustomerAnalyticsWidget(
                    analytics: _customerAnalytics!,
                    height: 280,
                  )
                : const SizedBox(
                    height: 280,
                    child: Center(
                      child: Text(
                        'No customer data available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomCharts() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order trends
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppThemes.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemes.getBorderColor(context)),
            ),
            child: OrderTrendBarChart(
              data: _orderTrends,
              height: 280,
              title: 'Order Trends',
              barColor: Colors.blue,
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Conversion funnel
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppThemes.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemes.getBorderColor(context)),
            ),
            child: _conversionFunnel != null
                ? ConversionFunnelChart(
                    funnel: _conversionFunnel!,
                    height: 280,
                    title: 'Conversion Funnel',
                  )
                : const SizedBox(
                    height: 280,
                    child: Center(
                      child: Text(
                        'No conversion data available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductRow(TopProduct product) {
    final maxUnitsSold =
        _topProducts.isNotEmpty ? _topProducts.first.unitsSold : 1;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            product.rank.toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                product.unitsSoldText,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              product.formattedRevenue,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Container(
              width: 120,
              height: 6,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: product.getRelativePerformance(maxUnitsSold),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../services/subscription_management_service.dart';
import '../widgets/charts/subscription_status_pie_chart.dart';
import '../widgets/charts/subscription_revenue_chart.dart';

class SubscriptionAnalyticsPage extends StatefulWidget {
  const SubscriptionAnalyticsPage({super.key});

  @override
  State<SubscriptionAnalyticsPage> createState() =>
      _SubscriptionAnalyticsPageState();
}

class _SubscriptionAnalyticsPageState extends State<SubscriptionAnalyticsPage> {
  final SubscriptionManagementService _subscriptionService =
      SubscriptionManagementService();

  Map<String, dynamic>? _analytics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final analytics = await _subscriptionService.getSubscriptionStatistics();

      setState(() {
        _analytics = analytics;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Аналитик ачаалж чадсангүй: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Захиалгын аналитик'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _buildAnalyticsContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAnalytics,
            child: const Text('Дахин оролдох'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    if (_analytics == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewCards(),
          const SizedBox(height: 24),
          _buildSubscriptionStatusChart(),
          const SizedBox(height: 24),
          _buildRevenueChart(),
          const SizedBox(height: 24),
          _buildDetailedStats(),
          const SizedBox(height: 24),
          _buildManagementActions(),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Нийт дэлгүүр',
          '${_analytics!['totalStores']}',
          Icons.store,
          Colors.blue,
        ),
        _buildStatCard(
          'Идэвхтэй захиалга',
          '${_analytics!['activeSubscriptions']}',
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Сарын орлого',
          _subscriptionService
              .formatPaymentAmount(_analytics!['monthlyRevenue']),
          Icons.monetization_on,
          Colors.orange,
        ),
        _buildStatCard(
          'Дундаж хугацаа',
          '${_analytics!['averageDurationDays'].toStringAsFixed(1)} хоног',
          Icons.schedule,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatusChart() {
    final activeCount = _analytics!['activeSubscriptions'] ?? 0;
    final expiredCount = _analytics!['expiredSubscriptions'] ?? 0;
    final gracePeriodCount = _analytics!['gracePeriodSubscriptions'] ?? 0;
    final pendingCount = _analytics!['pendingSubscriptions'] ?? 0;
    final cancelledCount = _analytics!['cancelledSubscriptions'] ?? 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Захиалгын төлөв',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SubscriptionStatusPieChart(
                activeCount: activeCount,
                expiredCount: expiredCount,
                gracePeriodCount: gracePeriodCount,
                pendingCount: pendingCount,
                cancelledCount: cancelledCount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Сарын орлого',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SubscriptionRevenueChart(
                monthlyRevenue: _analytics!['monthlyRevenue'] ?? 0,
                activeSubscriptions: _analytics!['activeSubscriptions'] ?? 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStats() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Дэлгэрэнгүй статистик',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
                'Идэвхтэй захиалга',
                '${_analytics!['activeSubscriptions']}',
                '${_analytics!['activePercentage'].toStringAsFixed(1)}%',
                Colors.green),
            _buildStatRow(
                'Хугацаа дууссан',
                '${_analytics!['expiredSubscriptions']}',
                '${_analytics!['expiredPercentage'].toStringAsFixed(1)}%',
                Colors.red),
            _buildStatRow(
                'Хүлээлтийн хугацаа',
                '${_analytics!['gracePeriodSubscriptions']}',
                '${_analytics!['gracePeriodPercentage'].toStringAsFixed(1)}%',
                Colors.orange),
            _buildStatRow(
                'Хүлээгдэж буй',
                '${_analytics!['pendingSubscriptions']}',
                '${_analytics!['pendingPercentage'].toStringAsFixed(1)}%',
                Colors.blue),
            _buildStatRow(
                'Цуцлагдсан',
                '${_analytics!['cancelledSubscriptions']}',
                '${_analytics!['cancelledPercentage'].toStringAsFixed(1)}%',
                Colors.grey),
            const Divider(),
            _buildStatRow(
                'Нийт орлого',
                _subscriptionService
                    .formatPaymentAmount(_analytics!['monthlyRevenue']),
                '',
                Colors.orange),
            _buildStatRow(
                'Дундаж хугацаа',
                '${_analytics!['averageDurationDays'].toStringAsFixed(1)} хоног',
                '',
                Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
      String label, String value, String percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (percentage.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              percentage,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManagementActions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Удирдлагын үйлдлүүд',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to subscription management page
                      Navigator.pushNamed(context, '/subscription-management');
                    },
                    icon: const Icon(Icons.manage_accounts),
                    label: const Text('Захиалга удирдах'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to payment history page
                      Navigator.pushNamed(context, '/payment-history');
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('Төлбөрийн түүх'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Export analytics data
                      _exportAnalytics();
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Экспортлох'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Send notifications
                      _sendNotifications();
                    },
                    icon: const Icon(Icons.notifications),
                    label: const Text('Мэдэгдэл илгээх'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _exportAnalytics() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Экспортлох функц хэрэгжүүлэгдэж байна'),
      ),
    );
  }

  void _sendNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Мэдэгдэл илгээх функц хэрэгжүүлэгдэж байна'),
      ),
    );
  }
}

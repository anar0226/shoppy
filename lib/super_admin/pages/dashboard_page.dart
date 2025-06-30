import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../super_admin_app.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  PlatformStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlatformStats();
  }

  Future<void> _loadPlatformStats() async {
    try {
      // Get platform-wide statistics
      final storeSnapshot =
          await FirebaseFirestore.instance.collection('stores').get();
      final userSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final orderSnapshot =
          await FirebaseFirestore.instance.collection('orders').get();
      final notificationSnapshot = await FirebaseFirestore.instance
          .collection('notification_queue')
          .get();

      // Calculate active stores (those with recent activity)
      final activeStores = storeSnapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] ?? 'inactive';
        return status == 'active';
      }).length;

      // Calculate active users (those who logged in recently)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final activeUsers = userSnapshot.docs.where((doc) {
        final data = doc.data();
        final lastLogin = data['lastLoginAt'] as Timestamp?;
        return lastLogin != null && lastLogin.toDate().isAfter(thirtyDaysAgo);
      }).length;

      // Calculate total revenue
      double totalRevenue = 0;
      for (final doc in orderSnapshot.docs) {
        final data = doc.data();
        final total = (data['total'] ?? 0).toDouble();
        totalRevenue += total;
      }

      // Get commission statistics from Cloud Function
      Map<String, dynamic> commissionData = {};
      try {
        final callable =
            FirebaseFunctions.instance.httpsCallable('getCommissionStats');
        final result = await callable.call({
          'startDate': thirtyDaysAgo.toIso8601String(),
          'endDate': DateTime.now().toIso8601String(),
        });
        commissionData = Map<String, dynamic>.from(result.data);
      } catch (commissionError) {
        // Error loading commission data
        // Fallback to basic calculation if commission system isn't set up yet
        commissionData = {
          'summary': {
            'totalCommissionEarned': totalRevenue * 0.05,
            'pendingCommissions': 0.0,
            'paidCommissions': 0.0,
            'totalTransactions': 0,
            'pendingTransactions': 0,
            'averageCommissionPerTransaction': 0.0,
          },
          'topStores': [],
        };
      }

      final commissionSummary = commissionData['summary'] ?? {};
      final topStores =
          List<Map<String, dynamic>>.from(commissionData['topStores'] ?? []);

      // Calculate notification success rate
      final sentNotifications = notificationSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'sent';
      }).length;
      final totalNotifications = notificationSnapshot.docs.length;
      final successRate = totalNotifications > 0
          ? (sentNotifications / totalNotifications) * 100
          : 0.0;

      final stats = PlatformStats(
        totalStores: storeSnapshot.docs.length,
        activeStores: activeStores,
        totalUsers: userSnapshot.docs.length,
        activeUsers: activeUsers,
        totalOrders: orderSnapshot.docs.length,
        totalRevenue: totalRevenue,
        platformCommission:
            (commissionSummary['totalCommissionEarned'] ?? 0).toDouble(),
        notificationsSent: totalNotifications,
        notificationSuccessRate: successRate,
        // Commission-specific data
        pendingCommissions:
            (commissionSummary['pendingCommissions'] ?? 0).toDouble(),
        paidCommissions: (commissionSummary['paidCommissions'] ?? 0).toDouble(),
        totalCommissionTransactions:
            commissionSummary['totalTransactions'] ?? 0,
        pendingCommissionTransactions:
            commissionSummary['pendingTransactions'] ?? 0,
        averageCommissionPerTransaction:
            (commissionSummary['averageCommissionPerTransaction'] ?? 0)
                .toDouble(),
        topEarningStores: topStores,
      );

      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Error loading platform stats
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeCommissionRules() async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('initializeCommissionRules');
      final result = await callable.call();

      if (mounted) {
        final data = Map<String, dynamic>.from(result.data);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ??
                  'Commission rules initialized successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload stats to reflect the new commission rules
          _loadPlatformStats();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(data['message'] ?? 'Commission rules already exist'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing commission rules: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCommissionSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commission Settings'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Commission Overview',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildCommissionInfoRow('Total Commission Earned',
                  _stats?.formattedCommission ?? '\$0.00'),
              _buildCommissionInfoRow('Pending Commissions',
                  _stats?.formattedPendingCommissions ?? '\$0.00'),
              _buildCommissionInfoRow('Collected Commissions',
                  _stats?.formattedPaidCommissions ?? '\$0.00'),
              _buildCommissionInfoRow('Average per Transaction',
                  _stats?.formattedAverageCommission ?? '\$0.00'),
              _buildCommissionInfoRow(
                  'Collection Rate', _stats?.collectionRatePercent ?? '0%'),
              const SizedBox(height: 16),
              const Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Initialize commission rules for new marketplace\n'
                '• View detailed commission analytics\n'
                '• Manage commission rates per store/category\n'
                '• Process pending commission payouts',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeCommissionRules();
            },
            child: const Text('Initialize Rules'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Text(
            'Platform Overview',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Real-time statistics across the entire Shoppy platform',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),

          // Key Metrics Cards - Top Row
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard(
                'Total Stores',
                _stats?.totalStores.toString() ?? '0',
                Icons.store,
                Colors.blue,
                '${_stats?.activeStores ?? 0} active',
              ),
              _buildMetricCard(
                'Total Users',
                _stats?.totalUsers.toString() ?? '0',
                Icons.people,
                Colors.green,
                '${_stats?.activeUsers ?? 0} active',
              ),
              _buildMetricCard(
                'Total Orders',
                _stats?.totalOrders.toString() ?? '0',
                Icons.shopping_cart,
                Colors.orange,
                'This month',
              ),
              _buildMetricCard(
                'Platform Revenue',
                _stats?.formattedRevenue ?? '\$0.00',
                Icons.attach_money,
                Colors.purple,
                '${_stats?.formattedCommission ?? '\$0.00'} commission',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Commission Metrics Cards - New Row
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard(
                'Total Commission',
                _stats?.formattedCommission ?? '\$0.00',
                Icons.account_balance_wallet,
                Colors.indigo,
                '${_stats?.totalCommissionTransactions ?? 0} transactions',
              ),
              _buildMetricCard(
                'Pending Commission',
                _stats?.formattedPendingCommissions ?? '\$0.00',
                Icons.hourglass_empty,
                Colors.amber,
                '${_stats?.pendingCommissionTransactions ?? 0} pending',
              ),
              _buildMetricCard(
                'Collected Commission',
                _stats?.formattedPaidCommissions ?? '\$0.00',
                Icons.check_circle,
                Colors.teal,
                '${_stats?.collectionRatePercent ?? '0%'} collection rate',
              ),
              _buildMetricCard(
                'Avg. Commission',
                _stats?.formattedAverageCommission ?? '\$0.00',
                Icons.trending_up,
                Colors.deepPurple,
                'Per transaction',
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Top Earning Stores Section
          if (_stats?.topEarningStores.isNotEmpty == true) ...[
            Text(
              'Top Earning Stores (Commission)',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: _stats!.topEarningStores.take(5).map((store) {
                  final storeId = store['storeId'] ?? '';
                  final commission = (store['totalCommission'] ?? 0).toDouble();
                  final orders = store['totalOrders'] ?? 0;
                  final revenue = (store['totalRevenue'] ?? 0).toDouble();

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.store,
                              color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Store ${storeId.substring(0, 8)}...',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '$orders orders • ₮${revenue.toStringAsFixed(2)} revenue',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₮${commission.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Additional Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Notification Success Rate',
                  _stats?.successRatePercent ?? '0%',
                  Icons.notifications,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Commission Collection Rate',
                  _stats?.collectionRatePercent ?? '0%',
                  Icons.payment,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'User Engagement',
                  '${_stats?.userEngagementRate.toStringAsFixed(1) ?? '0'}%',
                  Icons.people_alt,
                  Colors.pink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildActionButton(
                'Commission Settings',
                Icons.settings,
                Colors.indigo,
                () => _showCommissionSettings(),
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                'Initialize Commission Rules',
                Icons.rule,
                Colors.green,
                () => _initializeCommissionRules(),
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                'Commission Analytics',
                Icons.analytics,
                Colors.orange,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Navigating to Commission Analytics...')),
                  );
                },
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                'Platform Overview',
                Icons.dashboard,
                Colors.blue,
                () => _loadPlatformStats(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
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

  Widget _buildActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

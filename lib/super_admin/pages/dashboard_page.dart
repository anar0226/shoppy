import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        platformCommission: totalRevenue * 0.05, // 5% platform commission
        notificationsSent: sentNotifications,
        notificationSuccessRate: successRate,
        topPerformingStores: {},
        recentActivity: {},
      );

      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading platform stats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          // Header
          const Text(
            'Platform Overview',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Stores',
                  '${_stats?.totalStores ?? 0}',
                  Icons.store,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Active Stores',
                  '${_stats?.activeStores ?? 0}',
                  Icons.storefront,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  '${_stats?.totalUsers ?? 0}',
                  Icons.people,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Active Users',
                  '${_stats?.activeUsers ?? 0}',
                  Icons.person,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Second Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Orders',
                  '${_stats?.totalOrders ?? 0}',
                  Icons.shopping_cart,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total Revenue',
                  '₮${_stats?.formattedRevenue ?? '0'}',
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Platform Commission',
                  '₮${_stats?.formattedCommission ?? '0'}',
                  Icons.account_balance_wallet,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Notification Success',
                  _stats?.successRatePercent ?? '0%',
                  Icons.notifications,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Growth Metrics
          Row(
            children: [
              Expanded(
                child: _buildGrowthCard(
                  'Store Growth Rate',
                  '${_stats?.storeGrowthRate.toStringAsFixed(1) ?? '0'}%',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGrowthCard(
                  'User Engagement',
                  '${_stats?.userEngagementRate.toStringAsFixed(1) ?? '0'}%',
                  Icons.people_outline,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Quick Actions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to stores management
                        },
                        icon: const Icon(Icons.store),
                        label: const Text('Manage Stores'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to payment management
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text('Payment Management'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to backup management
                        },
                        icon: const Icon(Icons.backup),
                        label: const Text('Backup Management'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

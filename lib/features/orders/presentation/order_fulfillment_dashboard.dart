import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/order_fulfillment_automation_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrderFulfillmentDashboard extends StatefulWidget {
  final String storeId;

  const OrderFulfillmentDashboard({
    Key? key,
    required this.storeId,
  }) : super(key: key);

  @override
  State<OrderFulfillmentDashboard> createState() =>
      _OrderFulfillmentDashboardState();
}

class _OrderFulfillmentDashboardState extends State<OrderFulfillmentDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderFulfillmentAutomationService _fulfillmentService =
      OrderFulfillmentAutomationService();

  bool _isLoading = false;
  Map<String, dynamic> _metrics = {};
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _recentTransitions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDashboardData();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _fulfillmentService.getFulfillmentMetrics(storeId: widget.storeId),
        _loadActiveOrders(),
        _loadRecentTransitions(),
      ]);

      setState(() {
        _metrics = results[0] as Map<String, dynamic>;
        _activeOrders = results[1] as List<Map<String, dynamic>>;
        _recentTransitions = results[2] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      _showError('Failed to load dashboard data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadActiveOrders() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('storeId', isEqualTo: widget.storeId)
          .where('status', whereIn: [
            OrderStatus.pending.name,
            OrderStatus.paymentPending.name,
            OrderStatus.paid.name,
            OrderStatus.processing.name,
            OrderStatus.readyForPickup.name,
            OrderStatus.deliveryRequested.name,
            OrderStatus.driverAssigned.name,
            OrderStatus.pickedUp.name,
            OrderStatus.inTransit.name,
            OrderStatus.outForDelivery.name,
          ])
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error loading active orders: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentTransitions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('order_transitions')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final transitions = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final orderId = data['orderId'] as String?;

        if (orderId != null) {
          // Check if this order belongs to our store
          final orderDoc = await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .get();

          if (orderDoc.exists &&
              orderDoc.data()?['storeId'] == widget.storeId) {
            data['id'] = doc.id;
            transitions.add(data);
          }
        }
      }

      return transitions;
    } catch (e) {
      debugPrint('Error loading recent transitions: $e');
      return [];
    }
  }

  void _startRealTimeUpdates() {
    // Listen to real-time order updates
    FirebaseFirestore.instance
        .collection('orders')
        .where('storeId', isEqualTo: widget.storeId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _loadDashboardData();
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Fulfillment Dashboard'),
        backgroundColor: const Color(0xFF1F226C),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Active Orders'),
            Tab(text: 'Workflow'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildActiveOrdersTab(),
                _buildWorkflowTab(),
                _buildAnalyticsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Key Metrics Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Orders',
                  '${_metrics['totalOrders'] ?? 0}',
                  Icons.shopping_bag,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Completed',
                  '${_metrics['completedOrders'] ?? 0}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Avg Processing',
                  '${(_metrics['averageProcessingTime'] ?? 0).toStringAsFixed(1)} min',
                  Icons.timer,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'On-Time Rate',
                  '${(_metrics['onTimeDeliveryRate'] ?? 0).toStringAsFixed(1)}%',
                  Icons.schedule,
                  Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Activity
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recent Order Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _buildRecentActivity(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_recentTransitions.isEmpty) {
      return const Center(child: Text('No recent activity'));
    }

    return ListView.builder(
      itemCount: _recentTransitions.length,
      itemBuilder: (context, index) {
        final transition = _recentTransitions[index];
        final timestamp = (transition['timestamp'] as Timestamp?)?.toDate();

        return Card(
          child: ListTile(
            leading: _getStatusIcon(transition['status'] as String?),
            title: Text(
                'Order #${(transition['orderId'] as String?)?.substring(0, 8) ?? 'Unknown'}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Status: ${_getStatusDisplayName(transition['status'] as String?)}'),
                Text('Reason: ${transition['reason'] ?? 'No reason'}'),
                if (timestamp != null)
                  Text(
                      'Time: ${DateFormat('MMM dd, HH:mm').format(timestamp)}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(transition['status'] as String?),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                transition['automated'] == true ? 'AUTO' : 'MANUAL',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveOrdersTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Filter and Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search orders...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    // TODO: Implement search
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F226C),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Orders List
          Expanded(
            child: _buildOrdersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    if (_activeOrders.isEmpty) {
      return const Center(child: Text('No active orders'));
    }

    return ListView.builder(
      itemCount: _activeOrders.length,
      itemBuilder: (context, index) {
        final order = _activeOrders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['id'] as String? ?? '';
    final status = order['status'] as String? ?? 'pending';
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final customerEmail = order['customerEmail'] as String? ?? '';
    final createdAt = (order['createdAt'] as Timestamp?)?.toDate();
    final items = (order['items'] as List?)?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: _getStatusIcon(status),
        title: Text('Order #${orderId.substring(0, 8)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: $customerEmail'),
            Text('Total: ₮${NumberFormat('#,###').format(total)}'),
            Text('Items: $items'),
            if (createdAt != null)
              Text('Created: ${DateFormat('MMM dd, HH:mm').format(createdAt)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusDisplayName(status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Order Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showOrderDetails(order),
                      icon: const Icon(Icons.visibility),
                      label: const Text('View Details'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showStatusUpdateDialog(orderId, status),
                      icon: const Icon(Icons.edit),
                      label: const Text('Update Status'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showOrderHistory(orderId),
                      icon: const Icon(Icons.history),
                      label: const Text('History'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Progress Indicator
                _buildOrderProgress(status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderProgress(String status) {
    final steps = [
      'pending',
      'paid',
      'processing',
      'readyForPickup',
      'inTransit',
      'delivered',
    ];

    final currentStepIndex = steps.indexOf(status);

    return Column(
      children: [
        const Text(
          'Order Progress',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isCompleted = index <= currentStepIndex;
            final isCurrent = index == currentStepIndex;

            return Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWorkflowTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Workflow Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Automation Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title:
                        const Text('Auto-transition paid orders to processing'),
                    subtitle: const Text(
                        'Automatically start processing when payment is confirmed'),
                    value: true, // TODO: Get from settings
                    onChanged: (value) {
                      // TODO: Update settings
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Auto-request delivery when ready'),
                    subtitle: const Text(
                        'Automatically request delivery when order is ready for pickup'),
                    value: true, // TODO: Get from settings
                    onChanged: (value) {
                      // TODO: Update settings
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Auto-complete delivered orders'),
                    subtitle: const Text(
                        'Mark orders as completed 24 hours after delivery'),
                    value: true, // TODO: Get from settings
                    onChanged: (value) {
                      // TODO: Update settings
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Workflow Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Workflow Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildWorkflowStatusItem('Orders pending processing',
                      _getOrderCountByStatus('paid')),
                  _buildWorkflowStatusItem('Orders being processed',
                      _getOrderCountByStatus('processing')),
                  _buildWorkflowStatusItem('Orders ready for pickup',
                      _getOrderCountByStatus('readyForPickup')),
                  _buildWorkflowStatusItem('Orders in delivery',
                      _getOrderCountByStatus('inTransit')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStatusItem(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.orange : Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Performance Metrics
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Avg Delivery Time',
                  '${(_metrics['averageDeliveryTime'] ?? 0).toStringAsFixed(1)} min',
                  Icons.local_shipping,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  'Cancellation Rate',
                  '${_calculateCancellationRate().toStringAsFixed(1)}%',
                  Icons.cancel,
                  Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Status Breakdown Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Status Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusBreakdown(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
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

  Widget _buildStatusBreakdown() {
    final statusBreakdown =
        _metrics['statusBreakdown'] as Map<String, dynamic>? ?? {};

    if (statusBreakdown.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return Column(
      children: statusBreakdown.entries.map((entry) {
        final status = entry.key;
        final count = entry.value as int;
        final total = _metrics['totalOrders'] as int? ?? 1;
        final percentage = (count / total * 100);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_getStatusDisplayName(status)),
              ),
              Text('$count (${percentage.toStringAsFixed(1)}%)'),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Helper methods
  Widget _getStatusIcon(String? status) {
    switch (status) {
      case 'pending':
        return const Icon(Icons.hourglass_empty, color: Colors.orange);
      case 'paid':
        return const Icon(Icons.payment, color: Colors.blue);
      case 'processing':
        return const Icon(Icons.settings, color: Colors.purple);
      case 'readyForPickup':
        return const Icon(Icons.inventory_2, color: Colors.green);
      case 'inTransit':
        return const Icon(Icons.local_shipping, color: Colors.blue);
      case 'delivered':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'cancelled':
        return const Icon(Icons.cancel, color: Colors.red);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'readyForPickup':
        return Colors.green;
      case 'inTransit':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayName(String? status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'paymentPending':
        return 'Payment Pending';
      case 'paid':
        return 'Paid';
      case 'processing':
        return 'Processing';
      case 'readyForPickup':
        return 'Ready for Pickup';
      case 'deliveryRequested':
        return 'Delivery Requested';
      case 'driverAssigned':
        return 'Driver Assigned';
      case 'pickedUp':
        return 'Picked Up';
      case 'inTransit':
        return 'In Transit';
      case 'outForDelivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  int _getOrderCountByStatus(String status) {
    return _activeOrders.where((order) => order['status'] == status).length;
  }

  double _calculateCancellationRate() {
    final totalOrders = _metrics['totalOrders'] as int? ?? 0;
    final cancelledOrders = _metrics['cancelledOrders'] as int? ?? 0;

    return totalOrders > 0 ? (cancelledOrders / totalOrders * 100) : 0.0;
  }

  // Dialog methods
  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => OrderDetailsDialog(order: order),
    );
  }

  void _showStatusUpdateDialog(String orderId, String currentStatus) {
    showDialog(
      context: context,
      builder: (context) => StatusUpdateDialog(
        orderId: orderId,
        currentStatus: currentStatus,
        onStatusUpdated: () {
          _loadDashboardData();
          _showSuccess('Order status updated successfully');
        },
      ),
    );
  }

  void _showOrderHistory(String orderId) {
    showDialog(
      context: context,
      builder: (context) => OrderHistoryDialog(orderId: orderId),
    );
  }
}

// Dialog Widgets
class OrderDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailsDialog({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          'Order #${(order['id'] as String?)?.substring(0, 8) ?? 'Unknown'}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Customer: ${order['customerEmail'] ?? 'Unknown'}'),
            Text(
                'Total: ₮${NumberFormat('#,###').format((order['total'] as num?)?.toDouble() ?? 0)}'),
            Text('Status: ${order['status'] ?? 'Unknown'}'),
            const SizedBox(height: 16),
            const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._buildItemsList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  List<Widget> _buildItemsList() {
    final items = order['items'] as List? ?? [];

    return items.map((item) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text('• ${item['name'] ?? 'Unknown'} x${item['quantity'] ?? 1}'),
      );
    }).toList();
  }
}

class StatusUpdateDialog extends StatefulWidget {
  final String orderId;
  final String currentStatus;
  final VoidCallback onStatusUpdated;

  const StatusUpdateDialog({
    Key? key,
    required this.orderId,
    required this.currentStatus,
    required this.onStatusUpdated,
  }) : super(key: key);

  @override
  State<StatusUpdateDialog> createState() => _StatusUpdateDialogState();
}

class _StatusUpdateDialogState extends State<StatusUpdateDialog> {
  late String _selectedStatus;
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Order Status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(labelText: 'New Status'),
            items: OrderStatus.values.map((status) {
              return DropdownMenuItem(
                value: status.name,
                child: Text(_getStatusDisplayName(status.name)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedStatus = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason (Optional)',
              hintText: 'Why are you updating this status?',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateStatus,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _updateStatus() async {
    setState(() => _isLoading = true);

    try {
      final fulfillmentService = OrderFulfillmentAutomationService();
      final newStatus =
          OrderStatus.values.firstWhere((s) => s.name == _selectedStatus);

      final success = await fulfillmentService.updateOrderStatus(
        widget.orderId,
        newStatus,
        reason: _reasonController.text.isEmpty ? null : _reasonController.text,
        userId: Provider.of<AuthProvider>(context, listen: false).user?.uid,
      );

      if (success) {
        widget.onStatusUpdated();
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to update order status');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'paymentPending':
        return 'Payment Pending';
      case 'paid':
        return 'Paid';
      case 'processing':
        return 'Processing';
      case 'readyForPickup':
        return 'Ready for Pickup';
      case 'deliveryRequested':
        return 'Delivery Requested';
      case 'driverAssigned':
        return 'Driver Assigned';
      case 'pickedUp':
        return 'Picked Up';
      case 'inTransit':
        return 'In Transit';
      case 'outForDelivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }
}

class OrderHistoryDialog extends StatefulWidget {
  final String orderId;

  const OrderHistoryDialog({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderHistoryDialog> createState() => _OrderHistoryDialogState();
}

class _OrderHistoryDialogState extends State<OrderHistoryDialog> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final fulfillmentService = OrderFulfillmentAutomationService();
      final history =
          await fulfillmentService.getOrderStatusHistory(widget.orderId);

      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Order History #${widget.orderId.substring(0, 8)}'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final entry = _history[index];
                  final timestamp =
                      (entry['timestamp'] as Timestamp?)?.toDate();

                  return ListTile(
                    leading: Icon(
                      entry['automated'] == true
                          ? Icons.smart_toy
                          : Icons.person,
                      color: entry['automated'] == true
                          ? Colors.blue
                          : Colors.green,
                    ),
                    title: Text(entry['status'] ?? 'Unknown'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry['reason'] ?? 'No reason'),
                        if (timestamp != null)
                          Text(DateFormat('MMM dd, yyyy HH:mm')
                              .format(timestamp)),
                      ],
                    ),
                    trailing: Text(
                      entry['automated'] == true ? 'AUTO' : 'MANUAL',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

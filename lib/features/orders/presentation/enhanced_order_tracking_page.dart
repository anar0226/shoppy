import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/services/order_fulfillment_automation_service.dart';

class EnhancedOrderTrackingPage extends StatefulWidget {
  final String orderId;

  const EnhancedOrderTrackingPage({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  State<EnhancedOrderTrackingPage> createState() =>
      _EnhancedOrderTrackingPageState();
}

class _EnhancedOrderTrackingPageState extends State<EnhancedOrderTrackingPage> {
  Map<String, dynamic>? _orderData;
  List<Map<String, dynamic>> _statusHistory = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrderData();
    _startRealTimeUpdates();
  }

  Future<void> _loadOrderData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load order data
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (!orderDoc.exists) {
        setState(() {
          _error = 'Order not found';
          _isLoading = false;
        });
        return;
      }

      // Load status history
      final fulfillmentService = OrderFulfillmentAutomationService();
      final history =
          await fulfillmentService.getOrderStatusHistory(widget.orderId);

      setState(() {
        _orderData = orderDoc.data();
        _orderData!['id'] = orderDoc.id;
        _statusHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load order data: $e';
        _isLoading = false;
      });
    }
  }

  void _startRealTimeUpdates() {
    FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() {
          _orderData = snapshot.data();
          _orderData!['id'] = snapshot.id;
        });

        // Reload history when order updates
        _loadStatusHistory();
      }
    });
  }

  Future<void> _loadStatusHistory() async {
    try {
      final fulfillmentService = OrderFulfillmentAutomationService();
      final history =
          await fulfillmentService.getOrderStatusHistory(widget.orderId);

      setState(() {
        _statusHistory = history;
      });
    } catch (e) {
      debugPrint('Error loading status history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId.substring(0, 8)}'),
        backgroundColor: const Color(0xFF1F226C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildOrderTrackingView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadOrderData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTrackingView() {
    final status = _orderData!['status'] as String? ?? 'pending';
    final total = (_orderData!['total'] as num?)?.toDouble() ?? 0.0;
    final createdAt = (_orderData!['createdAt'] as Timestamp?)?.toDate();
    final items = _orderData!['items'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _loadOrderData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Status Header
            _buildStatusHeader(status),

            const SizedBox(height: 24),

            // Progress Tracker
            _buildProgressTracker(status),

            const SizedBox(height: 24),

            // Order Details
            _buildOrderDetails(total, createdAt, items),

            const SizedBox(height: 24),

            // Delivery Information
            if (_hasDeliveryInfo()) _buildDeliveryInfo(),

            const SizedBox(height: 24),

            // Status History
            _buildStatusHistory(),

            const SizedBox(height: 24),

            // Action Buttons
            _buildActionButtons(status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(String status) {
    final statusInfo = _getStatusInfo(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusInfo.color, statusInfo.color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: statusInfo.color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            statusInfo.icon,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            statusInfo.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            statusInfo.description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          if (_getEstimatedTime(status) != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Estimated: ${_getEstimatedTime(status)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressTracker(String status) {
    final steps = [
      ProgressStep(
        title: 'Order Placed',
        description: 'Your order has been received',
        icon: Icons.shopping_cart,
        status: 'pending',
      ),
      ProgressStep(
        title: 'Payment Confirmed',
        description: 'Payment has been processed',
        icon: Icons.payment,
        status: 'paid',
      ),
      ProgressStep(
        title: 'Preparing Order',
        description: 'Your order is being prepared',
        icon: Icons.inventory_2,
        status: 'processing',
      ),
      ProgressStep(
        title: 'Ready for Delivery',
        description: 'Order is ready for pickup',
        icon: Icons.local_shipping,
        status: 'readyForPickup',
      ),
      ProgressStep(
        title: 'In Transit',
        description: 'Your order is on the way',
        icon: Icons.directions_car,
        status: 'inTransit',
      ),
      ProgressStep(
        title: 'Delivered',
        description: 'Order has been delivered',
        icon: Icons.check_circle,
        status: 'delivered',
      ),
    ];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isLast = index == steps.length - 1;
              final stepStatus = _getStepStatus(status, step.status);

              return _buildProgressStep(step, stepStatus, !isLast);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStep(
      ProgressStep step, StepStatus stepStatus, bool showLine) {
    Color getStepColor() {
      switch (stepStatus) {
        case StepStatus.completed:
          return Colors.green;
        case StepStatus.current:
          return const Color(0xFF1F226C);
        case StepStatus.pending:
          return Colors.grey;
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: stepStatus == StepStatus.pending
                    ? Colors.grey[200]
                    : getStepColor(),
                shape: BoxShape.circle,
              ),
              child: Icon(
                stepStatus == StepStatus.completed ? Icons.check : step.icon,
                color: stepStatus == StepStatus.pending
                    ? Colors.grey
                    : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: stepStatus == StepStatus.current
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: stepStatus == StepStatus.pending
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: stepStatus == StepStatus.pending
                          ? Colors.grey
                          : Colors.grey[600],
                    ),
                  ),
                  if (stepStatus == StepStatus.current &&
                      _getStepTimestamp(step.status) != null)
                    Text(
                      _formatTimestamp(_getStepTimestamp(step.status)!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1F226C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (showLine)
          Container(
            margin: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
            height: 24,
            width: 2,
            color: stepStatus == StepStatus.completed
                ? Colors.green
                : Colors.grey[300],
          ),
      ],
    );
  }

  Widget _buildOrderDetails(double total, DateTime? createdAt, List items) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Order ID:'),
                Text(
                  '#${widget.orderId.substring(0, 8)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount:'),
                Text(
                  '₮${NumberFormat('#,###').format(total)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Order Date:'),
                  Text(
                    DateFormat('MMM dd, yyyy HH:mm').format(createdAt),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Items:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => _buildOrderItem(item)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (item['imageUrl'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item['imageUrl'],
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image_not_supported),
                  );
                },
              ),
            )
          else
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_bag),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Unknown Item',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item['variant'] != null)
                  Text(
                    'Variant: ${item['variant']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'x${item['quantity'] ?? 1}',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    final deliveryAddress =
        _orderData!['deliveryAddress'] as Map<String, dynamic>?;
    final driverName = _orderData!['driverName'] as String?;
    final driverPhone = _orderData!['driverPhone'] as String?;
    final trackingId = _orderData!['deliveryTrackingId'] as String?;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (deliveryAddress != null) ...[
              const Text(
                'Delivery Address:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(_formatAddress(deliveryAddress)),
              const SizedBox(height: 12),
            ],
            if (driverName != null) ...[
              const Text(
                'Driver:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(driverName),
              if (driverPhone != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(driverPhone),
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ],
            if (trackingId != null) ...[
              const Text(
                'Tracking ID:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(trackingId),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHistory() {
    if (_statusHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._statusHistory
                .map((entry) => _buildHistoryEntry(entry))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryEntry(Map<String, dynamic> entry) {
    final timestamp = (entry['timestamp'] as Timestamp?)?.toDate();
    final status = entry['status'] as String? ?? 'Unknown';
    final reason = entry['reason'] as String? ?? 'No reason provided';
    final automated = entry['automated'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: automated ? Colors.blue : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusDisplayName(status),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (timestamp != null)
                  Text(
                    DateFormat('MMM dd, HH:mm').format(timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: automated ? Colors.blue[100] : Colors.green[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              automated ? 'AUTO' : 'MANUAL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: automated ? Colors.blue[700] : Colors.green[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    return Column(
      children: [
        if (status == 'pending' || status == 'paymentPending')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _cancelOrder,
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _contactSupport,
                icon: const Icon(Icons.support_agent),
                label: const Text('Contact Support'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareOrder,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F226C),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper methods
  StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return StatusInfo(
          title: 'Order Placed',
          description: 'Your order has been received and is being processed',
          icon: Icons.hourglass_empty,
          color: Colors.orange,
        );
      case 'paymentPending':
        return StatusInfo(
          title: 'Payment Pending',
          description: 'Waiting for payment confirmation',
          icon: Icons.payment,
          color: Colors.blue,
        );
      case 'paid':
        return StatusInfo(
          title: 'Payment Confirmed',
          description: 'Payment has been successfully processed',
          icon: Icons.check_circle,
          color: Colors.green,
        );
      case 'processing':
        return StatusInfo(
          title: 'Preparing Your Order',
          description: 'Your order is being prepared for delivery',
          icon: Icons.inventory_2,
          color: Colors.purple,
        );
      case 'readyForPickup':
        return StatusInfo(
          title: 'Ready for Delivery',
          description: 'Your order is ready and waiting for pickup',
          icon: Icons.local_shipping,
          color: Colors.blue,
        );
      case 'inTransit':
        return StatusInfo(
          title: 'On the Way',
          description: 'Your order is being delivered to you',
          icon: Icons.directions_car,
          color: Colors.indigo,
        );
      case 'delivered':
        return StatusInfo(
          title: 'Delivered',
          description: 'Your order has been successfully delivered',
          icon: Icons.check_circle,
          color: Colors.green,
        );
      case 'completed':
        return StatusInfo(
          title: 'Order Completed',
          description: 'Thank you for your order!',
          icon: Icons.star,
          color: Colors.green,
        );
      case 'cancelled':
        return StatusInfo(
          title: 'Order Cancelled',
          description: 'This order has been cancelled',
          icon: Icons.cancel,
          color: Colors.red,
        );
      default:
        return StatusInfo(
          title: 'Unknown Status',
          description: 'Order status is unknown',
          icon: Icons.help_outline,
          color: Colors.grey,
        );
    }
  }

  StepStatus _getStepStatus(String currentStatus, String stepStatus) {
    final statusOrder = [
      'pending',
      'paid',
      'processing',
      'readyForPickup',
      'inTransit',
      'delivered',
    ];

    final currentIndex = statusOrder.indexOf(currentStatus);
    final stepIndex = statusOrder.indexOf(stepStatus);

    if (currentIndex == -1 || stepIndex == -1) {
      return StepStatus.pending;
    }

    if (stepIndex < currentIndex) {
      return StepStatus.completed;
    } else if (stepIndex == currentIndex) {
      return StepStatus.current;
    } else {
      return StepStatus.pending;
    }
  }

  String? _getEstimatedTime(String status) {
    switch (status) {
      case 'processing':
        return '15-30 minutes';
      case 'readyForPickup':
        return 'Waiting for pickup';
      case 'inTransit':
        return '30-45 minutes';
      default:
        return null;
    }
  }

  DateTime? _getStepTimestamp(String stepStatus) {
    switch (stepStatus) {
      case 'pending':
        return (_orderData!['createdAt'] as Timestamp?)?.toDate();
      case 'paid':
        return (_orderData!['paidAt'] as Timestamp?)?.toDate();
      case 'processing':
        return (_orderData!['processingStartedAt'] as Timestamp?)?.toDate();
      case 'readyForPickup':
        return (_orderData!['readyAt'] as Timestamp?)?.toDate();
      case 'inTransit':
        return (_orderData!['inTransitAt'] as Timestamp?)?.toDate();
      case 'delivered':
        return (_orderData!['deliveredAt'] as Timestamp?)?.toDate();
      default:
        return null;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return DateFormat('MMM dd, HH:mm').format(timestamp);
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'pending':
        return 'Order Placed';
      case 'paymentPending':
        return 'Payment Pending';
      case 'paid':
        return 'Payment Confirmed';
      case 'processing':
        return 'Preparing Order';
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

  bool _hasDeliveryInfo() {
    return _orderData!['deliveryAddress'] != null ||
        _orderData!['driverName'] != null ||
        _orderData!['deliveryTrackingId'] != null;
  }

  String _formatAddress(Map<String, dynamic> address) {
    final parts = <String>[];

    if (address['street'] != null) parts.add(address['street']);
    if (address['district'] != null) parts.add(address['district']);
    if (address['khoroo'] != null) parts.add('Khoroo ${address['khoroo']}');
    if (address['city'] != null) parts.add(address['city']);

    return parts.join(', ');
  }

  // Action methods
  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // TODO: Implement order cancellation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancellation requested'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _contactSupport() {
    // TODO: Implement support contact
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Text('Support contact feature coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _shareOrder() {
    // TODO: Implement order sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share feature coming soon'),
      ),
    );
  }
}

// Data classes
class StatusInfo {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  StatusInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class ProgressStep {
  final String title;
  final String description;
  final IconData icon;
  final String status;

  ProgressStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
  });
}

enum StepStatus {
  completed,
  current,
  pending,
}

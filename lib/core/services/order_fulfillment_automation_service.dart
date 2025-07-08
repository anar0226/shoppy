import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Comprehensive Order Status Enum
enum OrderStatus {
  // Initial states
  pending, // Order placed, awaiting payment
  paymentPending, // Payment processing
  paymentFailed, // Payment failed

  // Payment confirmed states
  paid, // Payment confirmed
  processing, // Order being prepared
  readyForPickup, // Ready for delivery pickup

  // Delivery states
  deliveryRequested, // Delivery requested from provider
  driverAssigned, // Driver assigned
  pickedUp, // Order picked up by driver
  inTransit, // Order in transit
  outForDelivery, // Out for final delivery

  // Final states
  delivered, // Successfully delivered
  completed, // Order completed and confirmed

  // Exception states
  cancelled, // Order cancelled
  refunded, // Order refunded
  failed, // Order failed
  disputed, // Order disputed
}

/// Order Priority Levels
enum OrderPriority {
  low,
  normal,
  high,
  urgent,
}

/// Delivery Provider Types
enum DeliveryProvider {
  ubcab,
  internal,
  pickup,
  other,
}

/// Order Fulfillment Automation Service
class OrderFulfillmentAutomationService {
  static final OrderFulfillmentAutomationService _instance =
      OrderFulfillmentAutomationService._internal();
  factory OrderFulfillmentAutomationService() => _instance;
  OrderFulfillmentAutomationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _orderSubscriptions = {};
  final Map<String, Timer> _stateTransitionTimers = {};

  /// Initialize the automation service
  Future<void> initialize() async {
    debugPrint('Initializing Order Fulfillment Automation Service...');

    // Start monitoring existing orders
    await _startOrderMonitoring();

    // Schedule periodic tasks
    _schedulePeriodicTasks();

    debugPrint('Order Fulfillment Automation Service initialized');
  }

  /// Start monitoring orders for automatic state transitions
  Future<void> _startOrderMonitoring() async {
    try {
      // Monitor orders that need automatic processing
      final activeStatuses = [
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
      ];

      final subscription = _firestore
          .collection('orders')
          .where('status',
              whereIn: activeStatuses.take(10).toList()) // Firestore limit
          .snapshots()
          .listen(_handleOrderUpdates);

      _orderSubscriptions['main'] = subscription;
    } catch (e) {
      debugPrint('Error starting order monitoring: $e');
    }
  }

  /// Handle order updates and trigger state transitions
  void _handleOrderUpdates(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added ||
          change.type == DocumentChangeType.modified) {
        final orderData = change.doc.data() as Map<String, dynamic>;
        final orderId = change.doc.id;

        _processOrderStateTransition(orderId, orderData);
      }
    }
  }

  /// Process automatic state transitions for an order
  Future<void> _processOrderStateTransition(
      String orderId, Map<String, dynamic> orderData) async {
    try {
      final currentStatus = _parseOrderStatus(orderData['status']);
      final lastUpdated =
          (orderData['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final timeSinceUpdate = DateTime.now().difference(lastUpdated);

      // Check if order needs automatic transition
      switch (currentStatus) {
        case OrderStatus.pending:
          await _handlePendingOrder(orderId, orderData, timeSinceUpdate);
          break;
        case OrderStatus.paymentPending:
          await _handlePaymentPendingOrder(orderId, orderData, timeSinceUpdate);
          break;
        case OrderStatus.paid:
          await _handlePaidOrder(orderId, orderData);
          break;
        case OrderStatus.processing:
          await _handleProcessingOrder(orderId, orderData, timeSinceUpdate);
          break;
        case OrderStatus.readyForPickup:
          await _handleReadyForPickupOrder(orderId, orderData);
          break;
        case OrderStatus.deliveryRequested:
          await _handleDeliveryRequestedOrder(
              orderId, orderData, timeSinceUpdate);
          break;
        case OrderStatus.driverAssigned:
          await _handleDriverAssignedOrder(orderId, orderData, timeSinceUpdate);
          break;
        case OrderStatus.pickedUp:
          await _handlePickedUpOrder(orderId, orderData, timeSinceUpdate);
          break;
        case OrderStatus.inTransit:
          await _handleInTransitOrder(orderId, orderData, timeSinceUpdate);
          break;
        case OrderStatus.outForDelivery:
          await _handleOutForDeliveryOrder(orderId, orderData, timeSinceUpdate);
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('Error processing order state transition for $orderId: $e');
    }
  }

  /// Handle pending orders (auto-transition based on payment)
  Future<void> _handlePendingOrder(String orderId,
      Map<String, dynamic> orderData, Duration timeSinceUpdate) async {
    // Check if payment method requires immediate processing
    final paymentMethod = orderData['paymentMethod'] ?? 'card';

    if (paymentMethod == 'cash' || paymentMethod == 'pickup') {
      // For cash/pickup orders, automatically move to paid after validation
      await _transitionOrderStatus(orderId, OrderStatus.paid,
          reason: 'Cash/pickup payment method - auto-confirmed');
    } else if (timeSinceUpdate.inMinutes > 30) {
      // Check payment status for online payments
      await _checkPaymentStatus(orderId, orderData);
    }
  }

  /// Handle payment pending orders
  Future<void> _handlePaymentPendingOrder(String orderId,
      Map<String, dynamic> orderData, Duration timeSinceUpdate) async {
    if (timeSinceUpdate.inMinutes > 15) {
      // Check payment status after 15 minutes
      await _checkPaymentStatus(orderId, orderData);
    }

    if (timeSinceUpdate.inHours > 2) {
      // Auto-cancel after 2 hours if payment not confirmed
      await _transitionOrderStatus(orderId, OrderStatus.cancelled,
          reason: 'Payment timeout - order auto-cancelled');
    }
  }

  /// Handle paid orders (auto-transition to processing)
  Future<void> _handlePaidOrder(
      String orderId, Map<String, dynamic> orderData) async {
    // Automatically move paid orders to processing
    await _transitionOrderStatus(orderId, OrderStatus.processing,
        reason: 'Payment confirmed - moving to processing');

    // Reserve inventory
    await _reserveOrderInventory(orderId, orderData);

    // Notify store owner
    await _notifyStoreOwner(
        orderId, orderData, 'New paid order ready for processing');
  }

  /// Handle processing orders
  Future<void> _handleProcessingOrder(String orderId,
      Map<String, dynamic> orderData, Duration timeSinceUpdate) async {
    final storeId = orderData['storeId'] as String?;

    if (storeId != null) {
      // Check store's average processing time
      final avgProcessingTime = await _getStoreAverageProcessingTime(storeId);

      if (timeSinceUpdate.inMinutes > avgProcessingTime) {
        // Auto-transition to ready for pickup if processing is taking too long
        await _transitionOrderStatus(orderId, OrderStatus.readyForPickup,
            reason: 'Auto-transition based on processing time');
      }
    }
  }

  /// Handle ready for pickup orders
  Future<void> _handleReadyForPickupOrder(
      String orderId, Map<String, dynamic> orderData) async {
    final deliveryAddress =
        orderData['deliveryAddress'] as Map<String, dynamic>?;

    if (deliveryAddress != null && deliveryAddress.isNotEmpty) {
      // Automatically request delivery
      await _requestDelivery(orderId, orderData);
    } else {
      // Notify customer for pickup
      await _notifyCustomer(
          orderId, orderData, 'Your order is ready for pickup');
    }
  }

  /// Handle delivery requested orders
  Future<void> _handleDeliveryRequestedOrder(String orderId,
      Map<String, dynamic> orderData, Duration timeSinceUpdate) async {
    if (timeSinceUpdate.inMinutes > 30) {
      // Check delivery status if no driver assigned within 30 minutes
      await _checkDeliveryStatus(orderId, orderData);
    }
  }

  /// Handle driver assigned orders
  Future<void> _handleDriverAssignedOrder(String orderId,
      Map<String, dynamic> orderData, Duration timeSinceUpdate) async {
    if (timeSinceUpdate.inMinutes > 60) {
      // Escalate if driver hasn't picked up within 1 hour
      await _escalateDeliveryIssue(orderId, orderData, 'Driver pickup delay');
    }
  }

  /// Handle picked up orders
  Future<void> _handlePickedUpOrder(String orderId,
      Map<String, dynamic> orderData, Duration timeSinceUpdate) async {
    if (timeSinceUpdate.inMinutes > 5) {
      // Auto-transition to in transit after pickup
      await _transitionOrderStatus(orderId, OrderStatus.inTransit,
          reason: 'Order picked up - now in transit');
    }
  }

  /// Handle in transit orders
  Future<void> _handleInTransitOrder(String orderId,
      Map<String, dynamic> orderData, Duration timeSinceUpdate) async {
    final estimatedDeliveryTime =
        await _calculateEstimatedDeliveryTime(orderId, orderData);

    if (timeSinceUpdate.inMinutes > (estimatedDeliveryTime * 0.8).round()) {
      // Transition to out for delivery when 80% of estimated time has passed
      await _transitionOrderStatus(orderId, OrderStatus.outForDelivery,
          reason: 'Approaching delivery location');
    }
  }

  /// Handle out for delivery orders
  Future<void> _handleOutForDeliveryOrder(String orderId,
      Map<String, dynamic> orderData, Duration timeSinceUpdate) async {
    if (timeSinceUpdate.inHours > 2) {
      // Escalate if delivery is taking too long
      await _escalateDeliveryIssue(orderId, orderData, 'Delivery delay');
    }
  }

  /// Transition order to new status with proper logging
  Future<void> _transitionOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastTransition': {
          'status': newStatus.name,
          'reason': reason ?? 'Automatic transition',
          'timestamp': FieldValue.serverTimestamp(),
          'automated': true,
        },
      };

      // Add status-specific fields
      switch (newStatus) {
        case OrderStatus.paid:
          updateData['paidAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.processing:
          updateData['processingStartedAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.readyForPickup:
          updateData['readyAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.deliveryRequested:
          updateData['deliveryRequestedAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.driverAssigned:
          updateData['driverAssignedAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.pickedUp:
          updateData['pickedUpAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.inTransit:
          updateData['inTransitAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.outForDelivery:
          updateData['outForDeliveryAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.delivered:
          updateData['deliveredAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.completed:
          updateData['completedAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.cancelled:
          updateData['cancelledAt'] = FieldValue.serverTimestamp();
          break;
        default:
          break;
      }

      if (additionalData != null) {
        updateData.addAll(additionalData);
      }

      await _firestore.collection('orders').doc(orderId).update(updateData);

      // Log the transition
      await _logOrderTransition(orderId, newStatus, reason);

      // Trigger post-transition actions
      await _handlePostTransitionActions(orderId, newStatus);

      debugPrint('Order $orderId transitioned to ${newStatus.name}: $reason');
    } catch (e) {
      debugPrint('Error transitioning order $orderId to ${newStatus.name}: $e');
    }
  }

  /// Log order transition for audit trail
  Future<void> _logOrderTransition(
      String orderId, OrderStatus newStatus, String? reason) async {
    try {
      await _firestore.collection('order_transitions').add({
        'orderId': orderId,
        'status': newStatus.name,
        'reason': reason ?? 'Automatic transition',
        'timestamp': FieldValue.serverTimestamp(),
        'automated': true,
      });
    } catch (e) {
      debugPrint('Error logging order transition: $e');
    }
  }

  /// Handle actions after status transition
  Future<void> _handlePostTransitionActions(
      String orderId, OrderStatus newStatus) async {
    switch (newStatus) {
      case OrderStatus.paid:
        await _sendOrderConfirmationNotification(orderId);
        break;
      case OrderStatus.processing:
        await _sendProcessingNotification(orderId);
        break;
      case OrderStatus.readyForPickup:
        await _sendReadyNotification(orderId);
        break;
      case OrderStatus.inTransit:
        await _sendInTransitNotification(orderId);
        break;
      case OrderStatus.delivered:
        await _sendDeliveredNotification(orderId);
        _scheduleCompletionCheck(orderId);
        break;
      case OrderStatus.cancelled:
        await _releaseOrderInventory(orderId);
        await _sendCancellationNotification(orderId);
        break;
      default:
        break;
    }
  }

  /// Check payment status with payment provider
  Future<void> _checkPaymentStatus(
      String orderId, Map<String, dynamic> orderData) async {
    try {
      final paymentIntentId = orderData['paymentIntentId'] as String?;

      if (paymentIntentId != null) {
        // TODO: Integrate with actual payment provider API
        // For now, simulate payment check
        final isPaymentConfirmed = await _simulatePaymentCheck(paymentIntentId);

        if (isPaymentConfirmed) {
          await _transitionOrderStatus(orderId, OrderStatus.paid,
              reason: 'Payment confirmed by provider');
        } else {
          await _transitionOrderStatus(orderId, OrderStatus.paymentFailed,
              reason: 'Payment failed or declined');
        }
      }
    } catch (e) {
      debugPrint('Error checking payment status for order $orderId: $e');
    }
  }

  /// Simulate payment check (replace with actual payment provider integration)
  Future<bool> _simulatePaymentCheck(String paymentIntentId) async {
    // Simulate API call delay
    await Future.delayed(const Duration(seconds: 1));

    // Simulate 90% success rate
    return DateTime.now().millisecond % 10 != 0;
  }

  /// Reserve inventory for order
  Future<void> _reserveOrderInventory(
      String orderId, Map<String, dynamic> orderData) async {
    try {
      final items = orderData['items'] as List<dynamic>? ?? [];

      for (final item in items) {
        final productId = item['productId'] as String?;
        final quantity = item['quantity'] as int? ?? 1;
        final selectedVariants =
            item['selectedVariants'] as Map<String, dynamic>?;

        if (productId != null) {
          // Call inventory service to reserve stock
          // This would integrate with your existing inventory service
          debugPrint(
              'Reserving $quantity units of product $productId for order $orderId');
        }
      }
    } catch (e) {
      debugPrint('Error reserving inventory for order $orderId: $e');
    }
  }

  /// Release inventory for cancelled order
  Future<void> _releaseOrderInventory(String orderId) async {
    try {
      // This would integrate with your existing inventory service
      debugPrint('Releasing inventory for cancelled order $orderId');
    } catch (e) {
      debugPrint('Error releasing inventory for order $orderId: $e');
    }
  }

  /// Request delivery from provider
  Future<void> _requestDelivery(
      String orderId, Map<String, dynamic> orderData) async {
    try {
      await _transitionOrderStatus(orderId, OrderStatus.deliveryRequested,
          reason: 'Delivery automatically requested');

      // TODO: Integrate with actual delivery provider API
      debugPrint('Delivery requested for order $orderId');
    } catch (e) {
      debugPrint('Error requesting delivery for order $orderId: $e');
    }
  }

  /// Check delivery status with provider
  Future<void> _checkDeliveryStatus(
      String orderId, Map<String, dynamic> orderData) async {
    try {
      final trackingId = orderData['deliveryTrackingId'] as String?;

      if (trackingId != null) {
        // TODO: Check with delivery provider API
        debugPrint(
            'Checking delivery status for order $orderId with tracking $trackingId');
      }
    } catch (e) {
      debugPrint('Error checking delivery status for order $orderId: $e');
    }
  }

  /// Escalate delivery issues
  Future<void> _escalateDeliveryIssue(
      String orderId, Map<String, dynamic> orderData, String issue) async {
    try {
      await _firestore.collection('delivery_escalations').add({
        'orderId': orderId,
        'issue': issue,
        'orderData': orderData,
        'escalatedAt': FieldValue.serverTimestamp(),
        'status': 'open',
      });

      // Notify support team
      await _notifySupport(orderId, issue);

      debugPrint('Escalated delivery issue for order $orderId: $issue');
    } catch (e) {
      debugPrint('Error escalating delivery issue for order $orderId: $e');
    }
  }

  /// Calculate estimated delivery time
  Future<int> _calculateEstimatedDeliveryTime(
      String orderId, Map<String, dynamic> orderData) async {
    // Default to 45 minutes, could be enhanced with real-time traffic data
    return 45;
  }

  /// Get store's average processing time
  Future<int> _getStoreAverageProcessingTime(String storeId) async {
    try {
      final recentOrders = await _firestore
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('status', isEqualTo: OrderStatus.completed.name)
          .orderBy('completedAt', descending: true)
          .limit(10)
          .get();

      if (recentOrders.docs.isEmpty) return 30; // Default 30 minutes

      int totalProcessingTime = 0;
      int validOrders = 0;

      for (final doc in recentOrders.docs) {
        final data = doc.data();
        final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
        final readyAt = (data['readyAt'] as Timestamp?)?.toDate();

        if (paidAt != null && readyAt != null) {
          totalProcessingTime += readyAt.difference(paidAt).inMinutes;
          validOrders++;
        }
      }

      return validOrders > 0 ? (totalProcessingTime / validOrders).round() : 30;
    } catch (e) {
      debugPrint(
          'Error calculating average processing time for store $storeId: $e');
      return 30;
    }
  }

  /// Schedule completion check after delivery
  void _scheduleCompletionCheck(String orderId) {
    // Auto-complete order after 24 hours if no issues reported
    _stateTransitionTimers[orderId] =
        Timer(const Duration(hours: 24), () async {
      try {
        final orderDoc =
            await _firestore.collection('orders').doc(orderId).get();
        if (orderDoc.exists) {
          final data = orderDoc.data()!;
          if (data['status'] == OrderStatus.delivered.name) {
            await _transitionOrderStatus(orderId, OrderStatus.completed,
                reason: 'Auto-completed after 24 hours');
          }
        }
      } catch (e) {
        debugPrint('Error auto-completing order $orderId: $e');
      }
    });
  }

  /// Send various notifications
  Future<void> _sendOrderConfirmationNotification(String orderId) async {
    // TODO: Implement notification sending
    debugPrint('Sending order confirmation for $orderId');
  }

  Future<void> _sendProcessingNotification(String orderId) async {
    debugPrint('Sending processing notification for $orderId');
  }

  Future<void> _sendReadyNotification(String orderId) async {
    debugPrint('Sending ready notification for $orderId');
  }

  Future<void> _sendInTransitNotification(String orderId) async {
    debugPrint('Sending in transit notification for $orderId');
  }

  Future<void> _sendDeliveredNotification(String orderId) async {
    debugPrint('Sending delivered notification for $orderId');
  }

  Future<void> _sendCancellationNotification(String orderId) async {
    debugPrint('Sending cancellation notification for $orderId');
  }

  Future<void> _notifyStoreOwner(
      String orderId, Map<String, dynamic> orderData, String message) async {
    debugPrint('Notifying store owner for order $orderId: $message');
  }

  Future<void> _notifyCustomer(
      String orderId, Map<String, dynamic> orderData, String message) async {
    debugPrint('Notifying customer for order $orderId: $message');
  }

  Future<void> _notifySupport(String orderId, String issue) async {
    debugPrint('Notifying support for order $orderId: $issue');
  }

  /// Schedule periodic tasks
  void _schedulePeriodicTasks() {
    // Check for stuck orders every 15 minutes
    Timer.periodic(const Duration(minutes: 15), (_) => _checkStuckOrders());

    // Cleanup completed orders daily
    Timer.periodic(const Duration(hours: 24), (_) => _cleanupCompletedOrders());

    // Generate analytics reports
    Timer.periodic(
        const Duration(hours: 6), (_) => _generateAnalyticsReports());
  }

  /// Check for orders that might be stuck in a state
  Future<void> _checkStuckOrders() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 6));

      final stuckOrders = await _firestore
          .collection('orders')
          .where('updatedAt', isLessThan: Timestamp.fromDate(cutoffTime))
          .where('status', whereIn: [
        OrderStatus.processing.name,
        OrderStatus.deliveryRequested.name,
        OrderStatus.driverAssigned.name,
        OrderStatus.inTransit.name,
      ]).get();

      for (final doc in stuckOrders.docs) {
        await _escalateDeliveryIssue(
            doc.id, doc.data(), 'Order stuck in ${doc.data()['status']} state');
      }
    } catch (e) {
      debugPrint('Error checking stuck orders: $e');
    }
  }

  /// Cleanup old completed orders
  Future<void> _cleanupCompletedOrders() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(days: 30));

      final oldOrders = await _firestore
          .collection('orders')
          .where('completedAt', isLessThan: Timestamp.fromDate(cutoffTime))
          .where('status', isEqualTo: OrderStatus.completed.name)
          .get();

      for (final doc in oldOrders.docs) {
        // Archive instead of delete
        await _firestore
            .collection('archived_orders')
            .doc(doc.id)
            .set(doc.data());
        // Keep basic record for analytics
        await doc.reference.update({
          'archived': true,
          'archivedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error cleaning up completed orders: $e');
    }
  }

  /// Generate analytics reports
  Future<void> _generateAnalyticsReports() async {
    try {
      // Generate performance metrics
      await _generatePerformanceMetrics();

      // Generate delivery analytics
      await _generateDeliveryAnalytics();

      debugPrint('Analytics reports generated');
    } catch (e) {
      debugPrint('Error generating analytics reports: $e');
    }
  }

  Future<void> _generatePerformanceMetrics() async {
    // TODO: Implement performance metrics generation
  }

  Future<void> _generateDeliveryAnalytics() async {
    // TODO: Implement delivery analytics generation
  }

  /// Parse order status from string
  OrderStatus _parseOrderStatus(dynamic status) {
    if (status == null) return OrderStatus.pending;

    try {
      return OrderStatus.values.firstWhere(
        (s) => s.name == status.toString(),
        orElse: () => OrderStatus.pending,
      );
    } catch (e) {
      return OrderStatus.pending;
    }
  }

  /// Manual order status update (for admin use)
  Future<bool> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? reason,
    String? userId,
  }) async {
    try {
      await _transitionOrderStatus(orderId, newStatus,
          reason: reason ?? 'Manual update by ${userId ?? 'admin'}');
      return true;
    } catch (e) {
      debugPrint('Error manually updating order status: $e');
      return false;
    }
  }

  /// Get order status history
  Future<List<Map<String, dynamic>>> getOrderStatusHistory(
      String orderId) async {
    try {
      final transitions = await _firestore
          .collection('order_transitions')
          .where('orderId', isEqualTo: orderId)
          .orderBy('timestamp', descending: true)
          .get();

      return transitions.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting order status history: $e');
      return [];
    }
  }

  /// Get order fulfillment metrics
  Future<Map<String, dynamic>> getFulfillmentMetrics({
    String? storeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      Query query = _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));

      if (storeId != null) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      final orders = await query.get();

      final metrics = {
        'totalOrders': orders.docs.length,
        'completedOrders': 0,
        'cancelledOrders': 0,
        'averageProcessingTime': 0.0,
        'averageDeliveryTime': 0.0,
        'onTimeDeliveryRate': 0.0,
        'statusBreakdown': <String, int>{},
      };

      int totalProcessingTime = 0;
      int totalDeliveryTime = 0;
      int onTimeDeliveries = 0;
      int validProcessingOrders = 0;
      int validDeliveryOrders = 0;

      for (final doc in orders.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'pending';

        final Map<String, int> statusBreakdown =
            metrics['statusBreakdown'] as Map<String, int>;
        statusBreakdown[status] = (statusBreakdown[status] ?? 0) + 1;

        if (status == OrderStatus.completed.name) {
          metrics['completedOrders'] = (metrics['completedOrders'] as int) + 1;
        } else if (status == OrderStatus.cancelled.name) {
          metrics['cancelledOrders'] = (metrics['cancelledOrders'] as int) + 1;
        }

        // Calculate processing time
        final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
        final readyAt = (data['readyAt'] as Timestamp?)?.toDate();

        if (paidAt != null && readyAt != null) {
          totalProcessingTime += readyAt.difference(paidAt).inMinutes;
          validProcessingOrders++;
        }

        // Calculate delivery time
        final deliveryRequestedAt =
            (data['deliveryRequestedAt'] as Timestamp?)?.toDate();
        final deliveredAt = (data['deliveredAt'] as Timestamp?)?.toDate();

        if (deliveryRequestedAt != null && deliveredAt != null) {
          final deliveryTime =
              deliveredAt.difference(deliveryRequestedAt).inMinutes;
          totalDeliveryTime += deliveryTime;
          validDeliveryOrders++;

          // Check if delivery was on time (within 60 minutes)
          if (deliveryTime <= 60) {
            onTimeDeliveries++;
          }
        }
      }

      if (validProcessingOrders > 0) {
        metrics['averageProcessingTime'] =
            totalProcessingTime / validProcessingOrders;
      }

      if (validDeliveryOrders > 0) {
        metrics['averageDeliveryTime'] =
            totalDeliveryTime / validDeliveryOrders;
        metrics['onTimeDeliveryRate'] =
            (onTimeDeliveries / validDeliveryOrders) * 100;
      }

      return metrics;
    } catch (e) {
      debugPrint('Error getting fulfillment metrics: $e');
      return {};
    }
  }

  /// Dispose of the service
  void dispose() {
    for (final subscription in _orderSubscriptions.values) {
      subscription.cancel();
    }
    _orderSubscriptions.clear();

    for (final timer in _stateTransitionTimers.values) {
      timer.cancel();
    }
    _stateTransitionTimers.clear();
  }
}

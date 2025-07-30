import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'qpay_service.dart';

/// Debug service to help troubleshoot payment detection issues
class PaymentDebugService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final QPayService _qpayService = QPayService();

  /// Debug payment status for a specific order
  Future<Map<String, dynamic>> debugPaymentStatus(
      String orderId, String qpayInvoiceId) async {
    final debugInfo = <String, dynamic>{
      'orderId': orderId,
      'qpayInvoiceId': qpayInvoiceId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      // Check orders collection
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      debugInfo['orderExists'] = orderDoc.exists;
      if (orderDoc.exists) {
        debugInfo['orderData'] = orderDoc.data();
      }

      // Check temporary orders collection
      final tempOrderDoc =
          await _firestore.collection('temporary_orders').doc(orderId).get();
      debugInfo['tempOrderExists'] = tempOrderDoc.exists;
      if (tempOrderDoc.exists) {
        debugInfo['tempOrderData'] = tempOrderDoc.data();
      }

      // Check QPay payment status
      try {
        final qpayStatus = await _qpayService.checkPaymentStatus(qpayInvoiceId);
        debugInfo['qpayStatus'] = qpayStatus;

        // Also try alternative method if we have payment ID
        if (qpayStatus['payment_id'] != null) {
          try {
            final altQpayStatus = await _qpayService
                .checkPaymentStatusByPaymentId(qpayStatus['payment_id']);
            debugInfo['qpayStatusByPaymentId'] = altQpayStatus;
          } catch (e) {
            debugInfo['qpayStatusByPaymentIdError'] = e.toString();
          }
        }
      } catch (e) {
        debugInfo['qpayError'] = e.toString();
      }

      // Check webhook logs
      final webhookQuery = await _firestore
          .collection('qpay_webhooks')
          .where('orderId', isEqualTo: orderId)
          .orderBy('processedAt', descending: true)
          .limit(5)
          .get();

      debugInfo['webhookCount'] = webhookQuery.docs.length;
      debugInfo['webhooks'] =
          webhookQuery.docs.map((doc) => doc.data()).toList();

      // Check timeout logs
      final timeoutQuery = await _firestore
          .collection('payment_timeout_logs')
          .where('orderId', isEqualTo: orderId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      debugInfo['timeoutLogCount'] = timeoutQuery.docs.length;
      debugInfo['timeoutLogs'] =
          timeoutQuery.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugInfo['error'] = e.toString();
    }

    // Log debug info
    debugPrint('Payment Debug Info: $debugInfo');

    return debugInfo;
  }

  /// Get all active timeouts
  Future<List<Map<String, dynamic>>> getActiveTimeouts() async {
    try {
      final query = await _firestore
          .collection('temporary_orders')
          .where('status', isEqualTo: 'pending_payment')
          .get();

      return query.docs
          .map((doc) => {
                'orderId': doc.id,
                'data': doc.data(),
              })
          .toList();
    } catch (e) {
      debugPrint('Error getting active timeouts: $e');
      return [];
    }
  }

  /// Get recent webhook events
  Future<List<Map<String, dynamic>>> getRecentWebhooks({int limit = 10}) async {
    try {
      final query = await _firestore
          .collection('qpay_webhooks')
          .orderBy('processedAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => {
                'id': doc.id,
                'data': doc.data(),
              })
          .toList();
    } catch (e) {
      debugPrint('Error getting recent webhooks: $e');
      return [];
    }
  }

  /// Get recent timeout events
  Future<List<Map<String, dynamic>>> getRecentTimeoutLogs(
      {int limit = 10}) async {
    try {
      final query = await _firestore
          .collection('payment_timeout_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => {
                'id': doc.id,
                'data': doc.data(),
              })
          .toList();
    } catch (e) {
      debugPrint('Error getting recent timeout logs: $e');
      return [];
    }
  }

  /// Force check QPay status for an invoice
  Future<Map<String, dynamic>> forceCheckQPayStatus(
      String qpayInvoiceId) async {
    try {
      final status = await _qpayService.checkPaymentStatus(qpayInvoiceId);
      debugPrint('QPay Status for $qpayInvoiceId: $status');
      return status;
    } catch (e) {
      debugPrint('Error checking QPay status: $e');
      return {'error': e.toString()};
    }
  }

  /// Clear temporary order (for testing)
  Future<bool> clearTemporaryOrder(String orderId) async {
    try {
      await _firestore.collection('temporary_orders').doc(orderId).delete();
      debugPrint('Temporary order $orderId cleared');
      return true;
    } catch (e) {
      debugPrint('Error clearing temporary order: $e');
      return false;
    }
  }

  /// Simulate webhook processing (for testing)
  Future<bool> simulateWebhookProcessing(
      String orderId, String qpayInvoiceId) async {
    try {
      // This would simulate the webhook processing
      // In a real scenario, this would be handled by the Firebase function
      debugPrint('Simulating webhook processing for order $orderId');

      // Check if temporary order exists
      final tempOrderDoc =
          await _firestore.collection('temporary_orders').doc(orderId).get();
      if (!tempOrderDoc.exists) {
        debugPrint('No temporary order found for $orderId');
        return false;
      }

      // Check QPay status
      final qpayStatus = await _qpayService.checkPaymentStatus(qpayInvoiceId);
      final paymentStatus = qpayStatus['payment_status'];

      if (paymentStatus == 'PAID') {
        // Update temporary order status
        await _firestore.collection('temporary_orders').doc(orderId).update({
          'status': 'payment_successful',
          'paidAt': FieldValue.serverTimestamp(),
          'paymentStatus': qpayStatus,
        });
        debugPrint('Payment successful for order $orderId');
        return true;
      } else {
        debugPrint('Payment not successful for order $orderId: $paymentStatus');
        return false;
      }
    } catch (e) {
      debugPrint('Error simulating webhook processing: $e');
      return false;
    }
  }
}

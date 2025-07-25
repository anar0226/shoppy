import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SubscriptionManagementService {
  static final SubscriptionManagementService _instance =
      SubscriptionManagementService._internal();
  factory SubscriptionManagementService() => _instance;
  SubscriptionManagementService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get subscription analytics for admin dashboard
  Future<Map<String, dynamic>> getSubscriptionAnalytics() async {
    try {
      final callable = _functions.httpsCallable('getSubscriptionAnalytics');
      final result = await callable.call();

      if (result.data != null) {
        return Map<String, dynamic>.from(result.data);
      }

      throw Exception('Failed to get subscription analytics');
    } catch (e) {
      debugPrint('Error getting subscription analytics: $e');
      rethrow;
    }
  }

  /// Manually renew a subscription (admin function)
  Future<Map<String, dynamic>> manualSubscriptionRenewal(String storeId) async {
    try {
      final callable = _functions.httpsCallable('manualSubscriptionRenewal');
      final result = await callable.call({'storeId': storeId});

      if (result.data != null) {
        return Map<String, dynamic>.from(result.data);
      }

      throw Exception('Failed to manually renew subscription');
    } catch (e) {
      debugPrint('Error manually renewing subscription: $e');
      rethrow;
    }
  }

  /// Cancel a subscription
  Future<Map<String, dynamic>> cancelSubscription(String storeId) async {
    try {
      final callable = _functions.httpsCallable('cancelSubscription');
      final result = await callable.call({'storeId': storeId});

      if (result.data != null) {
        return Map<String, dynamic>.from(result.data);
      }

      throw Exception('Failed to cancel subscription');
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      rethrow;
    }
  }

  /// Get subscription payment history for a store
  Future<List<Map<String, dynamic>>> getSubscriptionPaymentHistory(
      String storeId) async {
    try {
      final callable =
          _functions.httpsCallable('getSubscriptionPaymentHistory');
      final result = await callable.call({'storeId': storeId});

      if (result.data != null && result.data['payments'] != null) {
        final List<dynamic> payments = result.data['payments'];
        return payments
            .map((payment) => Map<String, dynamic>.from(payment))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error getting subscription payment history: $e');
      rethrow;
    }
  }

  /// Verify subscription payment manually
  Future<Map<String, dynamic>> verifySubscriptionPayment(
      String paymentId, String storeId) async {
    try {
      final callable = _functions.httpsCallable('verifySubscriptionPayment');
      final result = await callable.call({
        'paymentId': paymentId,
        'storeId': storeId,
      });

      if (result.data != null) {
        return Map<String, dynamic>.from(result.data);
      }

      throw Exception('Failed to verify subscription payment');
    } catch (e) {
      debugPrint('Error verifying subscription payment: $e');
      rethrow;
    }
  }

  /// Get stores with specific subscription status
  Future<List<Map<String, dynamic>>> getStoresBySubscriptionStatus(
      String status) async {
    try {
      // This would typically be a Cloud Function, but for now we'll use Firestore directly
      // You can implement this as a Cloud Function if needed for admin access
      throw UnimplementedError(
          'This method should be implemented as a Cloud Function');
    } catch (e) {
      debugPrint('Error getting stores by subscription status: $e');
      rethrow;
    }
  }

  /// Get subscription statistics for dashboard
  Future<Map<String, dynamic>> getSubscriptionStatistics() async {
    try {
      final analytics = await getSubscriptionAnalytics();

      // Calculate additional statistics
      final totalStores = analytics['totalStores'] ?? 0;
      final activeSubscriptions = analytics['activeSubscriptions'] ?? 0;
      final expiredSubscriptions = analytics['expiredSubscriptions'] ?? 0;
      final gracePeriodSubscriptions =
          analytics['gracePeriodSubscriptions'] ?? 0;
      final pendingSubscriptions = analytics['pendingSubscriptions'] ?? 0;
      final cancelledSubscriptions = analytics['cancelledSubscriptions'] ?? 0;
      final monthlyRevenue = analytics['monthlyRevenue'] ?? 0;
      final averageSubscriptionDuration =
          analytics['averageSubscriptionDuration'] ?? 0;

      // Calculate percentages
      final activePercentage =
          totalStores > 0 ? (activeSubscriptions / totalStores) * 100 : 0;
      final expiredPercentage =
          totalStores > 0 ? (expiredSubscriptions / totalStores) * 100 : 0;
      final gracePeriodPercentage =
          totalStores > 0 ? (gracePeriodSubscriptions / totalStores) * 100 : 0;
      final pendingPercentage =
          totalStores > 0 ? (pendingSubscriptions / totalStores) * 100 : 0;
      final cancelledPercentage =
          totalStores > 0 ? (cancelledSubscriptions / totalStores) * 100 : 0;

      return {
        ...analytics,
        'activePercentage': activePercentage,
        'expiredPercentage': expiredPercentage,
        'gracePeriodPercentage': gracePeriodPercentage,
        'pendingPercentage': pendingPercentage,
        'cancelledPercentage': cancelledPercentage,
        'totalRevenue': monthlyRevenue,
        'averageDurationDays': averageSubscriptionDuration,
      };
    } catch (e) {
      debugPrint('Error getting subscription statistics: $e');
      rethrow;
    }
  }

  /// Check if user has admin privileges
  Future<bool> hasAdminPrivileges() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // This is a simple check - you might want to implement a more robust admin check
      // For now, we'll assume any authenticated user can access these functions
      // The actual admin check happens on the Cloud Function side
      return true;
    } catch (e) {
      debugPrint('Error checking admin privileges: $e');
      return false;
    }
  }

  /// Get subscription status display text
  String getSubscriptionStatusDisplay(String status) {
    switch (status) {
      case 'active':
        return 'Идэвхтэй';
      case 'expired':
        return 'Хугацаа дууссан';
      case 'gracePeriod':
        return 'Хүлээлтийн хугацаа';
      case 'pending':
        return 'Хүлээгдэж буй';
      case 'cancelled':
        return 'Цуцлагдсан';
      default:
        return 'Тодорхойгүй';
    }
  }

  /// Get subscription status color
  int getSubscriptionStatusColor(String status) {
    switch (status) {
      case 'active':
        return 0xFF4CAF50; // Green
      case 'expired':
        return 0xFFF44336; // Red
      case 'gracePeriod':
        return 0xFFFF9800; // Orange
      case 'pending':
        return 0xFF2196F3; // Blue
      case 'cancelled':
        return 0xFF9E9E9E; // Grey
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  /// Format payment amount
  String formatPaymentAmount(dynamic amount) {
    if (amount == null) return '₮0';
    final numAmount = amount is int ? amount.toDouble() : amount as double;
    return '₮${numAmount.toStringAsFixed(0)}';
  }

  /// Format date
  String formatDate(dynamic date) {
    if (date == null) return 'Тодорхойгүй';

    DateTime dateTime;
    if (date is String) {
      dateTime = DateTime.parse(date);
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'Тодорхойгүй';
    }

    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  /// Format date and time
  String formatDateTime(dynamic date) {
    if (date == null) return 'Тодорхойгүй';

    DateTime dateTime;
    if (date is String) {
      dateTime = DateTime.parse(date);
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'Тодорхойгүй';
    }

    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Get payment method display text
  String getPaymentMethodDisplay(String method) {
    switch (method) {
      case 'qpay':
        return 'QPay';
      case 'manual':
        return 'Гараар төлөгдсөн';
      default:
        return method;
    }
  }

  /// Get payment status display text
  String getPaymentStatusDisplay(String status) {
    switch (status) {
      case 'completed':
        return 'Амжилттай';
      case 'pending':
        return 'Хүлээгдэж буй';
      case 'failed':
        return 'Амжилтгүй';
      case 'cancelled':
        return 'Цуцлагдсан';
      default:
        return status;
    }
  }

  /// Get payment status color
  int getPaymentStatusColor(String status) {
    switch (status) {
      case 'completed':
        return 0xFF4CAF50; // Green
      case 'pending':
        return 0xFFFF9800; // Orange
      case 'failed':
        return 0xFFF44336; // Red
      case 'cancelled':
        return 0xFF9E9E9E; // Grey
      default:
        return 0xFF9E9E9E; // Grey
    }
  }
}

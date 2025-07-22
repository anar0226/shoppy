import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Simplified low stock notification service
class LowStockNotificationService {
  static final LowStockNotificationService _instance =
      LowStockNotificationService._internal();
  factory LowStockNotificationService() => _instance;
  LowStockNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isInitialized = false;

  /// Initialize the low stock notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
    } catch (e) {
      // Error initializing low stock notification service
    }
  }

  /// Get low stock alerts for a store
  Future<List<Map<String, dynamic>>> getLowStockAlerts(String storeId) async {
    try {
      final alerts = await _firestore
          .collection('low_stock_alerts')
          .where('storeId', isEqualTo: storeId)
          .where('resolved', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return alerts.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      // Error getting low stock alerts
      return [];
    }
  }

  /// Get alert statistics
  Future<Map<String, dynamic>> getAlertStatistics(String storeId) async {
    try {
      final alerts = await _firestore
          .collection('low_stock_alerts')
          .where('storeId', isEqualTo: storeId)
          .where('createdAt',
              isGreaterThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 30))))
          .get();

      int lowStockCount = 0;
      int criticalStockCount = 0;
      int resolvedCount = 0;

      for (final alertDoc in alerts.docs) {
        final data = alertDoc.data();
        final alertType = data['alertType'] as String;
        final resolved = data['resolved'] as bool? ?? false;

        if (resolved) {
          resolvedCount++;
        } else {
          if (alertType == 'critical') {
            criticalStockCount++;
          } else {
            lowStockCount++;
          }
        }
      }

      return {
        'totalAlerts': alerts.docs.length,
        'lowStockAlerts': lowStockCount,
        'criticalStockAlerts': criticalStockCount,
        'resolvedAlerts': resolvedCount,
        'activeAlerts': lowStockCount + criticalStockCount,
      };
    } catch (e) {
      // Error getting alert statistics
      return {};
    }
  }

  /// Dispose of all resources
  void dispose() {
    // Cleanup if needed
  }
}

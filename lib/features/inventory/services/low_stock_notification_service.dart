import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:collection/collection.dart';
import '../../products/models/product_model.dart';
import '../../stores/models/store_model.dart';
import '../../../admin_panel/services/notification_service.dart';
import '../../notifications/fcm_service.dart';
import '../../notifications/notification_service.dart'
    as UserNotificationService;

/// Comprehensive low stock notification system
class LowStockNotificationService {
  static final LowStockNotificationService _instance =
      LowStockNotificationService._internal();
  factory LowStockNotificationService() => _instance;
  LowStockNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Real-time monitoring subscriptions
  final Map<String, StreamSubscription> _storeSubscriptions = {};
  final Map<String, StreamSubscription> _productSubscriptions = {};
  final Map<String, Timer> _alertCooldowns = {};

  // Configuration constants
  static const int DEFAULT_LOW_STOCK_THRESHOLD = 5;
  static const int DEFAULT_CRITICAL_STOCK_THRESHOLD = 2;
  static const Duration ALERT_COOLDOWN = Duration(hours: 1);
  static const Duration CHECK_INTERVAL = Duration(minutes: 5);

  // Alert tracking
  final Map<String, DateTime> _lastAlertTimes = {};
  final Map<String, int> _alertCounts = {};

  bool _isInitialized = false;
  Timer? _periodicChecker;

  /// Initialize the low stock notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Start monitoring active stores
      await _startGlobalMonitoring();

      // Setup periodic checks
      _setupPeriodicChecks();

      // Listen for inventory events
      _setupInventoryEventListener();

      _isInitialized = true;
      debugPrint('Low stock notification service initialized');
    } catch (e) {
      debugPrint('Error initializing low stock notification service: $e');
    }
  }

  /// Start monitoring all active stores
  Future<void> _startGlobalMonitoring() async {
    try {
      final storesSnapshot = await _firestore
          .collection('stores')
          .where('isActive', isEqualTo: true)
          .get();

      for (final storeDoc in storesSnapshot.docs) {
        final store = StoreModel.fromFirestore(storeDoc);
        await startStoreMonitoring(store.id);
      }
    } catch (e) {
      debugPrint('Error starting global monitoring: $e');
    }
  }

  /// Start monitoring a specific store
  Future<void> startStoreMonitoring(String storeId) async {
    if (_storeSubscriptions.containsKey(storeId)) {
      return; // Already monitoring
    }

    try {
      // Get store settings
      final storeSettings = await _getStoreSettings(storeId);

      // Monitor products in this store
      final subscription = _firestore
          .collection('products')
          .where('storeId', isEqualTo: storeId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen((snapshot) {
        _handleProductChanges(storeId, snapshot, storeSettings);
      });

      _storeSubscriptions[storeId] = subscription;
      debugPrint('Started monitoring store: $storeId');
    } catch (e) {
      debugPrint('Error starting store monitoring: $e');
    }
  }

  /// Stop monitoring a specific store
  void stopStoreMonitoring(String storeId) {
    _storeSubscriptions[storeId]?.cancel();
    _storeSubscriptions.remove(storeId);

    // Clean up related subscriptions
    _productSubscriptions.removeWhere((key, subscription) {
      if (key.startsWith('${storeId}_')) {
        subscription.cancel();
        return true;
      }
      return false;
    });

    debugPrint('Stopped monitoring store: $storeId');
  }

  /// Handle product changes for a store
  void _handleProductChanges(
      String storeId, QuerySnapshot snapshot, StoreSettings settings) {
    for (final change in snapshot.docChanges) {
      final doc = change.doc;
      final product = ProductModel.fromFirestore(doc);

      switch (change.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          _checkProductStock(product, settings);
          break;
        case DocumentChangeType.removed:
          _clearProductAlerts(product.id);
          break;
      }
    }
  }

  /// Check stock levels for a product
  Future<void> _checkProductStock(
      ProductModel product, StoreSettings settings) async {
    try {
      final alerts = <LowStockAlert>[];

      // Check simple product stock
      if (product.variants.isEmpty) {
        final stockLevel = product.stock;
        if (stockLevel <= settings.criticalStockThreshold) {
          alerts.add(LowStockAlert(
            productId: product.id,
            productName: product.name,
            storeId: product.storeId,
            alertType: LowStockAlertType.critical,
            currentStock: stockLevel,
            threshold: settings.criticalStockThreshold,
            variantInfo: null,
          ));
        } else if (stockLevel <= settings.lowStockThreshold) {
          alerts.add(LowStockAlert(
            productId: product.id,
            productName: product.name,
            storeId: product.storeId,
            alertType: LowStockAlertType.low,
            currentStock: stockLevel,
            threshold: settings.lowStockThreshold,
            variantInfo: null,
          ));
        }
      }

      // Check variant stock
      for (final variant in product.variants) {
        if (variant.trackInventory) {
          for (final option in variant.options) {
            final stockLevel = variant.getStockForOption(option);
            if (stockLevel <= settings.criticalStockThreshold) {
              alerts.add(LowStockAlert(
                productId: product.id,
                productName: product.name,
                storeId: product.storeId,
                alertType: LowStockAlertType.critical,
                currentStock: stockLevel,
                threshold: settings.criticalStockThreshold,
                variantInfo: VariantInfo(
                  variantName: variant.name,
                  optionName: option,
                ),
              ));
            } else if (stockLevel <= settings.lowStockThreshold) {
              alerts.add(LowStockAlert(
                productId: product.id,
                productName: product.name,
                storeId: product.storeId,
                alertType: LowStockAlertType.low,
                currentStock: stockLevel,
                threshold: settings.lowStockThreshold,
                variantInfo: VariantInfo(
                  variantName: variant.name,
                  optionName: option,
                ),
              ));
            }
          }
        }
      }

      // Process alerts
      for (final alert in alerts) {
        await _processAlert(alert);
      }
    } catch (e) {
      debugPrint('Error checking product stock: $e');
    }
  }

  /// Process a low stock alert
  Future<void> _processAlert(LowStockAlert alert) async {
    try {
      final alertKey = _generateAlertKey(alert);

      // Check if we're in cooldown period
      if (_isInCooldown(alertKey)) {
        return;
      }

      // Create alert record
      await _createAlertRecord(alert);

      // Send notifications
      await _sendNotifications(alert);

      // Update tracking
      _updateAlertTracking(alertKey);

      // Schedule follow-up if critical
      if (alert.alertType == LowStockAlertType.critical) {
        _scheduleFollowUp(alert);
      }
    } catch (e) {
      debugPrint('Error processing alert: $e');
    }
  }

  /// Create alert record in database
  Future<void> _createAlertRecord(LowStockAlert alert) async {
    try {
      await _firestore.collection('low_stock_alerts').add({
        'productId': alert.productId,
        'productName': alert.productName,
        'storeId': alert.storeId,
        'alertType': alert.alertType.name,
        'currentStock': alert.currentStock,
        'threshold': alert.threshold,
        'variantInfo': alert.variantInfo?.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'resolved': false,
        'priority':
            alert.alertType == LowStockAlertType.critical ? 'high' : 'medium',
      });
    } catch (e) {
      debugPrint('Error creating alert record: $e');
    }
  }

  /// Send notifications for the alert
  Future<void> _sendNotifications(LowStockAlert alert) async {
    try {
      // Get store owner information
      final storeDoc =
          await _firestore.collection('stores').doc(alert.storeId).get();

      if (!storeDoc.exists) return;

      final storeData = storeDoc.data() as Map<String, dynamic>;
      final ownerId = storeData['ownerId'] as String;
      final storeName = storeData['name'] as String;

      // Create notification message
      final message = _createNotificationMessage(alert, storeName);

      // Send admin panel notification
      await NotificationService().createNotification(
        storeId: alert.storeId,
        ownerId: ownerId,
        title: alert.alertType == LowStockAlertType.critical
            ? 'Critical Stock Alert'
            : 'Low Stock Alert',
        message: message,
        type: NotificationType.product,
        data: {
          'productId': alert.productId,
          'alertType': alert.alertType.name,
          'currentStock': alert.currentStock,
          'variantInfo': alert.variantInfo?.toMap(),
        },
      );

      // Send push notification
      await FCMService.sendPushNotification(
        userId: ownerId,
        title:
            '📦 ${alert.alertType == LowStockAlertType.critical ? 'Critical' : 'Low'} Stock Alert',
        body: message,
        data: {
          'type': 'low_stock_alert',
          'productId': alert.productId,
          'storeId': alert.storeId,
          'alertType': alert.alertType.name,
        },
      );

      // Send email notification for critical alerts
      if (alert.alertType == LowStockAlertType.critical) {
        await _sendEmailNotification(alert, ownerId, storeName);
      }

      // Send SMS notification if enabled
      await _sendSMSNotification(alert, ownerId, storeName);
    } catch (e) {
      debugPrint('Error sending notifications: $e');
    }
  }

  /// Create notification message
  String _createNotificationMessage(LowStockAlert alert, String storeName) {
    final variantText = alert.variantInfo != null
        ? ' (${alert.variantInfo!.variantName}: ${alert.variantInfo!.optionName})'
        : '';

    return '${alert.productName}$variantText is running low in $storeName. '
        'Current stock: ${alert.currentStock} units (threshold: ${alert.threshold})';
  }

  /// Send email notification
  Future<void> _sendEmailNotification(
      LowStockAlert alert, String ownerId, String storeName) async {
    try {
      // Get owner email
      final ownerDoc = await _firestore.collection('users').doc(ownerId).get();

      if (!ownerDoc.exists) return;

      final ownerData = ownerDoc.data() as Map<String, dynamic>;
      final email = ownerData['email'] as String?;

      if (email == null || email.isEmpty) return;

      // Queue email for sending
      await _firestore.collection('email_queue').add({
        'to': email,
        'subject': 'Critical Stock Alert - $storeName',
        'body': _createEmailBody(alert, storeName),
        'type': 'low_stock_alert',
        'priority': 'high',
        'productId': alert.productId,
        'storeId': alert.storeId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending email notification: $e');
    }
  }

  /// Send SMS notification
  Future<void> _sendSMSNotification(
      LowStockAlert alert, String ownerId, String storeName) async {
    try {
      // Get owner phone number
      final ownerDoc = await _firestore.collection('users').doc(ownerId).get();

      if (!ownerDoc.exists) return;

      final ownerData = ownerDoc.data() as Map<String, dynamic>;
      final phone = ownerData['phoneNumber'] as String?;

      if (phone == null || phone.isEmpty) return;

      // Check if SMS notifications are enabled
      final smsEnabled = ownerData['smsNotifications'] as bool? ?? false;
      if (!smsEnabled) return;

      // Queue SMS for sending
      await _firestore.collection('sms_queue').add({
        'phoneNumber': phone,
        'message': _createSMSMessage(alert, storeName),
        'type': 'low_stock_alert',
        'priority':
            alert.alertType == LowStockAlertType.critical ? 'high' : 'normal',
        'productId': alert.productId,
        'storeId': alert.storeId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending SMS notification: $e');
    }
  }

  /// Create email body
  String _createEmailBody(LowStockAlert alert, String storeName) {
    final variantText = alert.variantInfo != null
        ? ' (${alert.variantInfo!.variantName}: ${alert.variantInfo!.optionName})'
        : '';

    return '''
Dear Store Owner,

Your product "${alert.productName}"$variantText in $storeName is critically low on stock.

Current Stock Level: ${alert.currentStock} units
Threshold: ${alert.threshold} units
Alert Type: ${alert.alertType.name.toUpperCase()}

Please restock this product as soon as possible to avoid stockouts.

Best regards,
Avii.mn Team
''';
  }

  /// Create SMS message
  String _createSMSMessage(LowStockAlert alert, String storeName) {
    final variantText = alert.variantInfo != null
        ? ' (${alert.variantInfo!.variantName}: ${alert.variantInfo!.optionName})'
        : '';

    return 'Avii.mn: ${alert.productName}$variantText is ${alert.alertType.name} stock '
        'in $storeName. Current: ${alert.currentStock} units. Please restock.';
  }

  /// Setup periodic checks
  void _setupPeriodicChecks() {
    _periodicChecker = Timer.periodic(CHECK_INTERVAL, (timer) {
      _performPeriodicCheck();
    });
  }

  /// Perform periodic check
  Future<void> _performPeriodicCheck() async {
    try {
      // Check for products that might need restocking notifications
      final alerts = await _firestore
          .collection('low_stock_alerts')
          .where('resolved', isEqualTo: false)
          .where('createdAt',
              isGreaterThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 1))))
          .get();

      for (final alertDoc in alerts.docs) {
        final alertData = alertDoc.data();
        final productId = alertData['productId'] as String;

        // Check if product still exists and is still low stock
        final productDoc =
            await _firestore.collection('products').doc(productId).get();

        if (productDoc.exists) {
          final product = ProductModel.fromFirestore(productDoc);
          final storeSettings = await _getStoreSettings(product.storeId);

          // Re-check stock levels
          await _checkProductStock(product, storeSettings);
        }
      }
    } catch (e) {
      debugPrint('Error performing periodic check: $e');
    }
  }

  /// Setup inventory event listener
  void _setupInventoryEventListener() {
    _firestore
        .collection('inventory_events')
        .where('type', isEqualTo: 'adjustment')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          _handleInventoryEvent(data);
        }
      }
    });
  }

  /// Handle inventory event
  Future<void> _handleInventoryEvent(Map<String, dynamic> eventData) async {
    try {
      final productId = eventData['productId'] as String;
      final newStock = eventData['newStock'] as int;
      final reason = eventData['reason'] as String;

      // If stock was increased (restock), resolve alerts
      if (reason == 'restock' && newStock > 0) {
        await _resolveAlertsForProduct(productId);
      }
    } catch (e) {
      debugPrint('Error handling inventory event: $e');
    }
  }

  /// Resolve alerts for a product
  Future<void> _resolveAlertsForProduct(String productId) async {
    try {
      final alerts = await _firestore
          .collection('low_stock_alerts')
          .where('productId', isEqualTo: productId)
          .where('resolved', isEqualTo: false)
          .get();

      final batch = _firestore.batch();

      for (final alertDoc in alerts.docs) {
        batch.update(alertDoc.reference, {
          'resolved': true,
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedReason': 'restocked',
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error resolving alerts: $e');
    }
  }

  /// Get store settings
  Future<StoreSettings> _getStoreSettings(String storeId) async {
    try {
      final storeDoc = await _firestore.collection('stores').doc(storeId).get();

      if (!storeDoc.exists) {
        return StoreSettings.defaultSettings();
      }

      final storeData = storeDoc.data() as Map<String, dynamic>;
      return StoreSettings.fromMap(storeData);
    } catch (e) {
      debugPrint('Error getting store settings: $e');
      return StoreSettings.defaultSettings();
    }
  }

  /// Generate alert key for tracking
  String _generateAlertKey(LowStockAlert alert) {
    final variantKey = alert.variantInfo != null
        ? '${alert.variantInfo!.variantName}:${alert.variantInfo!.optionName}'
        : '';
    return '${alert.productId}:${alert.alertType.name}:$variantKey';
  }

  /// Check if alert is in cooldown period
  bool _isInCooldown(String alertKey) {
    final lastAlertTime = _lastAlertTimes[alertKey];
    if (lastAlertTime == null) return false;

    return DateTime.now().difference(lastAlertTime) < ALERT_COOLDOWN;
  }

  /// Update alert tracking
  void _updateAlertTracking(String alertKey) {
    _lastAlertTimes[alertKey] = DateTime.now();
    _alertCounts[alertKey] = (_alertCounts[alertKey] ?? 0) + 1;
  }

  /// Schedule follow-up for critical alerts
  void _scheduleFollowUp(LowStockAlert alert) {
    final alertKey = _generateAlertKey(alert);

    _alertCooldowns[alertKey] = Timer(const Duration(hours: 4), () {
      _sendFollowUpNotification(alert);
    });
  }

  /// Send follow-up notification
  Future<void> _sendFollowUpNotification(LowStockAlert alert) async {
    try {
      // Check if product still has critical stock
      final productDoc =
          await _firestore.collection('products').doc(alert.productId).get();

      if (!productDoc.exists) return;

      final product = ProductModel.fromFirestore(productDoc);
      final storeSettings = await _getStoreSettings(product.storeId);

      // Check if still critical
      bool stillCritical = false;
      if (alert.variantInfo != null) {
        final variant = product.variants
            .firstWhereOrNull((v) => v.name == alert.variantInfo!.variantName);
        if (variant != null) {
          final stock =
              variant.getStockForOption(alert.variantInfo!.optionName);
          stillCritical = stock <= storeSettings.criticalStockThreshold;
        }
      } else {
        stillCritical = product.stock <= storeSettings.criticalStockThreshold;
      }

      if (stillCritical) {
        // Send follow-up notification
        await _sendNotifications(alert);
      }
    } catch (e) {
      debugPrint('Error sending follow-up notification: $e');
    }
  }

  /// Clear product alerts
  void _clearProductAlerts(String productId) {
    _lastAlertTimes.removeWhere((key, value) => key.startsWith(productId));
    _alertCounts.removeWhere((key, value) => key.startsWith(productId));
    _alertCooldowns.removeWhere((key, timer) {
      if (key.startsWith(productId)) {
        timer.cancel();
        return true;
      }
      return false;
    });
  }

  /// Get low stock alerts for a store
  Future<List<LowStockAlert>> getLowStockAlerts(String storeId) async {
    try {
      final alerts = await _firestore
          .collection('low_stock_alerts')
          .where('storeId', isEqualTo: storeId)
          .where('resolved', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return alerts.docs
          .map((doc) => LowStockAlert.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting low stock alerts: $e');
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
      debugPrint('Error getting alert statistics: $e');
      return {};
    }
  }

  /// Update store notification settings
  Future<void> updateStoreNotificationSettings(
    String storeId,
    StoreNotificationSettings settings,
  ) async {
    try {
      await _firestore.collection('stores').doc(storeId).update({
        'notificationSettings': settings.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating store notification settings: $e');
    }
  }

  /// Dispose of all resources
  void dispose() {
    _periodicChecker?.cancel();

    for (final subscription in _storeSubscriptions.values) {
      subscription.cancel();
    }

    for (final subscription in _productSubscriptions.values) {
      subscription.cancel();
    }

    for (final timer in _alertCooldowns.values) {
      timer.cancel();
    }

    _storeSubscriptions.clear();
    _productSubscriptions.clear();
    _alertCooldowns.clear();
  }
}

/// Low stock alert model
class LowStockAlert {
  final String productId;
  final String productName;
  final String storeId;
  final LowStockAlertType alertType;
  final int currentStock;
  final int threshold;
  final VariantInfo? variantInfo;
  final DateTime? createdAt;
  final bool resolved;

  LowStockAlert({
    required this.productId,
    required this.productName,
    required this.storeId,
    required this.alertType,
    required this.currentStock,
    required this.threshold,
    this.variantInfo,
    this.createdAt,
    this.resolved = false,
  });

  factory LowStockAlert.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LowStockAlert(
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      storeId: data['storeId'] ?? '',
      alertType: LowStockAlertType.values.firstWhere(
        (type) => type.name == data['alertType'],
        orElse: () => LowStockAlertType.low,
      ),
      currentStock: data['currentStock'] ?? 0,
      threshold: data['threshold'] ?? 0,
      variantInfo: data['variantInfo'] != null
          ? VariantInfo.fromMap(data['variantInfo'])
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      resolved: data['resolved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'storeId': storeId,
      'alertType': alertType.name,
      'currentStock': currentStock,
      'threshold': threshold,
      'variantInfo': variantInfo?.toMap(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'resolved': resolved,
    };
  }
}

/// Low stock alert types
enum LowStockAlertType {
  low,
  critical,
  outOfStock,
}

/// Variant information for alerts
class VariantInfo {
  final String variantName;
  final String optionName;

  VariantInfo({
    required this.variantName,
    required this.optionName,
  });

  factory VariantInfo.fromMap(Map<String, dynamic> map) {
    return VariantInfo(
      variantName: map['variantName'] ?? '',
      optionName: map['optionName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'variantName': variantName,
      'optionName': optionName,
    };
  }
}

/// Store settings for inventory notifications
class StoreSettings {
  final int lowStockThreshold;
  final int criticalStockThreshold;
  final bool enableEmailNotifications;
  final bool enableSMSNotifications;
  final bool enablePushNotifications;

  StoreSettings({
    required this.lowStockThreshold,
    required this.criticalStockThreshold,
    required this.enableEmailNotifications,
    required this.enableSMSNotifications,
    required this.enablePushNotifications,
  });

  factory StoreSettings.defaultSettings() {
    return StoreSettings(
      lowStockThreshold: 10,
      criticalStockThreshold: 3,
      enableEmailNotifications: true,
      enableSMSNotifications: false,
      enablePushNotifications: true,
    );
  }

  factory StoreSettings.fromMap(Map<String, dynamic> map) {
    final settings = map['inventorySettings'] as Map<String, dynamic>? ?? {};
    return StoreSettings(
      lowStockThreshold: settings['lowStockThreshold'] ?? 10,
      criticalStockThreshold: settings['criticalStockThreshold'] ?? 3,
      enableEmailNotifications: settings['enableEmailNotifications'] ?? true,
      enableSMSNotifications: settings['enableSMSNotifications'] ?? false,
      enablePushNotifications: settings['enablePushNotifications'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lowStockThreshold': lowStockThreshold,
      'criticalStockThreshold': criticalStockThreshold,
      'enableEmailNotifications': enableEmailNotifications,
      'enableSMSNotifications': enableSMSNotifications,
      'enablePushNotifications': enablePushNotifications,
    };
  }
}

/// Store notification settings
class StoreNotificationSettings {
  final bool enableLowStockAlerts;
  final bool enableCriticalStockAlerts;
  final bool enableEmailNotifications;
  final bool enableSMSNotifications;
  final bool enablePushNotifications;
  final Duration alertFrequency;

  StoreNotificationSettings({
    required this.enableLowStockAlerts,
    required this.enableCriticalStockAlerts,
    required this.enableEmailNotifications,
    required this.enableSMSNotifications,
    required this.enablePushNotifications,
    required this.alertFrequency,
  });

  factory StoreNotificationSettings.defaultSettings() {
    return StoreNotificationSettings(
      enableLowStockAlerts: true,
      enableCriticalStockAlerts: true,
      enableEmailNotifications: true,
      enableSMSNotifications: false,
      enablePushNotifications: true,
      alertFrequency: const Duration(hours: 1),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enableLowStockAlerts': enableLowStockAlerts,
      'enableCriticalStockAlerts': enableCriticalStockAlerts,
      'enableEmailNotifications': enableEmailNotifications,
      'enableSMSNotifications': enableSMSNotifications,
      'enablePushNotifications': enablePushNotifications,
      'alertFrequencyHours': alertFrequency.inHours,
    };
  }
}

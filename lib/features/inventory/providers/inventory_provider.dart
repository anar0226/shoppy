import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../products/models/product_model.dart';

/// Real-time inventory provider for global inventory state management
class InventoryProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Real-time inventory state management
  final Map<String, Map<String, dynamic>> _inventoryStates = {};
  final Map<String, StreamSubscription> _inventorySubscriptions = {};
  final Map<String, List<InventoryAlert>> _lowStockAlerts = {};
  final Map<String, DateTime> _lastReservationTime = {};
  final Map<String, StreamSubscription> _productStreams = {};
  final Map<String, StreamSubscription> _storeStreams = {};

  // Real-time inventory updates
  Map<String, Map<String, dynamic>> get inventoryStates => _inventoryStates;
  Map<String, List<InventoryAlert>> get lowStockAlerts => _lowStockAlerts;

  // Inventory reservation tracking
  final Map<String, InventoryReservation> _activeReservations = {};
  Map<String, InventoryReservation> get activeReservations =>
      _activeReservations;

  // Real-time monitoring
  final Map<String, int> _stockLevels = {};
  final Map<String, Map<String, int>> _variantStockLevels = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Initialize inventory provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize with current user's store inventory if applicable
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _initializeUserInventory(currentUser.uid);
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // Error initializing inventory provider
    }
  }

  /// Watch a store's inventory
  void watchStore(String storeId) {
    if (_storeStreams.containsKey(storeId)) return;

    final subscription = _firestore
        .collection('products')
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _handleProductChanges(storeId, snapshot);
    });

    _storeStreams[storeId] = subscription;
  }

  /// Stop watching a store
  void unwatchStore(String storeId) {
    _storeStreams[storeId]?.cancel();
    _storeStreams.remove(storeId);
    _inventoryStates.remove(storeId);
    _lowStockAlerts.remove(storeId);
  }

  /// Handle product changes for a store
  void _handleProductChanges(String storeId, QuerySnapshot snapshot) {
    final storeInventory = <String, dynamic>{};

    for (final doc in snapshot.docs) {
      final product = ProductModel.fromFirestore(doc);
      final productInventory = _calculateProductInventory(product);
      storeInventory[product.id] = productInventory;

      // Check for alerts
      _checkLowStockAlert(product);
    }

    _inventoryStates[storeId] = storeInventory;
    _updateLowStockAlerts(storeId);
    notifyListeners();
  }

  /// Calculate inventory for a product
  Map<String, dynamic> _calculateProductInventory(ProductModel product) {
    int totalAvailableStock = 0;
    int reservedStock = 0;

    if (product.variants.isEmpty) {
      totalAvailableStock = product.stock;
    } else {
      for (final variant in product.variants) {
        if (variant.trackInventory) {
          totalAvailableStock += variant.totalStock;
        }
      }
    }

    // Get reserved stock from active reservations
    final reservations = _activeReservations.values
        .where((r) => r.productId == product.id && !r.isExpired)
        .toList();
    reservedStock = reservations.fold(0, (total, r) => total + r.quantity);

    return {
      'totalAvailableStock': totalAvailableStock,
      'reservedStock': reservedStock,
      'availableStock': totalAvailableStock - reservedStock,
      'lastUpdated': DateTime.now(),
    };
  }

  /// Create low stock alert
  void _createLowStockAlert(ProductModel product, int threshold) {
    final alert = InventoryAlert(
      productId: product.id,
      productName: product.name,
      storeId: product.storeId,
      type: InventoryAlertType.lowStock,
      currentStock: product.totalAvailableStock,
      threshold: threshold,
      timestamp: DateTime.now(),
    );

    _lowStockAlerts.putIfAbsent(product.storeId, () => []);

    // Check if alert already exists
    final existingAlert = _lowStockAlerts[product.storeId]!
        .where((a) =>
            a.productId == product.id && a.type == InventoryAlertType.lowStock)
        .firstOrNull;

    if (existingAlert == null) {
      _lowStockAlerts[product.storeId]!.add(alert);
      _publishInventoryEvent('low_stock_alert', {
        'productId': product.id,
        'productName': product.name,
        'storeId': product.storeId,
        'currentStock': product.totalAvailableStock,
        'threshold': threshold,
      });
    }
  }

  /// Create out of stock alert
  void _createOutOfStockAlert(ProductModel product) {
    final alert = InventoryAlert(
      productId: product.id,
      productName: product.name,
      storeId: product.storeId,
      type: InventoryAlertType.outOfStock,
      currentStock: 0,
      threshold: 0,
      timestamp: DateTime.now(),
    );

    _lowStockAlerts.putIfAbsent(product.storeId, () => []);

    // Check if alert already exists
    final existingAlert = _lowStockAlerts[product.storeId]!
        .where((a) =>
            a.productId == product.id &&
            a.type == InventoryAlertType.outOfStock)
        .firstOrNull;

    if (existingAlert == null) {
      _lowStockAlerts[product.storeId]!.add(alert);
      _publishInventoryEvent('out_of_stock_alert', {
        'productId': product.id,
        'productName': product.name,
        'storeId': product.storeId,
      });
    }
  }

  /// Check for low stock alerts
  void _checkLowStockAlert(ProductModel product) {
    const lowStockThreshold = 5;

    if (product.totalAvailableStock <= lowStockThreshold &&
        product.totalAvailableStock > 0) {
      _createLowStockAlert(product, lowStockThreshold);
    }

    // Check for out of stock
    if (product.totalAvailableStock == 0) {
      _createOutOfStockAlert(product);
    }
  }

  /// Update low stock alerts for a store
  void _updateLowStockAlerts(String storeId) {
    final alerts = <InventoryAlert>[];

    for (final productInventory in _inventoryStates[storeId]?.values ?? []) {
      final productId = productInventory['productId'] as String?;
      if (productId == null) continue;

      final stock = productInventory['totalAvailableStock'] as int? ?? 0;

      // Check for low stock alerts
      if (stock <= 5 && stock > 0) {
        alerts.add(InventoryAlert(
          productId: productId,
          productName: productInventory['productName'] as String? ?? 'Unknown',
          storeId: storeId,
          type: InventoryAlertType.lowStock,
          currentStock: stock,
          threshold: 5,
          timestamp: DateTime.now(),
        ));
      }

      // Check for out of stock alerts
      if (stock == 0) {
        alerts.add(InventoryAlert(
          productId: productId,
          productName: productInventory['productName'] as String? ?? 'Unknown',
          storeId: storeId,
          type: InventoryAlertType.outOfStock,
          currentStock: 0,
          threshold: 0,
          timestamp: DateTime.now(),
        ));
      }
    }

    _lowStockAlerts[storeId] = alerts;
    notifyListeners();
  }

  /// Initialize user inventory with real-time updates
  Future<void> _initializeUserInventory(String userId) async {
    try {
      // Find user's stores
      final userStores = await _firestore
          .collection('stores')
          .where('ownerId', isEqualTo: userId)
          .get();

      // Watch all user's stores
      for (final storeDoc in userStores.docs) {
        watchStore(storeDoc.id);
      }
    } catch (e) {
      // Error initializing user inventory
    }
  }

  /// Get current stock level for a product
  int getCurrentStock(String productId) {
    return _stockLevels[productId] ?? 0;
  }

  /// Get variant stock level
  int getVariantStock(String productId, String variantName, String option) {
    return _variantStockLevels[productId]?['${variantName}_$option'] ?? 0;
  }

  /// Reserve inventory for a product
  Future<bool> reserveInventory(
      String productId, int quantity, Duration duration) async {
    try {
      final reservation = InventoryReservation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productId: productId,
        quantity: quantity,
        expiresAt: DateTime.now().add(duration),
        userId: _auth.currentUser?.uid ?? '',
      );

      _activeReservations[reservation.id] = reservation;
      _lastReservationTime[productId] = DateTime.now();
      notifyListeners();

      return true;
    } catch (e) {
      // Error reserving inventory
      return false;
    }
  }

  /// Release inventory reservation
  void releaseReservation(String reservationId) {
    _activeReservations.remove(reservationId);
    notifyListeners();
  }

  /// Publish inventory event
  void _publishInventoryEvent(String eventType, Map<String, dynamic> data) {
    try {
      _firestore.collection('inventory_events').add({
        'type': eventType,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _auth.currentUser?.uid,
      });
    } catch (e) {
      // Error publishing inventory event
    }
  }

  /// Clean up all subscriptions
  @override
  void dispose() {
    // Cancel all subscriptions
    for (final subscription in _inventorySubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _productStreams.values) {
      subscription.cancel();
    }
    for (final subscription in _storeStreams.values) {
      subscription.cancel();
    }

    super.dispose();
  }
}

/// Inventory alert model
class InventoryAlert {
  final String id;
  final String productId;
  final String productName;
  final String storeId;
  final InventoryAlertType type;
  final int currentStock;
  final int threshold;
  final DateTime timestamp;
  final bool resolved;

  InventoryAlert({
    String? id,
    required this.productId,
    required this.productName,
    required this.storeId,
    required this.type,
    required this.currentStock,
    required this.threshold,
    required this.timestamp,
    this.resolved = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'storeId': storeId,
      'type': type.toString(),
      'currentStock': currentStock,
      'threshold': threshold,
      'timestamp': Timestamp.fromDate(timestamp),
      'resolved': resolved,
    };
  }
}

/// Inventory alert types
enum InventoryAlertType {
  lowStock,
  outOfStock,
  restock,
}

/// Inventory reservation model
class InventoryReservation {
  final String id;
  final String productId;
  final int quantity;
  final DateTime expiresAt;
  final String userId;

  InventoryReservation({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.expiresAt,
    required this.userId,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());
}

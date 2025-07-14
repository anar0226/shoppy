import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/inventory_service.dart';
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
  final Set<String> _watchedProducts = {};

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

      // Setup real-time listeners
      _setupGlobalInventoryListener();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing inventory provider: $e');
    }
  }

  /// Setup global inventory listener for real-time updates
  void _setupGlobalInventoryListener() {
    // Listen to all product changes globally
    _inventorySubscriptions['global'] = _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _handleGlobalInventoryUpdate(snapshot);
    });

    // Listen to inventory events collection for coordinated updates
    _inventorySubscriptions['events'] = _firestore
        .collection('inventory_events')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      _handleInventoryEvents(snapshot);
    });
  }

  /// Handle global inventory updates
  void _handleGlobalInventoryUpdate(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      final doc = change.doc;
      final product = ProductModel.fromFirestore(doc);

      switch (change.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          _updateProductInventory(product);
          break;
        case DocumentChangeType.removed:
          _removeProductInventory(product.id);
          break;
      }
    }
    notifyListeners();
  }

  /// Update product inventory in local state
  void _updateProductInventory(ProductModel product) {
    final storeId = product.storeId;

    // Initialize store inventory if needed
    _inventoryStates.putIfAbsent(storeId, () => {});

    // Update product inventory
    _inventoryStates[storeId]![product.id] = {
      'productId': product.id,
      'name': product.name,
      'stock': product.stock,
      'variants': product.variants.map((v) => v.toMap()).toList(),
      'totalAvailableStock': product.totalAvailableStock,
      'hasStock': product.hasStock,
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    // Update stock levels cache
    _stockLevels[product.id] = product.stock;

    // Update variant stock levels
    if (product.variants.isNotEmpty) {
      _variantStockLevels[product.id] = {};
      for (final variant in product.variants) {
        _variantStockLevels[product.id]![variant.name] = variant.totalStock;
      }
    }

    // Check for low stock alerts
    _checkLowStockAlert(product);
  }

  /// Remove product inventory from local state
  void _removeProductInventory(String productId) {
    for (final storeInventory in _inventoryStates.values) {
      storeInventory.remove(productId);
    }
    _stockLevels.remove(productId);
    _variantStockLevels.remove(productId);
  }

  /// Handle inventory events (reservations, releases, adjustments)
  void _handleInventoryEvents(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final data = change.doc.data() as Map<String, dynamic>;
        final eventType = data['type'] as String;

        switch (eventType) {
          case 'reservation':
            _handleReservationEvent(data);
            break;
          case 'release':
            _handleReleaseEvent(data);
            break;
          case 'adjustment':
            _handleAdjustmentEvent(data);
            break;
          case 'low_stock_alert':
            _handleLowStockEvent(data);
            break;
        }
      }
    }
  }

  /// Handle reservation events
  void _handleReservationEvent(Map<String, dynamic> data) {
    final productId = data['productId'] as String;
    final quantity = data['quantity'] as int;
    final reservationId = data['reservationId'] as String;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();

    _activeReservations[reservationId] = InventoryReservation(
      id: reservationId,
      productId: productId,
      quantity: quantity,
      expiresAt: expiresAt,
      userId: data['userId'] as String,
    );

    notifyListeners();
  }

  /// Handle release events
  void _handleReleaseEvent(Map<String, dynamic> data) {
    final reservationId = data['reservationId'] as String;
    _activeReservations.remove(reservationId);
    notifyListeners();
  }

  /// Handle adjustment events
  void _handleAdjustmentEvent(Map<String, dynamic> data) {
    final productId = data['productId'] as String;
    final newStock = data['newStock'] as int;
    final reason = data['reason'] as String;

    // Update local stock levels
    _stockLevels[productId] = newStock;

    // Show notification for significant adjustments
    if (reason == 'restock' && newStock > 0) {
      _showRestockNotification(productId, newStock);
    }

    notifyListeners();
  }

  /// Handle low stock events
  void _handleLowStockEvent(Map<String, dynamic> data) {
    final productId = data['productId'] as String;
    final storeId = data['storeId'] as String;
    final currentStock = data['currentStock'] as int;

    _lowStockAlerts.putIfAbsent(storeId, () => []);

    final alert = InventoryAlert(
      productId: productId,
      productName: data['productName'] as String,
      storeId: storeId,
      type: InventoryAlertType.lowStock,
      currentStock: currentStock,
      threshold: data['threshold'] as int,
      timestamp: DateTime.now(),
    );

    // Add alert if not already exists
    final existingAlert = _lowStockAlerts[storeId]!
        .where((a) =>
            a.productId == productId && a.type == InventoryAlertType.lowStock)
        .firstOrNull;

    if (existingAlert == null) {
      _lowStockAlerts[storeId]!.add(alert);
      notifyListeners();
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
        'currentStock': 0,
        'threshold': 0,
      });
    }
  }

  /// Publish inventory event for real-time coordination
  Future<void> _publishInventoryEvent(
      String type, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('inventory_events').add({
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'data': data,
        ...data,
      });
    } catch (e) {
      debugPrint('Error publishing inventory event: $e');
    }
  }

  /// Show restock notification
  void _showRestockNotification(String productId, int newStock) {
    // This would trigger a UI notification
    debugPrint('Product $productId restocked to $newStock units');
  }

  /// Watch specific products for real-time updates
  void watchProduct(String productId) {
    if (_watchedProducts.contains(productId)) return;

    _watchedProducts.add(productId);

    _productStreams[productId] = _firestore
        .collection('products')
        .doc(productId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final product = ProductModel.fromFirestore(snapshot);
        _updateProductInventory(product);
        notifyListeners();
      }
    });
  }

  /// Stop watching a product
  void unwatchProduct(String productId) {
    _watchedProducts.remove(productId);
    _productStreams[productId]?.cancel();
    _productStreams.remove(productId);
  }

  /// Watch all products in a store
  void watchStore(String storeId) {
    if (_storeStreams.containsKey(storeId)) return;

    _storeStreams[storeId] = _firestore
        .collection('products')
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _handleStoreInventoryUpdate(storeId, snapshot);
    });
  }

  /// Stop watching a store
  void unwatchStore(String storeId) {
    _storeStreams[storeId]?.cancel();
    _storeStreams.remove(storeId);
  }

  /// Handle store inventory updates
  void _handleStoreInventoryUpdate(String storeId, QuerySnapshot snapshot) {
    _inventoryStates[storeId] = {};
    final alerts = <InventoryAlert>[];

    for (final doc in snapshot.docs) {
      final product = ProductModel.fromFirestore(doc);

      // Update inventory state
      _inventoryStates[storeId]![product.id] = {
        'productId': product.id,
        'name': product.name,
        'stock': product.stock,
        'variants': product.variants.map((v) => v.toMap()).toList(),
        'totalAvailableStock': product.totalAvailableStock,
        'hasStock': product.hasStock,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // Check for low stock alerts
      if (_shouldCreateLowStockAlert(product)) {
        alerts.add(InventoryAlert(
          productId: product.id,
          productName: product.name,
          storeId: storeId,
          type: InventoryAlertType.lowStock,
          currentStock: product.totalAvailableStock,
          threshold: 5,
          timestamp: DateTime.now(),
        ));
      }

      // Check for out of stock alerts
      if (product.totalAvailableStock == 0) {
        alerts.add(InventoryAlert(
          productId: product.id,
          productName: product.name,
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
      debugPrint('Error initializing user inventory: $e');
    }
  }

  bool _shouldCreateLowStockAlert(ProductModel product) {
    const lowStockThreshold = 5;

    if (product.variants.isNotEmpty) {
      return product.variants.any((variant) =>
          variant.trackInventory && variant.totalStock <= lowStockThreshold);
    }

    return product.stock <= lowStockThreshold && product.stock > 0;
  }

  /// Get current stock level for a product
  int getCurrentStock(String productId) {
    return _stockLevels[productId] ?? 0;
  }

  /// Get variant stock levels for a product
  Map<String, int> getVariantStockLevels(String productId) {
    return _variantStockLevels[productId] ?? {};
  }

  /// Reserve inventory with real-time coordination
  Future<bool> reserveInventory({
    required String productId,
    required int quantity,
    required String userId,
    Map<String, String>? selectedVariants,
    Duration timeout = const Duration(minutes: 15),
  }) async {
    try {
      final reservationId =
          'res_${DateTime.now().millisecondsSinceEpoch}_$userId';
      final expiresAt = DateTime.now().add(timeout);

      // Use InventoryService for atomic reservation
      final success = await InventoryService.reserveInventory(
        productId: productId,
        quantity: quantity,
        selectedVariants: selectedVariants,
      );

      if (success) {
        // Publish reservation event
        await _publishInventoryEvent('reservation', {
          'reservationId': reservationId,
          'productId': productId,
          'quantity': quantity,
          'userId': userId,
          'selectedVariants': selectedVariants,
          'expiresAt': Timestamp.fromDate(expiresAt),
        });

        // Track reservation locally
        _activeReservations[reservationId] = InventoryReservation(
          id: reservationId,
          productId: productId,
          quantity: quantity,
          expiresAt: expiresAt,
          userId: userId,
        );

        // Setup auto-release timer
        Timer(timeout, () => _autoReleaseReservation(reservationId));

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error reserving inventory: $e');
      return false;
    }
  }

  /// Auto-release expired reservations
  Future<void> _autoReleaseReservation(String reservationId) async {
    final reservation = _activeReservations[reservationId];
    if (reservation != null && DateTime.now().isAfter(reservation.expiresAt)) {
      await releaseReservation(reservationId);
    }
  }

  /// Release inventory reservation
  Future<bool> releaseReservation(String reservationId) async {
    try {
      final reservation = _activeReservations[reservationId];
      if (reservation == null) return false;

      // Use InventoryService for atomic release
      final success = await InventoryService.releaseInventory(
        productId: reservation.productId,
        quantity: reservation.quantity,
      );

      if (success) {
        // Publish release event
        await _publishInventoryEvent('release', {
          'reservationId': reservationId,
          'productId': reservation.productId,
          'quantity': reservation.quantity,
        });

        // Remove from local tracking
        _activeReservations.remove(reservationId);
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error releasing reservation: $e');
      return false;
    }
  }

  /// Get inventory state for a specific product
  Map<String, dynamic>? getProductInventory(String storeId, String productId) {
    return _inventoryStates[storeId]?[productId];
  }

  /// Check if product has sufficient stock
  bool checkStockAvailability({
    required String storeId,
    required String productId,
    required int quantity,
    Map<String, String>? selectedVariants,
  }) {
    final productInventory = getProductInventory(storeId, productId);
    if (productInventory == null) return false;

    if (selectedVariants != null && selectedVariants.isNotEmpty) {
      final variants =
          List<Map<String, dynamic>>.from(productInventory['variants']);

      for (final variantMap in variants) {
        final variantName = variantMap['name'];
        final selectedOption = selectedVariants[variantName];

        if (selectedOption != null && variantMap['trackInventory'] == true) {
          final stockByOption =
              Map<String, dynamic>.from(variantMap['stockByOption'] ?? {});
          final stock = stockByOption[selectedOption] ?? 0;

          if (stock < quantity) {
            return false;
          }
        }
      }

      return true;
    } else {
      final stock = productInventory['stock'] ?? 0;
      return stock >= quantity;
    }
  }

  /// Get low stock alerts for a store
  List<InventoryAlert> getLowStockAlerts(String storeId) {
    return _lowStockAlerts[storeId] ?? [];
  }

  /// Mark alert as resolved
  Future<void> resolveAlert(String storeId, String alertId) async {
    try {
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('inventory_alerts')
          .doc(alertId)
          .update({
        'resolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      // Remove from local alerts
      _lowStockAlerts[storeId]?.removeWhere((alert) => alert.id == alertId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error resolving alert: $e');
    }
  }

  /// Get real-time inventory stream for a specific product
  Stream<Map<String, dynamic>?> getProductInventoryStream(String productId) {
    return _firestore
        .collection('products')
        .doc(productId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final product = ProductModel.fromFirestore(snapshot);
        return {
          'productId': product.id,
          'name': product.name,
          'stock': product.stock,
          'variants': product.variants.map((v) => v.toMap()).toList(),
          'totalAvailableStock': product.totalAvailableStock,
          'hasStock': product.hasStock,
          'lastUpdated': DateTime.now().toIso8601String(),
        };
      }
      return null;
    });
  }

  /// Get real-time inventory stream for a store
  Stream<Map<String, Map<String, dynamic>>> getStoreInventoryStream(
      String storeId) {
    return _firestore
        .collection('products')
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final storeInventory = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final product = ProductModel.fromFirestore(doc);
        storeInventory[product.id] = {
          'productId': product.id,
          'name': product.name,
          'stock': product.stock,
          'variants': product.variants.map((v) => v.toMap()).toList(),
          'totalAvailableStock': product.totalAvailableStock,
          'hasStock': product.hasStock,
          'lastUpdated': DateTime.now().toIso8601String(),
        };
      }

      return storeInventory;
    });
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

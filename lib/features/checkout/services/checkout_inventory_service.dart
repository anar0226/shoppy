import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../cart/models/cart_item.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../../core/services/inventory_service.dart';
import '../../products/models/product_model.dart';

/// Enhanced checkout service with inventory reservation and management
class CheckoutInventoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, Timer> _reservationTimers = {};

  /// Reserve inventory for checkout with timeout and real-time coordination
  static Future<CheckoutReservationResult> reserveInventoryForCheckout({
    required String userId,
    required List<CartItem> cartItems,
    Duration timeout = const Duration(minutes: 15),
  }) async {
    try {
      final reservationId =
          'checkout_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      final reservedItems = <ReservedCartItem>[];
      final failedItems = <CartItem>[];

      // Pre-validate all items for availability
      final validationResult = await _validateCartItems(cartItems);
      if (!validationResult.success) {
        failedItems.addAll(validationResult.failedItems);
        return CheckoutReservationResult(
          success: false,
          reservationId: null,
          reservedItems: [],
          failedItems: failedItems,
          expiresAt: null,
          error: validationResult.error,
        );
      }

      // Create reservation transaction with retry logic
      final reservationResult = await _executeReservationWithRetry(
        reservationId,
        userId,
        cartItems,
        timeout,
        maxRetries: 3,
      );

      if (reservationResult.success) {
        // Create reservation document
        await _createReservationDocument(
            reservationId, userId, reservationResult.reservedItems, timeout);

        // Set up auto-release timer
        _setupAutoReleaseTimer(reservationId, timeout);

        // Publish reservation event for real-time coordination
        await _publishReservationEvent(
            reservationId, userId, cartItems, timeout);

        return CheckoutReservationResult(
          success: true,
          reservationId: reservationId,
          reservedItems: reservationResult.reservedItems,
          failedItems: reservationResult.failedItems,
          expiresAt: DateTime.now().add(timeout),
        );
      } else {
        return CheckoutReservationResult(
          success: false,
          reservationId: null,
          reservedItems: [],
          failedItems: reservationResult.failedItems,
          expiresAt: null,
          error: reservationResult.error,
        );
      }
    } catch (e) {
      debugPrint('Error reserving inventory for checkout: $e');
      return CheckoutReservationResult(
        success: false,
        reservationId: null,
        reservedItems: [],
        failedItems: cartItems,
        expiresAt: null,
        error: e.toString(),
      );
    }
  }

  /// Validate cart items before reservation
  static Future<ValidationResult> _validateCartItems(
      List<CartItem> cartItems) async {
    final failedItems = <CartItem>[];

    try {
      for (final item in cartItems) {
        final productDoc =
            await _firestore.collection('products').doc(item.product.id).get();

        if (!productDoc.exists) {
          failedItems.add(item);
          continue;
        }

        final product = ProductModel.fromFirestore(productDoc);

        if (!product.isActive) {
          failedItems.add(item);
          continue;
        }

        // Check stock availability
        if (!_checkItemStockAvailability(product, item)) {
          failedItems.add(item);
          continue;
        }
      }

      return ValidationResult(
        success: failedItems.isEmpty,
        failedItems: failedItems,
        error: failedItems.isEmpty ? null : 'Some items are not available',
      );
    } catch (e) {
      return ValidationResult(
        success: false,
        failedItems: cartItems,
        error: e.toString(),
      );
    }
  }

  /// Execute reservation with retry logic
  static Future<ReservationResult> _executeReservationWithRetry(
      String reservationId,
      String userId,
      List<CartItem> cartItems,
      Duration timeout,
      {int maxRetries = 3}) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final result = await _firestore
            .runTransaction<ReservationResult>((transaction) async {
          final reservedItems = <ReservedCartItem>[];
          final failedItems = <CartItem>[];

          // First pass: validate all items and check availability
          for (final item in cartItems) {
            final productRef =
                _firestore.collection('products').doc(item.product.id);
            final productSnap = await transaction.get(productRef);

            if (!productSnap.exists) {
              failedItems.add(item);
              continue;
            }

            final product = ProductModel.fromFirestore(productSnap);

            if (!product.isActive) {
              failedItems.add(item);
              continue;
            }

            // Check stock availability
            if (!_checkItemStockAvailability(product, item)) {
              failedItems.add(item);
              continue;
            }
          }

          // If any items failed, return failure
          if (failedItems.isNotEmpty) {
            return ReservationResult(
              success: false,
              reservedItems: [],
              failedItems: failedItems,
              error: 'Some items are not available',
            );
          }

          // Second pass: reserve inventory for all items atomically
          for (final item in cartItems) {
            final productRef =
                _firestore.collection('products').doc(item.product.id);
            final productSnap = await transaction.get(productRef);
            final product = ProductModel.fromFirestore(productSnap);

            if (item.selectedVariants != null &&
                item.selectedVariants!.isNotEmpty) {
              // Reserve variant inventory
              final updatedVariants = _reserveVariantInventory(
                product.variants,
                item.selectedVariants!,
                item.quantity,
              );

              transaction.update(productRef, {
                'variants': updatedVariants.map((v) => v.toMap()).toList(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } else {
              // Reserve simple product inventory
              transaction.update(productRef, {
                'stock': product.stock - item.quantity,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }

            reservedItems.add(ReservedCartItem(
              cartItem: item,
              reservationId: reservationId,
              reservedAt: DateTime.now(),
              expiresAt: DateTime.now().add(timeout),
            ));
          }

          return ReservationResult(
            success: true,
            reservedItems: reservedItems,
            failedItems: [],
            error: null,
          );
        });

        return result;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          return ReservationResult(
            success: false,
            reservedItems: [],
            failedItems: cartItems,
            error: 'Failed to reserve inventory after $maxRetries attempts: $e',
          );
        }

        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }

    return ReservationResult(
      success: false,
      reservedItems: [],
      failedItems: cartItems,
      error: 'Maximum retry attempts exceeded',
    );
  }

  /// Publish reservation event for real-time coordination
  static Future<void> _publishReservationEvent(
    String reservationId,
    String userId,
    List<CartItem> cartItems,
    Duration timeout,
  ) async {
    try {
      await _firestore.collection('inventory_events').add({
        'type': 'reservation',
        'reservationId': reservationId,
        'userId': userId,
        'items': cartItems
            .map((item) => {
                  'productId': item.product.id,
                  'quantity': item.quantity,
                  'selectedVariants': item.selectedVariants,
                })
            .toList(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(timeout)),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error publishing reservation event: $e');
    }
  }

  /// Check if a cart item has sufficient stock
  static bool _checkItemStockAvailability(ProductModel product, CartItem item) {
    if (item.selectedVariants != null && item.selectedVariants!.isNotEmpty) {
      // Check variant stock
      for (final variant in product.variants) {
        final selectedOption = item.selectedVariants![variant.name];
        if (selectedOption != null && variant.trackInventory) {
          final stock = variant.getStockForOption(selectedOption);
          if (stock < item.quantity) {
            return false;
          }
        }
      }
      return true;
    } else {
      // Check simple product stock
      return product.stock >= item.quantity;
    }
  }

  /// Reserve variant inventory
  static List<ProductVariant> _reserveVariantInventory(
    List<ProductVariant> variants,
    Map<String, String> selectedVariants,
    int quantity,
  ) {
    return variants.map((variant) {
      final selectedOption = selectedVariants[variant.name];
      if (selectedOption != null && variant.trackInventory) {
        final currentStock = variant.getStockForOption(selectedOption);
        final newStock = currentStock - quantity;

        final updatedStockByOption =
            Map<String, int>.from(variant.stockByOption);
        updatedStockByOption[selectedOption] = newStock;

        return ProductVariant(
          name: variant.name,
          options: variant.options,
          priceAdjustments: variant.priceAdjustments,
          stockByOption: updatedStockByOption,
          trackInventory: variant.trackInventory,
        );
      }
      return variant;
    }).toList();
  }

  /// Create reservation document in Firestore
  static Future<void> _createReservationDocument(
    String reservationId,
    String userId,
    List<ReservedCartItem> reservedItems,
    Duration timeout,
  ) async {
    try {
      await _firestore
          .collection('inventory_reservations')
          .doc(reservationId)
          .set({
        'userId': userId,
        'items': reservedItems
            .map((item) => {
                  'productId': item.cartItem.product.id,
                  'quantity': item.cartItem.quantity,
                  'selectedVariants': item.cartItem.selectedVariants,
                  'price': item.cartItem.totalPrice,
                  'name': item.cartItem.product.name,
                  'imageUrl': item.cartItem.product.images.isNotEmpty
                      ? item.cartItem.product.images.first
                      : '',
                  'reservedAt': Timestamp.fromDate(item.reservedAt),
                  'expiresAt': Timestamp.fromDate(item.expiresAt),
                })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'type': 'checkout',
      });
    } catch (e) {
      debugPrint('Error creating reservation document: $e');
    }
  }

  /// Set up auto-release timer for reservation
  static void _setupAutoReleaseTimer(String reservationId, Duration timeout) {
    _reservationTimers[reservationId]?.cancel();

    _reservationTimers[reservationId] = Timer(timeout, () async {
      await releaseReservation(reservationId);
    });
  }

  /// Release inventory reservation
  static Future<bool> releaseReservation(String reservationId) async {
    try {
      // Cancel auto-release timer
      _reservationTimers[reservationId]?.cancel();
      _reservationTimers.remove(reservationId);

      // Get reservation document
      final reservationDoc = await _firestore
          .collection('inventory_reservations')
          .doc(reservationId)
          .get();

      if (!reservationDoc.exists) {
        return false;
      }

      final reservationData = reservationDoc.data()!;
      final items =
          List<Map<String, dynamic>>.from(reservationData['items'] ?? []);

      // Release inventory in transaction
      await _firestore.runTransaction((transaction) async {
        for (final itemData in items) {
          final productId = itemData['productId'] as String;
          final quantity = itemData['quantity'] as int;
          final selectedVariants =
              itemData['selectedVariants'] as Map<String, String>?;

          final productRef = _firestore.collection('products').doc(productId);
          final productSnap = await transaction.get(productRef);

          if (productSnap.exists) {
            final product = ProductModel.fromFirestore(productSnap);

            if (selectedVariants != null && selectedVariants.isNotEmpty) {
              // Release variant inventory
              final updatedVariants = _releaseVariantInventory(
                product.variants,
                selectedVariants,
                quantity,
              );

              transaction.update(productRef, {
                'variants': updatedVariants.map((v) => v.toMap()).toList(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } else {
              // Release simple product inventory
              transaction.update(productRef, {
                'stock': product.stock + quantity,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      });

      // Mark reservation as released
      await _firestore
          .collection('inventory_reservations')
          .doc(reservationId)
          .update({
        'status': 'released',
        'releasedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error releasing reservation: $e');
      return false;
    }
  }

  /// Release variant inventory
  static List<ProductVariant> _releaseVariantInventory(
    List<ProductVariant> variants,
    Map<String, String> selectedVariants,
    int quantity,
  ) {
    return variants.map((variant) {
      final selectedOption = selectedVariants[variant.name];
      if (selectedOption != null && variant.trackInventory) {
        final currentStock = variant.getStockForOption(selectedOption);
        final newStock = currentStock + quantity;

        final updatedStockByOption =
            Map<String, int>.from(variant.stockByOption);
        updatedStockByOption[selectedOption] = newStock;

        return ProductVariant(
          name: variant.name,
          options: variant.options,
          priceAdjustments: variant.priceAdjustments,
          stockByOption: updatedStockByOption,
          trackInventory: variant.trackInventory,
        );
      }
      return variant;
    }).toList();
  }

  /// Confirm reservation and finalize order
  static Future<bool> confirmReservation(
      String reservationId, String orderId) async {
    try {
      // Cancel auto-release timer
      _reservationTimers[reservationId]?.cancel();
      _reservationTimers.remove(reservationId);

      // Mark reservation as confirmed
      await _firestore
          .collection('inventory_reservations')
          .doc(reservationId)
          .update({
        'status': 'confirmed',
        'orderId': orderId,
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error confirming reservation: $e');
      return false;
    }
  }

  /// Extend reservation timeout
  static Future<bool> extendReservation(
    String reservationId,
    Duration additionalTime,
  ) async {
    try {
      final reservationDoc = await _firestore
          .collection('inventory_reservations')
          .doc(reservationId)
          .get();

      if (!reservationDoc.exists) {
        return false;
      }

      final reservationData = reservationDoc.data()!;
      final currentExpiresAt =
          (reservationData['expiresAt'] as Timestamp).toDate();
      final newExpiresAt = currentExpiresAt.add(additionalTime);

      // Update reservation expiry
      await _firestore
          .collection('inventory_reservations')
          .doc(reservationId)
          .update({
        'expiresAt': Timestamp.fromDate(newExpiresAt),
        'extendedAt': FieldValue.serverTimestamp(),
      });

      // Update auto-release timer
      final timeUntilExpiry = newExpiresAt.difference(DateTime.now());
      _setupAutoReleaseTimer(reservationId, timeUntilExpiry);

      return true;
    } catch (e) {
      debugPrint('Error extending reservation: $e');
      return false;
    }
  }

  /// Get reservation status
  static Future<ReservationStatus?> getReservationStatus(
      String reservationId) async {
    try {
      final reservationDoc = await _firestore
          .collection('inventory_reservations')
          .doc(reservationId)
          .get();

      if (!reservationDoc.exists) {
        return null;
      }

      final data = reservationDoc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final status = data['status'] as String;

      return ReservationStatus(
        reservationId: reservationId,
        status: status,
        expiresAt: expiresAt,
        isExpired: DateTime.now().isAfter(expiresAt),
        timeUntilExpiry: expiresAt.difference(DateTime.now()),
      );
    } catch (e) {
      debugPrint('Error getting reservation status: $e');
      return null;
    }
  }

  /// Clean up expired reservations
  static Future<void> cleanupExpiredReservations() async {
    try {
      final now = DateTime.now();
      final expiredReservations = await _firestore
          .collection('inventory_reservations')
          .where('status', isEqualTo: 'active')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .get();

      for (final doc in expiredReservations.docs) {
        await releaseReservation(doc.id);
      }
    } catch (e) {
      debugPrint('Error cleaning up expired reservations: $e');
    }
  }

  /// Get user's active reservations
  static Future<List<ReservationStatus>> getUserActiveReservations(
      String userId) async {
    try {
      final reservations = await _firestore
          .collection('inventory_reservations')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      return reservations.docs.map((doc) {
        final data = doc.data();
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();

        return ReservationStatus(
          reservationId: doc.id,
          status: data['status'] as String,
          expiresAt: expiresAt,
          isExpired: DateTime.now().isAfter(expiresAt),
          timeUntilExpiry: expiresAt.difference(DateTime.now()),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting user active reservations: $e');
      return [];
    }
  }
}

/// Checkout reservation result
class CheckoutReservationResult {
  final bool success;
  final String? reservationId;
  final List<ReservedCartItem> reservedItems;
  final List<CartItem> failedItems;
  final DateTime? expiresAt;
  final String? error;

  CheckoutReservationResult({
    required this.success,
    this.reservationId,
    required this.reservedItems,
    required this.failedItems,
    this.expiresAt,
    this.error,
  });

  bool get hasFailedItems => failedItems.isNotEmpty;

  Duration? get timeUntilExpiry => expiresAt?.difference(DateTime.now());
}

/// Validation result for cart items
class ValidationResult {
  final bool success;
  final List<CartItem> failedItems;
  final String? error;

  ValidationResult({
    required this.success,
    required this.failedItems,
    this.error,
  });
}

/// Reservation result for internal use
class ReservationResult {
  final bool success;
  final List<ReservedCartItem> reservedItems;
  final List<CartItem> failedItems;
  final String? error;

  ReservationResult({
    required this.success,
    required this.reservedItems,
    required this.failedItems,
    this.error,
  });
}

/// Reserved cart item
class ReservedCartItem {
  final CartItem cartItem;
  final String reservationId;
  final DateTime reservedAt;
  final DateTime expiresAt;

  ReservedCartItem({
    required this.cartItem,
    required this.reservationId,
    required this.reservedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());
}

/// Reservation status
class ReservationStatus {
  final String reservationId;
  final String status;
  final DateTime expiresAt;
  final bool isExpired;
  final Duration timeUntilExpiry;

  ReservationStatus({
    required this.reservationId,
    required this.status,
    required this.expiresAt,
    required this.isExpired,
    required this.timeUntilExpiry,
  });

  bool get isActive => status == 'active' && !isExpired;
  bool get isConfirmed => status == 'confirmed';
  bool get isReleased => status == 'released';
}

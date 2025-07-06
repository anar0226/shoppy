import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../features/products/models/product_model.dart';

class InventoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Reserve inventory for a purchase (atomic transaction)
  /// Returns true if successful, false if insufficient stock
  static Future<bool> reserveInventory({
    required String productId,
    required int quantity,
    Map<String, String>? selectedVariants,
  }) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final productRef = _firestore.collection('products').doc(productId);
        final productSnap = await transaction.get(productRef);

        if (!productSnap.exists) {
          throw Exception('Product not found');
        }

        final product = ProductModel.fromFirestore(productSnap);

        // Check if product is active
        if (!product.isActive) {
          throw Exception('Product is not active');
        }

        if (selectedVariants != null && selectedVariants.isNotEmpty) {
          // Handle variant-based inventory
          return await _reserveVariantInventory(
            transaction,
            productRef,
            product,
            quantity,
            selectedVariants,
          );
        } else {
          // Handle simple product inventory
          return await _reserveSimpleInventory(
            transaction,
            productRef,
            product,
            quantity,
          );
        }
      });
    } catch (e) {
      debugPrint('Error reserving inventory: $e');
      return false;
    }
  }

  /// Reserve inventory for simple products (no variants)
  static Future<bool> _reserveSimpleInventory(
    Transaction transaction,
    DocumentReference productRef,
    ProductModel product,
    int quantity,
  ) async {
    if (product.stock < quantity) {
      debugPrint('Insufficient stock: ${product.stock} < $quantity');
      return false;
    }

    // Update stock
    transaction.update(productRef, {
      'stock': product.stock - quantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  /// Reserve inventory for variant products
  static Future<bool> _reserveVariantInventory(
    Transaction transaction,
    DocumentReference productRef,
    ProductModel product,
    int quantity,
    Map<String, String> selectedVariants,
  ) async {
    // Create updated variants list
    final updatedVariants = <Map<String, dynamic>>[];
    bool hasStock = true;

    for (final variant in product.variants) {
      final selectedOption = selectedVariants[variant.name];
      final variantMap = variant.toMap();

      if (selectedOption != null && variant.trackInventory) {
        final currentStock = variant.getStockForOption(selectedOption);

        if (currentStock < quantity) {
          debugPrint(
              'Insufficient variant stock: $currentStock < $quantity for ${variant.name}:$selectedOption');
          hasStock = false;
          break;
        }

        // Update stock for this variant option
        final updatedStockByOption =
            Map<String, int>.from(variant.stockByOption);
        updatedStockByOption[selectedOption] = currentStock - quantity;
        variantMap['stockByOption'] = updatedStockByOption;
      }

      updatedVariants.add(variantMap);
    }

    if (!hasStock) return false;

    // Update product with new variant stock levels
    transaction.update(productRef, {
      'variants': updatedVariants,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  /// Release reserved inventory (e.g., when order is cancelled)
  static Future<bool> releaseInventory({
    required String productId,
    required int quantity,
    Map<String, String>? selectedVariants,
  }) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final productRef = _firestore.collection('products').doc(productId);
        final productSnap = await transaction.get(productRef);

        if (!productSnap.exists) {
          throw Exception('Product not found');
        }

        final product = ProductModel.fromFirestore(productSnap);

        if (selectedVariants != null && selectedVariants.isNotEmpty) {
          // Handle variant-based inventory release
          return await _releaseVariantInventory(
            transaction,
            productRef,
            product,
            quantity,
            selectedVariants,
          );
        } else {
          // Handle simple product inventory release
          return await _releaseSimpleInventory(
            transaction,
            productRef,
            product,
            quantity,
          );
        }
      });
    } catch (e) {
      debugPrint('Error releasing inventory: $e');
      return false;
    }
  }

  /// Release inventory for simple products
  static Future<bool> _releaseSimpleInventory(
    Transaction transaction,
    DocumentReference productRef,
    ProductModel product,
    int quantity,
  ) async {
    transaction.update(productRef, {
      'stock': product.stock + quantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  /// Release inventory for variant products
  static Future<bool> _releaseVariantInventory(
    Transaction transaction,
    DocumentReference productRef,
    ProductModel product,
    int quantity,
    Map<String, String> selectedVariants,
  ) async {
    final updatedVariants = <Map<String, dynamic>>[];

    for (final variant in product.variants) {
      final selectedOption = selectedVariants[variant.name];
      final variantMap = variant.toMap();

      if (selectedOption != null && variant.trackInventory) {
        final currentStock = variant.getStockForOption(selectedOption);

        // Restore stock for this variant option
        final updatedStockByOption =
            Map<String, int>.from(variant.stockByOption);
        updatedStockByOption[selectedOption] = currentStock + quantity;
        variantMap['stockByOption'] = updatedStockByOption;
      }

      updatedVariants.add(variantMap);
    }

    transaction.update(productRef, {
      'variants': updatedVariants,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  /// Check real-time stock availability
  static Future<bool> checkStockAvailability({
    required String productId,
    required int quantity,
    Map<String, String>? selectedVariants,
  }) async {
    try {
      final productDoc =
          await _firestore.collection('products').doc(productId).get();

      if (!productDoc.exists) return false;

      final product = ProductModel.fromFirestore(productDoc);

      if (!product.isActive) return false;

      if (selectedVariants != null && selectedVariants.isNotEmpty) {
        return product.isVariantInStock(selectedVariants);
      } else {
        return product.stock >= quantity;
      }
    } catch (e) {
      debugPrint('Error checking stock availability: $e');
      return false;
    }
  }

  /// Get current stock levels for a product
  static Future<Map<String, dynamic>?> getStockLevels(String productId) async {
    try {
      final productDoc =
          await _firestore.collection('products').doc(productId).get();

      if (!productDoc.exists) return null;

      final product = ProductModel.fromFirestore(productDoc);

      final result = <String, dynamic>{
        'productId': productId,
        'isActive': product.isActive,
        'simpleStock': product.stock,
        'hasVariants': product.variants.isNotEmpty,
        'totalAvailableStock': product.totalAvailableStock,
        'hasStock': product.hasStock,
      };

      if (product.variants.isNotEmpty) {
        final variantStocks = <String, dynamic>{};
        for (final variant in product.variants) {
          variantStocks[variant.name] = {
            'trackInventory': variant.trackInventory,
            'stockByOption': variant.stockByOption,
            'totalStock': variant.totalStock,
            'hasStock': variant.hasStock,
          };
        }
        result['variantStocks'] = variantStocks;
      }

      return result;
    } catch (e) {
      debugPrint('Error getting stock levels: $e');
      return null;
    }
  }

  /// Bulk check stock for multiple products (for cart validation)
  static Future<Map<String, bool>> bulkCheckStock(
    List<Map<String, dynamic>> items,
  ) async {
    final results = <String, bool>{};

    try {
      final batch = _firestore.batch();
      final futures = <Future<DocumentSnapshot>>[];

      // Fetch all products in parallel
      for (final item in items) {
        final productId = item['productId'] as String;
        futures.add(_firestore.collection('products').doc(productId).get());
      }

      final snapshots = await Future.wait(futures);

      // Check stock for each item
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final productId = item['productId'] as String;
        final quantity = item['quantity'] as int;
        final selectedVariants =
            item['selectedVariants'] as Map<String, String>?;

        if (i < snapshots.length && snapshots[i].exists) {
          final product = ProductModel.fromFirestore(snapshots[i]);

          if (!product.isActive) {
            results[productId] = false;
            continue;
          }

          if (selectedVariants != null && selectedVariants.isNotEmpty) {
            results[productId] = product.isVariantInStock(selectedVariants);
          } else {
            results[productId] = product.stock >= quantity;
          }
        } else {
          results[productId] = false;
        }
      }
    } catch (e) {
      debugPrint('Error in bulk stock check: $e');
      // Mark all as unavailable on error
      for (final item in items) {
        results[item['productId'] as String] = false;
      }
    }

    return results;
  }

  /// Low stock alert threshold check
  static Future<List<String>> getProductsWithLowStock({
    String? storeId,
    int threshold = 5,
  }) async {
    try {
      Query query =
          _firestore.collection('products').where('isActive', isEqualTo: true);

      if (storeId != null) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      final snapshot = await query.get();
      final lowStockProducts = <String>[];

      for (final doc in snapshot.docs) {
        final product = ProductModel.fromFirestore(doc);

        if (product.totalAvailableStock <= threshold) {
          lowStockProducts.add(product.id);
        }
      }

      return lowStockProducts;
    } catch (e) {
      debugPrint('Error getting low stock products: $e');
      return [];
    }
  }
}

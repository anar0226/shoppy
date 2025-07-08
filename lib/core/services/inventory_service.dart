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

  // ==================== NEW ENTERPRISE FEATURES ====================

  /// Manual inventory adjustment with audit trail
  static Future<bool> adjustInventory({
    required String productId,
    required int adjustment,
    required String reason,
    required String userId,
    Map<String, String>? selectedVariants,
    String? notes,
  }) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final productRef = _firestore.collection('products').doc(productId);
        final productSnap = await transaction.get(productRef);

        if (!productSnap.exists) {
          throw Exception('Product not found');
        }

        final product = ProductModel.fromFirestore(productSnap);

        // Create audit log entry
        final auditRef = _firestore.collection('inventory_audit_log').doc();
        final auditData = {
          'productId': productId,
          'productName': product.name,
          'storeId': product.storeId,
          'adjustment': adjustment,
          'reason': reason,
          'userId': userId,
          'notes': notes,
          'selectedVariants': selectedVariants,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'manual_adjustment',
        };

        if (selectedVariants != null && selectedVariants.isNotEmpty) {
          // Handle variant adjustment
          final updatedVariants = <Map<String, dynamic>>[];

          for (final variant in product.variants) {
            final selectedOption = selectedVariants[variant.name];
            final variantMap = variant.toMap();

            if (selectedOption != null && variant.trackInventory) {
              final currentStock = variant.getStockForOption(selectedOption);
              final newStock = (currentStock + adjustment).clamp(0, 999999);

              final updatedStockByOption =
                  Map<String, int>.from(variant.stockByOption);
              updatedStockByOption[selectedOption] = newStock;
              variantMap['stockByOption'] = updatedStockByOption;

              // Add variant info to audit log
              auditData['previousStock'] = currentStock;
              auditData['newStock'] = newStock;
              auditData['variantName'] = variant.name;
              auditData['variantOption'] = selectedOption;
            }

            updatedVariants.add(variantMap);
          }

          transaction.update(productRef, {
            'variants': updatedVariants,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Handle simple product adjustment
          final previousStock = product.stock;
          final newStock = (previousStock + adjustment).clamp(0, 999999);

          auditData['previousStock'] = previousStock;
          auditData['newStock'] = newStock;

          transaction.update(productRef, {
            'stock': newStock,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Create audit log entry
        transaction.set(auditRef, auditData);

        return true;
      });
    } catch (e) {
      debugPrint('Error adjusting inventory: $e');
      return false;
    }
  }

  /// Get inventory audit trail for a product
  static Future<List<Map<String, dynamic>>> getInventoryAuditTrail({
    required String productId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('inventory_audit_log')
          .where('productId', isEqualTo: productId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting audit trail: $e');
      return [];
    }
  }

  /// Automated low stock notifications
  static Future<void> checkAndSendLowStockNotifications() async {
    try {
      final stores = await _firestore.collection('stores').get();

      for (final storeDoc in stores.docs) {
        final storeId = storeDoc.id;
        final storeData = storeDoc.data();
        final lowStockThreshold = storeData['lowStockThreshold'] ?? 5;

        final lowStockProducts = await getProductsWithLowStock(
          storeId: storeId,
          threshold: lowStockThreshold,
        );

        if (lowStockProducts.isNotEmpty) {
          // Create notification for store owner
          await _firestore.collection('notifications').add({
            'storeId': storeId,
            'ownerId': storeData['ownerId'],
            'type': 'low_stock_alert',
            'title': 'Low Stock Alert',
            'message':
                '${lowStockProducts.length} products are running low on stock',
            'data': {
              'productIds': lowStockProducts,
              'threshold': lowStockThreshold,
            },
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking low stock notifications: $e');
    }
  }

  /// Bulk inventory update from CSV/Excel data
  static Future<Map<String, dynamic>> bulkInventoryUpdate({
    required String storeId,
    required List<Map<String, dynamic>> updates,
    required String userId,
    String reason = 'Bulk inventory update',
  }) async {
    int successCount = 0;
    int errorCount = 0;
    final errors = <String>[];

    try {
      final batch = _firestore.batch();
      final auditEntries = <Map<String, dynamic>>[];

      for (final update in updates) {
        try {
          final productId = update['productId'] as String?;
          final sku = update['sku'] as String?;
          final newStock = update['stock'] as int?;

          if (productId == null && sku == null) {
            errors.add('Missing product ID or SKU');
            errorCount++;
            continue;
          }

          if (newStock == null || newStock < 0) {
            errors.add('Invalid stock value for ${productId ?? sku}');
            errorCount++;
            continue;
          }

          // Find product by ID or SKU
          Query query = _firestore
              .collection('products')
              .where('storeId', isEqualTo: storeId);

          if (productId != null) {
            query = query.where(FieldPath.documentId, isEqualTo: productId);
          } else {
            query = query.where('sku', isEqualTo: sku);
          }

          final productSnapshot = await query.limit(1).get();

          if (productSnapshot.docs.isEmpty) {
            errors.add('Product not found: ${productId ?? sku}');
            errorCount++;
            continue;
          }

          final productDoc = productSnapshot.docs.first;
          final productData = productDoc.data() as Map<String, dynamic>;
          final currentStock = productData['stock'] ?? 0;

          // Update product stock
          batch.update(productDoc.reference, {
            'stock': newStock,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Create audit entry
          auditEntries.add({
            'productId': productDoc.id,
            'productName': (productData['name'] as String?) ?? 'Unknown',
            'storeId': storeId,
            'adjustment': newStock - currentStock,
            'reason': reason,
            'userId': userId,
            'notes': 'Bulk update',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'bulk_update',
            'previousStock': currentStock,
            'newStock': newStock,
          });

          successCount++;
        } catch (e) {
          errors.add(
              'Error updating ${update['productId'] ?? update['sku']}: $e');
          errorCount++;
        }
      }

      // Commit batch update
      await batch.commit();

      // Create audit log entries
      for (final auditEntry in auditEntries) {
        await _firestore.collection('inventory_audit_log').add(auditEntry);
      }

      return {
        'success': true,
        'successCount': successCount,
        'errorCount': errorCount,
        'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'successCount': successCount,
        'errorCount': errorCount,
        'errors': errors,
      };
    }
  }

  /// Inventory valuation report
  static Future<Map<String, dynamic>> getInventoryValuation({
    required String storeId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('storeId', isEqualTo: storeId)
          .where('isActive', isEqualTo: true)
          .get();

      double totalValue = 0;
      int totalProducts = 0;
      int totalStock = 0;
      int lowStockCount = 0;
      int outOfStockCount = 0;
      final categoryBreakdown = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final product = ProductModel.fromFirestore(doc);
        final price = product.price;
        final stock = product.totalAvailableStock;
        final category = product.category ?? 'Uncategorized';

        totalProducts++;
        totalStock += stock;
        totalValue += price * stock;

        if (stock == 0) {
          outOfStockCount++;
        } else if (stock <= 5) {
          lowStockCount++;
        }

        // Category breakdown
        final categoryData = categoryBreakdown[category] ??
            {
              'productCount': 0,
              'totalStock': 0,
              'totalValue': 0.0,
            };

        categoryBreakdown[category] = {
          'productCount': (categoryData['productCount'] as int) + 1,
          'totalStock': (categoryData['totalStock'] as int) + stock,
          'totalValue':
              (categoryData['totalValue'] as double) + (price * stock),
        };
      }

      return {
        'storeId': storeId,
        'totalValue': totalValue,
        'totalProducts': totalProducts,
        'totalStock': totalStock,
        'lowStockCount': lowStockCount,
        'outOfStockCount': outOfStockCount,
        'averageValuePerProduct':
            totalProducts > 0 ? totalValue / totalProducts : 0,
        'categoryBreakdown': categoryBreakdown,
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error generating inventory valuation: $e');
      return {
        'error': e.toString(),
        'generatedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Set up automated reorder alerts
  static Future<bool> setupReorderAlert({
    required String productId,
    required int reorderPoint,
    required int reorderQuantity,
    required String userId,
  }) async {
    try {
      await _firestore.collection('reorder_alerts').doc(productId).set({
        'productId': productId,
        'reorderPoint': reorderPoint,
        'reorderQuantity': reorderQuantity,
        'isActive': true,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error setting up reorder alert: $e');
      return false;
    }
  }

  /// Check for products that need reordering
  static Future<List<Map<String, dynamic>>> getProductsNeedingReorder({
    String? storeId,
  }) async {
    try {
      final reorderAlertsSnapshot = await _firestore
          .collection('reorder_alerts')
          .where('isActive', isEqualTo: true)
          .get();

      final productsNeedingReorder = <Map<String, dynamic>>[];

      for (final alertDoc in reorderAlertsSnapshot.docs) {
        final alertData = alertDoc.data();
        final productId = alertData['productId'];
        final reorderPoint = alertData['reorderPoint'];

        final productDoc =
            await _firestore.collection('products').doc(productId).get();

        if (productDoc.exists) {
          final product = ProductModel.fromFirestore(productDoc);

          if (storeId != null && product.storeId != storeId) continue;

          if (product.totalAvailableStock <= reorderPoint) {
            productsNeedingReorder.add({
              'productId': productId,
              'productName': product.name,
              'currentStock': product.totalAvailableStock,
              'reorderPoint': reorderPoint,
              'reorderQuantity': alertData['reorderQuantity'],
              'storeId': product.storeId,
            });
          }
        }
      }

      return productsNeedingReorder;
    } catch (e) {
      debugPrint('Error getting products needing reorder: $e');
      return [];
    }
  }

  /// Generate inventory movement report
  static Future<Map<String, dynamic>> getInventoryMovementReport({
    required String storeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final snapshot = await _firestore
          .collection('inventory_audit_log')
          .where('storeId', isEqualTo: storeId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('timestamp', descending: true)
          .get();

      final movements = <Map<String, dynamic>>[];
      int totalAdjustments = 0;
      int positiveAdjustments = 0;
      int negativeAdjustments = 0;
      final reasonBreakdown = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        movements.add({
          'id': doc.id,
          ...data,
        });

        final adjustment = data['adjustment'] ?? 0;
        totalAdjustments++;

        if (adjustment > 0) {
          positiveAdjustments++;
        } else if (adjustment < 0) {
          negativeAdjustments++;
        }

        final reason = (data['reason'] as String?) ?? 'Unknown';
        reasonBreakdown[reason] = (reasonBreakdown[reason] ?? 0) + 1;
      }

      return {
        'storeId': storeId,
        'startDate': start.toIso8601String(),
        'endDate': end.toIso8601String(),
        'totalMovements': movements.length,
        'totalAdjustments': totalAdjustments,
        'positiveAdjustments': positiveAdjustments,
        'negativeAdjustments': negativeAdjustments,
        'reasonBreakdown': reasonBreakdown,
        'movements': movements,
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error generating movement report: $e');
      return {
        'error': e.toString(),
        'generatedAt': DateTime.now().toIso8601String(),
      };
    }
  }
}

import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../../../core/services/inventory_service.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  AnimationController? _shakeController; // reference for cart button shake

  List<CartItem> get items => List.unmodifiable(_items);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.totalPrice);

  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  void setShakeController(AnimationController? controller) {
    _shakeController = controller;
  }

  /// Add item to cart with stock validation
  Future<bool> addItem(CartItem newItem) async {
    // Check stock availability before adding
    final hasStock = await InventoryService.checkStockAvailability(
      productId: newItem.product.id,
      quantity: newItem.quantity,
      selectedVariants: newItem.selectedVariants,
    );

    if (!hasStock) {
      return false; // Stock not available
    }

    final existing = _items.indexWhere((i) =>
        i.product.id == newItem.product.id &&
        _variantsMatch(i.selectedVariants, newItem.selectedVariants));

    if (existing >= 0) {
      // Check if combined quantity would exceed stock
      final totalQuantity = _items[existing].quantity + newItem.quantity;
      final canAddMore = await InventoryService.checkStockAvailability(
        productId: newItem.product.id,
        quantity: totalQuantity,
        selectedVariants: newItem.selectedVariants,
      );

      if (!canAddMore) {
        return false; // Would exceed available stock
      }

      _items[existing].quantity = totalQuantity;
    } else {
      _items.add(newItem);
    }

    try {
      _shakeController?.forward(from: 0);
    } catch (_) {
      // controller might be disposed; ignore animation
    }
    notifyListeners();
    return true;
  }

  /// Check if two variant maps are the same
  bool _variantsMatch(
      Map<String, String>? variants1, Map<String, String>? variants2) {
    if (variants1 == null && variants2 == null) return true;
    if (variants1 == null || variants2 == null) return false;
    if (variants1.length != variants2.length) return false;

    for (final entry in variants1.entries) {
      if (variants2[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Change quantity with stock validation
  Future<bool> changeQuantity(String productId, int delta,
      {Map<String, String>? selectedVariants}) async {
    final idx = _items.indexWhere((i) =>
        i.product.id == productId &&
        _variantsMatch(i.selectedVariants, selectedVariants));

    if (idx >= 0) {
      final newQuantity = (_items[idx].quantity + delta).clamp(1, 999);

      // Check stock availability for new quantity
      final hasStock = await InventoryService.checkStockAvailability(
        productId: productId,
        quantity: newQuantity,
        selectedVariants: selectedVariants,
      );

      if (!hasStock) {
        return false; // Not enough stock
      }

      _items[idx].quantity = newQuantity;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Validate entire cart against current stock levels
  Future<Map<String, String>> validateCart() async {
    final errors = <String, String>{};

    if (_items.isEmpty) return errors;

    // Prepare items for bulk stock check
    final itemsToCheck = _items
        .map((item) => {
              'productId': item.product.id,
              'quantity': item.quantity,
              'selectedVariants': item.selectedVariants,
            })
        .toList();

    final stockResults = await InventoryService.bulkCheckStock(itemsToCheck);

    // Check results and build error messages
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final hasStock = stockResults[item.product.id] ?? false;

      if (!hasStock) {
        String variantInfo = '';
        if (item.selectedVariants != null &&
            item.selectedVariants!.isNotEmpty) {
          variantInfo = ' (${item.selectedVariants!.values.join(', ')})';
        }
        errors[item.product.id] =
            '${item.product.name}$variantInfo нь хангалттай нөөцгүй байна';
      }
    }

    return errors;
  }

  /// Remove items that are out of stock
  void removeOutOfStockItems(Set<String> outOfStockProductIds) {
    _items
        .removeWhere((item) => outOfStockProductIds.contains(item.product.id));
    notifyListeners();
  }

  /// Get items grouped by store for checkout
  Map<String, List<CartItem>> getItemsByStore() {
    final itemsByStore = <String, List<CartItem>>{};

    for (final item in _items) {
      final storeId = item.product.storeId;
      itemsByStore.putIfAbsent(storeId, () => []).add(item);
    }

    return itemsByStore;
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  AnimationController? _shakeController; // reference for cart button shake

  List<CartItem> get items => List.unmodifiable(_items);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.totalPrice);

  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  void setShakeController(AnimationController? controller) {
    _shakeController = controller;
  }

  void addItem(CartItem newItem) {
    final existing =
        _items.indexWhere((i) => i.product.id == newItem.product.id);
    if (existing >= 0) {
      _items[existing].quantity += newItem.quantity;
    } else {
      _items.add(newItem);
    }
    try {
      _shakeController?.forward(from: 0);
    } catch (_) {
      // controller might be disposed; ignore animation
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void changeQuantity(String productId, int delta) {
    final idx = _items.indexWhere((i) => i.product.id == productId);
    if (idx >= 0) {
      _items[idx].quantity = (_items[idx].quantity + delta).clamp(1, 999);
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

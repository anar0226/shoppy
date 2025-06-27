import 'package:flutter/material.dart';
import 'package:avii/features/products/models/product_model.dart';

class RecentlyViewedProvider extends ChangeNotifier {
  final List<ProductModel> _items = [];
  int maxItems;

  RecentlyViewedProvider({this.maxItems = 20});

  List<ProductModel> get items => List.unmodifiable(_items);

  void add(ProductModel product) {
    _items.removeWhere((p) => p.id == product.id);
    _items.insert(0, product);
    if (_items.length > maxItems) {
      _items.removeLast();
    }
    notifyListeners();
  }
}

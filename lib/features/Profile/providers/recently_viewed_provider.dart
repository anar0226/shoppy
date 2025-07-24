import 'package:flutter/material.dart';
import 'package:avii/features/products/models/product_model.dart';

class RecentlyViewedProvider extends ChangeNotifier {
  final List<ProductModel> _items = [];
  int maxItems;

  RecentlyViewedProvider({this.maxItems = 20});

  List<ProductModel> get items => List.unmodifiable(_items);

  void add(ProductModel product) {
    // Create a new list to avoid concurrent modification
    final newItems = List<ProductModel>.from(_items);

    // Remove existing product if it exists
    newItems.removeWhere((p) => p.id == product.id);

    // Add new product at the beginning
    newItems.insert(0, product);

    // Remove excess items if needed
    if (newItems.length > maxItems) {
      newItems.removeRange(maxItems, newItems.length);
    }

    // Update the list atomically
    _items.clear();
    _items.addAll(newItems);

    notifyListeners();
  }
}

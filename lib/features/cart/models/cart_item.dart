import 'package:avii/features/products/models/product_model.dart';

class CartItem {
  final ProductModel product;
  final String? variant; // NEW
  int quantity;

  CartItem({
    required this.product,
    this.variant,
    this.quantity = 1,
  });

  double get totalPrice => product.price * quantity;
}

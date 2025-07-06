import 'package:avii/features/products/models/product_model.dart';

class CartItem {
  final ProductModel product;
  final Map<String, String>? selectedVariants; // Selected variant options
  int quantity;

  CartItem({
    required this.product,
    this.selectedVariants,
    this.quantity = 1,
  });

  double get totalPrice {
    double basePrice = product.price;

    // Apply variant price adjustments if any
    if (selectedVariants != null && selectedVariants!.isNotEmpty) {
      for (final variant in product.variants) {
        final selectedOption = selectedVariants![variant.name];
        if (selectedOption != null) {
          final adjustment = variant.priceAdjustments[selectedOption] ?? 0.0;
          basePrice += adjustment;
        }
      }
    }

    return basePrice * quantity;
  }

  /// Get display text for selected variants
  String get variantDisplayText {
    if (selectedVariants == null || selectedVariants!.isEmpty) {
      return '';
    }
    return selectedVariants!.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
  }
}

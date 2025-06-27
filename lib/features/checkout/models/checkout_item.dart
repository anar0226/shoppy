class CheckoutItem {
  final String imageUrl;
  final String name;
  final String variant;
  final double price;
  final String? storeId;
  final String? category;

  CheckoutItem({
    required this.imageUrl,
    required this.name,
    required this.variant,
    required this.price,
    this.storeId,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'name': name,
      'variant': variant,
      'price': price,
      'storeId': storeId,
      'category': category,
    };
  }

  factory CheckoutItem.fromMap(Map<String, dynamic> map) {
    return CheckoutItem(
      imageUrl: map['imageUrl'] ?? '',
      name: map['name'] ?? '',
      variant: map['variant'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      storeId: map['storeId'],
      category: map['category'],
    );
  }
}

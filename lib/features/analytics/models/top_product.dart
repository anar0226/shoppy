class TopProduct {
  final String id;
  final String name;
  final String imageUrl;
  final int unitsSold;
  final double revenue;
  final double price;
  final String category;
  final int rank;
  final double conversionRate;

  TopProduct({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.unitsSold = 0,
    this.revenue = 0.0,
    this.price = 0.0,
    this.category = '',
    this.rank = 0,
    this.conversionRate = 0.0,
  });

  factory TopProduct.fromMap(Map<String, dynamic> map, {int rank = 0}) {
    // Safe image URL extraction
    String imageUrl = map['imageUrl'] ?? '';
    if (imageUrl.isEmpty && map['images'] != null) {
      final images = map['images'];
      if (images is List && images.isNotEmpty) {
        imageUrl = images[0]?.toString() ?? '';
      }
    }

    return TopProduct(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      imageUrl: imageUrl,
      unitsSold: map['unitsSold'] ?? 0,
      revenue: (map['revenue'] ?? 0).toDouble(),
      price: (map['price'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      rank: rank,
      conversionRate: (map['conversionRate'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'unitsSold': unitsSold,
      'revenue': revenue,
      'price': price,
      'category': category,
      'rank': rank,
      'conversionRate': conversionRate,
    };
  }

  // Helper methods for UI display
  String get formattedRevenue => '₮${revenue.toStringAsFixed(2)}';
  String get formattedPrice => '₮${price.toStringAsFixed(2)}';
  String get unitsSoldText => '$unitsSold sold';
  String get conversionRateText => '${conversionRate.toStringAsFixed(1)}%';

  // Calculate relative performance for progress bars
  double getRelativePerformance(int maxUnitsSold) {
    if (maxUnitsSold == 0) return 0.0;
    return unitsSold / maxUnitsSold;
  }

  double getRelativeRevenue(double maxRevenue) {
    if (maxRevenue == 0) return 0.0;
    return revenue / maxRevenue;
  }
}

class CategoryPerformance {
  final String category;
  final int productCount;
  final int totalUnitsSold;
  final double totalRevenue;
  final double averagePrice;
  final double conversionRate;

  CategoryPerformance({
    required this.category,
    this.productCount = 0,
    this.totalUnitsSold = 0,
    this.totalRevenue = 0.0,
    this.averagePrice = 0.0,
    this.conversionRate = 0.0,
  });

  factory CategoryPerformance.fromMap(Map<String, dynamic> map) {
    return CategoryPerformance(
      category: map['category'] ?? '',
      productCount: map['productCount'] ?? 0,
      totalUnitsSold: map['totalUnitsSold'] ?? 0,
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      averagePrice: (map['averagePrice'] ?? 0).toDouble(),
      conversionRate: (map['conversionRate'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'productCount': productCount,
      'totalUnitsSold': totalUnitsSold,
      'totalRevenue': totalRevenue,
      'averagePrice': averagePrice,
      'conversionRate': conversionRate,
    };
  }

  String get formattedRevenue => '₮${totalRevenue.toStringAsFixed(2)}';
  String get formattedAveragePrice => '₮${averagePrice.toStringAsFixed(2)}';
  String get conversionRateText => '${conversionRate.toStringAsFixed(1)}%';
}

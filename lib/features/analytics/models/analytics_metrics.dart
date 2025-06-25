class AnalyticsMetrics {
  final double totalRevenue;
  final double previousRevenue;
  final int totalOrders;
  final int previousOrders;
  final int totalCustomers;
  final int previousCustomers;
  final double conversionRate;
  final double previousConversionRate;
  final int totalProducts;
  final int lowStockProducts;
  final double averageOrderValue;
  final double previousAverageOrderValue;

  AnalyticsMetrics({
    this.totalRevenue = 0.0,
    this.previousRevenue = 0.0,
    this.totalOrders = 0,
    this.previousOrders = 0,
    this.totalCustomers = 0,
    this.previousCustomers = 0,
    this.conversionRate = 0.0,
    this.previousConversionRate = 0.0,
    this.totalProducts = 0,
    this.lowStockProducts = 0,
    this.averageOrderValue = 0.0,
    this.previousAverageOrderValue = 0.0,
  });

  // Calculate percentage changes
  double get revenueChange {
    if (previousRevenue == 0) return 0.0;
    return ((totalRevenue - previousRevenue) / previousRevenue) * 100;
  }

  double get ordersChange {
    if (previousOrders == 0) return 0.0;
    return ((totalOrders - previousOrders) / previousOrders) * 100;
  }

  double get customersChange {
    if (previousCustomers == 0) return 0.0;
    return ((totalCustomers - previousCustomers) / previousCustomers) * 100;
  }

  double get conversionRateChange {
    if (previousConversionRate == 0) return 0.0;
    return ((conversionRate - previousConversionRate) /
            previousConversionRate) *
        100;
  }

  double get averageOrderValueChange {
    if (previousAverageOrderValue == 0) return 0.0;
    return ((averageOrderValue - previousAverageOrderValue) /
            previousAverageOrderValue) *
        100;
  }

  // Helper methods for UI
  bool get revenueIncreased => revenueChange > 0;
  bool get ordersIncreased => ordersChange > 0;
  bool get customersIncreased => customersChange > 0;
  bool get conversionRateIncreased => conversionRateChange > 0;
  bool get averageOrderValueIncreased => averageOrderValueChange > 0;

  factory AnalyticsMetrics.fromMap(Map<String, dynamic> map) {
    return AnalyticsMetrics(
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      previousRevenue: (map['previousRevenue'] ?? 0).toDouble(),
      totalOrders: map['totalOrders'] ?? 0,
      previousOrders: map['previousOrders'] ?? 0,
      totalCustomers: map['totalCustomers'] ?? 0,
      previousCustomers: map['previousCustomers'] ?? 0,
      conversionRate: (map['conversionRate'] ?? 0).toDouble(),
      previousConversionRate: (map['previousConversionRate'] ?? 0).toDouble(),
      totalProducts: map['totalProducts'] ?? 0,
      lowStockProducts: map['lowStockProducts'] ?? 0,
      averageOrderValue: (map['averageOrderValue'] ?? 0).toDouble(),
      previousAverageOrderValue:
          (map['previousAverageOrderValue'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalRevenue': totalRevenue,
      'previousRevenue': previousRevenue,
      'totalOrders': totalOrders,
      'previousOrders': previousOrders,
      'totalCustomers': totalCustomers,
      'previousCustomers': previousCustomers,
      'conversionRate': conversionRate,
      'previousConversionRate': previousConversionRate,
      'totalProducts': totalProducts,
      'lowStockProducts': lowStockProducts,
      'averageOrderValue': averageOrderValue,
      'previousAverageOrderValue': previousAverageOrderValue,
    };
  }
}

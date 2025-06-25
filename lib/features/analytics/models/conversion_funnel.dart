class ConversionFunnelStep {
  final String stepName;
  final int count;
  final double percentage;
  final double conversionRate;
  final String description;

  ConversionFunnelStep({
    required this.stepName,
    this.count = 0,
    this.percentage = 0.0,
    this.conversionRate = 0.0,
    this.description = '',
  });

  factory ConversionFunnelStep.fromMap(Map<String, dynamic> map) {
    return ConversionFunnelStep(
      stepName: map['stepName'] ?? '',
      count: map['count'] ?? 0,
      percentage: (map['percentage'] ?? 0).toDouble(),
      conversionRate: (map['conversionRate'] ?? 0).toDouble(),
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stepName': stepName,
      'count': count,
      'percentage': percentage,
      'conversionRate': conversionRate,
      'description': description,
    };
  }

  String get formattedPercentage => '${percentage.toStringAsFixed(1)}%';
  String get formattedConversionRate => '${conversionRate.toStringAsFixed(1)}%';
}

class ConversionFunnel {
  final List<ConversionFunnelStep> steps;
  final DateTime startDate;
  final DateTime endDate;
  final int totalVisitors;
  final double overallConversionRate;

  ConversionFunnel({
    this.steps = const [],
    required this.startDate,
    required this.endDate,
    this.totalVisitors = 0,
    this.overallConversionRate = 0.0,
  });

  factory ConversionFunnel.create({
    required int storeVisitors,
    required int productViews,
    required int cartAdditions,
    required int checkoutStarted,
    required int ordersCompleted,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final steps = <ConversionFunnelStep>[];

    if (storeVisitors > 0) {
      steps.add(ConversionFunnelStep(
        stepName: 'Store Visitors',
        count: storeVisitors,
        percentage: 100.0,
        conversionRate: 100.0,
        description: 'Users who visited your store',
      ));

      steps.add(ConversionFunnelStep(
        stepName: 'Product Views',
        count: productViews,
        percentage: (productViews / storeVisitors) * 100,
        conversionRate: (productViews / storeVisitors) * 100,
        description: 'Visitors who viewed at least one product',
      ));

      steps.add(ConversionFunnelStep(
        stepName: 'Add to Cart',
        count: cartAdditions,
        percentage: (cartAdditions / storeVisitors) * 100,
        conversionRate:
            productViews > 0 ? (cartAdditions / productViews) * 100 : 0,
        description: 'Users who added items to cart',
      ));

      steps.add(ConversionFunnelStep(
        stepName: 'Checkout Started',
        count: checkoutStarted,
        percentage: (checkoutStarted / storeVisitors) * 100,
        conversionRate:
            cartAdditions > 0 ? (checkoutStarted / cartAdditions) * 100 : 0,
        description: 'Users who started the checkout process',
      ));

      steps.add(ConversionFunnelStep(
        stepName: 'Order Completed',
        count: ordersCompleted,
        percentage: (ordersCompleted / storeVisitors) * 100,
        conversionRate:
            checkoutStarted > 0 ? (ordersCompleted / checkoutStarted) * 100 : 0,
        description: 'Users who completed their purchase',
      ));
    }

    return ConversionFunnel(
      steps: steps,
      startDate: startDate,
      endDate: endDate,
      totalVisitors: storeVisitors,
      overallConversionRate:
          storeVisitors > 0 ? (ordersCompleted / storeVisitors) * 100 : 0,
    );
  }

  factory ConversionFunnel.fromMap(Map<String, dynamic> map) {
    return ConversionFunnel(
      steps: (map['steps'] as List?)
              ?.map((step) =>
                  ConversionFunnelStep.fromMap(step as Map<String, dynamic>))
              .toList() ??
          [],
      startDate:
          DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      endDate:
          DateTime.parse(map['endDate'] ?? DateTime.now().toIso8601String()),
      totalVisitors: map['totalVisitors'] ?? 0,
      overallConversionRate: (map['overallConversionRate'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'steps': steps.map((step) => step.toMap()).toList(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalVisitors': totalVisitors,
      'overallConversionRate': overallConversionRate,
    };
  }

  String get formattedOverallConversionRate =>
      '${overallConversionRate.toStringAsFixed(1)}%';

  // Get the biggest drop-off points
  List<MapEntry<String, double>> get dropOffPoints {
    final dropOffs = <MapEntry<String, double>>[];

    for (int i = 1; i < steps.length; i++) {
      final previousStep = steps[i - 1];
      final currentStep = steps[i];

      if (previousStep.count > 0) {
        final dropOffRate =
            ((previousStep.count - currentStep.count) / previousStep.count) *
                100;
        dropOffs.add(MapEntry(
            '${previousStep.stepName} → ${currentStep.stepName}', dropOffRate));
      }
    }

    dropOffs.sort((a, b) => b.value.compareTo(a.value));
    return dropOffs;
  }
}

class TrafficSource {
  final String source;
  final int visitors;
  final double percentage;
  final int conversions;
  final double conversionRate;
  final double revenue;

  TrafficSource({
    required this.source,
    this.visitors = 0,
    this.percentage = 0.0,
    this.conversions = 0,
    this.conversionRate = 0.0,
    this.revenue = 0.0,
  });

  factory TrafficSource.fromMap(Map<String, dynamic> map) {
    return TrafficSource(
      source: map['source'] ?? '',
      visitors: map['visitors'] ?? 0,
      percentage: (map['percentage'] ?? 0).toDouble(),
      conversions: map['conversions'] ?? 0,
      conversionRate: (map['conversionRate'] ?? 0).toDouble(),
      revenue: (map['revenue'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'visitors': visitors,
      'percentage': percentage,
      'conversions': conversions,
      'conversionRate': conversionRate,
      'revenue': revenue,
    };
  }

  String get formattedPercentage => '${percentage.toStringAsFixed(1)}%';
  String get formattedConversionRate => '${conversionRate.toStringAsFixed(1)}%';
  String get formattedRevenue => '\$${revenue.toStringAsFixed(2)}';
}

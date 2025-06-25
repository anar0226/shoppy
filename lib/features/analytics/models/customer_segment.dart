class CustomerSegment {
  final String segment;
  final int customerCount;
  final double percentage;
  final double averageOrderValue;
  final int totalOrders;
  final double totalRevenue;
  final String description;

  CustomerSegment({
    required this.segment,
    this.customerCount = 0,
    this.percentage = 0.0,
    this.averageOrderValue = 0.0,
    this.totalOrders = 0,
    this.totalRevenue = 0.0,
    this.description = '',
  });

  factory CustomerSegment.fromMap(Map<String, dynamic> map) {
    return CustomerSegment(
      segment: map['segment'] ?? '',
      customerCount: map['customerCount'] ?? 0,
      percentage: (map['percentage'] ?? 0).toDouble(),
      averageOrderValue: (map['averageOrderValue'] ?? 0).toDouble(),
      totalOrders: map['totalOrders'] ?? 0,
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'segment': segment,
      'customerCount': customerCount,
      'percentage': percentage,
      'averageOrderValue': averageOrderValue,
      'totalOrders': totalOrders,
      'totalRevenue': totalRevenue,
      'description': description,
    };
  }

  String get formattedPercentage => '${percentage.toStringAsFixed(1)}%';
  String get formattedRevenue => '\$${totalRevenue.toStringAsFixed(2)}';
  String get formattedAverageOrderValue =>
      '\$${averageOrderValue.toStringAsFixed(2)}';
}

enum CustomerSegmentType {
  newCustomers,
  returningCustomers,
  vipCustomers,
  atRiskCustomers,
  lostCustomers
}

class CustomerAnalytics {
  final int totalCustomers;
  final int newCustomers;
  final int returningCustomers;
  final int vipCustomers;
  final int atRiskCustomers;
  final int lostCustomers;
  final double customerRetentionRate;
  final double customerAcquisitionCost;
  final double customerLifetimeValue;

  CustomerAnalytics({
    this.totalCustomers = 0,
    this.newCustomers = 0,
    this.returningCustomers = 0,
    this.vipCustomers = 0,
    this.atRiskCustomers = 0,
    this.lostCustomers = 0,
    this.customerRetentionRate = 0.0,
    this.customerAcquisitionCost = 0.0,
    this.customerLifetimeValue = 0.0,
  });

  List<CustomerSegment> get segments {
    if (totalCustomers == 0) return [];

    return [
      CustomerSegment(
        segment: 'New Customers',
        customerCount: newCustomers,
        percentage: (newCustomers / totalCustomers) * 100,
        description: 'Customers who made their first purchase recently',
      ),
      CustomerSegment(
        segment: 'Returning Customers',
        customerCount: returningCustomers,
        percentage: (returningCustomers / totalCustomers) * 100,
        description: 'Customers who have made multiple purchases',
      ),
      CustomerSegment(
        segment: 'VIP Customers',
        customerCount: vipCustomers,
        percentage: (vipCustomers / totalCustomers) * 100,
        description: 'High-value customers with significant spending',
      ),
      CustomerSegment(
        segment: 'At Risk',
        customerCount: atRiskCustomers,
        percentage: (atRiskCustomers / totalCustomers) * 100,
        description: 'Customers who haven\'t purchased recently',
      ),
      CustomerSegment(
        segment: 'Lost Customers',
        customerCount: lostCustomers,
        percentage: (lostCustomers / totalCustomers) * 100,
        description: 'Customers who haven\'t purchased in a long time',
      ),
    ];
  }

  factory CustomerAnalytics.fromMap(Map<String, dynamic> map) {
    return CustomerAnalytics(
      totalCustomers: map['totalCustomers'] ?? 0,
      newCustomers: map['newCustomers'] ?? 0,
      returningCustomers: map['returningCustomers'] ?? 0,
      vipCustomers: map['vipCustomers'] ?? 0,
      atRiskCustomers: map['atRiskCustomers'] ?? 0,
      lostCustomers: map['lostCustomers'] ?? 0,
      customerRetentionRate: (map['customerRetentionRate'] ?? 0).toDouble(),
      customerAcquisitionCost: (map['customerAcquisitionCost'] ?? 0).toDouble(),
      customerLifetimeValue: (map['customerLifetimeValue'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalCustomers': totalCustomers,
      'newCustomers': newCustomers,
      'returningCustomers': returningCustomers,
      'vipCustomers': vipCustomers,
      'atRiskCustomers': atRiskCustomers,
      'lostCustomers': lostCustomers,
      'customerRetentionRate': customerRetentionRate,
      'customerAcquisitionCost': customerAcquisitionCost,
      'customerLifetimeValue': customerLifetimeValue,
    };
  }
}

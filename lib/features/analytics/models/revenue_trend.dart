import 'package:cloud_firestore/cloud_firestore.dart';

class RevenueTrend {
  final String period;
  final DateTime date;
  final double revenue;
  final int orders;
  final int customers;
  final double averageOrderValue;

  RevenueTrend({
    required this.period,
    required this.date,
    this.revenue = 0.0,
    this.orders = 0,
    this.customers = 0,
    this.averageOrderValue = 0.0,
  });

  factory RevenueTrend.fromMap(Map<String, dynamic> map) {
    return RevenueTrend(
      period: map['period'] ?? '',
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      revenue: (map['revenue'] ?? 0).toDouble(),
      orders: map['orders'] ?? 0,
      customers: map['customers'] ?? 0,
      averageOrderValue: (map['averageOrderValue'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'period': period,
      'date': Timestamp.fromDate(date),
      'revenue': revenue,
      'orders': orders,
      'customers': customers,
      'averageOrderValue': averageOrderValue,
    };
  }

  // Helper methods for chart formatting
  String get formattedRevenue => '\$${revenue.toStringAsFixed(2)}';
  String get shortPeriod {
    if (period.length > 10) {
      // For monthly data like "2024-01", return "Jan"
      if (period.contains('-')) {
        final parts = period.split('-');
        if (parts.length >= 2) {
          final month = int.tryParse(parts[1]);
          if (month != null && month >= 1 && month <= 12) {
            const months = [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec'
            ];
            return months[month - 1];
          }
        }
      }
    }
    return period;
  }
}

class ChartDataPoint {
  final double x;
  final double y;
  final String label;
  final DateTime date;

  ChartDataPoint({
    required this.x,
    required this.y,
    required this.label,
    required this.date,
  });

  factory ChartDataPoint.fromRevenueTrend(RevenueTrend trend, int index) {
    return ChartDataPoint(
      x: index.toDouble(),
      y: trend.revenue,
      label: trend.shortPeriod,
      date: trend.date,
    );
  }
}

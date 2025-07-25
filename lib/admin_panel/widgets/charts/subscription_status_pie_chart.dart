import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SubscriptionStatusPieChart extends StatelessWidget {
  final int activeCount;
  final int expiredCount;
  final int gracePeriodCount;
  final int pendingCount;
  final int cancelledCount;

  const SubscriptionStatusPieChart({
    super.key,
    required this.activeCount,
    required this.expiredCount,
    required this.gracePeriodCount,
    required this.pendingCount,
    required this.cancelledCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = activeCount +
        expiredCount +
        gracePeriodCount +
        pendingCount +
        cancelledCount;

    if (total == 0) {
      return const Center(
        child: Text(
          'Өгөгдөл байхгүй байна',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          if (activeCount > 0)
            PieChartSectionData(
              color: Colors.green,
              value: activeCount.toDouble(),
              title: '${((activeCount / total) * 100).toStringAsFixed(1)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          if (expiredCount > 0)
            PieChartSectionData(
              color: Colors.red,
              value: expiredCount.toDouble(),
              title: '${((expiredCount / total) * 100).toStringAsFixed(1)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          if (gracePeriodCount > 0)
            PieChartSectionData(
              color: Colors.orange,
              value: gracePeriodCount.toDouble(),
              title:
                  '${((gracePeriodCount / total) * 100).toStringAsFixed(1)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          if (pendingCount > 0)
            PieChartSectionData(
              color: Colors.blue,
              value: pendingCount.toDouble(),
              title: '${((pendingCount / total) * 100).toStringAsFixed(1)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          if (cancelledCount > 0)
            PieChartSectionData(
              color: Colors.grey,
              value: cancelledCount.toDouble(),
              title: '${((cancelledCount / total) * 100).toStringAsFixed(1)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

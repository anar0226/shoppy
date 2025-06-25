import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../features/analytics/models/customer_segment.dart';

class CustomerSegmentPieChart extends StatefulWidget {
  final List<CustomerSegment> segments;
  final double height;
  final String title;

  const CustomerSegmentPieChart({
    super.key,
    required this.segments,
    this.height = 240,
    this.title = 'Customer Segments',
  });

  @override
  State<CustomerSegmentPieChart> createState() =>
      _CustomerSegmentPieChartState();
}

class _CustomerSegmentPieChartState extends State<CustomerSegmentPieChart> {
  int touchedIndex = -1;

  final List<Color> segmentColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.segments.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'No customer data available',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                // Pie Chart
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              touchedIndex = -1;
                              return;
                            }
                            touchedIndex = pieTouchResponse
                                .touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _buildPieChartSections(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildLegend(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    return widget.segments.asMap().entries.map((entry) {
      final index = entry.key;
      final segment = entry.value;
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;

      return PieChartSectionData(
        color: segmentColors[index % segmentColors.length],
        value: segment.percentage,
        title: '${segment.percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<Widget> _buildLegend() {
    return widget.segments.asMap().entries.map((entry) {
      final index = entry.key;
      final segment = entry.value;
      final color = segmentColors[index % segmentColors.length];

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segment.segment,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${segment.customerCount} customers',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class CustomerAnalyticsWidget extends StatelessWidget {
  final CustomerAnalytics analytics;
  final double height;

  const CustomerAnalyticsWidget({
    super.key,
    required this.analytics,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    return CustomerSegmentPieChart(
      segments: analytics.segments,
      height: height,
      title: 'Customer Segments',
    );
  }
}

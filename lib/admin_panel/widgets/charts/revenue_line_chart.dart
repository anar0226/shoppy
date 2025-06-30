import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../features/analytics/models/revenue_trend.dart';

class RevenueLineChart extends StatefulWidget {
  final List<RevenueTrend> data;
  final double height;
  final String title;
  final Color lineColor;
  final bool showDots;

  const RevenueLineChart({
    super.key,
    required this.data,
    this.height = 280,
    this.title = 'Revenue Trend',
    this.lineColor = Colors.green,
    this.showDots = true,
  });

  @override
  State<RevenueLineChart> createState() => _RevenueLineChartState();
}

class _RevenueLineChartState extends State<RevenueLineChart> {
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'No data available',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    final maxRevenue =
        widget.data.map((d) => d.revenue).reduce((a, b) => a > b ? a : b);
    final minRevenue =
        widget.data.map((d) => d.revenue).reduce((a, b) => a < b ? a : b);

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
          const SizedBox(height: 8),
          Text(
            'Total: ₮${widget.data.fold<double>(0, (sum, d) => sum + d.revenue).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxRevenue > 0 ? maxRevenue / 4 : 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < widget.data.length) {
                          // Show every 5th label to avoid crowding
                          if (index % 5 == 0 ||
                              index == widget.data.length - 1) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                widget.data[index].shortPeriod,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                        }
                        return Container();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxRevenue > 0 ? maxRevenue / 4 : 1,
                      reservedSize: 60,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          _formatCurrency(value),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                    left: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                minX: 0,
                maxX: (widget.data.length - 1).toDouble(),
                minY: minRevenue > 0 ? 0 : minRevenue * 1.1,
                maxY: maxRevenue * 1.1,
                lineBarsData: [
                  LineChartBarData(
                    spots: widget.data.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.revenue);
                    }).toList(),
                    isCurved: true,
                    color: widget.lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: widget.showDots,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: touchedIndex == index ? 6 : 4,
                          color: widget.lineColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: widget.lineColor.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchCallback:
                      (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    setState(() {
                      if (touchResponse == null ||
                          touchResponse.lineBarSpots == null) {
                        touchedIndex = null;
                      } else {
                        touchedIndex =
                            touchResponse.lineBarSpots!.first.spotIndex;
                      }
                    });
                  },
                  getTouchedSpotIndicator:
                      (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((spotIndex) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: widget.lineColor.withOpacity(0.8),
                          strokeWidth: 2,
                          dashArray: [5, 5],
                        ),
                        FlDotData(
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                            radius: 6,
                            color: widget.lineColor,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.black87,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final flSpot = barSpot;
                        final index = flSpot.x.toInt();
                        if (index >= 0 && index < widget.data.length) {
                          final data = widget.data[index];
                          return LineTooltipItem(
                            '${data.period}\n',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Revenue: ${data.formattedRevenue}\n',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              TextSpan(
                                text: 'Orders: ${data.orders}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '₮${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '₮${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '₮${value.toStringAsFixed(0)}';
    }
  }
}

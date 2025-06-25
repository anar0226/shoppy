import 'package:flutter/material.dart';
import '../../../features/analytics/models/conversion_funnel.dart';

class ConversionFunnelChart extends StatelessWidget {
  final ConversionFunnel funnel;
  final double height;
  final String title;

  const ConversionFunnelChart({
    super.key,
    required this.funnel,
    this.height = 300,
    this.title = 'Conversion Funnel',
  });

  @override
  Widget build(BuildContext context) {
    if (funnel.steps.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No funnel data available',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Overall Conversion Rate: ${funnel.formattedOverallConversionRate}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: funnel.steps.length,
              itemBuilder: (context, index) {
                final step = funnel.steps[index];
                final isLast = index == funnel.steps.length - 1;

                return Column(
                  children: [
                    _buildFunnelStep(step, index, funnel.steps.first.count),
                    if (!isLast) _buildFunnelArrow(),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildDropOffAnalysis(),
        ],
      ),
    );
  }

  Widget _buildFunnelStep(ConversionFunnelStep step, int index, int maxCount) {
    final double widthRatio = step.count / maxCount;
    final Color stepColor = _getStepColor(index);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Step indicator
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: stepColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Funnel bar
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    stepColor,
                    stepColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: stepColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Progress bar
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widthRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: stepColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  // Text content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                step.stepName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                step.description,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              step.count.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              step.formattedPercentage,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelArrow() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: const Row(
        children: [
          SizedBox(width: 36), // Align with step indicators
          Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildDropOffAnalysis() {
    final dropOffs = funnel.dropOffPoints;
    if (dropOffs.isEmpty) return Container();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Biggest Drop-off Points',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          ...dropOffs.take(2).map((dropOff) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      dropOff.key,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${dropOff.value.toStringAsFixed(1)}% drop',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getStepColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }
}

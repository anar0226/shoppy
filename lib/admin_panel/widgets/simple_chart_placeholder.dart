import 'package:flutter/material.dart';

class SimpleChartPlaceholder extends StatelessWidget {
  final double height;
  const SimpleChartPlaceholder({super.key, this.height = 160});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(child: Text('Chart')),
    );
  }
}

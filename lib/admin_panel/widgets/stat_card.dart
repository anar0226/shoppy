import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String delta;
  final bool deltaUp;
  final IconData icon;
  final Color iconBg;
  final String periodLabel;
  final String comparisonLabel;
  const StatCard(
      {super.key,
      required this.title,
      required this.value,
      required this.delta,
      required this.deltaUp,
      required this.icon,
      required this.iconBg,
      this.periodLabel = 'Today',
      this.comparisonLabel = 'vs yesterday'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              Text(periodLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w700)),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: iconBg.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: iconBg),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(deltaUp ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14, color: deltaUp ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Text(delta,
                  style: TextStyle(
                      fontSize: 14,
                      color: deltaUp ? Colors.green : Colors.red)),
              const SizedBox(width: 4),
              Text(comparisonLabel,
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}

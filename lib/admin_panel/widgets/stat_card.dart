import 'package:flutter/material.dart';
import '../../features/settings/themes/app_themes.dart';

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
        color: AppThemes.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppThemes.getSecondaryTextColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  periodLabel,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppThemes.getSecondaryTextColor(context)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppThemes.getTextColor(context),
                  ),
                ),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                deltaUp ? Icons.trending_up : Icons.trending_down,
                size: 16,
                color: deltaUp ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  delta,
                  style: TextStyle(
                    fontSize: 12,
                    color: deltaUp ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  comparisonLabel ?? 'өмнөх үе',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppThemes.getSecondaryTextColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (periodLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              periodLabel!,
              style: TextStyle(
                fontSize: 12,
                color: AppThemes.getSecondaryTextColor(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

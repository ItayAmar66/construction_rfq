import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

/// Compact insight chips for dashboards.
class DashboardInsightsRow extends StatelessWidget {
  const DashboardInsightsRow({super.key, required this.items});

  final List<DashboardInsight> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _InsightCard(item: items[i]),
      ),
    );
  }
}

class DashboardInsight {
  const DashboardInsight({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppTheme.navy,
    this.hint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? hint;
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.item});

  final DashboardInsight item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: AppTheme.cardDecoration(elevation: 1).copyWith(
        border: Border.all(color: item.color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 16, color: item.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.micro(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.kpiValue(context).copyWith(
              fontSize: 17,
              color: item.color,
            ),
          ),
          if (item.hint != null)
            Text(
              item.hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.micro(context),
            ),
        ],
      ),
    );
  }
}

/// Format currency for insights.
String formatInsightCurrency(double value) {
  return NumberFormat.currency(locale: 'he_IL', symbol: '₪').format(value);
}

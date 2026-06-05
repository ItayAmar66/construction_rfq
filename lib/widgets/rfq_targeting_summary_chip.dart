import 'package:flutter/material.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/supplier_targeting_helpers.dart';

class RfqTargetingSummaryChip extends StatelessWidget {
  const RfqTargetingSummaryChip({
    super.key,
    required this.summary,
  });

  final CustomerTargetingSummary summary;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (summary.mode) {
      CustomerTargetingMode.open => (
          Icons.public_outlined,
          AppTheme.navy,
        ),
      CustomerTargetingMode.invited => (
          Icons.mail_outline,
          AppTheme.amber,
        ),
      CustomerTargetingMode.categoryMatch => (
          Icons.category_outlined,
          AppTheme.teal,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

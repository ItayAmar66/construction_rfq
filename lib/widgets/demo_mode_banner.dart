import 'package:flutter/material.dart';

import '../config/app_mode.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/hebrew_strings.dart';

/// Subtle demo-mode indicator for dashboards and login.
class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!AppMode.isDemoMode) return const SizedBox.shrink();

    if (compact) {
      return Chip(
        avatar: Icon(Icons.science_outlined, size: 16, color: AppTheme.amber),
        label: Text(
          HebrewStrings.demoModeBadge,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        backgroundColor: AppTheme.amber.withValues(alpha: 0.12),
        visualDensity: VisualDensity.compact,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: AppTheme.amber, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppMode.statusMessage ?? HebrewStrings.demoModeHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

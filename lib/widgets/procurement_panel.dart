import 'package:flutter/material.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';

/// Consistent procurement-focused section chrome (no logic).
class ProcurementPanel extends StatelessWidget {
  const ProcurementPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.tint = AppTheme.teal,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: child,
    );
  }
}

class ProcurementScreenIntro extends StatelessWidget {
  const ProcurementScreenIntro({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.request_quote_outlined,
    this.tint = AppTheme.teal,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ProcurementPanel(
      tint: tint,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

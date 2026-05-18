import 'package:flutter/material.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';

/// Unified list row card — premium, compact, RTL-safe.
class AppListCard extends StatelessWidget {
  const AppListCard({
    super.key,
    required this.onTap,
    required this.title,
    this.subtitle,
    this.meta,
    this.trailing,
    this.leading,
    this.badge,
    this.topChip,
  });

  final VoidCallback? onTap;
  final String title;
  final String? subtitle;
  final String? meta;
  final Widget? trailing;
  final Widget? leading;
  final Widget? badge;
  final Widget? topChip;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (topChip != null) ...[
                  topChip!,
                  const SizedBox(height: AppSpacing.xxs),
                ],
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.25,
                        ),
                  ),
                ],
                if (meta != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: AppSpacing.xs),
            badge!,
          ],
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            trailing!,
          ],
          const SizedBox(width: AppSpacing.xxs),
          Icon(
            Icons.chevron_left,
            size: 20,
            color: AppTheme.textSecondary.withValues(alpha: 0.6),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: AppTheme.cardDecoration(elevation: 1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: child,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Rounded, tinted "avatar" square showing an entity's initial (or an icon).
///
/// Matches the reference design's supplier/customer avatar tiles. Presentation
/// only — no logic.
class EntityAvatar extends StatelessWidget {
  const EntityAvatar({
    super.key,
    required this.name,
    this.color = AppTheme.teal,
    this.size = 44,
    this.icon,
  });

  final String name;
  final Color color;
  final double size;
  final IconData? icon;

  static String initialOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: icon != null
          ? Icon(icon, color: color, size: size * 0.5)
          : Text(
              initialOf(name),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.38,
              ),
            ),
    );
  }
}

/// A label-over-value field used inside detail/summary cards.
class InfoField extends StatelessWidget {
  const InfoField({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.dense = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        SizedBox(height: dense ? 1 : 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: valueColor ?? AppTheme.textSecondary),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: valueColor ?? AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Prominent "headline total" tile with a caption above a large amount.
///
/// Mirrors the reference quote/order cards' total box.
class PrimaryTotalBox extends StatelessWidget {
  const PrimaryTotalBox({
    super.key,
    required this.caption,
    required this.amount,
    this.amountColor,
    this.trailing,
  });

  final String caption;
  final String amount;
  final Color? amountColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  amount,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: amountColor ?? AppTheme.textPrimary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A compact section container: a rounded card with an optional titled header
/// and a body. Matches the reference "white card + header row + list" pattern.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding,
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: AppTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

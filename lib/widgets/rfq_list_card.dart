import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import 'design_system/design_system.dart';

/// Shared RFQ list row — reference "בקשה" card.
///
/// A visible RFQ number chip sits beside the title, the status is grouped on
/// the title line (never floating alone at the far edge), and metadata sits
/// on its own muted line below. Used by both the customer requests list and
/// the supplier incoming-requests list.
class RfqListCard extends StatelessWidget {
  const RfqListCard({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    this.meta,
    this.chips = const [],
    this.status,
    this.badge,
    this.action,
    this.onTap,
  });

  /// Short RFQ reference, e.g. `#A1B2C3`.
  final String number;
  final String title;
  final String? subtitle;
  final String? meta;

  /// Leading tags on the metadata line (tender / relevance chips).
  final List<Widget> chips;

  /// Status pill, shown on the title line.
  final Widget? status;

  /// Unread / count badge, shown on the title line before the status.
  final Widget? badge;

  /// Trailing action on the metadata line (e.g. supplier "respond" button).
  final Widget? action;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasMetaRow = chips.isNotEmpty || meta != null || action != null;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- Title line: number · title · badge · status ----
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _NumberChip(number),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      badge!,
                    ],
                    if (status != null) ...[
                      const SizedBox(width: 8),
                      status!,
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
                if (hasMetaRow) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (final chip in chips) ...[
                        chip,
                        const SizedBox(width: 6),
                      ],
                      if (meta != null)
                        Expanded(
                          child: Text(
                            meta!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (action != null) ...[
                        const SizedBox(width: 8),
                        action!,
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null && action == null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_left,
              size: 20,
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
            ),
          ],
        ],
      ),
    );
  }
}

class _NumberChip extends StatelessWidget {
  const _NumberChip(this.number);

  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Text(
        number,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.navy,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/count_badge.dart';

class DashboardTile extends StatefulWidget {
  const DashboardTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badge,
    this.count,
    this.showEmptyCountLabel = false,
    this.accent = DashboardAccent.teal,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;
  final int? count;
  final bool showEmptyCountLabel;
  final DashboardAccent accent;

  String? get _resolvedBadge {
    if (count != null) {
      return countBadgeLabel(count!, showEmptyLabel: showEmptyCountLabel);
    }
    return badge;
  }

  @override
  State<DashboardTile> createState() => _DashboardTileState();
}

class _DashboardTileState extends State<DashboardTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final resolvedBadge = widget._resolvedBadge;
    final accent = widget.accent.color;

    return AnimatedScale(
      scale: _pressed ? 0.99 : 1,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Ink(
            decoration: AppTheme.cardDecoration(elevation: 2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (resolvedBadge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (widget.count != null && widget.count! > 0)
                            ? AppTheme.amber.withValues(alpha: 0.15)
                            : AppTheme.surfaceTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        resolvedBadge,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: (widget.count != null && widget.count! > 0)
                              ? AppTheme.amber
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  Icon(
                    Icons.chevron_left,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

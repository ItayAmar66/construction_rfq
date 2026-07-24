import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_theme.dart';

/// Compact KPI tile shared by the customer and supplier dashboards.
///
/// Reference layout (Bonim): a tinted icon chip on the start side, with the
/// value (Heebo bold) and label grouped and vertically centred beside it — a
/// balanced tile with no empty region and no coloured side rail.
class V2StatCard extends StatefulWidget {
  const V2StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = DashboardAccent.navy,
    this.subtitle,
    this.onTap,
    this.badge,
    this.compact = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final DashboardAccent accent;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? badge;
  final bool compact;

  @override
  State<V2StatCard> createState() => _V2StatCardState();
}

class _V2StatCardState extends State<V2StatCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final accent = widget.accent.color;
        final maxH = constraints.maxHeight;
        final bounded = maxH.isFinite && maxH > 0;

        return AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: widget.onTap == null
                  ? null
                  : (v) => setState(() => _pressed = v),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: Ink(
                width: double.infinity,
                height: bounded ? maxH : null,
                decoration: AppTheme.cardDecoration(elevation: 2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, size: 20, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              widget.value,
                              maxLines: 1,
                              style: GoogleFonts.heebo(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                height: 1.05,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                          if (widget.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                widget.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  height: 1.1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.amber.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.badge!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.amberDark,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

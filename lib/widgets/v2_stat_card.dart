import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Compact premium KPI card — bounded layout, no vertical overflow.
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

  static const double _iconRowHeight = 20;
  static const double _iconBoxSize = 20;
  static const double _iconGlyphSize = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final accent = widget.accent.color;
        final maxH = constraints.maxHeight;
        final bounded = maxH.isFinite && maxH > 0;

        // Tighter top/sides, less bottom padding.
        const padH = 8.0;
        const padTop = 8.0;
        const padBottom = 5.0;

        final labelSize = widget.compact ? 9.0 : 10.0;
        final valueSize = widget.compact ? 15.0 : 17.0;
        final subtitleSize = widget.compact ? 7.0 : 7.5;

        final body = _StatBody(
          label: widget.label,
          value: widget.value,
          subtitle: widget.subtitle,
          labelSize: labelSize,
          valueSize: valueSize,
          subtitleSize: subtitleSize,
          flexValue: bounded,
        );

        return AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: widget.onTap == null
                  ? null
                  : (v) => setState(() => _pressed = v),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Ink(
                width: double.infinity,
                height: bounded ? maxH : null,
                decoration: AppTheme.cardDecoration(elevation: 2).copyWith(
                  border: Border(
                    right: BorderSide(color: accent, width: 3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    padH,
                    padTop,
                    padH,
                    padBottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: _iconRowHeight,
                        child: Row(
                          children: [
                            Container(
                              width: _iconBoxSize,
                              height: _iconBoxSize,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Icon(
                                widget.icon,
                                size: _iconGlyphSize,
                                color: accent,
                              ),
                            ),
                            const Spacer(),
                            if (widget.badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  widget.badge!,
                                  style: const TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.amber,
                                    height: 1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (bounded) Expanded(child: body) else body,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Label + KPI + optional subtitle — flex on value so it never overflows.
class _StatBody extends StatelessWidget {
  const _StatBody({
    required this.label,
    required this.value,
    this.subtitle,
    required this.labelSize,
    required this.valueSize,
    required this.subtitleSize,
    required this.flexValue,
  });

  final String label;
  final String value;
  final String? subtitle;
  final double labelSize;
  final double valueSize;
  final double subtitleSize;
  final bool flexValue;

  Widget _valueText() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: valueSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valueWidget = flexValue
        ? Flexible(
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: _valueText(),
            ),
          )
        : Padding(
            padding: const EdgeInsets.only(top: 1),
            child: _valueText(),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: flexValue ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: labelSize,
            fontWeight: FontWeight.w500,
            height: 1.05,
          ),
        ),
        valueWidget,
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.85),
                fontSize: subtitleSize,
                fontWeight: FontWeight.w400,
                height: 1.0,
              ),
            ),
          ),
      ],
    );
  }
}

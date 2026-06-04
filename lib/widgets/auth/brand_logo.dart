import 'package:flutter/material.dart';

import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';

/// Branded mark — no external assets required.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 56,
    this.showTagline = false,
    this.light = false,
  });

  final double size;
  final bool showTagline;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final fg = light ? Colors.white : AppTheme.navy;
    final accent = light ? AppTheme.tealLight : AppTheme.teal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppTheme.linearGradient(
              light ? [Colors.white.withValues(alpha: 0.2), accent] : AppTheme.gradientTeal,
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.handshake_outlined,
            size: size * 0.48,
            color: Colors.white,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'בקשות הצעת מחיר',
            style: AppTypography.h1(context).copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'רכש חכם לענף הבנייה',
            style: AppTypography.caption(context).copyWith(
              color: light
                  ? Colors.white.withValues(alpha: 0.75)
                  : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

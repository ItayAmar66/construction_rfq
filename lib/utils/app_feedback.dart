import 'package:flutter/material.dart';

import '../widgets/app_fade_in.dart';
import 'app_theme.dart';
import 'app_typography.dart';

/// Subtle success / info feedback — no flashy animations.
abstract final class AppFeedback {
  static void showSuccess(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_circle_outline,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.navy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        content: Row(
          children: [
            Icon(icon, color: AppTheme.emeraldLight, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTypography.body(context).copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.danger,
        content: Text(message),
      ),
    );
  }
}

/// Success checkmark overlay for confirmations.
class SuccessState extends StatelessWidget {
  const SuccessState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.check_circle_outline,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppFadeIn(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: AppTheme.emerald),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.h1(context),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySecondary(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../widgets/app_fade_in.dart';
import '../../widgets/auth/brand_logo.dart';

/// Shown when Firebase Auth succeeded but Firestore profile is missing.
class ProfileErrorScreen extends ConsumerWidget {
  const ProfileErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppTheme.linearGradient(AppTheme.gradientHero),
        ),
        child: SafeArea(
          child: Center(
            child: AppFadeIn(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: AppTheme.cardDecoration(elevation: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandLogo(size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 48,
                        color: AppTheme.amber,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'פרופיל המשתמש לא נמצא',
                        style: AppTypography.h1(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'החשבון קיים בהתחברות אך חסר מסמך משתמש ב-Firestore. '
                        'נסו להירשם מחדש או פנו לתמיכה.',
                        style: AppTypography.bodySecondary(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton(
                        onPressed: () async {
                          await ref.read(authServiceProvider).logout();
                          ref.invalidate(authSessionProvider);
                          if (context.mounted) context.go('/login');
                        },
                        child: const Text('התנתק וחזור להתחברות'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

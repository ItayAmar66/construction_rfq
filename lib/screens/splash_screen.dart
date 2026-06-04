import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_mode.dart';
import '../providers/providers.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../widgets/app_fade_in.dart';
import '../widgets/auth/brand_logo.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authSessionProvider, (prev, next) {
      next.whenOrNull(
        data: (session) {
          if (!context.mounted) return;
          if (!session.isAuthenticated) {
            context.go('/login');
            return;
          }
          if (session.profileMissing) {
            context.go('/profile-error');
            return;
          }
          if (session.profile != null) {
            context.go('/home');
          }
        },
      );
    });

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppTheme.linearGradient(AppTheme.gradientHero),
        ),
        child: SafeArea(
          child: Center(
            child: AppFadeIn(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BrandLogo(size: 72, showTagline: true, light: true),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'טוען את סביבת העבודה…',
                    style: AppTypography.body(context).copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  if (AppMode.isDemoMode) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        AppMode.statusMessage ?? 'מצב הדגמה',
                        style: AppTypography.micro(context).copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

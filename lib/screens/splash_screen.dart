import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_mode.dart';
import '../providers/enterprise_providers.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';
import '../utils/hebrew_strings.dart';
import '../widgets/auth/auth_scaffold.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(platformAccessGateProvider);
    ref.watch(membershipBootstrapSettledProvider);
    ref.watch(authBootstrapSettledProvider);

    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: authBackdropDecoration,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AuthBrandmark(onDark: true, size: 56),
                const SizedBox(height: 20),
                Text(
                  HebrewStrings.splashTagline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.4,
                  ),
                ),
                if (AppMode.isDemoMode &&
                    (AppMode.statusMessage?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 10),
                  Text(
                    AppMode.statusMessage!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.amberLight,
                    ),
                  ),
                ],
                const SizedBox(height: 36),
                const SizedBox(
                  height: 30,
                  width: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppTheme.amber,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  HebrewStrings.loading,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

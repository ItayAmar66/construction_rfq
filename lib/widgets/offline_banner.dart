import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_provider.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';

/// Slim, non-blocking banner shown app-wide while the device has no network
/// connection, so users understand why actions may be failing instead of
/// only finding out one SnackBar at a time.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isOffline
          ? Container(
              key: const ValueKey('offline-banner'),
              width: double.infinity,
              color: AppTheme.amber.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 16, color: AppTheme.amber),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'אין חיבור לאינטרנט — שינויים יישמרו כשהחיבור יחזור',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('offline-banner-hidden')),
    );
  }
}

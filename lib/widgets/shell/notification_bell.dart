import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/dashboard_analytics_provider.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';

import '../status_chip.dart';
/// Unread-notification count for the current user, derived from the
/// existing per-role dashboard analytics (no new business logic/state).
final shellUnreadCountProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user != null && user.userType.isSupplier) {
    final analytics = ref.watch(supplierDashboardAnalyticsProvider);
    return analytics.unseenIncoming + analytics.unreadOrders;
  }
  final analytics = ref.watch(customerDashboardAnalyticsProvider);
  return analytics.unreadQuotes + analytics.unreadRequestUpdates;
});

/// Bell icon with an unread-count badge; opens a short summary menu.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(shellUnreadCountProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isSupplier = user?.userType.isSupplier ?? false;
    final destination = isSupplier ? '/incoming' : '/received-quotes';

    return PopupMenuButton<void>(
      tooltip: 'התראות',
      offset: const Offset(0, 44),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: () => context.go(destination),
          child: Text(
            count > 0 ? 'יש לך $count עדכונים חדשים' : 'אין התראות חדשות',
          ),
        ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_outlined, size: 19, color: AppTheme.textPrimary),
            if (count > 0)
              Positioned(
                top: -6,
                left: -6,
                child: StatusChip.count(count, dense: true),
              ),
          ],
        ),
      ),
    );
  }
}

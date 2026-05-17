import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/dashboard_tile.dart';
import '../../widgets/error_message.dart';

class SupplierDashboardScreen extends ConsumerWidget {
  const SupplierDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final unseenIncomingCount = ref.watch(incomingUnseenCountProvider);
    final unreadOrdersCount =
        ref.watch(supplierUnreadOrdersToFulfillCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(HebrewStrings.home),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorMessage.fromError(
              e,
              onRetry: () => ref.invalidate(authSessionProvider),
            ),
        data: (user) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${HebrewStrings.welcomeSupplier}\n${user?.fullName ?? ''}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                user?.userType.label ?? '',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              DashboardTile(
                title: HebrewStrings.incomingRequests,
                subtitle: 'בקשות הצעת מחיר מלקוחות',
                icon: Icons.inbox_outlined,
                count: unseenIncomingCount,
                onTap: () => context.push('/incoming'),
              ),
              const SizedBox(height: 12),
              DashboardTile(
                title: HebrewStrings.sentQuotes,
                subtitle: 'היסטוריית הצעות ששלחת',
                icon: Icons.send_outlined,
                onTap: () => context.push('/sent-quotes'),
              ),
              const SizedBox(height: 12),
              DashboardTile(
                title: HebrewStrings.ordersToFulfill,
                subtitle: 'הזמנות שאושרו על ידי לקוחות',
                icon: Icons.assignment_turned_in_outlined,
                count: unreadOrdersCount,
                onTap: () => context.push('/supplier/orders'),
              ),
              const SizedBox(height: 12),
              DashboardTile(
                title: HebrewStrings.ordersHistory,
                subtitle: 'הזמנות שנשלחו ללקוחות',
                icon: Icons.history,
                onTap: () => context.push('/supplier/orders-history'),
              ),
              const SizedBox(height: 12),
              DashboardTile(
                title: HebrewStrings.profile,
                subtitle: 'פרטי חשבון והגדרות',
                icon: Icons.settings_outlined,
                onTap: () => context.push('/profile'),
              ),
            ],
          );
        },
      ),
    );
  }
}

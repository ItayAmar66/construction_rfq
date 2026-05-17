import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/cart_provider.dart';
import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/dashboard_tile.dart';
import '../../widgets/error_message.dart';

class CustomerDashboardScreen extends ConsumerWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final cartCount = ref.watch(cartProvider).fold(0, (s, i) => s + i.quantity);
    final unreadRequestsCount = ref.watch(customerUnreadRequestsCountProvider);
    final unreadQuotesCount =
        ref.watch(customerUnreadReceivedQuotesCountProvider);
    final unreadActiveOrdersCount =
        ref.watch(customerUnreadActiveOrdersCountProvider);

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
                '${HebrewStrings.welcomeCustomer}\n${user?.fullName ?? ''}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                user?.city ?? '',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              DashboardTile(
                title: HebrewStrings.catalog,
                subtitle: 'עיין בקטלוג חומרי הבנייה',
                icon: Icons.storefront_outlined,
                onTap: () => context.push('/catalog'),
              ),
              const SizedBox(height: 12),
              DashboardTile(
                title: HebrewStrings.cart,
                subtitle: 'הכן ושלח בקשת הצעת מחיר',
                icon: Icons.request_quote_outlined,
                badge: cartCount > 0 ? '$cartCount' : null,
                onTap: () => context.push('/cart'),
              ),
              const SizedBox(height: 12),
              DashboardTile(
                title: HebrewStrings.myRequests,
                subtitle: 'מעקב אחר בקשות קודמות',
                icon: Icons.history,
                count: unreadRequestsCount,
                onTap: () => context.push('/my-requests'),
              ),
              const SizedBox(height: 12),
              DashboardTile(
                title: HebrewStrings.receivedQuotes,
                subtitle: 'השווה הצעות מספקים',
                icon: Icons.compare_arrows,
                count: unreadQuotesCount,
                onTap: () => context.push('/received-quotes'),
              ),
              const SizedBox(height: 12),
              DashboardTile(
                title: HebrewStrings.activeOrders,
                subtitle: 'הזמנות שאושרו או בדרך אליך',
                icon: Icons.local_shipping_outlined,
                count: unreadActiveOrdersCount,
                onTap: () => context.push('/active-orders'),
              ),
            ],
          );
        },
      ),
    );
  }
}

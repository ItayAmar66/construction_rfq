import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quote_status.dart';
import '../utils/app_theme.dart';
import 'providers.dart';

class DashboardTask {
  const DashboardTask({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.accent = DashboardAccent.teal,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final DashboardAccent accent;
}

final customerDashboardTasksProvider = Provider<List<DashboardTask>>((ref) {
  final requests = ref.watch(customerRequestsProvider).valueOrNull ?? [];
  final quotes = ref.watch(customerReceivedQuotesProvider).valueOrNull ?? [];
  final tasks = <DashboardTask>[];

  final waitingForQuotes = requests
      .where(
        (r) =>
            r.status == QuoteRequestStatus.sent &&
            !r.hasApprovedQuote,
      )
      .length;
  if (waitingForQuotes > 0) {
    tasks.add(
      DashboardTask(
        title: 'ממתינות להצעות',
        subtitle: '$waitingForQuotes בקשות ללא הצעות עדיין',
        icon: Icons.hourglass_empty_outlined,
        route: '/my-requests',
        accent: DashboardAccent.amber,
      ),
    );
  }

  final unreadQuotes = quotes.where((q) => q.isUnreadByCustomer).length;
  if (unreadQuotes > 0) {
    tasks.add(
      DashboardTask(
        title: 'הצעות חדשות',
        subtitle: '$unreadQuotes הצעות שלא נצפו',
        icon: Icons.mark_email_unread_outlined,
        route: '/received-quotes',
        accent: DashboardAccent.emerald,
      ),
    );
  }

  final activeOrders = requests
      .where(
        (r) =>
            r.status == QuoteRequestStatus.ordered ||
            r.status == QuoteRequestStatus.shipped,
      )
      .length;
  if (activeOrders > 0) {
    tasks.add(
      DashboardTask(
        title: 'הזמנות פעילות',
        subtitle: '$activeOrders הזמנות במעקב',
        icon: Icons.local_shipping_outlined,
        route: '/active-orders',
        accent: DashboardAccent.navy,
      ),
    );
  }

  return tasks;
});

final supplierDashboardTasksProvider = Provider<List<DashboardTask>>((ref) {
  final incoming = ref.watch(incomingRequestsProvider).valueOrNull ?? [];
  final supplierId = ref.watch(authSessionProvider).valueOrNull?.profile?.id;
  final toFulfill = ref.watch(supplierOrdersToFulfillProvider).valueOrNull ?? [];
  final tasks = <DashboardTask>[];

  if (supplierId != null) {
    final unseen =
        incoming.where((r) => r.isUnseenBySupplier(supplierId)).length;
    if (unseen > 0) {
      tasks.add(
        DashboardTask(
          title: 'בקשות חדשות',
          subtitle: '$unseen בקשות שלא נצפו',
          icon: Icons.inbox_outlined,
          route: '/incoming',
          accent: DashboardAccent.teal,
        ),
      );
    }
  }

  final closingSoon = incoming.where((r) {
    if (!r.isTender || !r.isTenderActive) return false;
    final end = r.tenderEndTime;
    if (end == null) return false;
    return end.difference(DateTime.now()).inHours <= 24;
  }).length;
  if (closingSoon > 0) {
    tasks.add(
      DashboardTask(
        title: 'מכרזים נסגרים בקרוב',
        subtitle: '$closingSoon מכרזים ב-24 השעות הקרובות',
        icon: Icons.gavel_outlined,
        route: '/incoming',
        accent: DashboardAccent.amber,
      ),
    );
  }

  final unreadOrders =
      toFulfill.where((q) => q.isUnreadOrderBySupplier).length;
  if (unreadOrders > 0) {
    tasks.add(
      DashboardTask(
        title: 'הזמנות שאושרו',
        subtitle: '$unreadOrders הזמנות לטיפול',
        icon: Icons.assignment_turned_in_outlined,
        route: '/supplier/orders',
        accent: DashboardAccent.emerald,
      ),
    );
  }

  return tasks;
});

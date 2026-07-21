import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'no_access_view.dart';

/// Screen-level fallback guard for supplier-only routes (/incoming,
/// /supplier/orders, /sent-quotes). The router's redirect already keeps a
/// non-supplier from landing here; this gate exists so the guarantee does
/// not depend solely on that redirect (or on the nav item simply being
/// hidden) — a stale deep link, a back-button restore, or a future routing
/// bug still can't expose supplier-only content to a non-supplier session.
class SupplierOnlyGate extends ConsumerWidget {
  const SupplierOnlyGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(resolvedAuthSessionProvider).valueOrNull;
    final isSupplier = session?.profile?.userType.isSupplier ?? false;
    if (!isSupplier) {
      return const NoAccessView(
        title: 'אין הרשאה',
        message: 'עמוד זה זמין למשתמשי ספק בלבד.',
      );
    }
    return child;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/delivery.dart';
import '../../providers/delivery_providers.dart';
import '../../providers/supplier_hierarchy_providers.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/content_max_width.dart';
import '../../widgets/deliveries/deliveries_list_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

/// Cross-contractor deliveries the supplier is fulfilling — everything they have
/// shipped or still needs to ship, with a live shipment timeline per order.
class SupplierDeliveriesScreen extends ConsumerWidget {
  const SupplierDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(supplierAllRequestsProvider);
    final deliveries = ref.watch(supplierDeliveriesProvider);

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'משלוחים'),
      body: requestsAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const EmptyState(
          message: 'שגיאה בטעינת משלוחים',
          icon: Icons.error_outline,
        ),
        data: (_) {
          if (deliveries.isEmpty) {
            return const EmptyState(
              message: 'אין משלוחים לניהול כרגע',
              icon: Icons.local_shipping_outlined,
              hint: 'הזמנות שאושרו יופיעו כאן למעקב ולסימון כנשלחו',
            );
          }
          return ContentMaxWidth(
            child: DeliveriesListView(
              deliveries: deliveries,
              showContractor: true,
              onOpenOrder: (d) => _openOrder(context, d),
            ),
          );
        },
      ),
    );
  }

  void _openOrder(BuildContext context, Delivery d) {
    final quoteId = d.request.approvedQuoteId;
    if (quoteId == null || quoteId.isEmpty) return;
    context.push('/supplier/order/$quoteId?requestId=${d.id}');
  }
}

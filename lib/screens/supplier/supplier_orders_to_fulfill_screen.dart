import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/quote_match_summary_chips.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/design_system/app_card.dart';
import '../../widgets/design_system/design_system.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/mark_seen_on_open.dart';
import '../../widgets/projects/project_context_chip.dart';
import '../../widgets/summary_widgets.dart';

import '../../widgets/status_chip.dart';
class SupplierOrdersToFulfillScreen extends ConsumerWidget {
  const SupplierOrdersToFulfillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(supplierOrdersToFulfillProvider);
    final ordersCount = ref.watch(supplierOrdersToFulfillCountProvider);
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    return MarkSeenOnOpen(
      onMarkSeen: (ref) async {
        final user = ref.read(authSessionProvider).valueOrNull?.profile;
        if (user == null) return;
        await ref
            .read(quoteServiceProvider)
            .markSupplierOrdersToFulfillSeen(user.id);
      },
      child: Scaffold(
        appBar: SecondaryAppBar(
          title: HebrewStrings.ordersToFulfill,
          count: ordersCount,
        ),
        body: ordersAsync.when(
          loading: () => const LoadingView(),
          error: (_, __) => const EmptyState(
            message: HebrewStrings.errorGeneric,
            icon: Icons.error_outline,
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return const EmptyState(
                message: 'אין הזמנות ממתינות לביצוע',
                icon: Icons.local_shipping_outlined,
                hint:
                    'כאשר לקוח יאשר הצעה שלך, ההזמנה תופיע כאן לסימון נשלח / סופק.',
              );
            }
            return DateGroupedListView<SupplierQuote>(
              items: orders,
              dateFor: (q) => q.createdAt,
              itemBuilder: (context, quote) => _OrderCard(
                quote: quote,
                dateFormat: dateFormat,
                onTap: () => context.push(
                  '/supplier/order/${quote.id}?requestId=${quote.quoteRequestId}',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({
    required this.quote,
    required this.dateFormat,
    required this.onTap,
  });

  final SupplierQuote quote;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final request =
        ref.watch(quoteRequestProvider(quote.quoteRequestId)).valueOrNull;
    final customerName = request?.customerName ?? 'לקוח';
    final isUnread = quote.isUnreadOrderBySupplier;
    final currency =
        NumberFormat.currency(locale: 'he_IL', symbol: '₪', decimalDigits: 0);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EntityAvatar(
                    name: '',
                    icon: Icons.inventory_2_outlined,
                    color: AppTheme.amberDark,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${HebrewStrings.deliveryTime}: ${quote.deliveryTime} · ${dateFormat.format(quote.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (isUnread) ...[
                    StatusChip.count(1, dense: true),
                    const SizedBox(width: 6),
                  ],
                  StatusChip.quote(quote.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              PrimaryTotalBox(
                caption: 'סכום ההזמנה כולל מע״מ',
                amount: currency.format(quote.displayTotal),
              ),
              if (request != null) ...[
                const SizedBox(height: AppSpacing.xs),
                ProjectContextChip(request: request),
              ],
              QuoteMatchSummaryChips(
                items: quote.items,
                requestItems: request?.items ?? const [],
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton.icon(
                icon: Icons.local_shipping_outlined,
                label: 'פתיחה לביצוע',
                onPressed: onTap,
              ),
            ],
          ),
    );
  }
}

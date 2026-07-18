import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/delivery.dart';
import '../../models/quote_status.dart';
import '../../models/supplier_quote.dart';
import '../../providers/delivery_providers.dart';
import '../../providers/providers.dart';
import '../../providers/supplier_hierarchy_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/project_attention.dart';
import '../../utils/supplier_hierarchy.dart';
import '../../utils/supplier_quote_status.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/deliveries/delivery_detail_sheet.dart';
import '../../widgets/deliveries/delivery_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_chip.dart';

class SupplierProjectWorkspaceScreen extends ConsumerWidget {
  const SupplierProjectWorkspaceScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(supplierAllRequestsProvider);
    final project = ref.watch(supplierProjectGroupProvider(projectId));

    return Scaffold(
      appBar: SecondaryAppBar(
        title: 'פרויקט',
        breadcrumbs: project == null
            ? [BreadcrumbItem('קבלנים', onTap: () => context.go('/supplier/contractors'))]
            : [
                BreadcrumbItem('קבלנים', onTap: () => context.go('/supplier/contractors')),
                BreadcrumbItem(
                  project.requests.first.customerName,
                  onTap: () => context.go(
                    '/supplier/contractors/${contractorKeyFor(project.requests.first)}',
                  ),
                ),
              ],
      ),
      body: requestsAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const EmptyState(
          message: 'שגיאה בטעינת הפרויקט',
          icon: Icons.error_outline,
        ),
        data: (_) {
          if (project == null) {
            return const EmptyState(
              message: 'הפרויקט לא נמצא',
              icon: Icons.apartment_outlined,
            );
          }

          final sent = ref.watch(supplierSentQuotesProvider).valueOrNull ?? [];
          final toFulfill =
              ref.watch(supplierOrdersToFulfillProvider).valueOrNull ?? [];
          final history =
              ref.watch(supplierOrderHistoryProvider).valueOrNull ?? [];
          final myQuotes = <SupplierQuote>[...sent, ...toFulfill, ...history];

          return DefaultTabController(
            length: 5,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  project.projectName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (project.isNew)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.amber.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'פרויקט חדש',
                                    style: TextStyle(
                                        color: AppTheme.amberDark,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                          if (project.projectLocation.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                project.projectLocation,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                _ContractorMeta(
                                  icon: Icons.business_outlined,
                                  text: project.requests.first.customerName,
                                ),
                                if (project
                                    .requests.first.customerPhone.isNotEmpty)
                                  _ContractorMeta(
                                    icon: Icons.phone_outlined,
                                    text:
                                        project.requests.first.customerPhone,
                                  ),
                                _ContractorMeta(
                                  icon: Icons.assignment_outlined,
                                  text: '${project.requests.length} בקשות',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: TabBar(
                    isScrollable: true,
                    labelColor: AppTheme.navy,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.amber,
                    tabs: const [
                      Tab(text: 'בקשות'),
                      Tab(text: 'הצעות'),
                      Tab(text: 'הזמנות'),
                      Tab(text: 'משלוחים'),
                      Tab(text: 'היסטוריה'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    children: [
                      _SupplierRfqsTab(project: project),
                      _SupplierQuotesTab(project: project, myQuotes: myQuotes),
                      _SupplierOrdersTab(project: project, myQuotes: myQuotes),
                      _SupplierDeliveriesTab(project: project),
                      _SupplierHistoryTab(project: project, myQuotes: myQuotes),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SupplierRfqsTab extends StatelessWidget {
  const _SupplierRfqsTab({required this.project});

  final SupplierProjectGroup project;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');
    final attention = buildSupplierAttentionItems(
      project.requests,
      AppTheme.amber,
      AppTheme.danger,
      AppTheme.navy,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (attention.isNotEmpty) ...[
          Text('דורש את תשומת ליבך',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in attention)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(item.icon, color: item.tone),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/respond/${item.requestId}'),
              ),
            ),
          const SizedBox(height: 12),
        ],
        Text('כל בקשות המחיר', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final r in project.requests)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppListCard(
              onTap: () => context.push(
                r.isTender ? '/tender/${r.id}' : '/respond/${r.id}',
              ),
              title: r.customerName,
              subtitle: r.notes,
              meta: dateFormat.format(r.createdAt),
              trailing: StatusChip(status: r.status),
            ),
          ),
      ],
    );
  }
}

class _SupplierQuotesTab extends StatelessWidget {
  const _SupplierQuotesTab({required this.project, required this.myQuotes});

  final SupplierProjectGroup project;
  final List<SupplierQuote> myQuotes;

  @override
  Widget build(BuildContext context) {
    final requestIds = project.requests.map((r) => r.id).toSet();
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');
    final quotes = myQuotes
        .where((q) => requestIds.contains(q.quoteRequestId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (quotes.isEmpty) {
      return const EmptyState(
        message: 'עדיין לא הוגשו הצעות בפרויקט זה',
        icon: Icons.request_quote_outlined,
      );
    }

    final requestById = {for (final r in project.requests) r.id: r};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final q in quotes)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => context.push(
                '/supplier/order/${q.id}?requestId=${q.quoteRequestId}',
              ),
              title: Text(requestById[q.quoteRequestId]?.customerName ?? ''),
              subtitle: Text(SupplierQuoteStatus.displayLabel(q.status)),
              trailing: Text(
                currency.format(q.displayTotal),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _SupplierOrdersTab extends StatelessWidget {
  const _SupplierOrdersTab({required this.project, required this.myQuotes});

  final SupplierProjectGroup project;
  final List<SupplierQuote> myQuotes;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');
    final orders = supplierOrdersFor(project.requests, myQuotes);

    if (orders.isEmpty) {
      return const EmptyState(
        message: 'עדיין אין הזמנות מאושרות בפרויקט זה',
        icon: Icons.receipt_long_outlined,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final row in orders)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => context.push(
                '/supplier/order/${row.quote.id}?requestId=${row.request.id}',
              ),
              title: Text(row.request.customerName),
              subtitle: Text(SupplierQuoteStatus.displayLabel(row.quote.status)),
              trailing: Text(
                currency.format(row.quote.displayTotal),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _SupplierDeliveriesTab extends StatelessWidget {
  const _SupplierDeliveriesTab({required this.project});

  final SupplierProjectGroup project;

  @override
  Widget build(BuildContext context) {
    final deliveries = project.requests
        .where(Delivery.isDelivery)
        .map((r) => Delivery.fromRequest(r))
        .toList()
      ..sort(compareDeliveries);

    if (deliveries.isEmpty) {
      return const EmptyState(
        message: 'אין משלוחים בפרויקט זה',
        icon: Icons.local_shipping_outlined,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final d in deliveries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DeliveryCard(
              delivery: d,
              onTap: () => showDeliveryDetailSheet(
                context,
                delivery: d,
                openOrderLabel: 'פתיחת ההזמנה',
                onOpenOrder: (d.request.approvedQuoteId?.isNotEmpty ?? false)
                    ? () => context.push(
                          '/supplier/order/${d.request.approvedQuoteId}?requestId=${d.id}',
                        )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _ContractorMeta extends StatelessWidget {
  const _ContractorMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 5),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _SupplierHistoryTab extends StatelessWidget {
  const _SupplierHistoryTab({required this.project, required this.myQuotes});

  final SupplierProjectGroup project;
  final List<SupplierQuote> myQuotes;

  @override
  Widget build(BuildContext context) {
    final requestIds = project.requests.map((r) => r.id).toSet();
    final completed = myQuotes
        .where((q) =>
            requestIds.contains(q.quoteRequestId) &&
            (q.status == SupplierQuoteStatus.shipped ||
                q.status == SupplierQuoteStatus.rejected ||
                q.status == SupplierQuoteStatus.notSelected))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');
    final requestById = {for (final r in project.requests) r.id: r};

    if (completed.isEmpty) {
      return const EmptyState(
        message: 'אין עדיין היסטוריה בפרויקט זה',
        icon: Icons.history,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final q in completed)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(requestById[q.quoteRequestId]?.customerName ?? ''),
              subtitle: Text(SupplierQuoteStatus.displayLabel(q.status)),
              trailing: Text(currency.format(q.displayTotal)),
            ),
          ),
      ],
    );
  }
}

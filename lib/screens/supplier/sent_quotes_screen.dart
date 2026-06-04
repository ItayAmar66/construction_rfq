import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../models/supplier_quote_item.dart';
import '../../providers/providers.dart';
import '../../services/quote_service.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/supplier_quote_status.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_status_badge.dart';

enum _SentQuotesFilter { all, active, outdated, won }

class SentQuotesScreen extends ConsumerStatefulWidget {
  const SentQuotesScreen({super.key});

  @override
  ConsumerState<SentQuotesScreen> createState() => _SentQuotesScreenState();
}

class _SentQuotesScreenState extends ConsumerState<SentQuotesScreen> {
  _SentQuotesFilter _filter = _SentQuotesFilter.all;

  List<SupplierQuote> _applyFilter(List<SupplierQuote> quotes) {
    switch (_filter) {
      case _SentQuotesFilter.active:
        return quotes
            .where(
              (q) =>
                  q.status == SupplierQuoteStatus.sent && !q.isOutdated,
            )
            .toList();
      case _SentQuotesFilter.outdated:
        return quotes.where((q) => q.isOutdated).toList();
      case _SentQuotesFilter.won:
        return quotes
            .where((q) => q.status == SupplierQuoteStatus.approved)
            .toList();
      case _SentQuotesFilter.all:
        return quotes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(supplierSentQuotesProvider);
    final sentCount = ref.watch(supplierSentQuotesCountProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');

    return Scaffold(
      appBar: SecondaryAppBar(
        title: HebrewStrings.sentQuotes,
        count: sentCount,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _SentQuotesFilter.values.map((f) {
                final label = switch (f) {
                  _SentQuotesFilter.all => 'הכל',
                  _SentQuotesFilter.active => 'פעילות',
                  _SentQuotesFilter.outdated => 'מיושנות',
                  _SentQuotesFilter.won => 'זכיות',
                };
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: quotesAsync.when(
              loading: () => const LoadingView(),
              error: (_, __) =>
                  const Center(child: Text(HebrewStrings.errorGeneric)),
              data: (quotes) {
                final filtered = _applyFilter(quotes);
                if (filtered.isEmpty) {
                  return const EmptyState(
                    message: 'אין הצעות בסינון זה',
                    icon: Icons.send_outlined,
                  );
                }
                return DateGroupedListView<SupplierQuote>(
                  items: filtered,
                  dateFor: (q) => q.createdAt,
                  itemBuilder: (context, quote) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (quote.isOutdated)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'מיושנת — הלקוח עדכן את הבקשה',
                              style: TextStyle(
                                color: AppTheme.amber,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      AppListCard(
                        onTap: null,
                        title: currency.format(quote.displayTotal),
                        subtitle: quote.deliveryTime,
                        meta: dateFormat.format(quote.createdAt),
                        trailing: QuoteStatusBadge(status: quote.status),
                        leading: Icon(
                          quote.isOutdated
                              ? Icons.history_toggle_off
                              : Icons.receipt_long_outlined,
                          color: quote.isOutdated
                              ? AppTheme.amber
                              : AppTheme.teal,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          right: AppSpacing.sm,
                          bottom: AppSpacing.sm,
                        ),
                        child: _QuoteItemsLoader(quote: quote),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteItemsLoader extends ConsumerWidget {
  const _QuoteItemsLoader({required this.quote});

  final SupplierQuote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<SupplierQuoteItem>>(
      future: quote.items.isNotEmpty
          ? Future.value(quote.items)
          : ref.read(quoteServiceProvider).getSupplierQuoteItems(quote.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final items = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items.take(4).map((item) {
            return Text(
              '• ${item.productName} — ₪${item.totalItemPrice.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall,
            );
          }).toList(),
        );
      },
    );
  }
}

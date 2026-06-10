import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/request_display_helpers.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/catalog/quote_match_summary_chips.dart';
import '../../widgets/catalog/supplier_quote_items_section.dart';
import '../../widgets/projects/project_context_chip.dart';
import '../../widgets/quote_status_badge.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class SentQuotesScreen extends ConsumerWidget {
  const SentQuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(supplierSentQuotesProvider);
    final sentCount = ref.watch(supplierSentQuotesCountProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');

    return Scaffold(
      appBar: SecondaryAppBar(
        title: HebrewStrings.sentQuotes,
        count: sentCount,
      ),
      body: quotesAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => AppErrorCenter(
          message: HebrewStrings.errorLoadSentQuotes,
          onRetry: () => ref.invalidate(supplierSentQuotesProvider),
        ),
        data: (quotes) {
          if (quotes.isEmpty) {
            return const EmptyState(
              message: HebrewStrings.emptySentQuotes,
              icon: Icons.send_outlined,
              hint: HebrewStrings.emptySentQuotesHint,
            );
          }
          return DateGroupedListView<SupplierQuote>(
            items: quotes,
            dateFor: (q) => q.createdAt,
            itemBuilder: (context, quote) {
              return Consumer(
                builder: (context, ref, _) {
                  final request = ref
                      .watch(quoteRequestProvider(quote.quoteRequestId))
                      .valueOrNull;
                  final requestItems = request?.items ?? const [];
                  return Card(
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              RequestDisplayHelpers.sentQuoteTitle(
                                customerName: request?.customerName,
                                customerCity: request?.customerCity,
                                requestItems: requestItems,
                              ),
                            ),
                          ),
                          QuoteStatusBadge(status: quote.status),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (quote.isOutdated)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text(
                                'הלקוח עדכן את הבקשה לאחר שליחת ההצעה',
                                style: TextStyle(
                                  color: AppTheme.amber,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          Text(
                            '${RequestDisplayHelpers.sentQuoteSubtitle(
                              customerCity: request?.customerCity,
                              requestItems: requestItems,
                              deliveryTime: quote.deliveryTime,
                            )}\n${dateFormat.format(quote.createdAt)}',
                          ),
                          if (request != null)
                            ProjectContextChip(request: request),
                          QuoteMatchSummaryChips(
                            items: quote.items,
                            requestItems: requestItems,
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: SupplierQuoteItemsSection(
                            quote: quote,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

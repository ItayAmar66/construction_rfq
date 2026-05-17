import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/quote_request.dart';
import '../../models/quote_status.dart';
import '../../models/request_type.dart';
import '../../models/supplier_quote.dart';
import '../../models/supplier_quote_item.dart';
import '../../providers/providers.dart';
import '../../services/quote_service.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_status_badge.dart';
import '../../widgets/request_timeline.dart';
import '../../widgets/status_chip.dart';

class QuoteCompareScreen extends ConsumerWidget {
  const QuoteCompareScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(requestQuotesProvider(requestId));
    final requestAsync = ref.watch(quoteRequestProvider(requestId));
    final customerId =
        ref.watch(authSessionProvider).valueOrNull?.profile?.id;

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.compareQuotes),
      body: requestAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const Center(child: Text(HebrewStrings.errorGeneric)),
        data: (request) {
          if (request == null) {
            return const Center(child: Text('הבקשה לא נמצאה'));
          }
          return quotesAsync.when(
            loading: () => const LoadingView(),
            error: (_, __) =>
                const Center(child: Text(HebrewStrings.errorGeneric)),
            data: (quotes) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  StatusChip(status: request.status),
                  if (request.isTender) ...[
                    const SizedBox(height: 6),
                    Text(
                      RequestType.tender.label,
                      style: TextStyle(
                        color: Colors.deepPurple.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  RequestTimeline(request: request),
                  const SizedBox(height: 12),
                  _RequestActions(
                    request: request,
                    customerId: customerId,
                  ),
                  const SizedBox(height: 16),
                  if (quotes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('עדיין לא התקבלו הצעות לבקשה זו'),
                      ),
                    )
                  else
                    ...quotes.map(
                      (q) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _QuoteCard(
                          quote: q,
                          ref: ref,
                          requestId: requestId,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestActions extends ConsumerWidget {
  const _RequestActions({
    required this.request,
    required this.customerId,
  });

  final QuoteRequest request;
  final String? customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (customerId == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (request.isEditable)
          OutlinedButton.icon(
            onPressed: () => context.push('/edit-request/${request.id}'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('ערוך בקשה'),
          ),
        if (request.isEditable || request.status == QuoteRequestStatus.sent)
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('מחק בקשה'),
                  content: const Text('למחוק או לבטל את הבקשה?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('ביטול'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('מחק'),
                    ),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              try {
                await ref.read(quoteServiceProvider).deleteOrCancelQuoteRequest(
                      requestId: request.id,
                      customerId: customerId!,
                    );
                ref.invalidate(customerRequestsProvider);
                if (context.mounted) context.go('/my-requests');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('מחק בקשה'),
          ),
        if (request.isTender && request.isTenderActive)
          FilledButton.tonalIcon(
            onPressed: () async {
              try {
                await ref.read(quoteServiceProvider).closeTender(
                      requestId: request.id,
                      customerId: customerId!,
                    );
                ref.invalidate(quoteRequestProvider(request.id));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            icon: const Icon(Icons.gavel_outlined, size: 18),
            label: const Text('סגור מכרז'),
          ),
      ],
    );
  }
}

class _QuoteItemsList extends StatelessWidget {
  const _QuoteItemsList({required this.quote, required this.ref});

  final SupplierQuote quote;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (quote.items.isNotEmpty) {
      return Column(
        children: quote.items.map(_itemTile).toList(),
      );
    }

    return FutureBuilder<List<SupplierQuoteItem>>(
      future: ref.read(quoteServiceProvider).getSupplierQuoteItems(quote.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }
        return Column(children: snapshot.data!.map(_itemTile).toList());
      },
    );
  }

  Widget _itemTile(SupplierQuoteItem item) {
    return ListTile(
      dense: true,
      title: Text(item.productName),
      subtitle: Text('${item.requestedQuantity} × ₪${item.unitPrice}'),
      trailing: Text('₪${item.totalItemPrice.toStringAsFixed(0)}'),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.ref,
    required this.requestId,
  });

  final SupplierQuote quote;
  final WidgetRef ref;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push(
          '/quote-detail/${quote.id}?requestId=$requestId',
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quote.supplierName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  QuoteStatusBadge(status: quote.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'סה״כ: ₪${quote.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 15),
              ),
              Text('אספקה: ${quote.deliveryTime}'),
              const SizedBox(height: 8),
              _QuoteItemsList(quote: quote, ref: ref),
            ],
          ),
        ),
      ),
    );
  }
}

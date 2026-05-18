import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/quote_request.dart';
import '../../models/quote_status.dart';
import '../../models/supplier_quote.dart';
import '../../models/supplier_quote_item.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/app_fade_in.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_message.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_status_badge.dart';
import '../../widgets/request_timeline.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/tender_badge.dart';

class QuoteCompareScreen extends ConsumerWidget {
  const QuoteCompareScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(requestQuotesProvider(requestId));
    final requestAsync = ref.watch(quoteRequestProvider(requestId));
    final customerId =
        ref.watch(authSessionProvider).valueOrNull?.profile?.id;
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.compareQuotes),
      body: requestAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorMessage.fromError(
          e,
          onRetry: () => ref.invalidate(quoteRequestProvider(requestId)),
        ),
        data: (request) {
          if (request == null) {
            return const Center(child: Text('הבקשה לא נמצאה'));
          }
          return quotesAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorMessage.fromError(
              e,
              onRetry: () => ref.invalidate(requestQuotesProvider(requestId)),
            ),
            data: (quotes) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  AppFadeIn(
                    child: _RequestSummaryCard(
                      request: request,
                      customerId: customerId,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'הצעות שהתקבלו (${quotes.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (quotes.isEmpty)
                    const AppFadeIn(
                      child: EmptyState(
                        message: 'עדיין לא התקבלו הצעות לבקשה זו',
                        icon: Icons.compare_arrows,
                        hint: 'ספקים יוכלו להגיש הצעות בהמשך',
                        accentGradient: AppTheme.gradientTeal,
                      ),
                    )
                  else
                    ...quotes.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppFadeIn(
                          delay: Duration(milliseconds: 40 * e.key),
                          child: _QuoteCompareCard(
                            quote: e.value,
                            ref: ref,
                            requestId: requestId,
                            currency: currency,
                          ),
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

class _RequestSummaryCard extends ConsumerWidget {
  const _RequestSummaryCard({
    required this.request,
    required this.customerId,
  });

  final QuoteRequest request;
  final String? customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(status: request.status),
              if (request.isTender) const TenderBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          RequestTimeline(request: request),
          if (customerId != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _RequestActions(
              request: request,
              customerId: customerId!,
            ),
          ],
        ],
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
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        if (request.isEditable)
          OutlinedButton.icon(
            onPressed: () => context.push('/edit-request/${request.id}'),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('ערוך'),
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
                      child: const Text(
                        'מחק',
                        style: TextStyle(color: AppTheme.danger),
                      ),
                    ),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              try {
                await ref.read(quoteServiceProvider).deleteOrCancelQuoteRequest(
                      requestId: request.id,
                      customerId: customerId,
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
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('מחק'),
          ),
        if (request.isTender && request.isTenderActive)
          FilledButton.tonalIcon(
            onPressed: () async {
              try {
                await ref.read(quoteServiceProvider).closeTender(
                      requestId: request.id,
                      customerId: customerId,
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
            icon: const Icon(Icons.gavel_outlined, size: 16),
            label: const Text('סגור מכרז'),
          ),
      ],
    );
  }
}

class _QuoteCompareCard extends StatefulWidget {
  const _QuoteCompareCard({
    required this.quote,
    required this.ref,
    required this.requestId,
    required this.currency,
  });

  final SupplierQuote quote;
  final WidgetRef ref;
  final String requestId;
  final NumberFormat currency;

  @override
  State<_QuoteCompareCard> createState() => _QuoteCompareCardState();
}

class _QuoteCompareCardState extends State<_QuoteCompareCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: AppTheme.cardDecoration(),
        child: InkWell(
          onTap: () => context.push(
            '/quote-detail/${widget.quote.id}?requestId=${widget.requestId}',
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.quote.supplierName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    QuoteStatusBadge(status: widget.quote.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.currency.format(widget.quote.totalPrice),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                      ),
                ),
                Text(
                  'אספקה: ${widget.quote.deliveryTime}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _QuoteItemsPreview(
                  quote: widget.quote,
                  ref: widget.ref,
                  expanded: _expanded,
                  onToggle: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteItemsPreview extends StatelessWidget {
  const _QuoteItemsPreview({
    required this.quote,
    required this.ref,
    required this.expanded,
    required this.onToggle,
  });

  final SupplierQuote quote;
  final WidgetRef ref;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupplierQuoteItem>>(
      future: quote.items.isNotEmpty
          ? Future.value(quote.items)
          : ref.read(quoteServiceProvider).getSupplierQuoteItems(quote.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final items = snapshot.data!;
        if (items.isEmpty) return const SizedBox.shrink();

        final visible = expanded ? items : items.take(2).toList();
        final hidden = items.length - visible.length;

        return Column(
          children: [
            ...visible.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '₪${item.totalItemPrice.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            if (items.length > 2)
              TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(expanded ? 'הסתר פריטים' : 'עוד $hidden פריטים'),
              ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/quote_request.dart';
import '../../models/quote_status.dart';
import '../../models/supplier_quote.dart';
import '../../models/supplier_quote_item.dart';
import '../../providers/rfq_draft_provider.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/app_fade_in.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_message.dart';
import '../../widgets/loading_view.dart';
import '../../utils/quote_comparison.dart';
import '../../widgets/quote_financial_summary.dart';
import '../../widgets/quote_status_badge.dart';
import '../../widgets/request_timeline.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/supplier_trust_card.dart';
import '../../widgets/tender_badge.dart';
import '../../widgets/tender_bid_history_panel.dart';
import '../../widgets/tender_countdown_banner.dart';
import '../../widgets/tender_rules_panel.dart';
import '../../utils/supplier_quote_status.dart';
import '../../utils/tender_anonymity.dart';

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
              final hints = QuoteComparisonHints.fromQuotes(quotes);
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  AppFadeIn(
                    child: _RequestSummaryCard(
                      request: request,
                      customerId: customerId,
                    ),
                  ),
                  if (request.isTender) ...[
                    const TenderRulesPanel(compact: true),
                    const SizedBox(height: AppSpacing.sm),
                    TenderCountdownBanner(
                      endTime: request.tenderEndTime,
                      active: request.isTenderActive,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TenderBidHistoryPanel(
                      quotes: quotes,
                      request: request,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
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
                            request: request,
                            allQuotes: quotes,
                            requestId: requestId,
                            isBestPrice:
                                hints.bestPriceQuoteIds.contains(e.value.id),
                            isFastestDelivery: hints
                                .fastestDeliveryQuoteIds
                                .contains(e.value.id),
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
        OutlinedButton.icon(
          onPressed: () => _duplicateRequest(context, ref, request),
          icon: const Icon(Icons.copy_outlined, size: 16),
          label: const Text('שכפל בקשה'),
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

  Future<void> _duplicateRequest(
    BuildContext context,
    WidgetRef ref,
    QuoteRequest request,
  ) async {
    try {
      final items =
          await ref.read(quoteServiceProvider).getRequestItems(request.id);
      if (items.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('לא נמצאו פריטים לשכפול')),
          );
        }
        return;
      }
      ref.read(rfqDraftProvider.notifier).replaceAll(items);
      if (context.mounted) context.push('/cart');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }
}

class _QuoteCompareCard extends StatefulWidget {
  const _QuoteCompareCard({
    required this.quote,
    required this.ref,
    required this.request,
    required this.allQuotes,
    required this.requestId,
    this.isBestPrice = false,
    this.isFastestDelivery = false,
  });

  final SupplierQuote quote;
  final WidgetRef ref;
  final QuoteRequest request;
  final List<SupplierQuote> allQuotes;
  final String requestId;
  final bool isBestPrice;
  final bool isFastestDelivery;

  @override
  State<_QuoteCompareCard> createState() => _QuoteCompareCardState();
}

class _QuoteCompareCardState extends State<_QuoteCompareCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hideIdentity =
        widget.request.isTender && widget.request.isTenderActive;
    final displayName = hideIdentity
        ? TenderAnonymity.labelForQuote(
            widget.quote,
            widget.allQuotes,
            widget.request,
          )
        : widget.quote.supplierName;

    final isApproved = widget.quote.status == SupplierQuoteStatus.approved;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: AppTheme.cardDecoration(
          elevation: widget.isBestPrice ? 3 : 2,
        ).copyWith(
          border: Border.all(
            color: isApproved
                ? AppTheme.emerald
                : widget.isBestPrice
                    ? AppTheme.teal
                    : AppTheme.borderColor.withValues(alpha: 0.9),
            width: isApproved || widget.isBestPrice ? 1.5 : 1,
          ),
        ),
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
                if (widget.isBestPrice || isApproved)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        if (widget.isBestPrice)
                          _CompareBadge(
                            label: 'מחיר מוביל',
                            color: AppTheme.teal,
                            icon: Icons.sell_outlined,
                          ),
                        if (widget.isFastestDelivery)
                          _CompareBadge(
                            label: 'אספקה מהירה',
                            color: AppTheme.navy,
                            icon: Icons.local_shipping_outlined,
                          ),
                        if (isApproved)
                          _CompareBadge(
                            label: 'אושרה',
                            color: AppTheme.emerald,
                            icon: Icons.check_circle_outline,
                          ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (widget.quote.isTenderBid && widget.quote.bidVersion > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'v${widget.quote.bidVersion}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.teal,
                          ),
                        ),
                      ),
                    QuoteStatusBadge(status: widget.quote.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!hideIdentity)
                  SupplierTrustCard(
                    supplierId: widget.quote.supplierId,
                    supplierName: widget.quote.supplierName,
                    compact: true,
                  )
                else
                  Text(
                    'זהות הספק תיחשף לאחר סגירת המכרז',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                QuoteFinancialSummary(
                  quote: widget.quote,
                  compact: true,
                  isBestPrice: widget.isBestPrice,
                  isFastestDelivery: widget.isFastestDelivery,
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

class _CompareBadge extends StatelessWidget {
  const _CompareBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

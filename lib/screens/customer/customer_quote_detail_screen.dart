import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../models/supplier_quote_item.dart';
import '../../models/quote_request_item.dart';
import '../../models/user_type.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../analytics/catalog_rfq_analytics.dart';
import '../../utils/customer_quote_match_helpers.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/supplier_quote_status.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/customer_quote_approval_dialog.dart';
import '../../widgets/catalog/customer_quote_line_match_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_financial_summary.dart';
import '../../widgets/quote_status_badge.dart';
import '../../widgets/supplier_trust_card.dart';

class CustomerQuoteDetailScreen extends ConsumerStatefulWidget {
  const CustomerQuoteDetailScreen({
    super.key,
    required this.quoteId,
    required this.requestId,
  });

  final String quoteId;
  final String requestId;

  @override
  ConsumerState<CustomerQuoteDetailScreen> createState() =>
      _CustomerQuoteDetailScreenState();
}

class _CustomerQuoteDetailScreenState
    extends ConsumerState<CustomerQuoteDetailScreen> {
  bool _busy = false;

  Future<void> _approve(SupplierQuote quote) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final items = quote.items.isNotEmpty
        ? quote.items
        : await ref.read(quoteServiceProvider).getSupplierQuoteItems(quote.id);
    if (!mounted) return;

    final confirmed = await CustomerQuoteApprovalDialog.show(
      context: context,
      quote: quote,
      items: items,
    );
    if (confirmed != true || !mounted) return;

    if (quoteHasAlternativeItems(items)) {
      ref.read(catalogRfqAnalyticsProvider).track(
            CatalogRfqEventNames.approvalWithAlternatives,
            {'quoteId': quote.id, 'requestId': widget.requestId},
          );
    }

    setState(() => _busy = true);
    try {
      await ref.read(quoteServiceProvider).approveCustomerQuote(
            quoteId: quote.id,
            requestId: widget.requestId,
            customerId: user.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ההצעה אושרה וההזמנה נשלחה לספק')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(SupplierQuote quote) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('דחיית הצעה'),
        content: const Text('האם לדחות הצעה זו?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(HebrewStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(HebrewStrings.yes),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(quoteServiceProvider).rejectCustomerQuote(
            quoteId: quote.id,
            requestId: widget.requestId,
            customerId: user.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ההצעה נדחתה')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quoteAsync = ref.watch(supplierQuoteProvider(widget.quoteId));
    final requestAsync = ref.watch(quoteRequestProvider(widget.requestId));
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.quoteDetails),
      body: quoteAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const Center(child: Text(HebrewStrings.errorGeneric)),
        data: (quote) {
          if (quote == null) {
            return const Center(child: Text('ההצעה לא נמצאה'));
          }

          final request = requestAsync.valueOrNull;
          final supplierTypeLabel =
              UserType.fromString(quote.supplierType).label;
          final canActOnQuote = quote.status == SupplierQuoteStatus.sent;
          final requestHasOtherApproval = request != null &&
              request.hasApprovedQuote &&
              request.approvedQuoteId != quote.id;
          final canApprove = canActOnQuote &&
              !requestHasOtherApproval &&
              !_busy &&
              ref.watch(canApproveQuoteProvider);
          final canReject =
              canActOnQuote &&
              !(request?.hasApprovedQuote ?? false) &&
              !_busy;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        quote.supplierName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    QuoteStatusBadge(status: quote.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SupplierTrustCard(
                  supplierId: quote.supplierId,
                  supplierName: quote.supplierName,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QuoteFinancialSummary(quote: quote),
                      const SizedBox(height: AppSpacing.xs),
                      _infoRow('סוג ספק', supplierTypeLabel),
                      _infoRow(
                        HebrewStrings.requestDate,
                        dateFormat.format(quote.createdAt),
                      ),
                      if (quote.notes != null && quote.notes!.isNotEmpty)
                        _infoRow(HebrewStrings.notes, quote.notes!),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  HebrewStrings.productsInRequest,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _QuoteItemsSection(
                  quote: quote,
                  requestId: widget.requestId,
                ),
                if (canApprove || canReject) ...[
                  const SizedBox(height: 20),
                  if (requestHasOtherApproval)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'כבר אושרה הצעה אחרת לבקשה זו',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.amber,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (canApprove)
                    FilledButton(
                      onPressed: () => _approve(quote),
                      child: const Text(HebrewStrings.approveQuote),
                    ),
                  if (canReject) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _reject(quote),
                      child: const Text(HebrewStrings.rejectQuote),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      context.push('/compare-quotes/${widget.requestId}'),
                  child: const Text(HebrewStrings.compareQuotes),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _QuoteItemsSection extends ConsumerWidget {
  const _QuoteItemsSection({
    required this.quote,
    required this.requestId,
  });

  final SupplierQuote quote;
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestItemsAsync = ref.watch(quoteRequestProvider(requestId));

    Widget buildList(
      List<SupplierQuoteItem> items,
      List<QuoteRequestItem> requestItems,
    ) {
      final requestItemsById = indexRequestItemsById(requestItems);
      return Column(
        children: items
            .map(
              (item) => CustomerQuoteLineMatchCard(
                quoteItem: item,
                requestLine: requestLineForQuoteItem(item, requestItemsById),
              ),
            )
            .toList(),
      );
    }

    if (quote.items.isNotEmpty) {
      final requestItems = requestItemsAsync.valueOrNull?.items ?? const [];
      return buildList(quote.items, requestItems);
    }

    return FutureBuilder<List<SupplierQuoteItem>>(
      future: ref.read(quoteServiceProvider).getSupplierQuoteItems(quote.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final items = snapshot.data ?? [];
        final requestItems = requestItemsAsync.valueOrNull?.items ?? const [];
        return buildList(items, requestItems);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../models/supplier_quote_item.dart';
import '../../models/user_type.dart';
import '../../providers/providers.dart';
import '../../services/quote_service.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/supplier_quote_status.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_status_badge.dart';

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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('אישור הצעה'),
        content: Text(
          'לאשר את הצעת ${quote.supplierName} בסך '
          '₪${quote.totalPrice.toStringAsFixed(0)}?',
        ),
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
          final canApprove =
              canActOnQuote && !requestHasOtherApproval && !_busy;
          final canReject =
              canActOnQuote &&
              !(request?.hasApprovedQuote ?? false) &&
              !_busy;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                quote.supplierName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            QuoteStatusBadge(status: quote.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _infoRow('סוג ספק', supplierTypeLabel),
                        _infoRow(
                          HebrewStrings.deliveryTime,
                          quote.deliveryTime,
                        ),
                        if (quote.notes != null && quote.notes!.isNotEmpty)
                          _infoRow(HebrewStrings.notes, quote.notes!),
                        _infoRow(
                          HebrewStrings.requestDate,
                          dateFormat.format(quote.createdAt),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  HebrewStrings.productsInRequest,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _QuoteItemsSection(quote: quote),
                const SizedBox(height: 16),
                Card(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            HebrewStrings.totalQuote,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '₪${quote.totalPrice.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (canApprove || canReject) ...[
                  const SizedBox(height: 20),
                  if (requestHasOtherApproval)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'כבר אושרה הצעה אחרת לבקשה זו',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.orange.shade800,
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
              style: TextStyle(
                color: Colors.grey.shade700,
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
  const _QuoteItemsSection({required this.quote});

  final SupplierQuote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (quote.items.isNotEmpty) {
      return Column(
        children: quote.items.map((item) => _LineCard(item: item)).toList(),
      );
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
        return Column(
          children: items.map((item) => _LineCard(item: item)).toList(),
        );
      },
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.item});

  final SupplierQuoteItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.productName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text('${HebrewStrings.quantity}: ${item.requestedQuantity}'),
            Text(
              '${HebrewStrings.unitPrice}: ₪${item.unitPrice.toStringAsFixed(2)}',
            ),
            Text(
              '${HebrewStrings.totalPrice}: ₪${item.totalItemPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (item.notes != null && item.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${HebrewStrings.notes}: ${item.notes}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

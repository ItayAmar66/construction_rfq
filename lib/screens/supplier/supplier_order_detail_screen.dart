import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../models/user_type.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/supplier_quote_status.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/supplier_quote_items_section.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/mark_seen_on_open.dart';
import '../../widgets/quote_status_badge.dart';

class SupplierOrderDetailScreen extends ConsumerStatefulWidget {
  const SupplierOrderDetailScreen({
    super.key,
    required this.quoteId,
    required this.requestId,
  });

  final String quoteId;
  final String requestId;

  @override
  ConsumerState<SupplierOrderDetailScreen> createState() =>
      _SupplierOrderDetailScreenState();
}

class _SupplierOrderDetailScreenState
    extends ConsumerState<SupplierOrderDetailScreen> {
  bool _busy = false;

  Future<void> _markShipped(SupplierQuote quote) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('סימון כנשלח'),
        content: const Text('לסמן שההזמנה נשלחה ללקוח?'),
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
      await ref.read(quoteServiceProvider).markSupplierOrderShipped(
            quoteId: quote.id,
            requestId: widget.requestId,
            supplierId: user.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ההזמנה סומנה כנשלחה')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
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

    return MarkSeenOnOpen(
      onMarkSeen: (ref) async {
        final user = ref.read(authSessionProvider).valueOrNull?.profile;
        if (user == null) return;
        await ref.read(quoteServiceProvider).markSupplierOrderSeen(
              supplierId: user.id,
              quoteId: widget.quoteId,
            );
      },
      child: Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.orderDetails),
      body: quoteAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const Center(child: Text(HebrewStrings.errorGeneric)),
        data: (quote) {
          if (quote == null) {
            return const Center(child: Text('ההזמנה לא נמצאה'));
          }

          final request = requestAsync.valueOrNull;
          final canMarkShipped = quote.status == SupplierQuoteStatus.approved &&
              !_busy &&
              ref.watch(canMarkShippedProvider);

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
                          children: [
                            Expanded(
                              child: Text(
                                request?.customerName ?? 'לקוח',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            QuoteStatusBadge(status: quote.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (request != null) ...[
                          _infoRow(HebrewStrings.phone, request.customerPhone),
                          _infoRow(HebrewStrings.city, request.customerCity),
                          _infoRow(
                            'סוג לקוח',
                            UserType.fromString(request.customerType).label,
                          ),
                        ],
                        _infoRow(
                          HebrewStrings.deliveryTime,
                          quote.deliveryTime,
                        ),
                        _infoRow(
                          HebrewStrings.requestDate,
                          dateFormat.format(quote.createdAt),
                        ),
                        if (quote.notes != null && quote.notes!.isNotEmpty)
                          _infoRow(HebrewStrings.notes, quote.notes!),
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
                SupplierQuoteItemsSection(quote: quote),
                const SizedBox(height: 16),
                Card(
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
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (canMarkShipped) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _markShipped(quote),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text(HebrewStrings.markAsShipped),
                  ),
                ],
              ],
            ),
          );
        },
      ),
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
            width: 100,
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

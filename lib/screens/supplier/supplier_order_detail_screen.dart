import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/delivery.dart';
import '../../models/quote_status.dart';
import '../../models/receipt_status.dart';
import '../../models/receipt_checklist_item.dart';
import '../../models/supplier_quote.dart';
import '../../models/user_type.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/app_theme.dart';
import '../../utils/supplier_quote_status.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/supplier_quote_items_section.dart';
import '../../widgets/deliveries/delivery_widgets.dart';
import '../../widgets/deliveries/mark_shipped_sheet.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/mark_seen_on_open.dart';
import '../../widgets/summary_widgets.dart';

import '../../widgets/status_chip.dart';
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

    final result = await showMarkShippedSheet(
      context,
      orderTitle: quote.supplierName,
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(quoteServiceProvider).markSupplierOrderShipped(
            quoteId: quote.id,
            requestId: widget.requestId,
            supplierId: user.id,
            supplierOrgId: ref.read(primaryOrgIdProvider),
            expectedDeliveryDate: result.expectedDeliveryDate,
            trackingReference: result.trackingReference,
            carrierName: result.carrierName,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('המשלוח סומן כנשלח וממתין לאישור קבלה'),
        ),
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
          final pendingReceipt = request?.status ==
                  QuoteRequestStatus.pendingReceipt ||
              request?.receiptStatus == ReceiptStatus.pendingReceipt;
          final receiptComplete =
              request?.receiptStatus == ReceiptStatus.receivedFull;
          final receiptIssues =
              request?.receiptStatus == ReceiptStatus.receivedWithIssues;

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
                            EntityAvatar(
                              name: request?.customerName ?? 'לקוח',
                              color: AppTheme.navy,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                request?.customerName ?? 'לקוח',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            StatusChip.quote(quote.status),
                          ],
                        ),
                        if (pendingReceipt) ...[
                          const SizedBox(height: 8),
                          Text(
                            'ממתין לאישור קבלה',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (receiptComplete) ...[
                          const SizedBox(height: 8),
                          Text(
                            'המשלוח התקבל ואושר',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.emerald,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (receiptIssues) ...[
                          const SizedBox(height: 8),
                          Text(
                            'דווחה חריגה בקבלת המשלוח',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                if (request != null &&
                    Delivery.isDelivery(request) &&
                    request.shippedAt != null) ...[
                  const SizedBox(height: 12),
                  _DeliveryStatusCard(
                    delivery: Delivery.fromRequest(
                      request,
                      amount: quote.displayTotal,
                    ),
                  ),
                ],
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
                PrimaryTotalBox(
                  caption: HebrewStrings.totalQuote,
                  amount: NumberFormat.currency(
                    locale: 'he_IL',
                    symbol: '₪',
                    decimalDigits: 0,
                  ).format(quote.displayTotal),
                ),
                if (canMarkShipped) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _markShipped(quote),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text(HebrewStrings.markAsShipped),
                  ),
                ],
                if (receiptIssues &&
                    request != null &&
                    request.receiptChecklist.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'פריטים עם חריגות',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...request.receiptChecklist
                      .where((item) => item.condition.isIssue)
                      .map(
                        (item) => Card(
                          child: ListTile(
                            title: Text(item.productName),
                            subtitle: Text(
                              '${item.condition.label}'
                              '${item.issueNotes != null && item.issueNotes!.isNotEmpty ? ' · ${item.issueNotes}' : ''}',
                            ),
                            trailing: Text(
                              '${item.receivedQuantity}/${item.orderedQuantity}',
                            ),
                          ),
                        ),
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

class _DeliveryStatusCard extends StatelessWidget {
  const _DeliveryStatusCard({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final eta = deliveryEtaLabel(delivery);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'סטטוס משלוח',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                DeliveryStageChip(stage: delivery.stage, compact: true),
              ],
            ),
            if (delivery.stage.isOpen && eta != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  eta,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: delivery.isOverdue ? AppTheme.danger : AppTheme.navy,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            DeliveryTimeline(delivery: delivery),
          ],
        ),
      ),
    );
  }
}

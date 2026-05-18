import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/quote_request_item.dart';
import '../../models/supplier_quote.dart';
import '../../providers/providers.dart';
import '../../services/quote_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/supplier_quote_status.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/form_section.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_line_form_card.dart';
import '../../widgets/tender_badge.dart';

class TenderBidScreen extends ConsumerStatefulWidget {
  const TenderBidScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<TenderBidScreen> createState() => _TenderBidScreenState();
}

class _LineState {
  _LineState({
    required this.item,
    this.include = true,
    this.unitPrice = 0,
  });

  final QuoteRequestItem item;
  bool include;
  double unitPrice;

  double get total => unitPrice * item.quantity;
}

class _TenderBidScreenState extends ConsumerState<TenderBidScreen> {
  final _deliveryController = TextEditingController();
  final _notesController = TextEditingController();
  List<_LineState> _lines = [];
  bool _linesReady = false;
  bool _submitting = false;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadLines();
  }

  Future<void> _loadLines() async {
    final items =
        await ref.read(quoteServiceProvider).getRequestItems(widget.requestId);
    if (mounted) {
      setState(() {
        _lines = items.map((i) => _LineState(item: i)).toList();
        _linesReady = true;
      });
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _deliveryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatCountdown(DateTime? end) {
    if (end == null) return '--:--:--';
    final remaining = end.difference(DateTime.now());
    if (remaining.isNegative) return '00:00:00';
    final h = remaining.inHours.remainder(24).toString().padLeft(2, '0');
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (remaining.inDays > 0) {
      return '${remaining.inDays} ימים $h:$m:$s';
    }
    return '$h:$m:$s';
  }

  SupplierQuote? _myActiveBid(
    List<SupplierQuote> sent,
    String supplierId,
  ) {
    final mine = sent
        .where(
          (q) =>
              q.quoteRequestId == widget.requestId &&
              q.supplierId == supplierId &&
              q.status == SupplierQuoteStatus.sent,
        )
        .toList();
    if (mine.isEmpty) return null;
    mine.sort((a, b) => b.bidVersion.compareTo(a.bidVersion));
    return mine.first;
  }

  Future<void> _submitCounter() async {
    if (_deliveryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('נא להזין זמן אספקה')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final user = ref.read(authSessionProvider).valueOrNull?.profile;
      if (user == null) throw Exception('לא מחובר');
      final inputs = _lines
          .map(
            (l) => SupplierQuoteLineInput(
              productId: l.item.productId,
              productName: l.item.productName,
              requestedQuantity: l.item.quantity,
              unitPrice: l.unitPrice,
              totalItemPrice: l.total,
              includeInQuote: l.include && l.unitPrice > 0,
            ),
          )
          .toList();

      await ref.read(quoteServiceProvider).submitTenderCounterBid(
            supplier: user,
            quoteRequestId: widget.requestId,
            deliveryTime: _deliveryController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            lines: inputs,
          );
      ref.invalidate(incomingRequestsProvider);
      ref.invalidate(supplierSentQuotesProvider);
      ref.invalidate(quoteRequestProvider(widget.requestId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('הצעת הנגד נשלחה')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(quoteRequestProvider(widget.requestId));
    final sentAsync = ref.watch(supplierSentQuotesProvider);
    final supplierId =
        ref.watch(authSessionProvider).valueOrNull?.profile?.id ?? '';
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'מכרז'),
      body: requestAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const Center(child: Text('שגיאה בטעינה')),
        data: (request) {
          if (request == null) {
            return const Center(child: Text('הבקשה לא נמצאה'));
          }
          final sent = sentAsync.valueOrNull ?? [];
          final myBid = _myActiveBid(sent, supplierId);
          final lowest = request.lowestBid;
          final myPrice = myBid?.totalPrice;
          final isLeading = lowest != null &&
              myPrice != null &&
              (myPrice <= lowest + 0.01);
          final active = request.isTenderActive;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    const TenderBadge(),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: AppTheme.cardDecoration(
                        color: AppTheme.amber.withValues(alpha: 0.06),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            active ? 'המכרז פעיל' : 'המכרז הסתיים',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            lowest != null
                                ? 'מחיר מוביל: ${currency.format(lowest)}'
                                : 'עדיין אין הצעות מובילות',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (myPrice != null) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'ההצעה שלך: ${currency.format(myPrice)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              isLeading
                                  ? 'אתה מוביל כרגע'
                                  : 'יש הצעה נמוכה יותר — הגש הצעת נגד',
                              style: TextStyle(
                                color: isLeading
                                    ? AppTheme.emerald
                                    : AppTheme.amber,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'נותרו ${_formatCountdown(request.tenderEndTime)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!active)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          'לא ניתן להגיש הצעות נגד — המכרז נסגר',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    if (!_linesReady)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else ...[
                      FormSection(
                        title: 'פרטי הצעת נגד',
                        child: Column(
                          children: [
                            ..._lines.map(
                              (line) => QuoteLineFormCard(
                                productName: line.item.productName,
                                quantityLabel:
                                    'כמות: ${line.item.quantity} ${line.item.unitType}',
                                unitPriceField: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'מחיר ליחידה',
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  enabled: active,
                                  onChanged: (v) {
                                    line.unitPrice = double.tryParse(v) ?? 0;
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                            TextField(
                              controller: _deliveryController,
                              enabled: active,
                              decoration: const InputDecoration(
                                labelText: 'זמן אספקה',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextField(
                              controller: _notesController,
                              enabled: active,
                              decoration:
                                  const InputDecoration(labelText: 'הערות'),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (active && _linesReady)
                FormStickyActions(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitCounter,
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            myBid == null
                                ? 'שלח הצעה למכרז'
                                : 'הגש הצעת נגד',
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

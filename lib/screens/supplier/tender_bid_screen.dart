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
import '../../widgets/app_back_leading.dart';
import '../../widgets/loading_view.dart';

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
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.cardDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.04),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            active ? 'המכרז פעיל' : 'המכרז הסתיים',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            lowest != null
                                ? 'המחיר המוביל כרגע: ${currency.format(lowest)}'
                                : 'עדיין אין הצעות מובילות',
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (myPrice != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'ההצעה שלך: ${currency.format(myPrice)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isLeading
                                  ? 'אתה מוביל כרגע'
                                  : 'יש הצעה נמוכה יותר — הגש הצעת נגד',
                              style: TextStyle(
                                color: isLeading
                                    ? Colors.green.shade700
                                    : AppTheme.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'נותרו ${_formatCountdown(request.tenderEndTime)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!active)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'לא ניתן להגיש הצעות נגד — המכרז נסגר',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (!_linesReady)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      Text(
                        'פרטי הצעת נגד',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ..._lines.map(
                        (line) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.item.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'כמות: ${line.item.quantity} ${line.item.unitType}',
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'מחיר ליחידה',
                                  ),
                                  keyboardType: TextInputType.number,
                                  enabled: active,
                                  onChanged: (v) {
                                    line.unitPrice = double.tryParse(v) ?? 0;
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
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
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        enabled: active,
                        decoration: const InputDecoration(labelText: 'הערות'),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              if (active && _linesReady)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitCounter,
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              myBid == null
                                  ? 'שלח הצעה למכרז'
                                  : 'הגש הצעת נגד',
                            ),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/quote_request_item.dart';
import '../../models/supplier_quote.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/supplier_quote_status.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/app_back_leading.dart';
import '../../utils/payment_terms.dart';
import '../../utils/quote_financials.dart';
import '../../analytics/catalog_rfq_analytics.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/supplier_catalog_match_validation.dart';
import '../../utils/supplier_quote_line_mapper.dart';
import '../../widgets/catalog/quote_request_catalog_snapshot.dart';
import '../../widgets/catalog/supplier_catalog_match_controls.dart';
import '../../widgets/form_section.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_financial_form_section.dart';
import '../../widgets/quote_line_form_card.dart';
import '../../widgets/tender_badge.dart';
import '../../widgets/tender_bid_history_panel.dart';
import '../../widgets/tender_countdown_banner.dart';
import '../../widgets/tender_rules_panel.dart';

class TenderBidScreen extends ConsumerStatefulWidget {
  const TenderBidScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<TenderBidScreen> createState() => _TenderBidScreenState();
}

class _LineState {
  _LineState({required this.item});

  final QuoteRequestItem item;
  bool include = true;
  double unitPrice = 0;
  bool isExactMatch = true;
  String quotedName = '';
  String quotedSku = '';
  String supplierNotes = '';

  double get total => unitPrice * item.quantity;
}

class _TenderBidScreenState extends ConsumerState<TenderBidScreen> {
  final _deliveryController = TextEditingController();
  final _notesController = TextEditingController();
  List<_LineState> _lines = [];
  bool _linesReady = false;
  bool _submitting = false;
  QuoteFinancialFormValues? _financials;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    final defaults =
        ref.read(authSessionProvider).valueOrNull?.profile?.supplierDefaults;
    if (defaults != null) {
      _deliveryController.text = defaults.deliveryTimeHint;
    }
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

    for (final line in _lines) {
      final noteError = SupplierCatalogMatchValidation.missingAlternativeNote(
        item: line.item,
        isExactMatch: line.isExactMatch,
        includeInQuote: line.include && line.unitPrice > 0,
        unitPrice: line.unitPrice,
        supplierNotes: line.supplierNotes,
      );
      if (noteError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(noteError)),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final user = ref.read(authSessionProvider).valueOrNull?.profile;
      if (user == null) throw Exception('לא מחובר');
      final inputs = _lines
          .map(
            (l) => SupplierQuoteLineMapper.fromRequestLine(
              requestItem: l.item,
              unitPrice: l.unitPrice,
              requestedQuantity: l.item.quantity,
              includeInQuote: l.include && l.unitPrice > 0,
              isExactMatch: l.isExactMatch,
              quotedName: l.quotedName,
              quotedSku: l.quotedSku,
              supplierNotes: l.supplierNotes,
            ),
          )
          .toList();

      final financials = _financials ??
          QuoteFinancialFormValues(
            deliveryCost: 0,
            vatRate: QuoteFinancialBreakdown.defaultVatRate,
            validUntil: DateTime.now().add(const Duration(days: 14)),
            paymentTerms: PaymentTerms.defaultValue,
            breakdown: QuoteFinancialBreakdown.compute(
              subtotal: inputs.fold<double>(
                0,
                (s, l) => s + l.totalItemPrice,
              ),
            ),
          );

      await ref.read(quoteServiceProvider).submitTenderCounterBid(
            supplier: user,
            quoteRequestId: widget.requestId,
            deliveryTime: _deliveryController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            lines: inputs,
            deliveryCost: financials.deliveryCost,
            vatRate: financials.vatRate,
            validUntil: financials.validUntil,
            paymentTerms: financials.paymentTerms,
          );

      final analytics = ref.read(catalogRfqAnalyticsProvider);
      for (final line in _lines) {
        if (!line.item.isCatalogMatched || !line.include || line.unitPrice <= 0) {
          continue;
        }
        analytics.track(
          line.isExactMatch
              ? CatalogRfqEventNames.supplierExactQuote
              : CatalogRfqEventNames.supplierAlternativeQuote,
          {'requestItemId': line.item.id},
        );
      }

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
          final myPrice = myBid?.displayTotal;
          final lineSubtotal = _lines
              .where((l) => l.include && l.unitPrice > 0)
              .fold<double>(0, (s, l) => s + l.total);
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
                    const TenderRulesPanel(compact: true),
                    const SizedBox(height: AppSpacing.sm),
                    TenderCountdownBanner(
                      endTime: request.tenderEndTime,
                      active: active,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: AppTheme.cardDecoration(
                        color: isLeading
                            ? AppTheme.emerald.withValues(alpha: 0.08)
                            : AppTheme.amber.withValues(alpha: 0.06),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            active ? 'סטטוס ההצעה שלך' : 'המכרז הסתיים',
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
                                  ? 'אתה מוביל כרגע במכרז'
                                  : 'הוצעת — הגש הצעת נגד כדי לחזור למוביל',
                              style: TextStyle(
                                color: isLeading
                                    ? AppTheme.emerald
                                    : AppTheme.amber,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TenderBidHistoryPanel(
                      quotes: sent,
                      request: request,
                      forSupplierView: true,
                      currentSupplierId: supplierId,
                    ),
                    if (!active)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Text(
                          'המכרז נסגר — לא ניתן להגיש הצעות נוספות',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
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
                    else if (active) ...[
                      FormSection(
                        title: 'פרטי הצעת נגד',
                        child: Column(
                          children: [
                            ..._lines.map(
                              (line) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  QuoteRequestCatalogSnapshot(item: line.item),
                                  QuoteLineFormCard(
                                    productName: line.item.productName,
                                    quantityLabel:
                                        'כמות: ${line.item.quantity} ${line.item.unitType}',
                                    unitPriceField: TextField(
                                      decoration: const InputDecoration(
                                        labelText: 'מחיר ליחידה',
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        line.unitPrice = double.tryParse(v) ?? 0;
                                        setState(() {});
                                      },
                                    ),
                                    footer: line.item.isCatalogMatched
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              SupplierCatalogMatchControls(
                                                isExactMatch: line.isExactMatch,
                                                onExactMatchChanged: (v) {
                                                  line.isExactMatch = v;
                                                  setState(() {});
                                                },
                                                quotedName: line.quotedName,
                                                quotedSku: line.quotedSku,
                                                onQuotedNameChanged: (v) =>
                                                    line.quotedName = v,
                                                onQuotedSkuChanged: (v) =>
                                                    line.quotedSku = v,
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.xs,
                                              ),
                                              TextField(
                                                decoration: InputDecoration(
                                                  labelText: line.item
                                                              .isCatalogMatched &&
                                                          !line.isExactMatch
                                                      ? HebrewStrings
                                                          .alternativeSupplierNotes
                                                      : 'הערות לפריט',
                                                  isDense: true,
                                                ),
                                                onChanged: (v) =>
                                                    line.supplierNotes = v,
                                              ),
                                            ],
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            TextField(
                              controller: _deliveryController,
                              decoration: const InputDecoration(
                                labelText: 'זמן אספקה',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextField(
                              controller: _notesController,
                              decoration:
                                  const InputDecoration(labelText: 'הערות'),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      QuoteFinancialFormSection(
                        lineSubtotal: lineSubtotal,
                        initialDeliveryCost: ref
                            .read(authSessionProvider)
                            .valueOrNull
                            ?.profile
                            ?.supplierDefaults
                            .deliveryCost,
                        initialVatRate: ref
                            .read(authSessionProvider)
                            .valueOrNull
                            ?.profile
                            ?.supplierDefaults
                            .vatRate,
                        initialPaymentTerms: ref
                            .read(authSessionProvider)
                            .valueOrNull
                            ?.profile
                            ?.supplierDefaults
                            .paymentTerms,
                        initialValidityDays: ref
                            .read(authSessionProvider)
                            .valueOrNull
                            ?.profile
                            ?.supplierDefaults
                            .validityDays,
                        onChanged: (v) => setState(() => _financials = v),
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

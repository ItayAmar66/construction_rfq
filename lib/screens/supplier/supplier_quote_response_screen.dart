import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/quote_request.dart';
import '../../models/quote_request_item.dart';
import '../../models/request_type.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/user_facing_error.dart';
import '../../utils/payment_terms.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/form_section.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/procurement_panel.dart';
import '../../widgets/quote_financial_form_section.dart';
import '../../widgets/quote_line_form_card.dart';
import '../../utils/quote_financials.dart';
import '../../analytics/catalog_rfq_analytics.dart';
import '../../utils/supplier_catalog_match_validation.dart';
import '../../utils/supplier_quote_line_mapper.dart';
import '../../widgets/catalog/quote_request_catalog_snapshot.dart';
import '../../widgets/catalog/supplier_catalog_match_controls.dart';

class SupplierQuoteResponseScreen extends ConsumerStatefulWidget {
  const SupplierQuoteResponseScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<SupplierQuoteResponseScreen> createState() =>
      _SupplierQuoteResponseScreenState();
}

class _LineState {
  _LineState({required this.item});

  final QuoteRequestItem item;
  bool include = true;
  double unitPrice = 0;
  String notes = '';
  bool isExactMatch = true;
  String quotedName = '';
  String quotedSku = '';

  double get total => unitPrice * item.quantity;
}

class _SupplierQuoteResponseScreenState
    extends ConsumerState<SupplierQuoteResponseScreen> {
  final _deliveryController = TextEditingController();
  final _notesController = TextEditingController();
  QuoteRequest? _request;
  List<_LineState> _lines = [];
  bool _loading = true;
  bool _submitting = false;
  bool _submitSucceeded = false;
  QuoteFinancialFormValues? _financials;

  @override
  void dispose() {
    _deliveryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final quoteService = ref.read(quoteServiceProvider);
    final request = await quoteService.getRequest(widget.requestId);
    final items = await quoteService.getRequestItems(widget.requestId);
    if (mounted) {
      if (request != null && request.requestType == RequestType.tender) {
        context.replace('/tender/${widget.requestId}');
        return;
      }
      final profile = ref.read(authSessionProvider).valueOrNull?.profile;
      if (profile != null) {
        final defaults = profile.supplierDefaults;
        _deliveryController.text = defaults.deliveryTimeHint;
      }
      setState(() {
        _request = request;
        _lines = items.map((i) => _LineState(item: i)).toList();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting || _submitSucceeded) return;
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
        supplierNotes: line.notes,
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
              supplierNotes: l.notes,
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

      await ref.read(quoteServiceProvider).submitSupplierQuote(
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

      if (mounted) {
        setState(() => _submitSucceeded = true);
        ref.invalidate(incomingRequestsProvider);
        ref.invalidate(supplierSentQuotesProvider);
        ref.invalidate(customerReceivedQuotesProvider);
        ref.invalidate(requestQuotesProvider(widget.requestId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(HebrewStrings.quoteSubmitted),
            duration: Duration(seconds: 2),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (mounted) context.go('/sent-quotes');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: SecondaryAppBar(title: HebrewStrings.respondToRequest),
        body: LoadingView(message: HebrewStrings.loadingRequests),
      );
    }

    final request = _request;
    if (request == null) {
      return const Scaffold(
        appBar: SecondaryAppBar(title: HebrewStrings.respondToRequest),
        body: Center(child: Text('בקשה לא נמצאה')),
      );
    }

    final lineSubtotal = _lines
        .where((l) => l.include && l.unitPrice > 0)
        .fold<double>(0, (s, l) => s + l.total);

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.respondToRequest),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                ProcurementScreenIntro(
                  title: HebrewStrings.respondToRequest,
                  subtitle: 'הזן מחירים — סמן התאמה מדויקת או חלופה לפריטי קטלוג',
                  icon: Icons.receipt_long_outlined,
                  tint: AppTheme.emerald,
                ),
                const SizedBox(height: AppSpacing.md),
                FormSection(
                  title: HebrewStrings.customerInfo,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: AppTheme.cardDecoration(elevation: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request.customerName} · ${request.customerCity}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          request.customerPhone,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                        if (request.notes != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${HebrewStrings.notes}: ${request.notes}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FormSection(
                  title: HebrewStrings.productsInRequest,
                  child: Column(
                    children: [
                      if (_lines.every((line) => !line.item.isCatalogMatched))
                        Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppTheme.navy.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Text(
                            'פריטים ידניים — אין התאמת קטלוג. חלופות זמינות רק לפריטי קטלוג.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ..._lines
                        .map(
                          (line) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              QuoteRequestCatalogSnapshot(item: line.item),
                              QuoteLineFormCard(
                                productName: line.item.productName,
                                quantityLabel:
                                    'כמות מבוקשת: ${line.item.quantity} ${line.item.unitType}',
                                leading: Checkbox(
                                  value: line.include,
                                  onChanged: (v) {
                                    line.include = v ?? false;
                                    setState(() {});
                                  },
                                ),
                                unitPriceField: TextField(
                                  decoration: const InputDecoration(
                                    labelText: HebrewStrings.unitPrice,
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  enabled: line.include,
                                  onChanged: (v) {
                                    line.unitPrice = double.tryParse(v) ?? 0;
                                    setState(() {});
                                  },
                                ),
                                footer: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (line.item.isCatalogMatched) ...[
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
                                        enabled: line.include,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                    ],
                                    Text(
                                      '${HebrewStrings.totalPrice}: ₪${line.total.toStringAsFixed(2)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    TextField(
                                      decoration: InputDecoration(
                                        labelText: line.item.isCatalogMatched &&
                                                !line.isExactMatch
                                            ? HebrewStrings
                                                .alternativeSupplierNotes
                                            : HebrewStrings.availabilityNotes,
                                        isDense: true,
                                      ),
                                      enabled: line.include,
                                      onChanged: (v) => line.notes = v,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FormSection(
                  title: 'פרטי אספקה',
                  child: Column(
                    children: [
                      TextField(
                        controller: _deliveryController,
                        decoration: const InputDecoration(
                          labelText: HebrewStrings.deliveryTime,
                          hintText: 'לדוגמה: 2-3 ימי עסקים',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: HebrewStrings.notes,
                        ),
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
            ),
          ),
          FormStickyActions(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_financials != null)
                  Text(
                    '${HebrewStrings.totalQuote}: ₪${_financials!.breakdown.totalInclVat.toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                  )
                else
                  Text(
                    'סכום ביניים: ₪${lineSubtotal.toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: (_submitting || _submitSucceeded) ? null : _submit,
                  child: _submitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Text('שולח הצעה...'),
                          ],
                        )
                      : _submitSucceeded
                          ? const Text('ההצעה נשלחה')
                          : const Text(HebrewStrings.submitQuote),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
import '../../utils/payment_terms.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/form_section.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_financial_form_section.dart';
import '../../widgets/quote_line_form_card.dart';
import '../../utils/quote_financials.dart';
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

      if (mounted) {
        ref.invalidate(incomingRequestsProvider);
        ref.invalidate(supplierSentQuotesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(HebrewStrings.quoteSubmitted)),
        );
        context.go('/sent-quotes');
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
    if (_loading) {
      return const Scaffold(
        appBar: SecondaryAppBar(title: HebrewStrings.respondToRequest),
        body: LoadingView(),
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
                    children: _lines
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
                                      decoration: const InputDecoration(
                                        labelText: HebrewStrings.availabilityNotes,
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
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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

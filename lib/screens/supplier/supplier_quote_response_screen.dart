import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/quote_request.dart';
import '../../models/quote_request_item.dart';
import '../../models/request_type.dart';
import '../../models/app_user.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/payment_terms.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/form_section.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/procurement_panel.dart';
import '../../widgets/quote_financial_form_section.dart';
import '../../widgets/quote_line_form_card.dart';
import '../../utils/quote_financials.dart';
import '../../analytics/catalog_rfq_analytics.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/catalog_display_name.dart';
import '../../utils/supplier_catalog_match_validation.dart';
import '../../utils/supplier_quote_line_mapper.dart';
import '../../utils/supplier_quote_submit_validation.dart';
import '../../widgets/catalog/supplier_catalog_match_controls.dart';
import '../../widgets/catalog/quote_request_catalog_snapshot.dart';
import '../../widgets/projects/project_context_chip.dart';

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
  String? _submitError;
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

    void fail(String message) {
      if (!mounted) return;
      setState(() => _submitError = message);
      showAppSnackBar(context, message: message);
    }

    try {
      setState(() => _submitError = null);
      final pricedLines =
          _lines.where((l) => l.include && l.unitPrice > 0).toList();
      final lineSubtotal =
          pricedLines.fold<double>(0, (sum, line) => sum + line.total);
      final user = ref.read(authSessionProvider).valueOrNull?.profile;
      if (user == null) {
        fail('לא מחובר');
        return;
      }
      final supplierOrgId = _supplierOrgIdForSubmit(user);
      final validationError = SupplierQuoteSubmitValidation.validate(
        deliveryTime: _deliveryController.text,
        lineSubtotal: lineSubtotal,
        supplierOrgId: supplierOrgId,
      );
      if (validationError != null) {
        fail(validationError);
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
          fail(noteError);
          return;
        }
      }

      setState(() => _submitting = true);
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
            supplierOrgId: supplierOrgId!,
          );

      final analytics = ref.read(catalogRfqAnalyticsProvider);
      for (final line in _lines) {
        if (!line.item.isCatalogMatched ||
            !line.include ||
            line.unitPrice <= 0) {
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
        setState(() {
          _submitSucceeded = true;
          _submitError = null;
        });
        ref.invalidate(incomingRequestsProvider);
        ref.invalidate(supplierSentQuotesProvider);
        ref.invalidate(customerReceivedQuotesProvider);
        ref.invalidate(requestQuotesProvider(widget.requestId));
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        showAppSnackBar(context, message: HebrewStrings.quoteSubmitted);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (mounted) context.go('/sent-quotes');
      }
    } catch (e) {
      if (mounted) {
        fail(SupplierQuoteSubmitValidation.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _supplierOrgIdForSubmit(AppUser user) {
    final profileOrgId = user.supplierOrgId?.trim();
    if (profileOrgId != null && profileOrgId.isNotEmpty) return profileOrgId;
    final orgId = ref.read(primaryOrgIdProvider)?.trim();
    return orgId != null && orgId.isNotEmpty ? orgId : null;
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
    final delivery = _financials?.deliveryCost ?? 0;
    final vatRate =
        _financials?.vatRate ?? QuoteFinancialBreakdown.defaultVatRate;
    final displayTotal = QuoteFinancialBreakdown.compute(
      subtotal: lineSubtotal,
      deliveryCost: delivery,
      vatRate: vatRate,
    ).totalInclVat;
    final canQuote = ref.watch(canCreateSupplierQuoteProvider);

    return Scaffold(
      appBar: SecondaryAppBar(
        title: HebrewStrings.respondToRequest,
        actions: [
          if (canQuote)
            TextButton(
              onPressed: (_submitting || _submitSucceeded) ? null : _submit,
              child: Text(
                _submitting
                    ? 'שולח...'
                    : _submitSucceeded
                        ? 'נשלחה'
                        : HebrewStrings.submitQuote,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                ProcurementScreenIntro(
                  title: HebrewStrings.respondToRequest,
                  subtitle:
                      'הזן מחירים — סמן התאמה מדויקת או חלופה לפריטי קטלוג',
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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
                        ProjectContextChip(request: request),
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
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Text(
                            'פריטים ידניים — אין התאמת קטלוג. חלופות זמינות רק לפריטי קטלוג.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ..._lines.asMap().entries.map(
                        (entry) {
                          final index = entry.key;
                          final line = entry.value;
                          final displayName = CatalogDisplayName.forQuoteLine(
                            productName: line.item.productName,
                            variantName: line.item.variantName,
                            catalogProductName: line.item.catalogProductName,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              QuoteRequestCatalogSnapshot(
                                item: line.item,
                                lineNumber: index + 1,
                              ),
                              QuoteLineFormCard(
                                productName: displayName,
                                quantityLabel:
                                    'שורה ${index + 1} · כמות מבוקשת: ${line.item.quantity} ${line.item.unitType}',
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
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
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
                          );
                        },
                      ),
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
                      const SizedBox(height: AppSpacing.sm),
                      _SubmitQuoteActions(
                        displayTotal: displayTotal,
                        canQuote: canQuote,
                        submitting: _submitting,
                        submitSucceeded: _submitSucceeded,
                        errorMessage: _submitError,
                        onSubmit: _submit,
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
                const SizedBox(height: AppSpacing.md),
                FormStickyActions(
                  child: _SubmitQuoteActions(
                    displayTotal: displayTotal,
                    canQuote: canQuote,
                    submitting: _submitting,
                    submitSucceeded: _submitSucceeded,
                    errorMessage: _submitError,
                    onSubmit: _submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitQuoteActions extends StatelessWidget {
  const _SubmitQuoteActions({
    required this.displayTotal,
    required this.canQuote,
    required this.submitting,
    required this.submitSucceeded,
    required this.errorMessage,
    required this.onSubmit,
  });

  final double displayTotal;
  final bool canQuote;
  final bool submitting;
  final bool submitSucceeded;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${HebrewStrings.totalQuote}: ₪${displayTotal.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (errorMessage != null && errorMessage!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.08),
              border: Border.all(
                color: AppTheme.danger.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (canQuote)
          ElevatedButton(
            onPressed: (submitting || submitSucceeded) ? null : onSubmit,
            child: submitting
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
                : submitSucceeded
                    ? const Text('ההצעה נשלחה')
                    : const Text(HebrewStrings.submitQuote),
          )
        else
          const Text(
            'אין הרשאה לשליחת הצעה — פנה למנהל המכירות',
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

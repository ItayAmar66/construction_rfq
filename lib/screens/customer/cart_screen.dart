import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/catalog_rfq_analytics.dart';
import '../../models/request_type.dart';
import '../../providers/cart_provider.dart';
import '../../providers/providers.dart';
import '../../providers/rfq_draft_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/catalog_selector_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/manual_rfq_item_dialog.dart';
import '../../utils/rfq_draft_helpers.dart';
import '../../widgets/rfq_builder_sections.dart';
import '../../widgets/rfq_review_summary_card.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/rfq_draft_submit_bar.dart';
import '../../widgets/rfq_supplier_target_picker.dart';
import '../../widgets/rfq_draft_line_card.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _notesController = TextEditingController();
  bool _submitting = false;
  RequestType _requestType = RequestType.regular;
  Duration _tenderDuration = const Duration(hours: 24);
  List<String> _targetSupplierIds = const [];
  List<String> _targetSupplierNames = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncLegacyCart();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _syncLegacyCart() {
    final cart = ref.read(cartProvider);
    if (cart.isNotEmpty) {
      ref.read(rfqDraftProvider.notifier).importLegacyCart(cart);
    }
  }

  Future<void> _pickFromCatalog() async {
    final draft = await CatalogSelectorSheet.show(context);
    if (draft == null || !mounted) return;

    ref.read(catalogRfqAnalyticsProvider).track(
          CatalogRfqEventNames.catalogItemSelected,
          {'variantId': draft.variantId, 'source': 'rfq_draft'},
        );
    ref.read(rfqDraftProvider.notifier).addCatalogDraft(draft);
  }

  Future<void> _addManualItem() async {
    final result = await ManualRfqItemDialog.show(context);
    if (result != null && mounted) {
      ref.read(catalogRfqAnalyticsProvider).track(
            CatalogRfqEventNames.manualItemAdded,
          );
      ref.read(rfqDraftProvider.notifier).addManualItem(
            productName: result.productName,
            category: result.category,
            unitType: result.unitType,
            quantity: result.quantity,
            notes: result.notes,
          );
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final draft = ref.read(rfqDraftProvider);
    if (draft.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(HebrewStrings.confirmSubmit),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(HebrewStrings.no),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(HebrewStrings.yes),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final user = ref.read(authSessionProvider).valueOrNull?.profile;
      if (user == null) throw Exception('לא מחובר');
      final requestId = await ref.read(quoteServiceProvider).submitQuoteRequest(
            customer: user,
            requestItems: draft,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            requestType: _requestType,
            tenderDuration: _tenderDuration,
            invitedSupplierIds: _targetSupplierIds,
            invitedSupplierNames: _targetSupplierNames,
          );
      if (!mounted) return;
      ref.read(rfqDraftProvider.notifier).clear();
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(customerRequestsProvider);
      showAppSnackBar(context, message: 'הבקשה נשלחה בהצלחה');
      context.go('/request-confirmation?id=$requestId');
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: userFacingError(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(rfqDraftProvider);
    final summary = summarizeRfqDraft(draft);
    final catalogLines =
        draft.where((item) => item.isCatalogMatched).toList();
    final manualLines =
        draft.where((item) => !item.isCatalogMatched).toList();

    ref.listen(cartProvider, (prev, next) {
      if (next.isNotEmpty) {
        ref.read(rfqDraftProvider.notifier).importLegacyCart(next);
      }
    });

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.rfqDraftTitle),
      body: draft.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyState(
                      message: HebrewStrings.emptyRfqDraft,
                      icon: Icons.request_quote_outlined,
                      hint: HebrewStrings.emptyRfqDraftAction,
                      accentGradient: AppTheme.gradientAmber,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _pickFromCatalog,
                      icon: const Icon(Icons.manage_search_outlined),
                      label: const Text(HebrewStrings.pickFromCatalog),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _addManualItem,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text(HebrewStrings.addManualRfqItem),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      RfqBuilderStepHeader(
                        currentStep: summary.hasLines ? 2 : 1,
                      ),
                      const SizedBox(height: 12),
                      RfqDraftSummaryBar(summary: summary),
                      const SizedBox(height: 12),
                      if (catalogLines.isNotEmpty) ...[
                        const RfqDraftSectionHeader(
                          title: HebrewStrings.rfqCatalogSection,
                          subtitle: 'פריטים שנבחרו מהקטלוג המאושר',
                          icon: Icons.inventory_2_outlined,
                        ),
                        ...catalogLines.asMap().entries.map(
                          (entry) => RfqDraftLineCard(
                            item: entry.value,
                            lineNumber: entry.key + 1,
                            onQuantityChanged: (qty) => ref
                                .read(rfqDraftProvider.notifier)
                                .updateQuantity(entry.value.id, qty),
                            onNotesChanged: (notes) => ref
                                .read(rfqDraftProvider.notifier)
                                .updateLineNotes(entry.value.id, notes),
                            onRemove: () => ref
                                .read(rfqDraftProvider.notifier)
                                .removeLine(entry.value.id),
                          ),
                        ),
                      ],
                      if (manualLines.isNotEmpty) ...[
                        const RfqDraftSectionHeader(
                          title: HebrewStrings.rfqManualSection,
                          subtitle: 'פריטים חופשיים — יש לציין הערות כשצריך',
                          icon: Icons.edit_outlined,
                        ),
                        ...manualLines.asMap().entries.map(
                          (entry) => RfqDraftLineCard(
                            item: entry.value,
                            lineNumber: catalogLines.length + entry.key + 1,
                            onQuantityChanged: (qty) => ref
                                .read(rfqDraftProvider.notifier)
                                .updateQuantity(entry.value.id, qty),
                            onNotesChanged: (notes) => ref
                                .read(rfqDraftProvider.notifier)
                                .updateLineNotes(entry.value.id, notes),
                            onRemove: () => ref
                                .read(rfqDraftProvider.notifier)
                                .removeLine(entry.value.id),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFromCatalog,
                              icon: const Icon(Icons.manage_search_outlined),
                              label: const Text(HebrewStrings.pickFromCatalog),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _addManualItem,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text(HebrewStrings.addManualRfqItem),
                            ),
                          ),
                        ],
                      ),
                      const RfqDraftSectionHeader(
                        title: HebrewStrings.rfqRequestDetailsSection,
                        icon: Icons.tune_outlined,
                      ),
                      Text(
                        'סוג בקשה',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<RequestType>(
                        segments: [
                          ButtonSegment(
                            value: RequestType.regular,
                            label: Text(
                              RequestType.regular.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          ButtonSegment(
                            value: RequestType.tender,
                            label: Text(RequestType.tender.label),
                          ),
                        ],
                        selected: {_requestType},
                        onSelectionChanged: (s) {
                          setState(() => _requestType = s.first);
                        },
                      ),
                      if (_requestType == RequestType.tender) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('6 שעות'),
                              selected:
                                  _tenderDuration == const Duration(hours: 6),
                              onSelected: (_) => setState(
                                () => _tenderDuration = const Duration(hours: 6),
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('24 שעות'),
                              selected:
                                  _tenderDuration == const Duration(hours: 24),
                              onSelected: (_) => setState(
                                () =>
                                    _tenderDuration = const Duration(hours: 24),
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('3 ימים'),
                              selected:
                                  _tenderDuration == const Duration(days: 3),
                              onSelected: (_) => setState(
                                () => _tenderDuration = const Duration(days: 3),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: HebrewStrings.notes,
                        ),
                        maxLines: 2,
                      ),
                      const RfqDraftSectionHeader(
                        title: HebrewStrings.rfqReviewSection,
                        subtitle: 'בדוק שורות ויעד ספקים לפני שליחה',
                        icon: Icons.send_outlined,
                      ),
                      RfqSupplierTargetPicker(
                        selectedIds: _targetSupplierIds,
                        selectedNames: _targetSupplierNames,
                        onChanged: (selection) => setState(() {
                          _targetSupplierIds = selection.ids;
                          _targetSupplierNames = selection.names;
                        }),
                      ),
                      const SizedBox(height: 12),
                      RfqReviewSummaryCard(
                        summary: summary,
                        items: draft,
                        invitedSupplierNames: _targetSupplierNames,
                        hasMissingNotes: summary.linesMissingNotes > 0,
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
                RfqDraftSubmitBar(
                  summary: summary,
                  supplierNames: _targetSupplierNames,
                  onSubmit: _submit,
                  submitting: _submitting,
                ),
              ],
            ),
    );
  }
}

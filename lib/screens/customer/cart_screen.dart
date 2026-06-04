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
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/catalog_selector_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/manual_rfq_item_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLegacyCart());
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
    if (draft != null && mounted) {
      ref.read(catalogRfqAnalyticsProvider).track(
            CatalogRfqEventNames.catalogItemSelected,
            {'variantId': draft.variantId, 'source': 'rfq_draft'},
          );
      ref.read(rfqDraftProvider.notifier).addCatalogDraft(draft);
    }
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
          );
      ref.read(rfqDraftProvider.notifier).clear();
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(customerRequestsProvider);
      if (mounted) {
        context.go('/request-confirmation?id=$requestId');
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
    final draft = ref.watch(rfqDraftProvider);

    ref.listen(cartProvider, (prev, next) {
      if (next.isNotEmpty) {
        ref.read(rfqDraftProvider.notifier).importLegacyCart(next);
      }
    });

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.cart),
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
                      hint: HebrewStrings.emptyRfqDraftHint,
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
                      Text(
                        HebrewStrings.rfqMaterialsTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...draft.map(
                        (item) => RfqDraftLineCard(
                          item: item,
                          onQuantityChanged: (qty) => ref
                              .read(rfqDraftProvider.notifier)
                              .updateQuantity(item.id, qty),
                          onNotesChanged: (notes) => ref
                              .read(rfqDraftProvider.notifier)
                              .updateLineNotes(item.id, notes),
                          onRemove: () => ref
                              .read(rfqDraftProvider.notifier)
                              .removeLine(item.id),
                        ),
                      ),
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
                      const SizedBox(height: 16),
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
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(HebrewStrings.submitRequest),
                  ),
                ),
              ],
            ),
    );
  }
}

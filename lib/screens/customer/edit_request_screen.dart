import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/quote_request.dart';
import '../../models/quote_request_item.dart';
import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/catalog_selector_sheet.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/manual_rfq_item_dialog.dart';
import '../../widgets/rfq_draft_line_card.dart';

class EditRequestScreen extends ConsumerStatefulWidget {
  const EditRequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<EditRequestScreen> createState() => _EditRequestScreenState();
}

class _EditRequestScreenState extends ConsumerState<EditRequestScreen> {
  final _notesController = TextEditingController();
  List<QuoteRequestItem> _items = [];
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save(String customerId) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש להשאיר לפחות מוצר אחד בבקשה')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(quoteServiceProvider).updateQuoteRequest(
            requestId: widget.requestId,
            customerId: customerId,
            items: _items,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      ref.invalidate(customerRequestsProvider);
      ref.invalidate(quoteRequestProvider(widget.requestId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('הבקשה עודכנה בהצלחה')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String customerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('מחק בקשה'),
        content: const Text('האם למחוק או לבטל את הבקשה?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('מחק', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(quoteServiceProvider).deleteOrCancelQuoteRequest(
            requestId: widget.requestId,
            customerId: customerId,
          );
      ref.invalidate(customerRequestsProvider);
      if (mounted) context.go('/my-requests');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _syncFromRequest(QuoteRequestItem item, int quantity) {
    setState(() {
      _items = _items
          .map(
            (i) => i.id == item.id ? i.copyWith(quantity: quantity) : i,
          )
          .toList();
    });
  }

  void _syncNotes(QuoteRequestItem item, String notes) {
    final trimmed = notes.trim();
    setState(() {
      _items = _items
          .map(
            (i) => i.id == item.id
                ? i.copyWith(
                    notes: trimmed.isEmpty ? null : trimmed,
                    updateNotes: true,
                  )
                : i,
          )
          .toList();
    });
  }

  void _removeItem(QuoteRequestItem item) {
    setState(() => _items = _items.where((i) => i.id != item.id).toList());
  }

  Future<void> _pickFromCatalog() async {
    final draft = await CatalogSelectorSheet.show(context);
    if (draft == null || !mounted) return;
    setState(() {
      _items = [
        ..._items,
        QuoteRequestItem.fromCatalogDraft(
          draft,
          lineId: 'draft_${DateTime.now().microsecondsSinceEpoch}',
          quoteRequestId: widget.requestId,
        ),
      ];
    });
  }

  Future<void> _addManualItem() async {
    final result = await ManualRfqItemDialog.show(context);
    if (result == null || !mounted) return;
    setState(() {
      _items = [
        ..._items,
        QuoteRequestItem(
          id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
          quoteRequestId: widget.requestId,
          productId: 'manual_${DateTime.now().microsecondsSinceEpoch}',
          productName: result.productName,
          category: result.category,
          unitType: result.unitType,
          quantity: result.quantity,
          notes: result.notes,
          isCatalogMatched: false,
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(quoteRequestProvider(widget.requestId));
    final customerId =
        ref.watch(authSessionProvider).valueOrNull?.profile?.id;

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'ערוך בקשה'),
      body: requestAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const Center(child: Text('שגיאה בטעינת הבקשה')),
        data: (request) {
          if (request == null) {
            return const Center(child: Text('הבקשה לא נמצאה'));
          }
          if (!request.isEditable) {
            return const Center(
              child: Text('לא ניתן לערוך בקשה בסטטוס זה'),
            );
          }
          if (!_initialized) {
            _items = [...request.items];
            _notesController.text = request.notes ?? '';
            _initialized = true;
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ..._items.map(
                      (item) => RfqDraftLineCard(
                        item: item,
                        onQuantityChanged: (qty) => _syncFromRequest(item, qty),
                        onNotesChanged: (notes) => _syncNotes(item, notes),
                        onRemove: () => _removeItem(item),
                      ),
                    ),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'הערות לבקשה',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: _saving || customerId == null
                            ? null
                            : () => _save(customerId),
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('שמור שינויים'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _saving || customerId == null
                            ? null
                            : () => _delete(customerId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('מחק בקשה'),
                      ),
                    ],
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

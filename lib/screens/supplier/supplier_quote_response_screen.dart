import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/quote_request.dart';
import '../../models/quote_request_item.dart';
import '../../models/request_type.dart';
import '../../providers/providers.dart';
import '../../services/quote_service.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';

class SupplierQuoteResponseScreen extends ConsumerStatefulWidget {
  const SupplierQuoteResponseScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<SupplierQuoteResponseScreen> createState() =>
      _SupplierQuoteResponseScreenState();
}

class _LineState {
  _LineState({
    required this.item,
    this.include = true,
    this.unitPrice = 0,
    this.notes = '',
  });

  final QuoteRequestItem item;
  bool include;
  double unitPrice;
  String notes;

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
            (l) => SupplierQuoteLineInput(
              productId: l.item.productId,
              productName: l.item.productName,
              requestedQuantity: l.item.quantity,
              unitPrice: l.unitPrice,
              totalItemPrice: l.total,
              notes: l.notes.isEmpty ? null : l.notes,
              includeInQuote: l.include && l.unitPrice > 0,
            ),
          )
          .toList();

      await ref.read(quoteServiceProvider).submitSupplierQuote(
            supplier: user,
            quoteRequestId: widget.requestId,
            deliveryTime: _deliveryController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            lines: inputs,
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final request = _request;
    if (request == null) {
      return const Scaffold(
        appBar: SecondaryAppBar(title: HebrewStrings.respondToRequest),
        body: Center(child: Text('בקשה לא נמצאה')),
      );
    }

    final total = _lines
        .where((l) => l.include && l.unitPrice > 0)
        .fold<double>(0, (s, l) => s + l.total);

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.respondToRequest),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          HebrewStrings.customerInfo,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('${request.customerName} · ${request.customerCity}'),
                        Text(request.customerPhone),
                        if (request.notes != null)
                          Text('${HebrewStrings.notes}: ${request.notes}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  HebrewStrings.productsInRequest,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                ..._lines.map((line) => _LineCard(
                      line: line,
                      onChanged: () => setState(() {}),
                    )),
                const SizedBox(height: 16),
                TextField(
                  controller: _deliveryController,
                  decoration: const InputDecoration(
                    labelText: HebrewStrings.deliveryTime,
                    hintText: 'לדוגמה: 2-3 ימי עסקים',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: HebrewStrings.notes),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${HebrewStrings.totalQuote}: ₪${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
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

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line, required this.onChanged});

  final _LineState line;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: line.include,
                  onChanged: (v) {
                    line.include = v ?? false;
                    onChanged();
                  },
                ),
                Expanded(
                  child: Text(
                    line.item.productName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            Text('כמות מבוקשת: ${line.item.quantity} ${line.item.unitType}'),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: HebrewStrings.unitPrice,
              ),
              keyboardType: TextInputType.number,
              enabled: line.include,
              onChanged: (v) {
                line.unitPrice = double.tryParse(v) ?? 0;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            Text(
              '${HebrewStrings.totalPrice}: ₪${line.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: HebrewStrings.availabilityNotes,
              ),
              enabled: line.include,
              onChanged: (v) => line.notes = v,
            ),
          ],
        ),
      ),
    );
  }
}

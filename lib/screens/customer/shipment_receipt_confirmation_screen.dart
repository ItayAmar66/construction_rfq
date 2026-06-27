import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/receipt_checklist_item.dart';
import '../../models/receipt_status.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/project_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/shipment_receipt_helpers.dart';
import '../../utils/shipment_receipt_validation.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/loading_view.dart';

class ShipmentReceiptConfirmationScreen extends ConsumerStatefulWidget {
  const ShipmentReceiptConfirmationScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  ConsumerState<ShipmentReceiptConfirmationScreen> createState() =>
      _ShipmentReceiptConfirmationScreenState();
}

class _ShipmentReceiptConfirmationScreenState
    extends ConsumerState<ShipmentReceiptConfirmationScreen> {
  late List<ReceiptChecklistItem> _items;
  final _notesController = TextEditingController();
  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _initItems() {
    if (_initialized) return;
    final request = ref.read(quoteRequestProvider(widget.requestId)).valueOrNull;
    if (request == null) return;
    _items = ShipmentReceiptHelpers.initialChecklistFromRequest(request);
    if (request.receiptNotes != null && request.receiptNotes!.isNotEmpty) {
      _notesController.text = request.receiptNotes!;
    }
    _initialized = true;
  }

  Future<void> _submit({required bool fullReceipt}) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    final actorUid = session?.uid;
    if (actorUid == null || actorUid.isEmpty) return;

    try {
      if (fullReceipt) {
        ShipmentReceiptValidation.validateFullReceiptSubmit(_items);
      } else {
        ShipmentReceiptValidation.validateIssueReceiptSubmit(_items);
      }
    } on ShipmentReceiptValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final memberships =
          ref.read(currentUserMembershipsProvider).valueOrNull ?? const [];
      final request =
          ref.read(quoteRequestProvider(widget.requestId)).valueOrNull;
      final projectOrgId = request?.projectId != null &&
              request!.projectId!.isNotEmpty
          ? ref
              .read(projectProvider(request.projectId!))
              .valueOrNull
              ?.orgId
          : null;

      await ref.read(quoteServiceProvider).confirmShipmentReceipt(
            requestId: widget.requestId,
            actorUid: actorUid,
            checklist: _items,
            fullReceipt: fullReceipt,
            memberships: memberships,
            orgId: ref.read(primaryOrgIdProvider),
            projectOrgId: projectOrgId,
            receiptNotes: _notesController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fullReceipt
                ? 'קבלת המשלוח אושרה במלואה'
                : 'דווחה חריגה בקבלת המשלוח',
          ),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _markAllOk() {
    setState(() {
      _items = ShipmentReceiptValidation.markAllOk(_items);
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(quoteRequestProvider(widget.requestId));
    final approvedQuoteId =
        requestAsync.valueOrNull?.approvedQuoteId ?? '';
    final quoteAsync = approvedQuoteId.isEmpty
        ? const AsyncValue.data(null)
        : ref.watch(supplierQuoteProvider(approvedQuoteId));
    final canConfirm =
        ref.watch(canConfirmShipmentReceiptForRequestProvider(widget.requestId));
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'אישור קבלת משלוח'),
      body: requestAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const Center(child: Text(HebrewStrings.errorGeneric)),
        data: (request) {
          if (request == null) {
            return const Center(child: Text('הבקשה לא נמצאה'));
          }
          _initItems();

          if (request.receiptConfirmationComplete) {
            return Center(
              child: Text(
                request.receiptStatus == ReceiptStatus.receivedFull
                    ? 'קבלת המשלוח כבר אושרה'
                    : 'חריגת הקבלה כבר דווחה',
              ),
            );
          }

          if (!canConfirm) {
            return const Center(
              child: Text('אין הרשאה לאשר קבלת משלוח'),
            );
          }

          final quote = quoteAsync.valueOrNull;
          final fullReceiptReady =
              ShipmentReceiptValidation.isFullReceipt(_items);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (request.projectName != null)
                          Text(
                            request.projectName!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (quote != null)
                          Text('ספק: ${quote.supplierName}'),
                        Text('מזהה בקשה: ${request.id}'),
                        if (request.shippedAt != null)
                          Text(
                            'נשלח: ${dateFormat.format(request.shippedAt!)}',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _markAllOk,
                    icon: const Icon(Icons.done_all_outlined),
                    label: const Text('סמן הכל התקבל תקין'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...List.generate(_items.length, (index) {
                  final item = _items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'כמות שהוזמנה: ${item.orderedQuantity}${item.unit != null ? ' ${item.unit}' : ''}',
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: '${item.receivedQuantity}',
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'כמות שהתקבלה',
                            ),
                            onChanged: (value) {
                              final qty = int.tryParse(value) ?? 0;
                              setState(() {
                                _items[index] =
                                    item.copyWith(receivedQuantity: qty);
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<ReceiptItemCondition>(
                            value: item.condition,
                            decoration: const InputDecoration(
                              labelText: 'סטטוס פריט',
                            ),
                            items: ReceiptItemCondition.values
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c.label),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _items[index] =
                                          item.copyWith(condition: value);
                                    });
                                  },
                          ),
                          if (item.condition.isIssue) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: item.issueNotes ?? '',
                              enabled: !_busy,
                              decoration: const InputDecoration(
                                labelText: 'הערות',
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _items[index] = item.copyWith(
                                    issueNotes: value,
                                    updateIssueNotes: true,
                                  );
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                TextField(
                  controller: _notesController,
                  enabled: !_busy,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'הערות כלליות (אופציונלי)',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy || !fullReceiptReady
                      ? null
                      : () => _submit(fullReceipt: true),
                  child: const Text('אשר קבלה מלאה'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: _busy || fullReceiptReady
                      ? null
                      : () => _submit(fullReceipt: false),
                  child: const Text('שמור ודווח חריגה'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _busy ? null : () => context.pop(),
                  child: const Text(HebrewStrings.back),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rfq_supplier_target_picker.dart';

Future<SupplierTargetSelection?> showProcurementSupplierSendDialog(
  BuildContext context,
) {
  return showDialog<SupplierTargetSelection>(
    context: context,
    builder: (ctx) => const _ProcurementSupplierSendDialog(),
  );
}

class _ProcurementSupplierSendDialog extends ConsumerStatefulWidget {
  const _ProcurementSupplierSendDialog();

  @override
  ConsumerState<_ProcurementSupplierSendDialog> createState() =>
      _ProcurementSupplierSendDialogState();
}

class _ProcurementSupplierSendDialogState
    extends ConsumerState<_ProcurementSupplierSendDialog> {
  List<String> _selectedIds = const [];
  List<String> _selectedNames = const [];
  List<String> _selectedOrgIds = const [];

  void _confirm() {
    final selection = SupplierTargetSelection(
      ids: _selectedIds,
      names: _selectedNames,
      orgIds: _selectedOrgIds,
    );
    if (selection.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('יש לבחור לפחות ספק אחד לשליחת הבקשה'),
        ),
      );
      return;
    }
    Navigator.pop(context, selection);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('בחירת ספקים לשליחה'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: RfqSupplierTargetPicker(
            requiresSelection: true,
            selectedIds: _selectedIds,
            selectedNames: _selectedNames,
            selectedOrgIds: _selectedOrgIds,
            onChanged: (selection) {
              setState(() {
                _selectedIds = selection.ids;
                _selectedNames = selection.names;
                _selectedOrgIds = selection.orgIds;
              });
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ביטול'),
        ),
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.send_outlined, size: 18),
          label: const Text('שלח לספקים'),
        ),
      ],
    );
  }
}

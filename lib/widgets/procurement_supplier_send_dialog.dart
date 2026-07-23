import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design_system/primary_button.dart';
import 'design_system/tertiary_button.dart';
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
        TertiaryButton(
          label: 'ביטול',
          onPressed: () => Navigator.pop(context),
        ),
        PrimaryButton.icon(
          icon: Icons.send_outlined,
          label: 'שלח לספקים',
          onPressed: _confirm,
          expand: false,
        ),
      ],
    );
  }
}

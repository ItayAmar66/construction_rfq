import 'package:flutter/material.dart';

import '../utils/hebrew_strings.dart';

class ManualRfqItemResult {
  const ManualRfqItemResult({
    required this.productName,
    required this.category,
    required this.unitType,
    required this.quantity,
    this.notes,
  });

  final String productName;
  final String category;
  final String unitType;
  final int quantity;
  final String? notes;
}

class ManualRfqItemDialog extends StatefulWidget {
  const ManualRfqItemDialog({super.key});

  static Future<ManualRfqItemResult?> show(BuildContext context) {
    return showDialog<ManualRfqItemResult>(
      context: context,
      builder: (_) => const ManualRfqItemDialog(),
    );
  }

  @override
  State<ManualRfqItemDialog> createState() => _ManualRfqItemDialogState();
}

class _ManualRfqItemDialogState extends State<ManualRfqItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _unitController = TextEditingController();
  final _notesController = TextEditingController();
  int _quantity = 1;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ManualRfqItemResult(
        productName: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        unitType: _unitController.text.trim(),
        quantity: _quantity,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(HebrewStrings.addManualRfqItem),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.rfqItemName,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'שדה חובה' : null,
              ),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.category,
                ),
              ),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.unit,
                ),
              ),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.notes,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(HebrewStrings.quantity),
                  const Spacer(),
                  IconButton(
                    onPressed:
                        _quantity > 1 ? () => setState(() => _quantity--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_quantity'),
                  IconButton(
                    onPressed: () => setState(() => _quantity++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(HebrewStrings.cancel),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text(HebrewStrings.addRfqItem),
        ),
      ],
    );
  }
}

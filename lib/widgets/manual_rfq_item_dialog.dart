import 'package:flutter/material.dart';

import '../utils/app_spacing.dart';
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
  final _nameFocus = FocusNode();
  final _categoryFocus = FocusNode();
  final _unitFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _unitController = TextEditingController();
  final _notesController = TextEditingController();
  int _quantity = 1;

  @override
  void dispose() {
    _nameFocus.dispose();
    _categoryFocus.dispose();
    _unitFocus.dispose();
    _notesFocus.dispose();
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
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_categoryFocus),
                  decoration: const InputDecoration(
                    labelText: HebrewStrings.rfqItemName,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'שדה חובה' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _categoryController,
                  focusNode: _categoryFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_unitFocus),
                  decoration: const InputDecoration(
                    labelText: HebrewStrings.category,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _unitController,
                  focusNode: _unitFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_notesFocus),
                  decoration: const InputDecoration(
                    labelText: HebrewStrings.unit,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _notesController,
                  focusNode: _notesFocus,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: HebrewStrings.notes,
                  ),
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Text(HebrewStrings.quantity),
                    const Spacer(),
                    IconButton(
                      onPressed:
                          _quantity > 1 ? () => setState(() => _quantity--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

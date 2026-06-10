import 'package:flutter/material.dart';

import '../../utils/hebrew_strings.dart';

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key});

  static Future<CreateProjectResult?> show(BuildContext context) {
    return showDialog<CreateProjectResult>(
      context: context,
      builder: (_) => const CreateProjectDialog(),
    );
  }

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class CreateProjectResult {
  const CreateProjectResult({
    required this.name,
    required this.location,
    required this.cityOrArea,
    this.notes,
  });

  final String name;
  final String location;
  final String cityOrArea;
  final String? notes;
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש להזין שם פרויקט')),
      );
      return;
    }
    Navigator.pop(
      context,
      CreateProjectResult(
        name: name,
        location: _locationController.text.trim(),
        cityOrArea: _cityController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(HebrewStrings.addProject),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: HebrewStrings.projectNameLabel,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: HebrewStrings.projectLocationLabel,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: HebrewStrings.city,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: HebrewStrings.projectNotesLabel,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(HebrewStrings.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text(HebrewStrings.saveProject),
        ),
      ],
    );
  }
}

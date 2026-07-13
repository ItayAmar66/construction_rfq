import 'package:flutter/material.dart';

import '../../utils/hebrew_strings.dart';

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key, this.initial});

  final CreateProjectResult? initial;

  static Future<CreateProjectResult?> show(
    BuildContext context, {
    CreateProjectResult? initial,
  }) {
    return showDialog<CreateProjectResult>(
      context: context,
      builder: (_) => CreateProjectDialog(initial: initial),
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
    this.managerName,
    this.managerPhone,
    this.startDate,
    this.estimatedCompletionDate,
  });

  final String name;
  final String location;
  final String cityOrArea;
  final String? notes;
  final String? managerName;
  final String? managerPhone;
  final DateTime? startDate;
  final DateTime? estimatedCompletionDate;
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _locationController =
      TextEditingController(text: widget.initial?.location ?? '');
  late final _cityController =
      TextEditingController(text: widget.initial?.cityOrArea ?? '');
  late final _notesController =
      TextEditingController(text: widget.initial?.notes ?? '');
  late final _managerNameController =
      TextEditingController(text: widget.initial?.managerName ?? '');
  late final _managerPhoneController =
      TextEditingController(text: widget.initial?.managerPhone ?? '');
  DateTime? _startDate;
  DateTime? _estimatedCompletionDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initial?.startDate;
    _estimatedCompletionDate = widget.initial?.estimatedCompletionDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate =
        (isStart ? _startDate : _estimatedCompletionDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 6),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _estimatedCompletionDate = picked;
      }
    });
  }

  String _fmtDate(DateTime? date) {
    if (date == null) return 'בחירת תאריך';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CreateProjectResult(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        cityOrArea: _cityController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        managerName: _managerNameController.text.trim().isEmpty
            ? null
            : _managerNameController.text.trim(),
        managerPhone: _managerPhoneController.text.trim().isEmpty
            ? null
            : _managerPhoneController.text.trim(),
        startDate: _startDate,
        estimatedCompletionDate: _estimatedCompletionDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? HebrewStrings.addProject : 'עריכת פרויקט',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.projectNameLabel,
                ),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'יש להזין שם פרויקט'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.projectLocationLabel,
                ),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'יש להזין מיקום / כתובת'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.city,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _managerNameController,
                      decoration: const InputDecoration(
                        labelText: 'מנהל פרויקט',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _managerPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'טלפון',
                      ),
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.calendar_today_outlined,
                          size: 16),
                      label: Text('תחילה: ${_fmtDate(_startDate)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.event_available_outlined,
                          size: 16),
                      label: Text('סיום משוער: ${_fmtDate(_estimatedCompletionDate)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.projectNotesLabel,
                ),
                maxLines: 2,
              ),
            ],
          ),
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

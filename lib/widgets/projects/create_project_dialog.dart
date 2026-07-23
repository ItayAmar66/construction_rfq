import 'package:flutter/material.dart';

import '../../utils/hebrew_strings.dart';
import '../design_system/app_text_field.dart';
import '../design_system/primary_button.dart';
import '../design_system/secondary_button.dart';
import '../design_system/tertiary_button.dart';

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
              AppTextField(
                controller: _nameController,
                label: HebrewStrings.projectNameLabel,
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'יש להזין שם פרויקט'
                    : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _locationController,
                label: HebrewStrings.projectLocationLabel,
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'יש להזין מיקום / כתובת'
                    : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _cityController,
                label: HebrewStrings.city,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _managerNameController,
                      label: 'מנהל פרויקט',
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _managerPhoneController,
                      label: 'טלפון',
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
                    child: SecondaryButton(
                      label: 'תחילה: ${_fmtDate(_startDate)}',
                      icon: Icons.calendar_today_outlined,
                      onPressed: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SecondaryButton(
                      label: 'סיום משוער: ${_fmtDate(_estimatedCompletionDate)}',
                      icon: Icons.event_available_outlined,
                      onPressed: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _notesController,
                label: HebrewStrings.projectNotesLabel,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TertiaryButton(
          label: HebrewStrings.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        PrimaryButton(
          label: HebrewStrings.saveProject,
          onPressed: _save,
          expand: false,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/request_type.dart';
import '../models/request_urgency.dart';
import '../models/rfq_submission.dart';
import '../providers/rfq_prefill_provider.dart';
import '../utils/app_spacing.dart';

/// Shared RFQ metadata fields for cart and edit flows.
class RfqDetailsForm extends StatefulWidget {
  const RfqDetailsForm({
    super.key,
    required this.onChanged,
    this.showRequestType = true,
    this.initialNotes,
    this.initialDeliveryAddress,
    this.initialDeliveryCity,
    this.initialUrgency = RequestUrgency.normal,
    this.initialRequiredDeliveryDate,
    this.initialExpirationDays = 14,
    this.initialRequestType = RequestType.regular,
    this.initialTenderDuration = const Duration(hours: 24),
  });

  final ValueChanged<RfqSubmission> onChanged;
  final bool showRequestType;
  final String? initialNotes;
  final String? initialDeliveryAddress;
  final String? initialDeliveryCity;
  final RequestUrgency initialUrgency;
  final DateTime? initialRequiredDeliveryDate;
  final int initialExpirationDays;
  final RequestType initialRequestType;
  final Duration initialTenderDuration;

  @override
  State<RfqDetailsForm> createState() => RfqDetailsFormState();
}

class RfqDetailsFormState extends State<RfqDetailsForm> {
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _notesController;
  late RequestUrgency _urgency;
  DateTime? _requiredDate;
  late int _expirationDays;
  late RequestType _requestType;
  late Duration _tenderDuration;

  @override
  void initState() {
    super.initState();
    _addressController =
        TextEditingController(text: widget.initialDeliveryAddress ?? '');
    _cityController =
        TextEditingController(text: widget.initialDeliveryCity ?? '');
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
    _urgency = widget.initialUrgency;
    _requiredDate = widget.initialRequiredDeliveryDate;
    _expirationDays = widget.initialExpirationDays;
    _requestType = widget.initialRequestType;
    _tenderDuration = widget.initialTenderDuration;
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  void applyPrefill(RfqPrefill prefill) {
    _addressController.text = prefill.deliveryAddress ?? '';
    _cityController.text = prefill.deliveryCity ?? '';
    _notesController.text = prefill.notes ?? '';
    _urgency = prefill.urgency;
    _requiredDate = prefill.requiredDeliveryDate;
    _expirationDays = prefill.expirationDays;
    setState(() {});
    _emit();
  }

  void _emit() {
    widget.onChanged(
      RfqSubmission(
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        deliveryAddress: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        deliveryCity: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        urgency: _urgency,
        requiredDeliveryDate: _requiredDate,
        expirationDays: _expirationDays,
        requestType: _requestType,
        tenderDuration: _tenderDuration,
      ),
    );
  }

  Future<void> _pickDate({
    required bool requiredDelivery,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: requiredDelivery
          ? (_requiredDate ?? now.add(const Duration(days: 3)))
          : now.add(Duration(days: _expirationDays)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('he'),
    );
    if (picked == null) return;
    setState(() {
      if (requiredDelivery) {
        _requiredDate = picked;
      } else {
        _expirationDays = picked.difference(now).inDays.clamp(1, 90);
      }
    });
    _emit();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy', 'he');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'פרטי אספקה',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'כתובת אספקה',
            hintText: 'רחוב, מספר, אתר',
            isDense: true,
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _cityController,
          decoration: const InputDecoration(
            labelText: 'עיר / אזור',
            isDense: true,
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'דחיפות',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xxs),
        SegmentedButton<RequestUrgency>(
          segments: RequestUrgency.values
              .map(
                (u) => ButtonSegment(
                  value: u,
                  label: Text(u.label, style: const TextStyle(fontSize: 11)),
                ),
              )
              .toList(),
          selected: {_urgency},
          onSelectionChanged: (s) {
            setState(() => _urgency = s.first);
            _emit();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('תאריך אספקה נדרש'),
          subtitle: Text(
            _requiredDate == null
                ? 'לא נבחר'
                : dateFmt.format(_requiredDate!),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            onPressed: () => _pickDate(requiredDelivery: true),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('תוקף הבקשה'),
          subtitle: Text('$_expirationDays ימים מהיום'),
          trailing: IconButton(
            icon: const Icon(Icons.event_busy_outlined, size: 20),
            onPressed: () => _pickDate(requiredDelivery: false),
          ),
        ),
        if (widget.showRequestType) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'סוג בקשה',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<RequestType>(
            segments: [
              ButtonSegment(
                value: RequestType.regular,
                label: Text(
                  RequestType.regular.label,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              ButtonSegment(
                value: RequestType.tender,
                label: Text(RequestType.tender.label),
              ),
            ],
            selected: {_requestType},
            onSelectionChanged: (s) {
              setState(() => _requestType = s.first);
              _emit();
            },
          ),
          if (_requestType == RequestType.tender) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('6 שעות'),
                  selected: _tenderDuration == const Duration(hours: 6),
                  onSelected: (_) {
                    setState(() => _tenderDuration = const Duration(hours: 6));
                    _emit();
                  },
                ),
                ChoiceChip(
                  label: const Text('24 שעות'),
                  selected: _tenderDuration == const Duration(hours: 24),
                  onSelected: (_) {
                    setState(
                      () => _tenderDuration = const Duration(hours: 24),
                    );
                    _emit();
                  },
                ),
                ChoiceChip(
                  label: const Text('3 ימים'),
                  selected: _tenderDuration == const Duration(days: 3),
                  onSelected: (_) {
                    setState(() => _tenderDuration = const Duration(days: 3));
                    _emit();
                  },
                ),
              ],
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'הערות לספקים',
            hintText: 'גישה לאתר, שעות פריקה, דרישות מיוחדות…',
          ),
          maxLines: 4,
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }
}

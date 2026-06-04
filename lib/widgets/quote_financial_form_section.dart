import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/payment_terms.dart';
import '../utils/quote_financials.dart';
import 'form_section.dart';

/// Supplier form fields for quote financials (VAT, delivery, validity).
class QuoteFinancialFormSection extends StatefulWidget {
  const QuoteFinancialFormSection({
    super.key,
    required this.lineSubtotal,
    required this.onChanged,
    this.enabled = true,
    this.initialDeliveryCost,
    this.initialVatRate,
    this.initialPaymentTerms,
    this.initialValidityDays,
  });

  final double lineSubtotal;
  final void Function(QuoteFinancialFormValues values) onChanged;
  final bool enabled;
  final double? initialDeliveryCost;
  final double? initialVatRate;
  final String? initialPaymentTerms;
  final int? initialValidityDays;

  @override
  State<QuoteFinancialFormSection> createState() =>
      _QuoteFinancialFormSectionState();
}

class QuoteFinancialFormValues {
  const QuoteFinancialFormValues({
    required this.deliveryCost,
    required this.vatRate,
    required this.validUntil,
    required this.paymentTerms,
    required this.breakdown,
  });

  final double deliveryCost;
  final double vatRate;
  final DateTime validUntil;
  final String paymentTerms;
  final QuoteFinancialBreakdown breakdown;
}

class _QuoteFinancialFormSectionState extends State<QuoteFinancialFormSection> {
  final _deliveryController = TextEditingController(text: '0');
  final _vatController = TextEditingController(
    text: QuoteFinancialBreakdown.defaultVatRate.toStringAsFixed(0),
  );
  String _paymentTerms = PaymentTerms.defaultValue;
  DateTime _validUntil = DateTime.now().add(const Duration(days: 14));

  @override
  void initState() {
    super.initState();
    if (widget.initialDeliveryCost != null) {
      _deliveryController.text =
          widget.initialDeliveryCost!.toStringAsFixed(0);
    }
    if (widget.initialVatRate != null) {
      _vatController.text = widget.initialVatRate!.toStringAsFixed(0);
    }
    if (widget.initialPaymentTerms != null) {
      _paymentTerms = widget.initialPaymentTerms!;
    }
    if (widget.initialValidityDays != null) {
      _validUntil = DateTime.now().add(
        Duration(days: widget.initialValidityDays!),
      );
    }
    _notify();
    _deliveryController.addListener(_notify);
    _vatController.addListener(_notify);
  }

  @override
  void dispose() {
    _deliveryController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(_currentValues());
  }

  QuoteFinancialFormValues _currentValues() {
    final delivery = double.tryParse(_deliveryController.text) ?? 0;
    final vat = double.tryParse(_vatController.text) ??
        QuoteFinancialBreakdown.defaultVatRate;
    final breakdown = QuoteFinancialBreakdown.compute(
      subtotal: widget.lineSubtotal,
      deliveryCost: delivery,
      vatRate: vat,
    );
    return QuoteFinancialFormValues(
      deliveryCost: delivery,
      vatRate: vat,
      validUntil: _validUntil,
      paymentTerms: _paymentTerms,
      breakdown: breakdown,
    );
  }

  Future<void> _pickValidity() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('he', 'IL'),
    );
    if (picked != null) {
      setState(() => _validUntil = picked);
      _notify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = _currentValues();
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    return FormSection(
      title: 'סיכום כספי',
      subtitle: 'מחיר סופי כולל מע״מ ותנאים',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _deliveryController,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'עלות משלוח (₪)',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _vatController,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'מע״מ (%)',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _paymentTerms,
            decoration: const InputDecoration(labelText: 'תנאי תשלום'),
            items: [
              for (final v in PaymentTerms.values)
                DropdownMenuItem(value: v, child: Text(PaymentTerms.label(v))),
            ],
            onChanged: widget.enabled
                ? (v) {
                    if (v == null) return;
                    setState(() => _paymentTerms = v);
                    _notify();
                  }
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: widget.enabled ? _pickValidity : null,
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text('תוקף הצעה: ${dateFormat.format(_validUntil)}'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppTheme.navy.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                _previewRow(
                  'סכום ביניים',
                  currency.format(values.breakdown.subtotal),
                ),
                if (values.breakdown.deliveryCost > 0)
                  _previewRow(
                    'משלוח',
                    currency.format(values.breakdown.deliveryCost),
                  ),
                _previewRow(
                  'מע״מ',
                  currency.format(values.breakdown.vatAmount),
                ),
                const Divider(height: 14),
                _previewRow(
                  'סה״כ כולל מע״מ',
                  currency.format(values.breakdown.totalInclVat),
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: AppTheme.navy,
            ),
          ),
        ],
      ),
    );
  }
}

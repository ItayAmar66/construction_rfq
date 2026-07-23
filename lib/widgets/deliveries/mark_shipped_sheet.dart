import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';
import '../design_system/primary_button.dart';
import '../design_system/secondary_button.dart';

/// Result of the "mark shipped" flow: an optional ETA, carrier and tracking ref.
class MarkShippedResult {
  const MarkShippedResult({
    this.expectedDeliveryDate,
    this.carrierName,
    this.trackingReference,
  });

  final DateTime? expectedDeliveryDate;
  final String? carrierName;
  final String? trackingReference;
}

/// Presents a bottom sheet to capture shipment details before dispatching an
/// order. Returns null if the supplier cancels.
Future<MarkShippedResult?> showMarkShippedSheet(
  BuildContext context, {
  String? orderTitle,
}) {
  return showModalBottomSheet<MarkShippedResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MarkShippedSheet(orderTitle: orderTitle),
  );
}

class _MarkShippedSheet extends StatefulWidget {
  const _MarkShippedSheet({this.orderTitle});
  final String? orderTitle;

  @override
  State<_MarkShippedSheet> createState() => _MarkShippedSheetState();
}

class _MarkShippedSheetState extends State<_MarkShippedSheet> {
  DateTime? _eta;
  final _carrier = TextEditingController();
  final _tracking = TextEditingController();

  @override
  void dispose() {
    _carrier.dispose();
    _tracking.dispose();
    super.dispose();
  }

  Future<void> _pickEta() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eta ?? now.add(const Duration(days: 2)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 180)),
      helpText: 'בחירת צפי הגעה',
    );
    if (picked != null) setState(() => _eta = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, dd/MM/yyyy', 'he');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.navy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping_outlined,
                      color: AppTheme.navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'סימון ההזמנה כנשלחה',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (widget.orderTitle != null)
                        Text(
                          widget.orderTitle!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: _pickEta,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'צפי הגעה ללקוח',
                  prefixIcon: Icon(Icons.event_outlined),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _eta != null ? dateFormat.format(_eta!) : 'בחר תאריך משוער',
                  style: TextStyle(
                    color: _eta != null
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _carrier,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'חברת הובלה (רשות)',
                prefixIcon: Icon(Icons.local_shipping_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tracking,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'מספר מעקב / תעודת משלוח (רשות)',
                prefixIcon: Icon(Icons.qr_code_2),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'ביטול',
                    onPressed: () => Navigator.pop(context),
                    expand: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PrimaryButton.icon(
                    icon: Icons.check,
                    label: 'אשר ושלח',
                    onPressed: () => Navigator.pop(
                      context,
                      MarkShippedResult(
                        expectedDeliveryDate: _eta,
                        carrierName: _carrier.text.trim().isEmpty
                            ? null
                            : _carrier.text.trim(),
                        trackingReference: _tracking.text.trim().isEmpty
                            ? null
                            : _tracking.text.trim(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/delivery.dart';
import '../../utils/app_theme.dart';
import 'delivery_widgets.dart';

/// Bottom sheet showing the full lifecycle timeline + logistics for a delivery.
Future<void> showDeliveryDetailSheet(
  BuildContext context, {
  required Delivery delivery,
  bool showContractor = false,
  VoidCallback? onOpenOrder,
  String openOrderLabel = 'פתיחת ההזמנה',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, controller) => _DeliveryDetailSheet(
        delivery: delivery,
        controller: controller,
        showContractor: showContractor,
        onOpenOrder: onOpenOrder,
        openOrderLabel: openOrderLabel,
      ),
    ),
  );
}

class _DeliveryDetailSheet extends StatelessWidget {
  const _DeliveryDetailSheet({
    required this.delivery,
    required this.controller,
    required this.showContractor,
    required this.onOpenOrder,
    required this.openOrderLabel,
  });

  final Delivery delivery;
  final ScrollController controller;
  final bool showContractor;
  final VoidCallback? onOpenOrder;
  final String openOrderLabel;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');
    final style = DeliveryStageStyle.of(delivery.stage);
    final metaBits = <String>[
      if (showContractor) delivery.contractorName,
      if (!showContractor && delivery.supplierName != null)
        delivery.supplierName!,
      if (delivery.projectLocation != null) delivery.projectLocation!,
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            delivery.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (metaBits.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                metaBits.join(' · '),
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    DeliveryStageChip(stage: delivery.stage),
                  ],
                ),
                const SizedBox(height: 20),
                if (delivery.carrierName != null ||
                    delivery.trackingReference != null ||
                    delivery.amount != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        if (delivery.carrierName != null)
                          _InfoRow(
                            icon: Icons.local_shipping_outlined,
                            label: 'חברת הובלה',
                            value: delivery.carrierName!,
                          ),
                        if (delivery.trackingReference != null)
                          _InfoRow(
                            icon: Icons.qr_code_2,
                            label: 'מספר מעקב',
                            value: delivery.trackingReference!,
                          ),
                        if (delivery.amount != null)
                          _InfoRow(
                            icon: Icons.payments_outlined,
                            label: 'סכום ההזמנה',
                            value: currency.format(delivery.amount),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'מסלול המשלוח',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                DeliveryTimeline(delivery: delivery),
                if (onOpenOrder != null) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: style.color),
                      onPressed: () {
                        Navigator.pop(context);
                        onOpenOrder!();
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: Text(openOrderLabel),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

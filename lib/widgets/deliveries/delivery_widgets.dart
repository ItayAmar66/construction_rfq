import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/delivery.dart';
import '../../utils/app_theme.dart';
import '../status_chip.dart';

/// Resolved colours + icon for a delivery stage.
class DeliveryStageStyle {
  const DeliveryStageStyle(this.color, this.surface, this.icon, this.label);
  final Color color;
  final Color surface;
  final IconData icon;
  final String label;

  static DeliveryStageStyle of(DeliveryStage stage) {
    switch (stage) {
      case DeliveryStage.awaitingShipment:
        return DeliveryStageStyle(
          AppTheme.amberDark,
          AppTheme.amber.withValues(alpha: 0.14),
          Icons.inventory_2_outlined,
          stage.label,
        );
      case DeliveryStage.inTransit:
        return DeliveryStageStyle(
          AppTheme.navy,
          AppTheme.navy.withValues(alpha: 0.10),
          Icons.local_shipping_outlined,
          stage.label,
        );
      case DeliveryStage.delayed:
        return DeliveryStageStyle(
          AppTheme.danger,
          AppTheme.danger.withValues(alpha: 0.10),
          Icons.running_with_errors_outlined,
          stage.label,
        );
      case DeliveryStage.delivered:
        return DeliveryStageStyle(
          AppTheme.emerald,
          AppTheme.emerald.withValues(alpha: 0.12),
          Icons.check_circle_outline,
          stage.label,
        );
      case DeliveryStage.deliveredWithIssues:
        return DeliveryStageStyle(
          AppTheme.danger,
          AppTheme.danger.withValues(alpha: 0.10),
          Icons.report_problem_outlined,
          stage.label,
        );
    }
  }
}

/// Pill showing a delivery stage with matching icon + colour.
class DeliveryStageChip extends StatelessWidget {
  const DeliveryStageChip(
      {super.key, required this.stage, this.compact = false});

  final DeliveryStage stage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = DeliveryStageStyle.of(stage);
    return StatusChip(
      label: style.label,
      foreground: style.color,
      background: style.surface,
      icon: style.icon,
      dense: compact,
      bordered: false,
    );
  }
}

/// Human relative label for a delivery's ETA (e.g. "עוד 3 ימים" / "באיחור").
String? deliveryEtaLabel(Delivery d) {
  final days = d.daysToEta;
  if (days == null) return null;
  if (days < 0) return 'באיחור ${-days} ${-days == 1 ? 'יום' : 'ימים'}';
  if (days == 0) return 'צפי הגעה היום';
  if (days == 1) return 'צפי הגעה מחר';
  return 'צפי הגעה בעוד $days ימים';
}

/// A rich, tappable delivery card used across contractor + supplier surfaces.
class DeliveryCard extends StatelessWidget {
  const DeliveryCard({
    super.key,
    required this.delivery,
    this.onTap,
    this.showContractor = false,
    this.trailingAmount,
  });

  final Delivery delivery;
  final VoidCallback? onTap;

  /// When true shows the contractor name (supplier-facing lists).
  final bool showContractor;
  final String? trailingAmount;

  @override
  Widget build(BuildContext context) {
    final style = DeliveryStageStyle.of(delivery.stage);
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');
    final eta = deliveryEtaLabel(delivery);
    final metaBits = <String>[
      if (showContractor) delivery.contractorName,
      if (!showContractor && delivery.supplierName != null)
        delivery.supplierName!,
      if (delivery.projectLocation != null) delivery.projectLocation!,
      if (delivery.itemCount > 0) '${delivery.itemCount} פריטים',
    ];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: style.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(style.icon, color: style.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          delivery.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (metaBits.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              metaBits.join(' · '),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DeliveryStageChip(stage: delivery.stage, compact: true),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: delivery.stage.progress,
                  minHeight: 5,
                  backgroundColor: AppTheme.borderColor,
                  valueColor: AlwaysStoppedAnimation(style.color),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (delivery.stage.isOpen && eta != null) ...[
                    Icon(
                      delivery.isOverdue
                          ? Icons.warning_amber_rounded
                          : Icons.schedule,
                      size: 15,
                      color:
                          delivery.isOverdue ? AppTheme.danger : AppTheme.navy,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        eta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: delivery.isOverdue
                              ? AppTheme.danger
                              : AppTheme.navy,
                        ),
                      ),
                    ),
                  ] else if (delivery.stage.isClosed &&
                      delivery.receivedAt != null) ...[
                    const Icon(Icons.event_available,
                        size: 15, color: AppTheme.textSecondary),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'התקבל ${dateFormat.format(delivery.receivedAt!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ] else if (delivery.stage == DeliveryStage.awaitingShipment)
                    Text(
                      'טרם נשלח מהספק',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  const Spacer(),
                  if (trailingAmount != null)
                    Text(
                      trailingAmount!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    )
                  else if (delivery.trackingReference != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_2,
                            size: 15, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          delivery.trackingReference!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical milestone timeline for a single delivery.
class DeliveryTimeline extends StatelessWidget {
  const DeliveryTimeline({super.key, required this.delivery});

  final Delivery delivery;

  IconData _iconFor(DeliveryEventKind kind) {
    switch (kind) {
      case DeliveryEventKind.ordered:
        return Icons.receipt_long_outlined;
      case DeliveryEventKind.shipped:
        return Icons.local_shipping_outlined;
      case DeliveryEventKind.expected:
        return Icons.schedule;
      case DeliveryEventKind.delivered:
        return Icons.check_circle_outline;
      case DeliveryEventKind.issue:
        return Icons.report_problem_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = delivery.timeline;
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');
    final accent = DeliveryStageStyle.of(delivery.stage).color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < events.length; i++)
          _TimelineRow(
            icon: _iconFor(events[i].kind),
            title: events[i].title,
            subtitle: events[i].subtitle,
            dateText: events[i].date != null
                ? dateFormat.format(events[i].date!)
                : null,
            done: events[i].done,
            isCurrent: events[i].isCurrent,
            isIssue: events[i].kind == DeliveryEventKind.issue,
            isLast: i == events.length - 1,
            accent: accent,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.dateText,
    required this.done,
    required this.isCurrent,
    required this.isIssue,
    required this.isLast,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? dateText;
  final bool done;
  final bool isCurrent;
  final bool isIssue;
  final bool isLast;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final active = done || isCurrent;
    final color = isIssue
        ? AppTheme.danger
        : active
            ? accent
            : AppTheme.textSecondary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: active
                      ? color.withValues(alpha: 0.14)
                      : AppTheme.surfaceTint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? color : AppTheme.borderColor,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: done
                        ? accent.withValues(alpha: 0.4)
                        : AppTheme.borderColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w600,
                            color: active
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      if (dateText != null)
                        Text(
                          dateText!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented filter bar with live counts for delivery lists.
class DeliveryFilterBar<T> extends StatelessWidget {
  const DeliveryFilterBar({
    super.key,
    required this.options,
    required this.labelOf,
    required this.countOf,
    required this.selected,
    required this.onSelected,
  });

  final List<T> options;
  final String Function(T) labelOf;
  final int Function(T) countOf;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _FilterChip(
                label: labelOf(o),
                count: countOf(o),
                selected: o == selected,
                onTap: () => onSelected(o),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.navy : AppTheme.surfaceTint,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

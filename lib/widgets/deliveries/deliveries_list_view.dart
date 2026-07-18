import 'package:flutter/material.dart';

import '../../models/delivery.dart';
import '../../providers/delivery_providers.dart';
import '../../utils/app_theme.dart';
import '../empty_state.dart';
import 'delivery_detail_sheet.dart';
import 'delivery_widgets.dart';

/// Shared, fully-featured deliveries surface: a summary strip, filter chips,
/// search, and a responsive card grid. Reused by contractor + supplier screens.
class DeliveriesListView extends StatefulWidget {
  const DeliveriesListView({
    super.key,
    required this.deliveries,
    this.showContractor = false,
    this.onOpenOrder,
    this.openOrderLabel = 'פתיחת ההזמנה',
    this.padding = const EdgeInsets.all(16),
  });

  final List<Delivery> deliveries;
  final bool showContractor;
  final void Function(Delivery)? onOpenOrder;
  final String openOrderLabel;
  final EdgeInsets padding;

  @override
  State<DeliveriesListView> createState() => _DeliveriesListViewState();
}

class _DeliveriesListViewState extends State<DeliveriesListView> {
  DeliveryFilter _filter = DeliveryFilter.all;
  String _query = '';

  int _countFor(DeliveryFilter f) =>
      widget.deliveries.where(f.matches).length;

  bool _matchesQuery(Delivery d) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return d.title.toLowerCase().contains(q) ||
        d.contractorName.toLowerCase().contains(q) ||
        (d.supplierName?.toLowerCase().contains(q) ?? false) ||
        (d.trackingReference?.toLowerCase().contains(q) ?? false) ||
        (d.projectLocation?.toLowerCase().contains(q) ?? false);
  }

  void _openDetail(Delivery d) {
    showDeliveryDetailSheet(
      context,
      delivery: d,
      showContractor: widget.showContractor,
      openOrderLabel: widget.openOrderLabel,
      onOpenOrder:
          widget.onOpenOrder != null ? () => widget.onOpenOrder!(d) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = summarizeDeliveries(widget.deliveries);
    final visible = widget.deliveries
        .where(_filter.matches)
        .where(_matchesQuery)
        .toList();

    return ListView(
      padding: widget.padding,
      children: [
        _SummaryStrip(summary: summary),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'חיפוש לפי פרויקט, קבלן, ספק או מספר מעקב',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            filled: true,
            fillColor: AppTheme.surfaceTint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        DeliveryFilterBar<DeliveryFilter>(
          options: DeliveryFilter.values,
          labelOf: (f) => f.label,
          countOf: _countFor,
          selected: _filter,
          onSelected: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: EmptyState(
              message: _query.isNotEmpty
                  ? 'לא נמצאו משלוחים תואמים'
                  : 'אין משלוחים בקטגוריה זו',
              icon: Icons.local_shipping_outlined,
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCol = constraints.maxWidth >= 720;
              if (!twoCol) {
                return Column(
                  children: [
                    for (final d in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DeliveryCard(
                          delivery: d,
                          showContractor: widget.showContractor,
                          onTap: () => _openDetail(d),
                        ),
                      ),
                  ],
                );
              }
              const spacing = 12.0;
              final itemWidth = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final d in visible)
                    SizedBox(
                      width: itemWidth,
                      child: DeliveryCard(
                        delivery: d,
                        showContractor: widget.showContractor,
                        onTap: () => _openDetail(d),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});
  final DeliverySummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            value: summary.active,
            label: 'פעילים',
            icon: Icons.local_shipping_outlined,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            value: summary.delayed,
            label: 'דורש טיפול',
            icon: Icons.warning_amber_rounded,
            color: AppTheme.danger,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            value: summary.delivered,
            label: 'הושלמו',
            icon: Icons.check_circle_outline,
            color: AppTheme.emerald,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

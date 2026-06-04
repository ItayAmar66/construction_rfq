import 'package:flutter/material.dart';

import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

class RequestTimeline extends StatelessWidget {
  const RequestTimeline({super.key, required this.request});

  final QuoteRequest request;

  @override
  Widget build(BuildContext context) {
    final steps = _stepsFor(request);
    final activeIndex = _activeIndex(steps, request.status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: AppTheme.cardDecoration(elevation: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_outlined, size: 18, color: AppTheme.navy),
              const SizedBox(width: 8),
              Text('מעקב סטטוס', style: AppTypography.h2(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...List.generate(steps.length, (i) {
            final done = i < activeIndex;
            final current = i == activeIndex;
            final isLast = i == steps.length - 1;
            return _TimelineRow(
              label: steps[i].label,
              done: done,
              current: current,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  int _activeIndex(List<_Step> steps, QuoteRequestStatus status) {
    final idx = steps.indexWhere((s) => s.statuses.contains(status));
    return idx < 0 ? 0 : idx;
  }

  List<_Step> _stepsFor(QuoteRequest request) {
    if (request.status == QuoteRequestStatus.cancelled) {
      return const [
        _Step('בוטלה', {QuoteRequestStatus.cancelled}),
      ];
    }
    return const [
      _Step('נשלח לספקים', {
        QuoteRequestStatus.sent,
        QuoteRequestStatus.draft,
      }),
      _Step('התקבלו הצעות', {QuoteRequestStatus.quotesReceived}),
      _Step('הצעה אושרה', {QuoteRequestStatus.ordered}),
      _Step('בהכנה', {QuoteRequestStatus.ordered}),
      _Step('בדרך', {QuoteRequestStatus.shipped}),
      _Step('נמסר', {
        QuoteRequestStatus.shipped,
        QuoteRequestStatus.completed,
      }),
    ];
  }
}

class _Step {
  const _Step(this.label, this.statuses);
  final String label;
  final Set<QuoteRequestStatus> statuses;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.done,
    required this.current,
    required this.isLast,
  });

  final String label;
  final bool done;
  final bool current;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = current
        ? AppTheme.teal
        : done
            ? AppTheme.emerald
            : AppTheme.borderColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: current ? 14 : 10,
                  height: current ? 14 : 10,
                  decoration: BoxDecoration(
                    color: current ? Colors.white : dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dotColor,
                      width: current ? 3 : 0,
                    ),
                    boxShadow: current
                        ? [
                            BoxShadow(
                              color: AppTheme.teal.withValues(alpha: 0.35),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: done
                          ? AppTheme.emerald.withValues(alpha: 0.4)
                          : AppTheme.borderColor,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Text(
                label,
                style: AppTypography.body(context).copyWith(
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  color: done || current
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../models/request_audit_event.dart';
import '../models/supplier_quote.dart';
import '../utils/app_theme.dart';
import '../utils/request_audit_trail.dart';

class RequestTimeline extends StatelessWidget {
  const RequestTimeline({
    super.key,
    required this.request,
    this.quotes = const [],
  });

  final QuoteRequest request;
  final List<SupplierQuote> quotes;

  @override
  Widget build(BuildContext context) {
    final steps = _stepsFor(request, quotes);
    final activeIndex = _activeIndex(steps, request.status, quotes);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'מעקב סטטוס',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) {
            final done = i <= activeIndex;
            final current = i == activeIndex;
            final isLast = i == steps.length - 1;
            return _TimelineRow(
              label: steps[i].label,
              detail: steps[i].detail,
              done: done,
              current: current,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  static int _activeIndex(
    List<_Step> steps,
    QuoteRequestStatus status,
    List<SupplierQuote> quotes,
  ) {
    if (status == QuoteRequestStatus.cancelled) return 0;

    if (status == QuoteRequestStatus.shipped ||
        status == QuoteRequestStatus.pendingReceipt ||
        status == QuoteRequestStatus.receivedFull ||
        status == QuoteRequestStatus.receivedWithIssues ||
        status == QuoteRequestStatus.completed) {
      return steps.length - 1;
    }
    if (status == QuoteRequestStatus.ordered) {
      return steps.indexWhere(
        (s) => s.type == RequestAuditEventType.quoteApproved,
      );
    }
    if (status == QuoteRequestStatus.quotesReceived || quotes.isNotEmpty) {
      return steps.indexWhere(
        (s) => s.type == RequestAuditEventType.supplierQuoted,
      );
    }
    return steps.indexWhere((s) => s.type == RequestAuditEventType.sent);
  }

  static List<_Step> _stepsFor(
    QuoteRequest request,
    List<SupplierQuote> quotes,
  ) {
    if (request.status == QuoteRequestStatus.cancelled) {
      return const [
        _Step('בוטלה', RequestAuditEventType.sent, statuses: {
          QuoteRequestStatus.cancelled,
        }),
      ];
    }

    final events = RequestAuditTrail.build(request: request, quotes: quotes);
    final quoteCount = quotes.isNotEmpty
        ? quotes.length
        : events
            .where((e) => e.type == RequestAuditEventType.supplierQuoted)
            .length;

    return [
      _Step(
        RequestAuditTrail.labelFor(RequestAuditEventType.sent),
        RequestAuditEventType.sent,
        statuses: {
          QuoteRequestStatus.sent,
          QuoteRequestStatus.draft,
        },
      ),
      _Step(
        quoteCount > 0 ? 'התקבלו $quoteCount הצעות' : 'התקבלו הצעות',
        RequestAuditEventType.supplierQuoted,
        statuses: {QuoteRequestStatus.quotesReceived},
        detail: quoteCount > 0 ? '$quoteCount ספקים הגישו הצעות' : null,
      ),
      _Step(
        RequestAuditTrail.labelFor(RequestAuditEventType.quoteApproved),
        RequestAuditEventType.quoteApproved,
        statuses: {QuoteRequestStatus.ordered},
      ),
      _Step(
        RequestAuditTrail.labelFor(RequestAuditEventType.shipped),
        RequestAuditEventType.shipped,
        statuses: {
          QuoteRequestStatus.shipped,
          QuoteRequestStatus.pendingReceipt,
          QuoteRequestStatus.receivedFull,
          QuoteRequestStatus.receivedWithIssues,
          QuoteRequestStatus.completed,
        },
      ),
    ];
  }
}

class _Step {
  const _Step(
    this.label,
    this.type, {
    this.statuses = const {},
    this.detail,
  });

  final String label;
  final RequestAuditEventType type;
  final Set<QuoteRequestStatus> statuses;
  final String? detail;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.detail,
    required this.done,
    required this.current,
    required this.isLast,
  });

  final String label;
  final String? detail;
  final bool done;
  final bool current;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = current
        ? AppTheme.accentColor
        : done
            ? AppTheme.primaryColor
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
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: current
                        ? Border.all(color: AppTheme.accentColor, width: 3)
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: done
                          ? AppTheme.primaryColor.withValues(alpha: 0.35)
                          : AppTheme.borderColor,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              current ? FontWeight.bold : FontWeight.w500,
                          color: done
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                  ),
                  if (detail != null && done) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

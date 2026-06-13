import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/enterprise/audit_event.dart';
import '../../repositories/audit_repository.dart';
import '../../utils/app_theme.dart';

class AuditEventsList extends ConsumerWidget {
  const AuditEventsList({
    super.key,
    required this.eventsAsync,
    this.compact = false,
  });

  final AsyncValue<List<AuditEvent>> eventsAsync;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return eventsAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, __) => const Text('לא ניתן לטעון היסטוריה'),
      data: (events) {
        if (events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'עדיין אין פעולות להצגה',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        final fmt = DateFormat('dd/MM HH:mm', 'he');
        return Column(
          children: [
            for (final event in events)
              ListTile(
                dense: compact,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _iconFor(event.action),
                  size: compact ? 18 : 22,
                  color: AppTheme.textSecondary,
                ),
                title: Text(
                  event.summaryHebrew,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (event.actorName?.isNotEmpty == true) event.actorName!,
                    if (event.createdAt != null) fmt.format(event.createdAt!),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
          ],
        );
      },
    );
  }

  IconData _iconFor(String action) {
    switch (action) {
      case AuditAction.invitationCreated:
      case AuditAction.invitationAccepted:
      case AuditAction.invitationCancelled:
        return Icons.mail_outline;
      case AuditAction.roleChanged:
        return Icons.badge_outlined;
      case AuditAction.projectAssigned:
      case AuditAction.projectAssignmentRemoved:
        return Icons.group_outlined;
      case AuditAction.projectCompleted:
      case AuditAction.projectCreated:
      case AuditAction.projectDeletionRequested:
      case AuditAction.projectDeletionCancelled:
        return Icons.construction_outlined;
      case AuditAction.rfqSent:
        return Icons.send_outlined;
      case AuditAction.quoteSubmitted:
      case AuditAction.quoteApproved:
      case AuditAction.quoteRejected:
        return Icons.request_quote_outlined;
      case AuditAction.orderMarkedShipped:
        return Icons.local_shipping_outlined;
      default:
        return Icons.history;
    }
  }
}

class OrgAuditHistoryTab extends ConsumerWidget {
  const OrgAuditHistoryTab({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(orgAuditEventsProvider(orgId));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'היסטוריית פעולות',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        AuditEventsList(eventsAsync: events),
      ],
    );
  }
}

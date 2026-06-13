import 'package:flutter/material.dart';

import '../../models/enterprise/organization_invitation.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';

class PendingInvitationsSection extends StatelessWidget {
  const PendingInvitationsSection({
    super.key,
    required this.invitations,
    this.canCancel = false,
    this.onCancel,
  });

  final List<OrganizationInvitation> invitations;
  final bool canCancel;
  final void Function(OrganizationInvitation invite)? onCancel;

  @override
  Widget build(BuildContext context) {
    final pending = invitations.where((i) => i.isPending).toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'הזמנות ממתינות (${pending.length})',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        for (final invite in pending)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.mail_outline, size: 20),
              title: Text(
                invite.displayName?.isNotEmpty == true
                    ? invite.displayName!
                    : invite.email,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                '${invite.email} · ${EnterpriseRoleLabels.hebrew(invite.role)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: canCancel && onCancel != null
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'בטל הזמנה',
                      onPressed: () => onCancel!(invite),
                    )
                  : const Chip(
                      label: Text('ממתין', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
            ),
          ),
      ],
    );
  }
}

class InvitationAcceptBanner extends StatelessWidget {
  const InvitationAcceptBanner({
    super.key,
    required this.invitations,
    required this.onAccept,
    this.accepting = false,
  });

  final List<OrganizationInvitation> invitations;
  final void Function(OrganizationInvitation invite) onAccept;
  final bool accepting;

  @override
  Widget build(BuildContext context) {
    final pending = invitations.where((i) => i.isPending).toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    final invite = pending.first;
    return Card(
      color: AppTheme.teal.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.group_add_outlined, color: AppTheme.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'יש לך הזמנה להצטרף לחברה',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${EnterpriseRoleLabels.hebrew(invite.role)} · ${invite.orgId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: accepting ? null : () => onAccept(invite),
              child: accepting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('הצטרף לחברה'),
            ),
          ],
        ),
      ),
    );
  }
}

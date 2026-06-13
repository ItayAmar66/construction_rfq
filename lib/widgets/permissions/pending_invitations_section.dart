import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/enterprise/organization_invitation.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import '../../utils/invitation_link_builder.dart';

class InvitationsManagementSection extends StatelessWidget {
  const InvitationsManagementSection({
    super.key,
    required this.invitations,
    required this.canManage,
    required this.isEmailConfigured,
    this.onCancel,
    this.onCopyLink,
    this.onResend,
  });

  final List<OrganizationInvitation> invitations;
  final bool canManage;
  final bool isEmailConfigured;
  final void Function(OrganizationInvitation invite)? onCancel;
  final void Function(OrganizationInvitation invite)? onCopyLink;
  final void Function(OrganizationInvitation invite)? onResend;

  @override
  Widget build(BuildContext context) {
    if (invitations.isEmpty) return const SizedBox.shrink();
    final fmt = DateFormat('dd/MM/yyyy', 'he');
    final active = invitations
        .where((i) => i.status == 'pending' || i.status == 'accepted')
        .toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));

    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'הזמנות (${active.length})',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (!isEmailConfigured) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceTint,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Text(
              'שליחת מייל אמיתית תופעל לאחר חיבור ספק מייל מאובטח. '
              'כרגע ניתן להעתיק קישור הזמנה.',
              style: TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (final invite in active)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mail_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          invite.displayName?.isNotEmpty == true
                              ? invite.displayName!
                              : invite.email,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _StatusChip(
                        label: invitationStatusLabel(invite.status),
                      ),
                      const SizedBox(width: 4),
                      _StatusChip(
                        label: invitationDeliveryStatusLabel(
                          invite.deliveryStatus,
                        ),
                        muted: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${invite.email} · ${EnterpriseRoleLabels.hebrew(invite.role)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (invite.createdAt != null)
                    Text(
                      'נוצר: ${fmt.format(invite.createdAt!)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  if (canManage && invite.isPending) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onCopyLink == null
                              ? null
                              : () => onCopyLink!(invite),
                          icon: const Icon(Icons.link, size: 16),
                          label: const Text('העתק קישור'),
                        ),
                        if (isEmailConfigured && onResend != null)
                          OutlinedButton.icon(
                            onPressed: () => onResend!(invite),
                            icon: const Icon(Icons.send_outlined, size: 16),
                            label: const Text('שלח שוב'),
                          ),
                        if (onCancel != null)
                          TextButton.icon(
                            onPressed: () => onCancel!(invite),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('בטל'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      visualDensity: VisualDensity.compact,
      backgroundColor: muted
          ? AppTheme.surfaceTint
          : AppTheme.teal.withValues(alpha: 0.1),
    );
  }
}

class PendingInvitationsSection extends InvitationsManagementSection {
  const PendingInvitationsSection({
    super.key,
    required super.invitations,
    super.canManage = false,
    super.isEmailConfigured = false,
    super.onCancel,
    super.onCopyLink,
    super.onResend,
  });
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

String invitationStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'ממתין';
    case 'accepted':
      return 'התקבל';
    case 'cancelled':
      return 'בוטל';
    default:
      return status;
  }
}

String invitationDeliveryStatusLabel(String deliveryStatus) {
  switch (deliveryStatus) {
    case InviteDeliveryStatus.pending:
      return 'ממתין';
    case InviteDeliveryStatus.sent:
      return 'נשלח';
    case InviteDeliveryStatus.failed:
      return 'נכשל';
    case InviteDeliveryStatus.copied:
      return 'הועתק';
    case InviteDeliveryStatus.accepted:
      return 'התקבל';
    default:
      return deliveryStatus;
  }
}

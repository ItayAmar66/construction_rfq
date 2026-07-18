import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enterprise/membership.dart';
import '../../models/enterprise/organization_invitation.dart';
import '../../models/enterprise/organization_type.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../repositories/invitation_repository.dart';
import '../../screens/invitations/invite_landing_screen.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import '../../utils/org_id_helpers.dart';
import '../../utils/role_invitation_policy.dart';
import '../enterprise/org_setup_required_banner.dart';
import 'invite_user_dialog.dart';
import 'pending_access_requests_section.dart';
import 'pending_invitations_section.dart';
import 'role_read_only_notice.dart';
import 'team_permissions_section.dart';

/// The full team-access management flow for the current user's organization:
/// my-user summary, invite action, pending invitations, pending access
/// requests, and the team & permissions list — one consolidated widget shared
/// by the contractor and supplier company screens.
class OrgTeamAccessSection extends ConsumerWidget {
  const OrgTeamAccessSection({super.key, required this.orgType});

  final OrganizationType orgType;

  bool get _isContractor => orgType == OrganizationType.contractor;

  String get _teamTitle => _isContractor ? 'צוות החברה' : 'צוות הספק';

  String get _connectMessage => _isContractor
      ? 'שינוי הרשאות יופעל אחרי חיבור צוות החברה.'
      : 'שינוי הרשאות יופעל אחרי חיבור צוות הספק.';

  String get _readOnlyMessage => _isContractor
      ? 'רק מנהל חברה יכול לשנות הרשאות.'
      : 'רק מנהל ספק יכול לשנות הרשאות.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final user = session?.profile;
    final canManageRoles = ref.watch(canManageCompanyRolesProvider);
    final canInvite = ref.watch(canInviteCompanyMembersProvider);
    final myMemberships =
        ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [];
    final actorRoles = myMemberships.firstOrNull?.roles ?? const [];
    final orgId = myMemberships.firstOrNull?.orgId;
    final realOrgId = OrgIdHelpers.isRealOrgId(orgId) ? orgId : null;
    final orgMembershipsAsync = realOrgId != null
        ? ref.watch(orgMembershipsProvider(realOrgId))
        : const AsyncValue<List<Membership>>.data([]);
    final invitationsAsync = realOrgId != null
        ? ref.watch(orgInvitationsProvider(realOrgId))
        : const AsyncValue<List<OrganizationInvitation>>.data([]);
    final emailConfigured =
        ref.watch(invitationRepositoryProvider).isEmailProviderConfigured;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (user != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'המשתמש שלי',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    myMemberships.firstOrNull?.roles.firstOrNull != null
                        ? EnterpriseRoleLabels.hebrew(
                            myMemberships.first.roles.first)
                        : EnterpriseRoleLabels.legacyLabel(user),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (realOrgId == null) ...[
          const OrgSetupRequiredBanner(),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                _teamTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (canInvite && realOrgId != null)
              FilledButton.icon(
                onPressed: () => _openInviteDialog(context, ref, realOrgId),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('הוסף משתמש'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        invitationsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (invites) => PendingInvitationsSection(
            invitations: invites,
            canManage: canManageRoles && realOrgId != null,
            isEmailConfigured: emailConfigured,
            onCancel: canManageRoles
                ? (invite) => _cancelInvite(context, ref, invite)
                : null,
            onCopyLink: canManageRoles
                ? (invite) => _copyInviteLink(context, invite)
                : null,
            onResend: canManageRoles && emailConfigured
                ? (invite) => _resendInvite(context, ref, invite)
                : null,
          ),
        ),
        if (invitationsAsync.valueOrNull?.any((i) => i.isPending) == true)
          const SizedBox(height: 12),
        orgMembershipsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('שגיאה בטעינת חברי הצוות'),
          data: (members) {
            if (realOrgId == null) {
              return Column(
                children: [
                  const _EmptyTeamState(),
                  const SizedBox(height: 12),
                  RoleReadOnlyNotice(
                    message: _connectMessage,
                    showDisabledButton: false,
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canManageRoles)
                  PendingAccessRequestsSection(
                    title: 'משתמשים ממתינים לאישור בחברה שלי',
                    orgId: realOrgId,
                    orgType: orgType,
                  ),
                TeamPermissionsSection(
                  orgId: realOrgId,
                  orgType: orgType,
                  actorRoles: actorRoles,
                  isPlatformAdmin: false,
                  title: 'ניהול צוות והרשאות',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (!canManageRoles)
          RoleReadOnlyNotice(
            message: _readOnlyMessage,
            showDisabledButton: false,
          ),
      ],
    );
  }

  Future<void> _openInviteDialog(
    BuildContext context,
    WidgetRef ref,
    String orgId,
  ) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    final actorRoles = ref
            .read(currentUserMembershipsProvider)
            .valueOrNull
            ?.firstOrNull
            ?.roles ??
        const [];
    OrganizationInvitation? createdInvite;
    await InviteUserDialog.show(
      context: context,
      orgType: orgType,
      allowedRoles: RoleInvitationPolicy.assignableRoles(
        orgType: orgType,
        actorRoles: actorRoles,
      ),
      onSubmit: ({required name, required email, required role}) async {
        createdInvite =
            await ref.read(invitationRepositoryProvider).createInvitation(
                  orgId: orgId,
                  orgType: orgType,
                  email: email,
                  role: role,
                  invitedByUid: session?.uid ?? '',
                  invitedByName: session?.profile?.fullName,
                  displayName: name.isEmpty ? null : name,
                  canManage: ref.read(canInviteCompanyMembersProvider),
                  actorRoles: actorRoles,
                );
        ref.invalidate(orgInvitationsProvider(orgId));
      },
    );
    if (context.mounted && createdInvite != null) {
      await _showInviteCreatedDialog(context, createdInvite!);
    }
  }

  Future<void> _showInviteCreatedDialog(
    BuildContext context,
    OrganizationInvitation invite,
  ) async {
    final emailConfigured = ProviderScope.containerOf(context)
        .read(invitationRepositoryProvider)
        .isEmailProviderConfigured;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ההזמנה נוצרה'),
        content: Text(
          emailConfigured
              ? 'ההזמנה נשלחה. ניתן גם להעתיק קישור לשיתוף ידני.'
              : 'כרגע ניתן להעתיק קישור הזמנה. שליחת מייל אוטומטית תחובר בהמשך.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('סגור'),
          ),
          FilledButton(
            onPressed: () {
              copyInviteLink(invite);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('קישור ההזמנה הועתק')),
              );
            },
            child: const Text('העתק קישור'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyInviteLink(
    BuildContext context,
    OrganizationInvitation invite,
  ) async {
    copyInviteLink(invite);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('קישור ההזמנה הועתק')),
      );
    }
  }

  Future<void> _resendInvite(
    BuildContext context,
    WidgetRef ref,
    OrganizationInvitation invite,
  ) async {
    await ref.read(invitationRepositoryProvider).deliverInvitation(
          invitation: invite,
          canManage: ref.read(canManageCompanyRolesProvider),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ההזמנה נשלחה שוב')),
      );
    }
  }

  Future<void> _cancelInvite(
    BuildContext context,
    WidgetRef ref,
    OrganizationInvitation invite,
  ) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    await ref.read(invitationRepositoryProvider).cancelInvitation(
          inviteId: invite.id,
          canManage: ref.read(canManageCompanyRolesProvider),
          actorUid: session?.uid ?? '',
          actorEmail: session?.profile?.email,
          actorName: session?.profile?.fullName,
          inviteForAudit: invite,
        );
    final orgId =
        ref.read(currentUserMembershipsProvider).valueOrNull?.firstOrNull?.orgId;
    if (orgId != null) ref.invalidate(orgInvitationsProvider(orgId));
  }
}

class _EmptyTeamState extends StatelessWidget {
  const _EmptyTeamState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 32, color: AppTheme.textSecondary),
          const SizedBox(height: 8),
          const Text(
            'עדיין אין צוות מחובר לחברה',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'בשלב הבא ניתן יהיה להזמין משתמשים ולשייך תפקידים',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

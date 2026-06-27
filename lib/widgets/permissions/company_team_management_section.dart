import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/membership.dart';
import '../../models/enterprise/organization_type.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../providers/user_approval_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import '../../utils/role_invitation_policy.dart';
import '../../widgets/permissions/membership_row_card.dart';
import '../../widgets/permissions/role_change_dialog.dart';
import 'pending_access_requests_section.dart';

class CompanyTeamManagementSection extends ConsumerWidget {
  const CompanyTeamManagementSection({
    super.key,
    required this.orgId,
    required this.orgType,
    required this.canManage,
    required this.actorRoles,
    required this.pendingTitle,
  });

  final String orgId;
  final OrganizationType orgType;
  final bool canManage;
  final List<EnterpriseRole> actorRoles;
  final String pendingTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipsAsync = ref.watch(orgMembershipsProvider(orgId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canManage)
          PendingAccessRequestsSection(
            title: pendingTitle,
            orgId: orgId,
            orgType: orgType,
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                'ניהול משתמשים',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        membershipsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('שגיאה בטעינת משתמשים'),
          data: (members) {
            if (members.isEmpty) {
              return const Text('אין משתמשים בחברה');
            }
            return Column(
              children: [
                for (final membership in members)
                  _TeamMemberCard(
                    membership: membership,
                    orgId: orgId,
                    orgType: orgType,
                    canManage: canManage,
                    actorRoles: actorRoles,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TeamMemberCard extends ConsumerWidget {
  const _TeamMemberCard({
    required this.membership,
    required this.orgId,
    required this.orgType,
    required this.canManage,
    required this.actorRoles,
  });

  final Membership membership;
  final String orgId;
  final OrganizationType orgType;
  final bool canManage;
  final List<EnterpriseRole> actorRoles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = membership.roles.firstOrNull;
    final isDisabled = membership.status == 'disabled';

    return Column(
      children: [
        MembershipRowCard(
          membership: membership,
          canEditRole: canManage && !isDisabled,
          onEditRole: canManage && !isDisabled
              ? () => _editRole(context, ref)
              : null,
        ),
        if (canManage && membership.uid != ref.read(authSessionProvider).valueOrNull?.uid)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: Row(
              children: [
                if (membership.projectIds.isNotEmpty)
                  Expanded(
                    child: Text(
                      'פרויקטים: ${membership.projectIds.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                if (role != null)
                  Text(
                    EnterpriseRoleLabels.hebrew(role),
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => _toggleDisabled(context, ref, disable: !isDisabled),
                  child: Text(isDisabled ? 'הפעל מחדש' : 'השבת משתמש'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _editRole(BuildContext context, WidgetRef ref) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    await RoleChangeDialog.show(
      context: context,
      membership: membership,
      displayName: membership.displayLabel,
      orgType: orgType,
      allowedRoles: RoleInvitationPolicy.assignableRoles(
        orgType: orgType,
        actorRoles: actorRoles,
      ),
      onSave: (newRole) async {
        await ref.read(organizationRepositoryProvider).updateMemberRole(
              orgId: orgId,
              memberUid: membership.uid,
              newRole: newRole,
              actorUid: session?.uid ?? '',
              orgType: orgType,
            );
        ref.invalidate(orgMembershipsProvider(orgId));
      },
    );
  }

  Future<void> _toggleDisabled(
    BuildContext context,
    WidgetRef ref, {
    required bool disable,
  }) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    final service = ref.read(userApprovalServiceProvider);
    if (disable) {
      await service.disableUser(
        uid: membership.uid,
        orgId: orgId,
        actorUid: session?.uid ?? '',
      );
    } else {
      await service.reactivateUser(
        uid: membership.uid,
        orgId: orgId,
        actorUid: session?.uid ?? '',
      );
    }
    ref.invalidate(orgMembershipsProvider(orgId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(disable ? 'המשתמש הושבת' : 'המשתמש הופעל מחדש')),
      );
    }
  }
}

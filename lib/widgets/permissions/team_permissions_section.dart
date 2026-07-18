import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account_status.dart';
import '../../models/app_user.dart';
import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/membership.dart';
import '../../models/enterprise/organization_type.dart';
import '../../models/enterprise/project.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../providers/team_permissions_providers.dart';
import '../../services/effective_permissions.dart';
import '../../services/team_permissions_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/team_permissions_policy.dart';
import 'access_badges.dart';
import 'edit_permissions_dialog.dart';
import 'user_access_panel.dart';

/// Unified team & permissions management section.
class TeamPermissionsSection extends ConsumerWidget {
  const TeamPermissionsSection({
    super.key,
    required this.orgId,
    required this.orgType,
    required this.actorRoles,
    required this.isPlatformAdmin,
    this.orgName,
    this.title = 'צוות והרשאות',
    this.userProfilesByUid = const {},
  });

  final String orgId;
  final OrganizationType orgType;
  final List<EnterpriseRole> actorRoles;
  final bool isPlatformAdmin;
  final String? orgName;
  final String title;
  final Map<String, AppUser> userProfilesByUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipsAsync = ref.watch(orgMembershipsProvider(orgId));
    final projectsAsync = orgType == OrganizationType.contractor
        ? ref.watch(teamOrgProjectsProvider(orgId))
        : const AsyncValue<List<Project>>.data([]);
    final canView = TeamPermissionsPolicy.canViewTeam(
      isPlatformAdmin: isPlatformAdmin,
      actorRoles: actorRoles,
      orgType: orgType,
    );

    if (!canView) {
      return const Text('אין הרשאת צפייה בצוות');
    }

    final readOnlyMessage = TeamPermissionsPolicy.readOnlyMessage(
      isPlatformAdmin: isPlatformAdmin,
      actorRoles: actorRoles,
      orgType: orgType,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (readOnlyMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.amber.withValues(alpha: 0.25)),
            ),
            child: Text(
              readOnlyMessage,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 12),
        membershipsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('שגיאה בטעינת משתמשים'),
          data: (members) {
            if (members.isEmpty) {
              return const Text('אין משתמשים בחברה');
            }
            final projects = projectsAsync.valueOrNull ?? const <Project>[];
            final namesByUid = {
              for (final m in members) m.uid: m.displayLabel,
            };
            return Column(
              children: [
                for (final membership in members)
                  _TeamMemberPermissionsCard(
                    membership: membership,
                    orgId: orgId,
                    orgType: orgType,
                    orgName: orgName,
                    actorRoles: actorRoles,
                    isPlatformAdmin: isPlatformAdmin,
                    userProfile: userProfilesByUid[membership.uid],
                    projects: projects,
                    memberNamesByUid: namesByUid,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TeamMemberPermissionsCard extends ConsumerWidget {
  const _TeamMemberPermissionsCard({
    required this.membership,
    required this.orgId,
    required this.orgType,
    required this.orgName,
    required this.actorRoles,
    required this.isPlatformAdmin,
    required this.userProfile,
    required this.projects,
    required this.memberNamesByUid,
  });

  final Membership membership;
  final String orgId;
  final OrganizationType orgType;
  final String? orgName;
  final List<EnterpriseRole> actorRoles;
  final bool isPlatformAdmin;
  final AppUser? userProfile;
  final List<Project> projects;
  final Map<String, String> memberNamesByUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final actorUid = session?.uid ?? '';
    final canEdit = TeamPermissionsPolicy.canEditMemberPermissions(
      isPlatformAdmin: isPlatformAdmin,
      actorRoles: actorRoles,
      orgType: orgType,
      actorUid: actorUid,
      targetUid: membership.uid,
    );
    final canEditProjects = TeamPermissionsPolicy.canEditProjectAccess(
      isPlatformAdmin: isPlatformAdmin,
      actorRoles: actorRoles,
      orgType: orgType,
    );
    final accountStatus =
        userProfile?.accountStatus ?? _membershipAccountStatus(membership.status);
    final hasCustomPermissions =
        membership.grants.isNotEmpty || membership.revokes.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => _showAccessPanel(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.navy.withValues(alpha: 0.1),
                    child: Text(
                      membership.displayLabel.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          membership.displayLabel,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (membership.email?.isNotEmpty == true)
                          Text(
                            membership.email!,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  MembershipStatusBadge(
                    status: accountStatus == AccountStatus.disabled
                        ? 'disabled'
                        : membership.status,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RoleBadge(role: membership.role, compact: true),
                  if (orgType == OrganizationType.contractor)
                    ProjectAccessBadge(membership: membership),
                  if (hasCustomPermissions)
                    const PermissionSourceChip(
                      source: PermissionSource.customGrant,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showAccessPanel(context),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('פירוט הרשאות'),
                  ),
                  FilledButton(
                    onPressed: canEdit
                        ? () => _openEditDialog(context, ref, canEditProjects)
                        : null,
                    child: const Text('ערוך הרשאות'),
                  ),
                  if (orgType == OrganizationType.contractor)
                    OutlinedButton(
                      onPressed: (canEdit || canEditProjects) && projects.isNotEmpty
                          ? () => _openEditDialog(
                                context,
                                ref,
                                canEditProjects,
                                projectsOnly: true,
                              )
                          : null,
                      child: const Text('גישה לפרויקטים'),
                    ),
                  if (canEdit && membership.uid != actorUid)
                    OutlinedButton(
                      onPressed: () => _toggleStatus(context, ref),
                      child: Text(
                        membership.status == 'disabled' ||
                                accountStatus == AccountStatus.disabled
                            ? 'הפעל מחדש'
                            : 'השבת',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccessPanel(BuildContext context) {
    UserAccessPanel.show(
      context: context,
      membership: membership,
      orgName: orgName,
      projects: projects,
      memberNamesByUid: memberNamesByUid,
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    bool canEditProjects, {
    bool projectsOnly = false,
  }) async {
    AppUser? profile = userProfile;
    profile ??=
        await ref.read(teamPermissionsServiceProvider).fetchUserProfile(membership.uid);

    if (!context.mounted) return;

    final saved = await EditPermissionsDialog.show(
      context: context,
      ref: ref,
      membership: membership,
      orgType: orgType,
      actorRoles: actorRoles,
      isPlatformAdmin: isPlatformAdmin,
      userProfile: profile,
      orgName: orgName,
      projects: projects,
      canEditRole: !projectsOnly,
      canEditProjectAccess: canEditProjects,
      canEditStatus: true,
    );

    if (saved == true && context.mounted) {
      ref.invalidate(orgMembershipsProvider(orgId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ההרשאות עודכנו בהצלחה')),
      );
    }
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    final disable = membership.status != 'disabled';
    final input = TeamPermissionUpdateInput(
      membershipStatus: disable ? 'disabled' : 'active',
      accountStatus: disable ? AccountStatus.disabled : AccountStatus.active,
    );
    await ref.read(teamPermissionsServiceProvider).updateMemberPermissions(
          membership: membership,
          orgType: orgType,
          actorUid: session?.uid ?? '',
          isPlatformAdmin: isPlatformAdmin,
          actorRoles: actorRoles,
          input: input,
        );
    ref.invalidate(orgMembershipsProvider(orgId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(disable ? 'המשתמש הושבת' : 'המשתמש הופעל מחדש'),
        ),
      );
    }
  }

  static AccountStatus _membershipAccountStatus(String status) {
    if (status == 'disabled') return AccountStatus.disabled;
    return AccountStatus.active;
  }

}

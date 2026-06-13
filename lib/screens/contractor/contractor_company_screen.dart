import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enterprise/membership.dart';
import '../../models/enterprise/organization_invitation.dart';
import '../../models/enterprise/organization_type.dart';
import '../../models/enterprise/permission.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../repositories/invitation_repository.dart';
import '../../repositories/organization_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_hierarchy_presets.dart';
import '../../utils/enterprise_role_labels.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/enterprise/enterprise_role_badge.dart';
import '../../widgets/permissions/invite_user_dialog.dart';
import '../../widgets/permissions/membership_row_card.dart';
import '../../widgets/permissions/pending_invitations_section.dart';
import '../../widgets/permissions/permission_hierarchy_tree.dart';
import '../../widgets/permissions/permission_matrix_card.dart';
import '../../widgets/permissions/role_change_dialog.dart';
import '../../widgets/permissions/role_read_only_notice.dart';

class ContractorCompanyScreen extends ConsumerWidget {
  const ContractorCompanyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(effectivePermissionsProvider);
    final canManage = perms.contains(Permission.manageUsers) ||
        perms.contains(Permission.manageProjects);

    if (!canManage) {
      return Scaffold(
        appBar:
            const SecondaryAppBar(title: HebrewStrings.contractorCompanyTitle),
        body: const Center(child: Text('אין הרשאת ניהול חברה')),
      );
    }

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar:
            const SecondaryAppBar(title: HebrewStrings.contractorCompanyTitle),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Center(child: EnterpriseRoleBadge()),
            ),
            TabBar(
              isScrollable: true,
              labelColor: AppTheme.navy,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.teal,
              tabs: const [
                Tab(text: 'עץ חברה'),
                Tab(text: 'משתמשים והרשאות'),
                Tab(text: 'פרויקטים'),
                Tab(text: 'תפקידי רכש'),
                Tab(text: 'הגדרות אישורים'),
                Tab(text: 'היסטוריית פעולות'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _CompanyTreeTab(),
                  _UsersPermissionsTab(),
                  const _PlaceholderTab(
                    title: 'פרויקטים',
                    message: 'פתחו פרויקט מהבית או מדף הפרויקט.',
                    icon: Icons.construction_outlined,
                  ),
                  const _PlaceholderTab(
                    title: 'תפקידי רכש',
                    message: 'רכש יכול לשלוח בקשות לספקים ולאשר הצעות.',
                    icon: Icons.shopping_cart_outlined,
                  ),
                  const _PlaceholderTab(
                    title: 'הגדרות אישורים',
                    message: 'תהליך אישור בקשות — בקרוב.',
                    icon: Icons.approval_outlined,
                  ),
                  const _PlaceholderTab(
                    title: 'היסטוריית פעולות',
                    message: 'יומן פעולות — בקרוב.',
                    icon: Icons.history,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyTreeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final preset = EnterpriseHierarchyPresets.contractorCompany;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'מי מנהל את מי',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'תפקיד חברה קובע מה המשתמש יכול לעשות. שיוך לפרויקט יגיע בשלב הבא.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 16),
                PermissionHierarchyTree(
                  root: preset.root,
                  headerTitle: preset.title,
                  headerSubtitle: preset.subtitle,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        PermissionMatrixSection(
          title: 'סיכום הרשאות',
          summaries: EnterpriseHierarchyPresets.contractorMatrix,
        ),
        const SizedBox(height: 12),
        const RoleReadOnlyNotice(),
      ],
    );
  }
}

class _UsersPermissionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final user = session?.profile;
    final canManageRoles = ref.watch(canManageCompanyRolesProvider);
    final myMemberships =
        ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [];
    final orgId = myMemberships.firstOrNull?.orgId ??
        (session?.uid != null ? 'legacy-${session!.uid}' : null);
    final orgMembershipsAsync = orgId != null
        ? ref.watch(orgMembershipsProvider(orgId))
        : const AsyncValue<List<Membership>>.data([]);
    final invitationsAsync = orgId != null
        ? ref.watch(orgInvitationsProvider(orgId))
        : const AsyncValue<List<OrganizationInvitation>>.data([]);

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
        Row(
          children: [
            Expanded(
              child: Text(
                'צוות החברה',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (canManageRoles && orgId != null)
              FilledButton.icon(
                onPressed: () => _openInviteDialog(context, ref, orgId),
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
            canCancel: canManageRoles,
            onCancel: canManageRoles
                ? (invite) => _cancelInvite(context, ref, invite.id)
                : null,
          ),
        ),
        if (invitationsAsync.valueOrNull?.any((i) => i.isPending) == true)
          const SizedBox(height: 12),
        orgMembershipsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('שגיאה בטעינת חברי הצוות'),
          data: (members) {
            if (members.isEmpty) {
              return const Column(
                children: [
                  _EmptyTeamState(),
                  SizedBox(height: 12),
                  RoleReadOnlyNotice(
                    message: 'שינוי הרשאות יופעל אחרי חיבור צוות החברה.',
                    showDisabledButton: false,
                  ),
                ],
              );
            }
            return Column(
              children: [
                for (final m in members)
                  MembershipRowCard(
                    membership: m,
                    displayName: m.uid,
                    canEditRole: canManageRoles,
                    onEditRole: canManageRoles
                        ? () => _openRoleDialog(context, ref, m, orgId!)
                        : null,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (!canManageRoles)
          const RoleReadOnlyNotice(
            message: 'רק מנהל חברה יכול לשנות הרשאות.',
            showDisabledButton: false,
          ),
      ],
    );
  }

  Future<void> _openRoleDialog(
    BuildContext context,
    WidgetRef ref,
    Membership membership,
    String orgId,
  ) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    final actorUid = session?.uid ?? '';
    await RoleChangeDialog.show(
      context: context,
      membership: membership,
      displayName: membership.uid,
      orgType: OrganizationType.contractor,
      allowedRoles: EnterpriseRoleLabels.contractorAssignableRoles,
      onSave: (newRole) async {
        await ref.read(organizationRepositoryProvider).updateMemberRole(
              orgId: orgId,
              memberUid: membership.uid,
              newRole: newRole,
              actorUid: actorUid,
              orgType: OrganizationType.contractor,
            );
        ref.invalidate(orgMembershipsProvider(orgId));
      },
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ההרשאה עודכנה')),
      );
    }
  }

  Future<void> _openInviteDialog(
    BuildContext context,
    WidgetRef ref,
    String orgId,
  ) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    await InviteUserDialog.show(
      context: context,
      orgType: OrganizationType.contractor,
      allowedRoles: EnterpriseRoleLabels.contractorAssignableRoles,
      onSubmit: ({required name, required email, required role}) async {
        await ref.read(invitationRepositoryProvider).createInvitation(
              orgId: orgId,
              orgType: OrganizationType.contractor,
              email: email,
              role: role,
              invitedByUid: session?.uid ?? '',
              invitedByName: session?.profile?.fullName,
              displayName: name.isEmpty ? null : name,
              canManage: true,
            );
        ref.invalidate(orgInvitationsProvider(orgId));
      },
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ההזמנה נוצרה')),
      );
    }
  }

  Future<void> _cancelInvite(
    BuildContext context,
    WidgetRef ref,
    String inviteId,
  ) async {
    await ref.read(invitationRepositoryProvider).cancelInvitation(
          inviteId: inviteId,
          canManage: true,
        );
    final orgId = ref.read(currentUserMembershipsProvider).valueOrNull
        ?.firstOrNull?.orgId;
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

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(message),
          ),
        ),
        const SizedBox(height: 12),
        const RoleReadOnlyNotice(showDisabledButton: false),
      ],
    );
  }
}

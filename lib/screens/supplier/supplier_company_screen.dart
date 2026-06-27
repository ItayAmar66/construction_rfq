import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enterprise/enterprise_role.dart';
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
import '../../utils/role_invitation_policy.dart';
import '../../utils/org_id_helpers.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/enterprise/enterprise_role_badge.dart';
import '../../widgets/enterprise/org_setup_required_banner.dart';
import '../../widgets/permissions/pending_access_requests_section.dart';
import '../../widgets/permissions/team_permissions_section.dart';
import '../../widgets/permissions/invite_user_dialog.dart';
import '../../widgets/permissions/membership_row_card.dart';
import '../../widgets/permissions/pending_invitations_section.dart';
import '../../widgets/permissions/audit_events_list.dart';
import '../../screens/invitations/invite_landing_screen.dart';
import '../../widgets/permissions/permission_hierarchy_tree.dart';
import '../../widgets/permissions/permission_matrix_card.dart';
import '../../widgets/permissions/role_change_dialog.dart';
import '../../widgets/permissions/role_read_only_notice.dart';

class SupplierCompanyScreen extends ConsumerWidget {
  const SupplierCompanyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(effectivePermissionsProvider);
    final canManage = perms.contains(Permission.manageUsers);

    if (!canManage) {
      return Scaffold(
        appBar:
            const SecondaryAppBar(title: HebrewStrings.supplierCompanyTitle),
        body: const Center(child: Text('אין הרשאת ניהול ספק')),
      );
    }

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar:
            const SecondaryAppBar(title: HebrewStrings.supplierCompanyTitle),
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
              indicatorColor: AppTheme.amber,
              tabs: const [
                Tab(text: 'עץ ספק'),
                Tab(text: 'צוות והרשאות'),
                Tab(text: 'צוות מכירות'),
                Tab(text: 'צוות תפעול'),
                Tab(text: 'הגדרות הצעות'),
                Tab(text: 'היסטוריית פעולות'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SupplierTreeTab(),
                  _SupplierUsersTab(),
                  const _PlaceholderTab(
                    title: 'צוות מכירות',
                    message: 'יתווסף בהמשך',
                    icon: Icons.support_agent_outlined,
                  ),
                  const _PlaceholderTab(
                    title: 'צוות תפעול',
                    message: 'יתווסף בהמשך',
                    icon: Icons.local_shipping_outlined,
                  ),
                  const _PlaceholderTab(
                    title: 'הגדרות הצעות',
                    message: 'יתווסף בהמשך',
                    icon: Icons.request_quote_outlined,
                  ),
                  const _SupplierAuditHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierTreeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final preset = EnterpriseHierarchyPresets.supplierCompany;
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
                const Text(
                  'מכירות מטפלים בהצעות מחיר. תפעול מטפל בהזמנות שאושרו ובסימון נשלח/סופק.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
          summaries: EnterpriseHierarchyPresets.supplierMatrix,
        ),
        const SizedBox(height: 12),
        const RoleReadOnlyNotice(),
      ],
    );
  }
}

class _SupplierUsersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final user = session?.profile;
    final canManageRoles = ref.watch(canManageCompanyRolesProvider);
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
                  const Text(
                    'המשתמש שלי',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    EnterpriseRoleLabels.legacyLabel(user),
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
                'צוות הספק',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (canManageRoles && realOrgId != null)
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
              return const Column(
                children: [
                  _EmptyTeamState(),
                  SizedBox(height: 12),
                  RoleReadOnlyNotice(
                    message: 'שינוי הרשאות יופעל אחרי חיבור צוות הספק.',
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
                    orgType: OrganizationType.supplier,
                  ),
                TeamPermissionsSection(
                  orgId: realOrgId,
                  orgType: OrganizationType.supplier,
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
          const RoleReadOnlyNotice(
            message: 'רק מנהל ספק יכול לשנות הרשאות.',
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
      displayName: membership.displayLabel,
      orgType: OrganizationType.supplier,
      allowedRoles: RoleInvitationPolicy.supplierLaunchRoles,
      onSave: (newRole) async {
        await ref.read(organizationRepositoryProvider).updateMemberRole(
              orgId: orgId,
              memberUid: membership.uid,
              newRole: newRole,
              actorUid: actorUid,
              orgType: OrganizationType.supplier,
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
    final actorRoles = ref
            .read(currentUserMembershipsProvider)
            .valueOrNull
            ?.firstOrNull
            ?.roles ??
        const [];
    OrganizationInvitation? createdInvite;
    await InviteUserDialog.show(
      context: context,
      orgType: OrganizationType.supplier,
      allowedRoles: RoleInvitationPolicy.assignableRoles(
        orgType: OrganizationType.supplier,
        actorRoles: actorRoles,
      ),
      onSubmit: ({required name, required email, required role}) async {
        createdInvite =
            await ref.read(invitationRepositoryProvider).createInvitation(
                  orgId: orgId,
                  orgType: OrganizationType.supplier,
                  email: email,
                  role: role,
                  invitedByUid: session?.uid ?? '',
                  invitedByName: session?.profile?.fullName,
                  displayName: name.isEmpty ? null : name,
                  canManage: ref.read(canManageCompanyRolesProvider),
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
    final emailConfigured =
        ProviderScope.containerOf(context)
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
    final orgId = ref.read(currentUserMembershipsProvider).valueOrNull
        ?.firstOrNull?.orgId;
    if (orgId != null) ref.invalidate(orgInvitationsProvider(orgId));
  }
}

class _SupplierAuditHistoryTab extends ConsumerWidget {
  const _SupplierAuditHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgId = ref.watch(currentUserMembershipsProvider).valueOrNull
        ?.firstOrNull?.orgId;
    if (orgId == null) {
      return const Center(child: Text('אין ארגון מחובר'));
    }
    return OrgAuditHistoryTab(orgId: orgId);
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
      child: const Column(
        children: [
          Icon(Icons.people_outline, size: 32, color: AppTheme.textSecondary),
          SizedBox(height: 8),
          Text(
            'עדיין אין צוות מחובר לספק',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'בשלב הבא ניתן יהיה להזמין משתמשים ולשייך תפקידים',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
      ],
    );
  }
}

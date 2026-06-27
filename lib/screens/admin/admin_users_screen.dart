import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/account_status.dart';
import '../../models/app_user.dart';
import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/membership.dart';
import '../../models/enterprise/organization_type.dart';
import '../../models/enterprise/project.dart';
import '../../providers/admin_management_providers.dart';
import '../../providers/admin_providers.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../providers/team_permissions_providers.dart';
import '../../services/team_permissions_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/permissions/edit_permissions_dialog.dart';
import 'admin_platform_gate.dart';

class AdminUsersManagementScreen extends ConsumerStatefulWidget {
  const AdminUsersManagementScreen({super.key});

  @override
  ConsumerState<AdminUsersManagementScreen> createState() =>
      _AdminUsersManagementScreenState();
}

class _AdminUsersManagementScreenState
    extends ConsumerState<AdminUsersManagementScreen> {
  String _query = '';
  String _statusFilter = 'all';
  String _companyFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminAllUsersProvider);
    final membershipsAsync = ref.watch(adminAllMembershipsProvider);
    final orgsAsync = ref.watch(adminOrganizationsProvider);

    return AdminPlatformGate(
      child: Scaffold(
        appBar: const SecondaryAppBar(
          title: 'ניהול משתמשים',
          homeRoute: '/admin',
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AdminBackToCockpitButton(),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'חיפוש לפי שם / אימייל / חברה',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('כל הסטטוסים')),
                    DropdownMenuItem(value: 'active', child: Text('פעיל')),
                    DropdownMenuItem(
                      value: 'pendingApproval',
                      child: Text('ממתין'),
                    ),
                    DropdownMenuItem(value: 'disabled', child: Text('מושבת')),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                ),
                orgsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (orgs) => DropdownButton<String>(
                    value: _companyFilter,
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('כל החברות'),
                      ),
                      for (final org in orgs)
                        DropdownMenuItem(
                          value: org.id,
                          child: Text(org.name),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _companyFilter = v ?? 'all'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            usersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('שגיאה בטעינת משתמשים'),
              data: (users) {
                final memberships =
                    membershipsAsync.valueOrNull ?? const <Membership>[];
                final orgs = orgsAsync.valueOrNull ?? const [];
                final orgNames = {for (final o in orgs) o.id: o.name};
                final orgTypes = {for (final o in orgs) o.id: o.type};

                final filtered = users.where((user) {
                  final userMemberships =
                      memberships.where((m) => m.uid == user.id).toList();
                  if (_statusFilter != 'all' &&
                      user.accountStatus.value != _statusFilter) {
                    return false;
                  }
                  if (_companyFilter != 'all' &&
                      !userMemberships.any((m) => m.orgId == _companyFilter)) {
                    return false;
                  }
                  if (_query.isEmpty) return true;
                  final haystack = [
                    user.fullName,
                    user.email,
                    ...userMemberships.map(
                      (m) => orgNames[m.orgId] ?? m.orgId,
                    ),
                  ].join(' ').toLowerCase();
                  return haystack.contains(_query.toLowerCase());
                }).toList();

                if (filtered.isEmpty) {
                  return const Text('אין משתמשים תואמים');
                }

                return Column(
                  children: [
                    for (final user in filtered)
                      _AdminUserRowCard(
                        user: user,
                        memberships: memberships
                            .where((m) => m.uid == user.id)
                            .toList(),
                        orgNames: orgNames,
                        orgTypes: orgTypes,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminUserRowCard extends ConsumerWidget {
  const _AdminUserRowCard({
    required this.user,
    required this.memberships,
    required this.orgNames,
    required this.orgTypes,
  });

  final AppUser user;
  final List<Membership> memberships;
  final Map<String, String> orgNames;
  final Map<String, OrganizationType> orgTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryMembership = memberships.firstOrNull;
    final companyText = memberships.isEmpty
        ? (user.requestedOrgName ?? user.userType.label)
        : memberships
            .map((m) => orgNames[m.orgId] ?? m.orgId)
            .join(' · ');
    final roleText = memberships.isEmpty
        ? (user.requestedRole ?? '—')
        : memberships
            .map((m) {
              final role = m.roles.firstOrNull;
              return role != null ? EnterpriseRoleLabels.hebrew(role) : '—';
            })
            .join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              user.fullName.isEmpty ? user.email : user.fullName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(user.email, style: const TextStyle(color: AppTheme.textSecondary)),
            Text('חברה: $companyText'),
            Text('תפקיד: $roleText'),
            Text('סטטוס: ${user.accountStatus.label}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (primaryMembership != null)
                  FilledButton(
                    onPressed: () => _editPermissions(
                      context,
                      ref,
                      primaryMembership,
                    ),
                    child: const Text('ערוך הרשאות'),
                  ),
                if (primaryMembership != null)
                  OutlinedButton(
                    onPressed: () => context.push(
                      '/admin/company/${primaryMembership.orgId}?tab=team',
                    ),
                    child: const Text('פתח חברה'),
                  ),
                if (primaryMembership != null)
                  OutlinedButton(
                    onPressed: user.accountStatus == AccountStatus.disabled
                        ? () => _reactivateUser(context, ref, primaryMembership)
                        : () => _disableUser(context, ref, primaryMembership),
                    child: Text(
                      user.accountStatus == AccountStatus.disabled
                          ? 'הפעל מחדש'
                          : 'השבת',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPermissions(
    BuildContext context,
    WidgetRef ref,
    Membership membership,
  ) async {
    final orgType =
        orgTypes[membership.orgId] ?? membership.orgType;
    final projects = orgType == OrganizationType.contractor
        ? await ref
            .read(teamPermissionsServiceProvider)
            .fetchProjectsForOrg(membership.orgId)
        : const <Project>[];

    if (!context.mounted) return;

    final actorRoles = orgType == OrganizationType.contractor
        ? const [EnterpriseRole.contractorCompanyOwner]
        : const [EnterpriseRole.supplierOwner];

    final saved = await EditPermissionsDialog.show(
      context: context,
      ref: ref,
      membership: membership,
      orgType: orgType,
      actorRoles: actorRoles,
      isPlatformAdmin: true,
      userProfile: user,
      orgName: orgNames[membership.orgId],
      projects: projects,
    );

    if (saved == true) {
      ref.invalidate(adminAllUsersProvider);
      ref.invalidate(adminAllMembershipsProvider);
      ref.invalidate(orgMembershipsProvider(membership.orgId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ההרשאות עודכנו בהצלחה')),
        );
      }
    }
  }

  Future<void> _disableUser(
    BuildContext context,
    WidgetRef ref,
    Membership membership,
  ) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    await ref.read(teamPermissionsServiceProvider).updateMemberPermissions(
          membership: membership,
          orgType: orgTypes[membership.orgId] ?? membership.orgType,
          actorUid: session?.uid ?? '',
          isPlatformAdmin: true,
          actorRoles: const [EnterpriseRole.contractorCompanyOwner],
          input: const TeamPermissionUpdateInput(
            membershipStatus: 'disabled',
            accountStatus: AccountStatus.disabled,
          ),
        );
    ref.invalidate(adminAllUsersProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('המשתמש הושבת')),
      );
    }
  }

  Future<void> _reactivateUser(
    BuildContext context,
    WidgetRef ref,
    Membership membership,
  ) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    await ref.read(teamPermissionsServiceProvider).updateMemberPermissions(
          membership: membership,
          orgType: orgTypes[membership.orgId] ?? membership.orgType,
          actorUid: session?.uid ?? '',
          isPlatformAdmin: true,
          actorRoles: const [EnterpriseRole.contractorCompanyOwner],
          input: const TeamPermissionUpdateInput(
            membershipStatus: 'active',
            accountStatus: AccountStatus.active,
          ),
        );
    ref.invalidate(adminAllUsersProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('המשתמש הופעל מחדש')),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/account_status.dart';
import '../../models/app_user.dart';
import '../../models/enterprise/membership.dart';
import '../../providers/admin_management_providers.dart';
import '../../providers/admin_providers.dart';
import '../../providers/user_approval_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import '../../widgets/app_back_leading.dart';
import 'admin_platform_gate.dart';

class AdminUsersManagementScreen extends ConsumerWidget {
  const AdminUsersManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            usersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('שגיאה בטעינת משתמשים'),
              data: (users) {
                final memberships =
                    membershipsAsync.valueOrNull ?? const <Membership>[];
                final orgs = orgsAsync.valueOrNull ?? const [];
                final orgNames = {for (final o in orgs) o.id: o.name};

                if (users.isEmpty) {
                  return const Text('אין משתמשים');
                }

                return Column(
                  children: [
                    for (final user in users)
                      _AdminUserRowCard(
                        user: user,
                        memberships: memberships
                            .where((m) => m.uid == user.id)
                            .toList(),
                        orgNames: orgNames,
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
  });

  final AppUser user;
  final List<Membership> memberships;
  final Map<String, String> orgNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                if (memberships.isNotEmpty)
                  FilledButton(
                    onPressed: () =>
                        context.push('/admin/company/${memberships.first.orgId}'),
                    child: const Text('פתח ניהול'),
                  ),
                OutlinedButton(
                  onPressed: user.accountStatus == AccountStatus.disabled
                      ? () => _reactivateUser(context, ref)
                      : () => _disableUser(context, ref),
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

  Future<void> _disableUser(BuildContext context, WidgetRef ref) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    if (memberships.isEmpty) return;
    await ref.read(userApprovalServiceProvider).disableUser(
          uid: user.id,
          orgId: memberships.first.orgId,
          actorUid: session?.uid ?? '',
        );
    ref.invalidate(adminAllUsersProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('המשתמש הושבת')),
      );
    }
  }

  Future<void> _reactivateUser(BuildContext context, WidgetRef ref) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    if (memberships.isEmpty) return;
    await ref.read(userApprovalServiceProvider).reactivateUser(
          uid: user.id,
          orgId: memberships.first.orgId,
          actorUid: session?.uid ?? '',
        );
    ref.invalidate(adminAllUsersProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('המשתמש הופעל מחדש')),
      );
    }
  }
}

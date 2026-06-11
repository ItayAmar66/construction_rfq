import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/membership.dart';
import '../../models/enterprise/organization_type.dart';
import '../../models/enterprise/permission.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../repositories/organization_repository.dart';
import '../../utils/enterprise_role_labels.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/enterprise/enterprise_role_badge.dart';

class ContractorCompanyScreen extends ConsumerWidget {
  const ContractorCompanyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(effectivePermissionsProvider);
    final canManage =
        perms.contains(Permission.manageUsers) ||
        perms.contains(Permission.manageProjects);

    if (!canManage) {
      return Scaffold(
        appBar: const SecondaryAppBar(title: HebrewStrings.contractorCompanyTitle),
        body: const Center(child: Text('אין הרשאת ניהול חברה')),
      );
    }

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.contractorCompanyTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: EnterpriseRoleBadge()),
          const SizedBox(height: 12),
          const _RoleManagementSection(),
          const SizedBox(height: 12),
          const _SectionCard(
            title: 'צוות',
            subtitle: 'בקרוב: הזמנת משתמשים',
            icon: Icons.people_outline,
          ),
          const _SectionCard(
            title: 'פרויקטים',
            subtitle: 'פתחו פרויקט מהבית או מדף הפרויקט',
            icon: Icons.construction_outlined,
          ),
          const _SectionCard(
            title: 'הגדרות רכש',
            subtitle: 'אישור בקשות ושליחה לספקים',
            icon: Icons.settings_suggest_outlined,
          ),
        ],
      ),
    );
  }
}

class _RoleManagementSection extends ConsumerWidget {
  const _RoleManagementSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final user = session?.profile;
    final canManageRoles = ref.watch(canManageCompanyRolesProvider);
    final memberships =
        ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [];
    final currentRole = memberships.firstOrNull?.roles.firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined),
                const SizedBox(width: 8),
                Text(
                  'ניהול הרשאות',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              user?.fullName ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              currentRole != null
                  ? EnterpriseRoleLabels.hebrew(currentRole)
                  : user != null
                      ? EnterpriseRoleLabels.legacyLabel(user)
                      : 'משתמש',
              style: const TextStyle(color: Colors.black54),
            ),
            if (!canManageRoles) ...[
              const SizedBox(height: 8),
              const Text('אין הרשאה לשנות תפקידים'),
            ] else if (memberships.isEmpty) ...[
              const SizedBox(height: 8),
              const Text('בקרוב: הזמנת משתמשים. התפקיד הנוכחי מוצג לפי legacy.'),
            ] else ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<EnterpriseRole>(
                value: currentRole,
                decoration: const InputDecoration(
                  labelText: 'תפקיד',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final role in EnterpriseRoleLabels.contractorAssignableRoles)
                    DropdownMenuItem(
                      value: role,
                      child: Text(EnterpriseRoleLabels.hebrew(role)),
                    ),
                ],
                onChanged: (role) async {
                  if (role == null || user == null) return;
                  try {
                    await ref.read(organizationRepositoryProvider).updateMemberRole(
                          orgId: memberships.first.orgId,
                          memberUid: user.id,
                          newRole: role,
                          actorUid: user.id,
                        );
                    ref.invalidate(currentUserMembershipsProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

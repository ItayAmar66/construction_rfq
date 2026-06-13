import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enterprise/permission.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_hierarchy_presets.dart';
import '../../utils/enterprise_role_labels.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/enterprise/enterprise_role_badge.dart';
import '../../widgets/permissions/permission_hierarchy_tree.dart';
import '../../widgets/permissions/permission_matrix_card.dart';
import '../../widgets/permissions/role_read_only_notice.dart';

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

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: const SecondaryAppBar(title: HebrewStrings.contractorCompanyTitle),
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
    final memberships =
        ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [];
    final currentRole = memberships.firstOrNull?.roles.firstOrNull;

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
                  'משתמשים והרשאות',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                if (user != null) ...[
                  Text(
                    user.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentRole != null
                        ? EnterpriseRoleLabels.hebrew(currentRole)
                        : EnterpriseRoleLabels.legacyLabel(user),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
                const SizedBox(height: 12),
                if (memberships.isEmpty)
                  const _EmptyTeamState()
                else
                  Text(
                    'הרשאות בפועל יחוברו ל-Memberships בשלב הבא.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                const RoleReadOnlyNotice(
                  message:
                      'שינוי הרשאות יופעל אחרי חיבור משתמשים והרשאות מלא',
                ),
              ],
            ),
          ),
        ),
      ],
    );
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

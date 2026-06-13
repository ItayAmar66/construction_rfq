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

class SupplierCompanyScreen extends ConsumerWidget {
  const SupplierCompanyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(effectivePermissionsProvider);
    final canManage = perms.contains(Permission.manageUsers);

    if (!canManage) {
      return Scaffold(
        appBar: const SecondaryAppBar(title: HebrewStrings.supplierCompanyTitle),
        body: const Center(child: Text('אין הרשאת ניהול ספק')),
      );
    }

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: const SecondaryAppBar(title: HebrewStrings.supplierCompanyTitle),
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
                Tab(text: 'משתמשים והרשאות'),
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
                    message:
                        'מכירות מטפלים בהצעות מחיר ומענה לבקשות.',
                    icon: Icons.support_agent_outlined,
                  ),
                  const _PlaceholderTab(
                    title: 'צוות תפעול',
                    message:
                        'תפעול מטפל בהזמנות שאושרו ובסימון נשלח/סופק.',
                    icon: Icons.local_shipping_outlined,
                  ),
                  const _PlaceholderTab(
                    title: 'הגדרות הצעות',
                    message: 'תהליך הצעת מחיר — בקרוב.',
                    icon: Icons.request_quote_outlined,
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
    final memberships =
        ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [];

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
                if (user != null) ...[
                  const SizedBox(height: 12),
                  Text(user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    EnterpriseRoleLabels.legacyLabel(user),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
                const SizedBox(height: 12),
                if (memberships.isEmpty)
                  const _EmptyTeamState()
                else
                  const Text('הרשאות בפועל יחוברו ל-Memberships בשלב הבא.'),
                const SizedBox(height: 12),
                const RoleReadOnlyNotice(),
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

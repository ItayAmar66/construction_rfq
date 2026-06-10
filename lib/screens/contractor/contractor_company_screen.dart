import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enterprise/permission.dart';
import '../../providers/enterprise_providers.dart';
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
        children: const [
          Center(child: EnterpriseRoleBadge()),
          SizedBox(height: 12),
          _SectionCard(
            title: 'צוות',
            subtitle: 'משתמשים ותפקידים — בקרוב',
            icon: Icons.people_outline,
          ),
          _SectionCard(
            title: 'תפקידים',
            subtitle: 'בעל חברה, רכש, מנהל פרויקט, מהנדס',
            icon: Icons.badge_outlined,
          ),
          _SectionCard(
            title: 'פרויקטים',
            subtitle: 'אתרים ופרויקטים פעילים',
            icon: Icons.construction_outlined,
          ),
          _SectionCard(
            title: 'הגדרות רכש',
            subtitle: 'אישור בקשות ושליחה לספקים',
            icon: Icons.settings_suggest_outlined,
          ),
        ],
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

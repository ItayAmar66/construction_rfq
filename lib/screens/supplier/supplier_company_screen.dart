import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enterprise/permission.dart';
import '../../providers/enterprise_providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/enterprise/enterprise_role_badge.dart';

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

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.supplierCompanyTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Center(child: EnterpriseRoleBadge()),
          SizedBox(height: 12),
          _SectionCard(
            title: 'צוות מכירות',
            subtitle: 'נציגי מכירות — בקרוב',
            icon: Icons.support_agent_outlined,
          ),
          _SectionCard(
            title: 'מנהלי מכירות',
            subtitle: 'ניהול הצעות צוות — בקרוב',
            icon: Icons.supervisor_account_outlined,
          ),
          _SectionCard(
            title: 'תפעול',
            subtitle: 'משלוחים וסימון נשלח/סופק',
            icon: Icons.local_shipping_outlined,
          ),
          _SectionCard(
            title: 'הגדרות הצעות',
            subtitle: 'תהליך הצעת מחיר — בקרוב',
            icon: Icons.request_quote_outlined,
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

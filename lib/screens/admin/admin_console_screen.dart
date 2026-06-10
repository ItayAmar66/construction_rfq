import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/enterprise_providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';

class AdminConsoleScreen extends ConsumerWidget {
  const AdminConsoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isPlatformAdminProvider);
    if (!isAdmin) {
      return Scaffold(
        appBar: const SecondaryAppBar(title: HebrewStrings.adminConsoleTitle),
        body: const Center(child: Text('אין הרשאת ניהול מערכת')),
      );
    }

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.adminConsoleTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _PanelTile(
            title: 'ארגונים',
            subtitle: 'קריאה בלבד — ניהול מלא בקרוב',
            icon: Icons.apartment_outlined,
          ),
          _PanelTile(
            title: 'משתמשים וחברויות',
            subtitle: 'קריאה בלבד — ניהול מלא בקרוב',
            icon: Icons.groups_outlined,
          ),
          _PanelTile(
            title: 'פרויקטים',
            subtitle: 'קריאה בלבד — ניהול מלא בקרוב',
            icon: Icons.location_city_outlined,
          ),
          _PanelTile(
            title: 'בקשות RFQ',
            subtitle: 'קריאה בלבד — ניהול מלא בקרוב',
            icon: Icons.assignment_outlined,
          ),
          _PanelTile(
            title: 'ספקים',
            subtitle: 'קריאה בלבד — ניהול מלא בקרוב',
            icon: Icons.storefront_outlined,
          ),
          _PanelTile(
            title: 'הצעות והזמנות',
            subtitle: 'מעקב RFQ וסטטוסים — בקרוב',
            icon: Icons.receipt_long_outlined,
          ),
        ],
      ),
    );
  }
}

class _PanelTile extends StatelessWidget {
  const _PanelTile({
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
        trailing: const Icon(Icons.chevron_left),
        onTap: () {},
      ),
    );
  }
}

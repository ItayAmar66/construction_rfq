import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enterprise/audit_event.dart';
import '../../models/app_user.dart';
import '../../models/enterprise/project.dart';
import '../../models/quote_request.dart';
import '../../models/quote_status.dart';
import '../../models/supplier_directory_entry.dart';
import '../../models/supplier_quote.dart';
import '../../providers/admin_providers.dart';
import '../../providers/enterprise_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_hierarchy_presets.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/supplier_quote_status.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/permissions/permission_hierarchy_tree.dart';
import '../../repositories/audit_repository.dart';
import '../../widgets/permissions/audit_events_list.dart';
import '../../widgets/platform_admin_role_badge.dart';

class AdminConsoleScreen extends ConsumerWidget {
  const AdminConsoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showAdmin = ref.watch(showAdminNavProvider);
    final hasClaim = ref.watch(hasPlatformAdminClaimProvider);

    if (!showAdmin) {
      return Scaffold(
        appBar: const SecondaryAppBar(title: HebrewStrings.adminConsoleTitle),
        body: const Center(child: Text('אין הרשאת ניהול מערכת')),
      );
    }

    final countsAsync = ref.watch(adminOverviewCountsProvider);

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.adminConsoleTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PlatformAdminRoleBadge(),
          const SizedBox(height: 12),
          const _PlatformHierarchyCard(),
          if (!hasClaim) ...[
            const SizedBox(height: 12),
            const _BootstrapWarning(),
          ],
          const SizedBox(height: 16),
          countsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const _PanelError(
              message: 'אין הרשאה לקריאת הנתונים',
            ),
            data: (counts) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CountChip(label: 'משתמשים', value: counts.users),
                _CountChip(label: 'פרויקטים', value: counts.projects),
                _CountChip(label: 'בקשות RFQ', value: counts.requests),
                _CountChip(label: 'ספקים', value: counts.suppliers),
                _CountChip(label: 'הצעות', value: counts.quotes),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _AdminPanel<List<AuditEvent>>(
            title: 'פעולות אחרונות',
            icon: Icons.history,
            async: ref.watch(adminAuditEventsProvider),
            builder: (events) {
              if (events.isEmpty) return const _PanelEmpty();
              return AuditEventsList(
                eventsAsync: AsyncValue.data(events),
                compact: true,
              );
            },
          ),
          _AdminPanel<List<AppUser>>(
            title: 'משתמשים',
            icon: Icons.groups_outlined,
            async: ref.watch(adminRecentUsersProvider),
            builder: (list) {
              if (list.isEmpty) return const _PanelEmpty();
              return Column(
                children: [
                  for (final user in list)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(user.fullName),
                      subtitle: Text('${user.email} · ${user.userType.label}'),
                    ),
                ],
              );
            },
          ),
          _AdminPanel<List<Project>>(
            title: 'פרויקטים',
            icon: Icons.location_city_outlined,
            async: ref.watch(adminRecentProjectsProvider),
            builder: (list) {
              if (list.isEmpty) return const _PanelEmpty();
              return Column(
                children: [
                  for (final project in list)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(project.name),
                      subtitle: Text(
                        '${project.locationLine.isEmpty ? 'ללא מיקום' : project.locationLine} · ${project.status}',
                      ),
                    ),
                ],
              );
            },
          ),
          _AdminPanel<List<QuoteRequest>>(
            title: 'בקשות RFQ',
            icon: Icons.assignment_outlined,
            async: ref.watch(adminRecentRequestsProvider),
            builder: (list) {
              if (list.isEmpty) return const _PanelEmpty();
              return Column(
                children: [
                  for (final request in list)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(request.customerName),
                      subtitle: Text(
                        '${request.status.label} · ${request.projectName ?? 'ללא פרויקט'}',
                      ),
                    ),
                ],
              );
            },
          ),
          _AdminPanel<List<SupplierDirectoryEntry>>(
            title: 'ספקים',
            icon: Icons.storefront_outlined,
            async: ref.watch(adminSuppliersProvider),
            builder: (list) {
              if (list.isEmpty) return const _PanelEmpty();
              return Column(
                children: [
                  for (final supplier in list)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(supplier.displayName),
                      subtitle: Text(
                        supplier.city.isEmpty ? supplier.uid : supplier.city,
                      ),
                    ),
                ],
              );
            },
          ),
          _AdminPanel<List<SupplierQuote>>(
            title: 'הצעות והזמנות',
            icon: Icons.receipt_long_outlined,
            async: ref.watch(adminRecentQuotesProvider),
            builder: (list) {
              if (list.isEmpty) return const _PanelEmpty();
              return Column(
                children: [
                  for (final quote in list)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(quote.supplierName),
                      subtitle: Text(
                        '${SupplierQuoteStatus.displayLabel(quote.status)} · ${quote.supplierName}',
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlatformHierarchyCard extends StatelessWidget {
  const _PlatformHierarchyCard();

  @override
  Widget build(BuildContext context) {
    final preset = EnterpriseHierarchyPresets.platform;
    return Card(
      color: AppTheme.navy.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree_outlined, color: AppTheme.navy),
                const SizedBox(width: 8),
                Text(
                  'מנהל מערכת',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Text(
                'מנהל מערכת ≠ מנהל חברה — '
                'מנהל מערכת הוא רמת פלטפורמה בלבד (Itay/בעלי מערכת). '
                'מנהל חברה מנהל ארגון קבלן או ספק.',
                style: TextStyle(fontSize: 13, height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
            PermissionHierarchyTree(
              root: preset.root,
              headerTitle: preset.title,
              headerSubtitle: preset.subtitle,
            ),
          ],
        ),
      ),
    );
  }
}

class _BootstrapWarning extends StatelessWidget {
  const _BootstrapWarning();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceTint,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'מצב bootstrap: נדרש custom claim platformAdmin לגישה מאובטחת מלאה. '
          'הפאנלים עלולים להציג "אין הרשאה" עד להגדרת claim.',
          style: TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: AppTheme.navy.withValues(alpha: 0.12),
        child: Text('$value', style: const TextStyle(fontSize: 11)),
      ),
      label: Text(label),
    );
  }
}

class _AdminPanel<T> extends StatelessWidget {
  const _AdminPanel({
    required this.title,
    required this.icon,
    required this.async,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final AsyncValue<T> async;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.navy),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) {
                final message = error.toString().contains('permission-denied')
                    ? 'אין הרשאה לקריאת הנתונים'
                    : 'אין נתונים להצגה';
                return _PanelError(message: message);
              },
              data: builder,
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text('אין נתונים להצגה'),
    );
  }
}

class _PanelError extends StatelessWidget {
  const _PanelError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child:
          Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
    );
  }
}

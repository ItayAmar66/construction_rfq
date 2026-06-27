import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/enterprise/organization.dart';
import '../../models/enterprise/organization_type.dart';
import '../../providers/admin_management_providers.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_back_leading.dart';
import 'admin_company_detail_screen.dart';
import 'admin_platform_gate.dart';

class AdminContractorCompaniesScreen extends ConsumerWidget {
  const AdminContractorCompaniesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminPlatformGate(
      child: AdminOrgListScreen(
        title: 'ניהול חברות קבלן',
        orgType: OrganizationType.contractor,
        orgsAsync: ref.watch(adminContractorOrganizationsProvider),
      ),
    );
  }
}

class AdminSupplierCompaniesScreen extends ConsumerWidget {
  const AdminSupplierCompaniesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminPlatformGate(
      child: AdminOrgListScreen(
        title: 'ניהול ספקים',
        orgType: OrganizationType.supplier,
        orgsAsync: ref.watch(adminSupplierOrganizationsProvider),
      ),
    );
  }
}

class AdminOrgListScreen extends ConsumerWidget {
  const AdminOrgListScreen({
    super.key,
    required this.title,
    required this.orgType,
    required this.orgsAsync,
  });

  final String title;
  final OrganizationType orgType;
  final AsyncValue<List<Organization>> orgsAsync;

  String get _listRoute =>
      orgType == OrganizationType.contractor ? '/admin/contractors' : '/admin/suppliers';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: SecondaryAppBar(
        title: title,
        homeRoute: '/admin',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminBackToCockpitButton(),
          const SizedBox(height: 8),
          orgsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('שגיאה בטעינת חברות'),
            data: (orgs) {
              if (orgs.isEmpty) {
                return const Text('אין חברות להצגה');
              }
              return Column(
                children: [
                  for (final org in orgs)
                    _AdminOrgRowCard(
                      org: org,
                      listRoute: _listRoute,
                      showProjectCount: orgType == OrganizationType.contractor,
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

class _AdminOrgRowCard extends ConsumerWidget {
  const _AdminOrgRowCard({
    required this.org,
    required this.listRoute,
    required this.showProjectCount,
  });

  final Organization org;
  final String listRoute;
  final bool showProjectCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(adminOrgSummaryProvider(org.id));
    final typeLabel =
        org.type == OrganizationType.contractor ? 'קבלן' : 'ספק';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              org.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            summaryAsync.when(
              loading: () => Text(
                '$typeLabel · ${org.status}',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              error: (_, __) => Text(
                '$typeLabel · ${org.status}',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              data: (summary) {
                final parts = <String>[
                  typeLabel,
                  org.status,
                  '${summary.userCount} משתמשים',
                ];
                if (showProjectCount) {
                  parts.add('${summary.projectCount} פרויקטים');
                }
                return Text(
                  parts.join(' · '),
                  style: const TextStyle(color: AppTheme.textSecondary),
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => context.push('/admin/company/${org.id}'),
                  child: const Text('פתח'),
                ),
                FilledButton(
                  onPressed: () => context.push(
                    '/admin/company/${org.id}?tab=team',
                  ),
                  child: const Text('צוות והרשאות'),
                ),
                OutlinedButton(
                  onPressed: () => AdminCompanyDetailScreen.openEditDialog(
                    context,
                    ref,
                    org: org,
                  ),
                  child: const Text('ערוך חברה'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

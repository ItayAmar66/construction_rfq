import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/organization.dart';
import '../../models/enterprise/organization_type.dart';
import '../../providers/admin_management_providers.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/permissions/pending_access_requests_section.dart';
import '../../widgets/permissions/team_permissions_section.dart';
import 'admin_platform_gate.dart';

enum AdminCompanyTab {
  overview,
  team,
  pending,
  projects,
  settings,
}

class AdminCompanyDetailScreen extends ConsumerStatefulWidget {
  const AdminCompanyDetailScreen({
    super.key,
    required this.orgId,
    this.initialTab = AdminCompanyTab.team,
  });

  final String orgId;
  final AdminCompanyTab initialTab;

  static AdminCompanyTab tabFromQuery(String? tab) {
    switch (tab) {
      case 'overview':
        return AdminCompanyTab.overview;
      case 'pending':
        return AdminCompanyTab.pending;
      case 'projects':
        return AdminCompanyTab.projects;
      case 'settings':
        return AdminCompanyTab.settings;
      case 'team':
      default:
        return AdminCompanyTab.team;
    }
  }

  static Future<void> openEditDialog(
    BuildContext context,
    WidgetRef ref, {
    required Organization org,
  }) async {
    final nameCtrl = TextEditingController(text: org.name);
    final phoneCtrl = TextEditingController(text: org.phone ?? '');
    final emailCtrl = TextEditingController(text: org.email ?? '');
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('ערוך חברה'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'שם חברה'),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'טלפון'),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'אימייל'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('ביטול'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setState(() => saving = true);
                      try {
                        await ref
                            .read(adminManagementServiceProvider)
                            .updateOrganizationDetails(
                              orgId: org.id,
                              name: nameCtrl.text,
                              phone: phoneCtrl.text,
                              email: emailCtrl.text,
                            );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('שמור'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();

    if (saved == true) {
      ref.invalidate(adminOrganizationsProvider);
      ref.invalidate(adminContractorOrganizationsProvider);
      ref.invalidate(adminSupplierOrganizationsProvider);
      ref.invalidate(adminOrganizationProvider(org.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('פרטי החברה עודכנו')),
        );
      }
    }
  }

  @override
  ConsumerState<AdminCompanyDetailScreen> createState() =>
      _AdminCompanyDetailScreenState();
}

class _AdminCompanyDetailScreenState
    extends ConsumerState<AdminCompanyDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(adminOrganizationProvider(widget.orgId));

    return AdminPlatformGate(
      child: orgAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Scaffold(
          appBar: const SecondaryAppBar(title: 'ניהול חברה'),
          body: const Center(child: Text('שגיאה בטעינת חברה')),
        ),
        data: (org) {
          if (org == null) {
            return Scaffold(
              appBar: const SecondaryAppBar(title: 'ניהול חברה'),
              body: const Center(child: Text('החברה לא נמצאה')),
            );
          }

          final listRoute = org.type == OrganizationType.contractor
              ? '/admin/contractors'
              : '/admin/suppliers';
          final typeLabel =
              org.type == OrganizationType.contractor ? 'קבלן' : 'ספק';
          final actorRoles = org.type == OrganizationType.contractor
              ? const [EnterpriseRole.contractorCompanyOwner]
              : const [EnterpriseRole.supplierOwner];

          return Scaffold(
            appBar: SecondaryAppBar(
              title: 'ניהול ${org.name}',
              homeRoute: '/admin',
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const AdminBackToCockpitButton(),
                      AdminBackToOrgListButton(listRoute: listRoute),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppTheme.navy,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.teal,
                  tabs: const [
                    Tab(text: 'סקירה'),
                    Tab(text: 'צוות והרשאות'),
                    Tab(text: 'ממתינים לאישור'),
                    Tab(text: 'פרויקטים'),
                    Tab(text: 'הגדרות חברה'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _OverviewCard(org: org, typeLabel: typeLabel),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          TeamPermissionsSection(
                            orgId: org.id,
                            orgType: org.type,
                            orgName: org.name,
                            isPlatformAdmin: true,
                            actorRoles: actorRoles,
                            title: 'ניהול צוות והרשאות',
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          PendingAccessRequestsSection(
                            title: 'משתמשים ממתינים לאישור',
                            orgId: org.id,
                            orgType: org.type,
                          ),
                        ],
                      ),
                      _OrgProjectsTab(orgId: org.id, orgType: org.type),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _OverviewCard(org: org, typeLabel: typeLabel),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => AdminCompanyDetailScreen.openEditDialog(
                              context,
                              ref,
                              org: org,
                            ),
                            child: const Text('ערוך חברה'),
                          ),
                          if (org.type == OrganizationType.supplier) ...[
                            const SizedBox(height: 16),
                            _SupplierDirectoryTab(org: org),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.org, required this.typeLabel});

  final Organization org;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              org.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text('$typeLabel · ${org.status}',
                style: const TextStyle(color: AppTheme.textSecondary)),
            if (org.phone?.isNotEmpty == true) Text('טלפון: ${org.phone}'),
            if (org.email?.isNotEmpty == true) Text('אימייל: ${org.email}'),
          ],
        ),
      ),
    );
  }
}

class _OrgProjectsTab extends ConsumerWidget {
  const _OrgProjectsTab({required this.orgId, required this.orgType});

  final String orgId;
  final OrganizationType orgType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orgType != OrganizationType.contractor) {
      return const Center(child: Text('פרויקטים רלוונטיים לקבלנים בלבד'));
    }

    final projectsAsync = ref.watch(adminProjectsForOrgProvider(orgId));

    return projectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('שגיאה בטעינת פרויקטים')),
      data: (projects) {
        if (projects.isEmpty) {
          return const Center(child: Text('אין פרויקטים לחברה זו'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (_, i) {
            final project = projects[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(project.name),
                subtitle: Text(
                  '${project.statusLabel} · ${project.managerUids.length} משתמשים משויכים',
                ),
                trailing: FilledButton(
                  onPressed: () => context.push('/projects/${project.id}'),
                  child: const Text('פתח'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SupplierDirectoryTab extends ConsumerWidget {
  const _SupplierDirectoryTab({required this.org});

  final Organization org;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directoryAsync =
        ref.watch(adminSupplierDirectoryForOrgProvider(org.id));

    return directoryAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('שגיאה בטעינת ספר ספקים'),
      data: (entries) {
        if (entries.isEmpty) {
          return const Text('אין רשומה בספר הספקים');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ספר ספקים',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            for (final entry in entries)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(entry.displayName),
                  subtitle: Text(
                    'עיר: ${entry.city.isEmpty ? '—' : entry.city}',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

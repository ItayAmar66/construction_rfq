import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/admin_management_providers.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/app_back_leading.dart';
import 'admin_platform_gate.dart';

class AdminProjectsManagementScreen extends ConsumerWidget {
  const AdminProjectsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(adminAllProjectsProvider);
    final orgsAsync = ref.watch(adminOrganizationsProvider);

    return AdminPlatformGate(
      child: Scaffold(
        appBar: const SecondaryAppBar(
          title: 'ניהול פרויקטים',
          homeRoute: '/admin',
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AdminBackToCockpitButton(),
            const SizedBox(height: 8),
            projectsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('שגיאה בטעינת פרויקטים'),
              data: (projects) {
                final orgNames = {
                  for (final o in orgsAsync.valueOrNull ?? const [])
                    o.id: o.name,
                };

                if (projects.isEmpty) {
                  return const Text('אין פרויקטים');
                }

                return Column(
                  children: [
                    for (final project in projects)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(project.name),
                          subtitle: Text(
                            '${project.companyName ?? orgNames[project.orgId] ?? '—'} · '
                            '${project.managerUids.length} משתמשים · ${project.statusLabel}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: project.orgId == null
                                    ? null
                                    : () => context.push(
                                          '/admin/company/${project.orgId}',
                                        ),
                                child: const Text('חברה'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    context.push('/projects/${project.id}'),
                                child: const Text('פתח'),
                              ),
                            ],
                          ),
                        ),
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

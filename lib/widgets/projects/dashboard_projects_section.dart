import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/enterprise/project.dart';
import '../../providers/project_providers.dart';
import '../../providers/providers.dart';
import '../../providers/enterprise_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/project_order_helpers.dart';
import '../../utils/user_facing_error.dart';
import '../dashboard_section_header.dart';
import '../empty_state.dart';
import 'create_project_dialog.dart';
import 'project_status_chip.dart';

class DashboardProjectsSection extends ConsumerWidget {
  const DashboardProjectsSection({super.key});

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final result = await CreateProjectDialog.show(context);
    if (result == null || !context.mounted) return;

    final uid = ref.read(authSessionProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await ref.read(projectRepositoryProvider).createProject(
            ownerUid: uid,
            name: result.name,
            location: result.location,
            cityOrArea: result.cityOrArea,
            notes: result.notes,
            companyName:
                ref.read(authSessionProvider).valueOrNull?.profile?.fullName,
          );
      ref.invalidate(currentUserProjectsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(currentUserProjectsProvider);
    final pendingAsync = ref.watch(deletionPendingProjectsProvider);
    final openCounts = ref.watch(openRequestCountByProjectProvider);
    final canCreateProject = ref.watch(canCreateProjectProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: DashboardSectionHeader(
                title: HebrewStrings.projectsSection,
                subtitle: 'אתרים ופרויקטים פעילים',
                icon: Icons.location_city_outlined,
                accentColor: AppTheme.navy,
              ),
            ),
            if (canCreateProject)
              TextButton.icon(
                onPressed: () => _createProject(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(HebrewStrings.addProject),
              ),
          ],
        ),
        const SizedBox(height: 8),
        pendingAsync.when(
          data: (pending) {
            if (pending.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final project in pending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ProjectCard(
                      project: project,
                      openRequests: openCounts[project.id] ?? 0,
                      onOpen: () => context.push('/projects/${project.id}'),
                      onNewRequest: () => context.push(
                            ProjectOrderHelpers.catalogRouteForProject(
                              project.id,
                            ),
                          ),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        projectsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => EmptyState(
            message: HebrewStrings.errorGeneric,
            icon: Icons.error_outline,
            hint: HebrewStrings.errorGenericHint,
            actionLabel: 'נסה שוב',
            onAction: () => ref.invalidate(currentUserProjectsProvider),
          ),
          data: (projects) {
            if (projects.isEmpty) {
              return EmptyState(
                message: HebrewStrings.emptyProjects,
                icon: Icons.apartment_outlined,
                hint: canCreateProject
                    ? 'צרו פרויקט כדי לשייך בקשות חומרים לאתר'
                    : 'אין פרויקטים משויכים לחשבון זה',
                actionLabel:
                    canCreateProject ? HebrewStrings.createFirstProject : null,
                onAction: canCreateProject
                    ? () => _createProject(context, ref)
                    : null,
              );
            }

            return Column(
              children: [
                for (final project in projects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ProjectCard(
                      project: project,
                      openRequests: openCounts[project.id] ?? 0,
                      onOpen: () => context.push('/projects/${project.id}'),
                      onNewRequest: () => context.push(
                            ProjectOrderHelpers.catalogRouteForProject(
                              project.id,
                            ),
                          ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.openRequests,
    required this.onOpen,
    required this.onNewRequest,
  });

  final Project project;
  final int openRequests;
  final VoidCallback onOpen;
  final VoidCallback onNewRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.teal.withValues(alpha: 0.12),
                child: const Icon(Icons.apartment_outlined,
                    color: AppTheme.teal, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ProjectStatusChip(project: project),
                      ],
                    ),
                    if (project.locationLine.isNotEmpty)
                      Text(
                        project.locationLine,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    if (openRequests > 0)
                      Text(
                        '$openRequests בקשות פתוחות',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.navy,
                        ),
                      ),
                    Text(
                      'פתח פרויקט',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onNewRequest,
                child: const Text(HebrewStrings.newProjectOrder),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

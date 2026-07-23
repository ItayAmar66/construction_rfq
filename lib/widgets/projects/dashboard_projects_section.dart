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
import '../design_system/primary_button.dart';
import '../design_system/tertiary_button.dart';
import '../empty_state.dart';
import '../loading_view.dart';
import 'create_project_dialog.dart';

import '../status_chip.dart';
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
            managerName: result.managerName,
            managerPhone: result.managerPhone,
            startDate: result.startDate,
            estimatedCompletionDate: result.estimatedCompletionDate,
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

  static Future<void> editProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final result = await CreateProjectDialog.show(
      context,
      initial: CreateProjectResult(
        name: project.name,
        location: project.location,
        cityOrArea: project.cityOrArea,
        notes: project.notes,
        managerName: project.managerName,
        managerPhone: project.managerPhone,
        startDate: project.startDate,
        estimatedCompletionDate: project.estimatedCompletionDate,
      ),
    );
    if (result == null || !context.mounted) return;
    final uid = ref.read(authSessionProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await ref.read(projectRepositoryProvider).updateProjectDetails(
            projectId: project.id,
            ownerUid: uid,
            name: result.name,
            location: result.location,
            cityOrArea: result.cityOrArea,
            notes: result.notes,
            managerName: result.managerName,
            managerPhone: result.managerPhone,
            startDate: result.startDate,
            estimatedCompletionDate: result.estimatedCompletionDate,
          );
      ref.invalidate(currentUserProjectsProvider);
      ref.invalidate(projectProvider(project.id));
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
              TertiaryButton(
                label: HebrewStrings.addProject,
                icon: Icons.add,
                onPressed: () => _createProject(context, ref),
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
                      onEdit: () => editProject(context, ref, project),
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
          loading: () => const LoadingView(),
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
                      onEdit: () => editProject(context, ref, project),
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

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({
    required this.project,
    required this.openRequests,
    required this.onOpen,
    required this.onNewRequest,
    required this.onEdit,
  });

  final Project project;
  final int openRequests;
  final VoidCallback onOpen;
  final VoidCallback onNewRequest;
  final VoidCallback onEdit;

  String _fmtDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(projectProcurementSummaryProvider(project.id));
    final needsAttention = summary.pendingQuotes > 0 || openRequests > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                            if (needsAttention)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(end: 6),
                                child: StatusChip(
                                  label: 'דורש תשומת לב',
                                  foreground: AppTheme.amberDark,
                                  background:
                                      AppTheme.amber.withValues(alpha: 0.14),
                                  icon: Icons.priority_high,
                                  dense: true,
                                  bordered: false,
                                ),
                              ),
                            StatusChip.project(project),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'עריכת פרויקט',
                              visualDensity: VisualDensity.compact,
                              onPressed: onEdit,
                            ),
                          ],
                        ),
                        if (project.locationLine.isNotEmpty)
                          Text(
                            project.locationLine,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        if (project.managerName != null &&
                            project.managerName!.isNotEmpty)
                          Text(
                            'מנהל פרויקט: ${project.managerName}'
                            '${project.managerPhone != null && project.managerPhone!.isNotEmpty ? ' · ${project.managerPhone}' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        if (project.startDate != null ||
                            project.estimatedCompletionDate != null)
                          Text(
                            'התחלה: ${_fmtDate(project.startDate)} · סיום משוער: ${_fmtDate(project.estimatedCompletionDate)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MiniStat(label: 'בקשות פתוחות', value: '$openRequests'),
                  _MiniStat(
                      label: 'הצעות ממתינות', value: '${summary.pendingQuotes}'),
                  _MiniStat(
                      label: 'הזמנות פעילות', value: '${summary.approvedOrders}'),
                  const Spacer(),
                  PrimaryButton.tonal(
                    label: HebrewStrings.newProjectOrder,
                    onPressed: onNewRequest,
                    expand: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/project_assignment_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_hierarchy_presets.dart';
import 'permission_hierarchy_tree.dart';
import 'role_read_only_notice.dart';

/// Project team hierarchy section for project workspace.
/// Shows real assignments if available; otherwise empty state.
class ProjectTeamHierarchySection extends ConsumerWidget {
  const ProjectTeamHierarchySection({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = EnterpriseHierarchyPresets.projectTeam;
    final theme = Theme.of(context);
    final assignmentsAsync = ref.watch(projectAssignmentsProvider(projectId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              preset.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'הרשאות החברה קובעות מה המשתמש יכול לעשות. '
              'שיוך לפרויקט קובע באיזה פרויקט הוא יכול לעבוד.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            assignmentsAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, __) => const _ProjectTeamEmptyState(
                message: 'לא ניתן לטעון צוות פרויקט כרגע',
              ),
              data: (assignments) {
                if (assignments.isEmpty) {
                  return const _ProjectTeamEmptyState(
                    message: 'עדיין לא הוגדר צוות לפרויקט',
                  );
                }
                return Column(
                  children: [
                    for (final assignment in assignments)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceTint,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                assignment.uid,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              assignmentRoleLabel(assignment.role),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.teal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            PermissionHierarchyTree(
              root: preset.root,
              showHeader: false,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('שייך משתמש לפרויקט'),
                ),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('ערוך הרשאות בפרויקט'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const RoleReadOnlyNotice(
              message: 'שיוך משתמשים לפרויקט יופעל בשלב הבא.',
              showDisabledButton: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTeamEmptyState extends StatelessWidget {
  const _ProjectTeamEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.group_outlined,
            size: 20,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

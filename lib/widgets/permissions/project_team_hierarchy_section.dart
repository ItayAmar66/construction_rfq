import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/membership.dart';
import '../../models/enterprise/organization_type.dart';
import '../../models/enterprise/project_assignment.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../repositories/project_assignment_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_hierarchy_presets.dart';
import '../../utils/project_assignment_roles.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/permissions/assign_project_member_dialog.dart';
import '../../widgets/permissions/role_change_dialog.dart';
import 'permission_hierarchy_tree.dart';

/// Project team section — real assignments with assign/edit/remove.
class ProjectTeamHierarchySection extends ConsumerWidget {
  const ProjectTeamHierarchySection({
    super.key,
    required this.projectId,
    this.orgId,
  });

  final String projectId;
  final String? orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = EnterpriseHierarchyPresets.projectTeam;
    final theme = Theme.of(context);
    final canManage = ref.watch(canManageProjectTeamProvider(projectId));
    final assignmentsAsync = ref.watch(projectAssignmentsProvider(projectId));
    final resolvedOrgId = orgId ??
        ref.watch(currentUserMembershipsProvider).valueOrNull?.firstOrNull?.orgId;
    final members =
        resolvedOrgId != null
            ? ref.watch(orgMembershipsProvider(resolvedOrgId)).valueOrNull ??
                const <Membership>[]
            : const <Membership>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    preset.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                assignmentsAsync.maybeWhen(
                  data: (list) => list.isEmpty
                      ? const SizedBox.shrink()
                      : Chip(
                          label: Text('${list.length} משויכים'),
                          visualDensity: VisualDensity.compact,
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
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
                      _AssignmentRow(
                        assignment: assignment,
                        canManage: canManage,
                        onEdit: canManage
                            ? () => _editAssignment(context, ref, assignment)
                            : null,
                        onRemove: canManage
                            ? () => _removeAssignment(context, ref, assignment)
                            : null,
                      ),
                  ],
                );
              },
            ),
            if (members.isEmpty && canManage) ...[
              const SizedBox(height: 8),
              const _ProjectTeamEmptyState(
                message:
                    'אין עדיין משתמשים לשיוך. הוסף משתמשים דרך ניהול חברה.',
              ),
            ],
            const SizedBox(height: 12),
            if (canManage)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: members.isEmpty
                      ? null
                      : () => _assignMember(
                            context,
                            ref,
                            members,
                            assignmentsAsync.valueOrNull ?? const [],
                            resolvedOrgId ?? '',
                          ),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('שייך משתמש לפרויקט'),
                ),
              ),
            const SizedBox(height: 12),
            PermissionHierarchyTree(
              root: preset.root,
              showHeader: false,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignMember(
    BuildContext context,
    WidgetRef ref,
    List<Membership> members,
    List<ProjectAssignment> existing,
    String orgId,
  ) async {
    final canManage = ref.read(canManageProjectTeamProvider(projectId));
    if (!canManage) return;

    final session = ref.read(authSessionProvider).valueOrNull;
    try {
      await AssignProjectMemberDialog.show(
        context: context,
        members: members,
        existingUids: existing.map((a) => a.uid).toSet(),
        onSave: ({required member, required role}) async {
          await ref.read(projectAssignmentRepositoryProvider).assignUserToProject(
                projectId: projectId,
                orgId: orgId,
                uid: member.uid,
                role: role,
                actorUid: session?.uid ?? '',
                canManage: canManage,
                displayName: member.uid,
                orgMembers: members,
              );
          ref.invalidate(projectAssignmentsProvider(projectId));
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('המשתמש שויך לפרויקט')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  Future<void> _editAssignment(
    BuildContext context,
    WidgetRef ref,
    ProjectAssignment assignment,
  ) async {
    final canManage = ref.read(canManageProjectTeamProvider(projectId));
    if (!canManage) return;

    final session = ref.read(authSessionProvider).valueOrNull;
    try {
      await RoleChangeDialog.show(
        context: context,
        membership: Membership(
          uid: assignment.uid,
          orgId: assignment.orgId,
          orgType: OrganizationType.contractor,
          roles: [assignment.role],
        ),
        displayName: assignment.displayName ?? assignment.uid,
        orgType: OrganizationType.contractor,
        allowedRoles: ProjectAssignmentRoles.assignable,
        onSave: (newRole) async {
          await ref
              .read(projectAssignmentRepositoryProvider)
              .updateProjectAssignmentRole(
                projectId: projectId,
                uid: assignment.uid,
                role: newRole,
                actorUid: session?.uid ?? '',
                canManage: canManage,
              );
          ref.invalidate(projectAssignmentsProvider(projectId));
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  Future<void> _removeAssignment(
    BuildContext context,
    WidgetRef ref,
    ProjectAssignment assignment,
  ) async {
    final canManage = ref.read(canManageProjectTeamProvider(projectId));
    if (!canManage) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('הסר מהפרויקט'),
        content: Text('להסיר את ${assignment.displayName ?? assignment.uid}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('הסר'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final session = ref.read(authSessionProvider).valueOrNull;
    try {
      await ref.read(projectAssignmentRepositoryProvider).removeProjectAssignment(
            projectId: projectId,
            uid: assignment.uid,
            canManage: canManage,
            actorUid: session?.uid ?? '',
            orgId: assignment.orgId,
          );
      ref.invalidate(projectAssignmentsProvider(projectId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.assignment,
    required this.canManage,
    this.onEdit,
    this.onRemove,
  });

  final ProjectAssignment assignment;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              assignment.displayName ?? assignment.uid,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            ProjectAssignmentRoles.label(assignment.role),
            style: const TextStyle(
              color: AppTheme.teal,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'שינוי תפקיד',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.person_remove_outlined, size: 18),
              tooltip: 'הסר מהפרויקט',
              onPressed: onRemove,
            ),
          ],
        ],
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
          const Icon(Icons.group_outlined, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

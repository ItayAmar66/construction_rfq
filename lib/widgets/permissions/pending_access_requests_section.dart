import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/access_request.dart';
import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/organization.dart';
import '../../models/enterprise/organization_type.dart';
import '../../models/enterprise/project.dart';
import '../../providers/admin_management_providers.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../providers/user_approval_providers.dart';
import '../../services/user_approval_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';

class PendingAccessRequestsSection extends ConsumerWidget {
  const PendingAccessRequestsSection({
    super.key,
    required this.title,
    this.orgId,
    this.orgType,
    this.showOrgPicker = false,
  });

  final String title;
  final String? orgId;
  final OrganizationType? orgType;
  final bool showOrgPicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = showOrgPicker
        ? ref.watch(allPendingAccessRequestsProvider)
        : orgId != null
            ? ref.watch(pendingAccessRequestsForOrgProvider(orgId!))
            : const AsyncValue<List<AccessRequest>>.data([]);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_top_outlined, color: AppTheme.navy),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            pendingAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _PendingRequestsError(
                error: error,
                onRetry: () {
                  if (showOrgPicker) {
                    ref.invalidate(allPendingAccessRequestsProvider);
                  } else if (orgId != null) {
                    ref.invalidate(pendingAccessRequestsForOrgProvider(orgId!));
                  }
                },
              ),
              data: (requests) {
                final pendingOnly = requests.where((r) => r.isPending).toList();
                if (pendingOnly.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('אין משתמשים שממתינים לאישור'),
                  );
                }
                return Column(
                  children: [
                    for (final request in pendingOnly)
                      _PendingRequestCard(
                        request: request,
                        orgId: orgId,
                        orgType: orgType,
                        showOrgPicker: showOrgPicker,
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

class _PendingRequestsError extends StatelessWidget {
  const _PendingRequestsError({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error.toString();
    final isPermission = message.contains('permission-denied');
    final isIndex = message.contains('failed-precondition') ||
        message.contains('requires an index');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isPermission
                ? 'אין הרשאה לטעון בקשות ממתינות'
                : isIndex
                    ? 'נדרש אינדקס Firestore לבקשות ממתינות'
                    : 'שגיאה בטעינת בקשות',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('נסה שוב')),
        ],
      ),
    );
  }
}

class _PendingRequestCard extends ConsumerWidget {
  const _PendingRequestCard({
    required this.request,
    this.orgId,
    this.orgType,
    required this.showOrgPicker,
  });

  final AccessRequest request;
  final String? orgId;
  final OrganizationType? orgType;
  final bool showOrgPicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeLabel =
        request.requestedOrgType == OrganizationType.supplier ? 'ספק' : 'קבלן';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.amber.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(request.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(request.email, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(
              'בקשה: $typeLabel · ${request.requestedOrgName.isNotEmpty ? request.requestedOrgName : 'ללא שם חברה'}',
              style: const TextStyle(fontSize: 13),
            ),
            if (request.requestedRole.isNotEmpty)
              Text('תפקיד מבוקש: ${request.requestedRole}',
                  style: const TextStyle(fontSize: 13)),
            if (request.requestedProjectName.isNotEmpty)
              Text('פרויקט: ${request.requestedProjectName}',
                  style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => ApproveUserDialog.show(
                    context: context,
                    ref: ref,
                    request: request,
                    fixedOrgId: orgId,
                    fixedOrgType: orgType,
                    showOrgPicker: showOrgPicker,
                  ),
                  child: const Text('אשר'),
                ),
                OutlinedButton(
                  onPressed: () => _reject(context, ref),
                  child: const Text('דחה'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('דחיית בקשה'),
        content: Text('לדחות את ${request.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ביטול')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('דחה')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final session = ref.read(authSessionProvider).valueOrNull;
    await ref.read(userApprovalServiceProvider).rejectAccessRequest(
          request: request,
          actorUid: session?.uid ?? '',
        );
    ref.invalidate(allPendingAccessRequestsProvider);
    if (orgId != null) ref.invalidate(pendingAccessRequestsForOrgProvider(orgId!));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הבקשה נדחתה')),
      );
    }
  }
}

class ApproveUserDialog {
  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required AccessRequest request,
    String? fixedOrgId,
    OrganizationType? fixedOrgType,
    bool showOrgPicker = false,
  }) async {
    final isAdmin = ref.read(hasPlatformAdminClaimProvider);
    final myMemberships =
        ref.read(currentUserMembershipsProvider).valueOrNull ?? const [];
    final actorRoles = myMemberships.firstOrNull?.roles ?? const [];

    List<Organization> orgs = const [];
    if (showOrgPicker) {
      orgs = await ref.read(adminOrganizationsProvider.future);
      orgs = orgs
          .where((o) => o.type == request.requestedOrgType)
          .toList();
    }

    Organization? selectedOrg;
    if (fixedOrgId != null && fixedOrgId.isNotEmpty) {
      if (showOrgPicker) {
        selectedOrg = orgs.where((o) => o.id == fixedOrgId).firstOrNull;
      }
      selectedOrg ??= Organization(
        id: fixedOrgId,
        type: fixedOrgType ?? request.requestedOrgType,
        name: request.requestedOrgName,
        ownerUid: '',
      );
    } else if (request.requestedOrgId.isNotEmpty) {
      selectedOrg = Organization(
        id: request.requestedOrgId,
        type: request.requestedOrgType,
        name: request.requestedOrgName,
        ownerUid: '',
      );
    } else if (orgs.isNotEmpty) {
      selectedOrg = orgs.first;
    }

    final orgType = selectedOrg?.type ?? request.requestedOrgType;
    var roles = UserApprovalService.approvalRolesFor(
      orgType: orgType,
      actorRoles: actorRoles,
      isPlatformAdmin: isAdmin,
    );
    if (roles.isEmpty) roles = [EnterpriseRole.contractorViewer];

    EnterpriseRole selectedRole = request.requestedRole.isNotEmpty
        ? EnterpriseRole.fromValue(request.requestedRole) ?? roles.first
        : roles.first;
    if (!roles.contains(selectedRole)) selectedRole = roles.first;

    final selectedProjects = <String>{};
    List<Project> projects = const [];
    if (selectedOrg != null) {
      projects =
          await ref.read(userApprovalServiceProvider).fetchProjectsForOrg(selectedOrg.id);
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> reloadProjects(String orgId) async {
            projects = await ref
                .read(userApprovalServiceProvider)
                .fetchProjectsForOrg(orgId);
            selectedProjects.clear();
            setState(() {});
          }

          return AlertDialog(
            title: const Text('אשר משתמש'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${request.fullName} · ${request.email}'),
                    const SizedBox(height: 12),
                    if (showOrgPicker && orgs.isNotEmpty)
                      DropdownButtonFormField<Organization>(
                        value: selectedOrg,
                        decoration: const InputDecoration(labelText: 'שייך לחברה'),
                        items: orgs
                            .map((o) => DropdownMenuItem(value: o, child: Text(o.name)))
                            .toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          selectedOrg = v;
                          final nextRoles = UserApprovalService.approvalRolesFor(
                            orgType: v.type,
                            actorRoles: actorRoles,
                            isPlatformAdmin: isAdmin,
                          );
                          selectedRole = nextRoles.first;
                          await reloadProjects(v.id);
                        },
                      )
                    else if (selectedOrg != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('חברה'),
                        subtitle: Text(selectedOrg!.name),
                      ),
                    DropdownButtonFormField<EnterpriseRole>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'בחר תפקיד'),
                      items: roles
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(EnterpriseRoleLabels.hebrew(r)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => selectedRole = v);
                      },
                    ),
                    if (orgType == OrganizationType.contractor && projects.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('גישה לפרויקטים',
                          style: Theme.of(ctx).textTheme.titleSmall),
                      for (final project in projects)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(project.name),
                          value: selectedProjects.contains(project.id),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedProjects.add(project.id);
                              } else {
                                selectedProjects.remove(project.id);
                              }
                            });
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ביטול')),
              FilledButton(
                onPressed: selectedOrg == null
                    ? null
                    : () async {
                        final session = ref.read(authSessionProvider).valueOrNull;
                        try {
                          await ref.read(userApprovalServiceProvider).approveAccessRequest(
                                request: request,
                                orgId: selectedOrg!.id,
                                orgType: selectedOrg!.type,
                                role: selectedRole,
                                actorUid: session?.uid ?? '',
                                actorName: session?.profile?.fullName,
                                actorEmail: session?.profile?.email,
                                projectIds: selectedProjects.toList(),
                              );
                          ref.invalidate(allPendingAccessRequestsProvider);
                          ref.invalidate(pendingAccessRequestsForOrgProvider(selectedOrg!.id));
                          ref.invalidate(orgMembershipsProvider(selectedOrg!.id));
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('המשתמש אושר בהצלחה')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                child: const Text('אשר'),
              ),
            ],
          );
        },
      ),
    );
  }
}

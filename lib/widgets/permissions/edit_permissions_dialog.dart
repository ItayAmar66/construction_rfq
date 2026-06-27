import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account_status.dart';
import '../../models/app_user.dart';
import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/membership.dart';
import '../../models/enterprise/organization.dart';
import '../../models/enterprise/organization_type.dart';
import '../../models/enterprise/project.dart';
import '../../providers/providers.dart';
import '../../providers/team_permissions_providers.dart';
import '../../services/team_permissions_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import '../../utils/membership_role_update_errors.dart';
import '../../utils/team_permissions_policy.dart';

class EditPermissionsDialog extends ConsumerStatefulWidget {
  const EditPermissionsDialog({
    super.key,
    required this.membership,
    required this.orgType,
    required this.actorRoles,
    required this.isPlatformAdmin,
    this.userProfile,
    this.orgName,
    this.projects = const [],
    this.canEditRole = true,
    this.canEditProjectAccess = true,
    this.canEditStatus = true,
  });

  final Membership membership;
  final OrganizationType orgType;
  final List<EnterpriseRole> actorRoles;
  final bool isPlatformAdmin;
  final AppUser? userProfile;
  final String? orgName;
  final List<Project> projects;
  final bool canEditRole;
  final bool canEditProjectAccess;
  final bool canEditStatus;

  static Future<bool?> show({
    required BuildContext context,
    required WidgetRef ref,
    required Membership membership,
    required OrganizationType orgType,
    required List<EnterpriseRole> actorRoles,
    required bool isPlatformAdmin,
    AppUser? userProfile,
    String? orgName,
    List<Project> projects = const [],
    bool canEditRole = true,
    bool canEditProjectAccess = true,
    bool canEditStatus = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => EditPermissionsDialog(
          membership: membership,
          orgType: orgType,
          actorRoles: actorRoles,
          isPlatformAdmin: isPlatformAdmin,
          userProfile: userProfile,
          orgName: orgName,
          projects: projects,
          canEditRole: canEditRole,
          canEditProjectAccess: canEditProjectAccess,
          canEditStatus: canEditStatus,
      ),
    );
  }

  @override
  ConsumerState<EditPermissionsDialog> createState() =>
      _EditPermissionsDialogState();
}

class _EditPermissionsDialogState extends ConsumerState<EditPermissionsDialog> {
  late EnterpriseRole _selectedRole;
  late String _membershipStatus;
  late AccountStatus _accountStatus;
  late Set<String> _selectedProjectIds;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final allowed = TeamPermissionsPolicy.assignableRoles(
      orgType: widget.orgType,
      actorRoles: widget.actorRoles,
      isPlatformAdmin: widget.isPlatformAdmin,
    );
    _selectedRole = widget.membership.roles.firstOrNull ??
        (allowed.isNotEmpty ? allowed.first : EnterpriseRole.contractorViewer);
    _membershipStatus = widget.membership.status;
    _accountStatus = widget.userProfile?.accountStatus ?? AccountStatus.active;
    _selectedProjectIds = {...widget.membership.projectIds};
  }

  @override
  Widget build(BuildContext context) {
    final allowedRoles = TeamPermissionsPolicy.assignableRoles(
      orgType: widget.orgType,
      actorRoles: widget.actorRoles,
      isPlatformAdmin: widget.isPlatformAdmin,
    );
    final displayName = widget.userProfile?.fullName.isNotEmpty == true
        ? widget.userProfile!.fullName
        : widget.membership.displayLabel;
    final email =
        widget.userProfile?.email ?? widget.membership.email ?? '';

    return AlertDialog(
      title: const Text('עריכת הרשאות משתמש'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (email.isNotEmpty)
                Text(email, style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: widget.orgName ?? widget.membership.orgId,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'חברה',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EnterpriseRole>(
                value: allowedRoles.contains(_selectedRole)
                    ? _selectedRole
                    : allowedRoles.firstOrNull,
                decoration: const InputDecoration(
                  labelText: 'תפקיד',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final role in allowedRoles)
                    DropdownMenuItem(
                      value: role,
                      child: Text(EnterpriseRoleLabels.hebrew(role)),
                    ),
                ],
                onChanged: widget.canEditRole && !_saving
                    ? (role) {
                        if (role != null) setState(() => _selectedRole = role);
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _membershipStatus,
                decoration: const InputDecoration(
                  labelText: 'סטטוס חברות',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('פעיל')),
                  DropdownMenuItem(value: 'disabled', child: Text('מושבת')),
                ],
                onChanged: widget.canEditStatus && !_saving
                    ? (v) {
                        if (v != null) setState(() => _membershipStatus = v);
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountStatus>(
                value: _accountStatus,
                decoration: const InputDecoration(
                  labelText: 'סטטוס חשבון',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final status in [
                    AccountStatus.active,
                    AccountStatus.disabled,
                    if (widget.isPlatformAdmin) AccountStatus.rejected,
                  ])
                    DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    ),
                ],
                onChanged: widget.canEditStatus && !_saving
                    ? (v) {
                        if (v != null) setState(() => _accountStatus = v);
                      }
                    : null,
              ),
              if (widget.orgType == OrganizationType.contractor &&
                  widget.projects.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'גישה לפרויקטים',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (widget.canEditProjectAccess) ...[
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(
                                  () => _selectedProjectIds = {
                                    for (final p in widget.projects) p.id,
                                  },
                                ),
                        child: const Text('בחר הכל'),
                      ),
                      TextButton(
                        onPressed:
                            _saving ? null : () => setState(_selectedProjectIds.clear),
                        child: const Text('נקה הכל'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                for (final project in widget.projects)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(project.name),
                    subtitle: Text(project.statusLabel),
                    value: _selectedProjectIds.contains(project.id),
                    onChanged: widget.canEditProjectAccess && !_saving
                        ? (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedProjectIds.add(project.id);
                              } else {
                                _selectedProjectIds.remove(project.id);
                              }
                            });
                          }
                        : null,
                  ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('ביטול'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('שמור הרשאות'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final session = ref.read(authSessionProvider).valueOrNull;
      final input = TeamPermissionUpdateInput(
        role: _selectedRole,
        membershipStatus: _membershipStatus,
        accountStatus: _accountStatus,
        projectIds: widget.orgType == OrganizationType.contractor
            ? _selectedProjectIds.toList()
            : null,
      );

      await ref.read(teamPermissionsServiceProvider).updateMemberPermissions(
            membership: widget.membership,
            orgType: widget.orgType,
            actorUid: session?.uid ?? '',
            isPlatformAdmin: widget.isPlatformAdmin,
            actorRoles: widget.actorRoles,
            input: input,
            actorEmail: session?.profile?.email,
            actorName: session?.profile?.fullName,
          );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = MembershipRoleUpdateErrors.userMessage(e);
      });
    }
  }
}

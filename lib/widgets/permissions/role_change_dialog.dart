import 'package:flutter/material.dart';

import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/membership.dart';
import '../../models/enterprise/organization_type.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';

/// Role change dialog — safe subset of allowed role changes.
class RoleChangeDialog extends StatefulWidget {
  const RoleChangeDialog({
    super.key,
    required this.membership,
    required this.displayName,
    required this.orgType,
    required this.allowedRoles,
    required this.onSave,
  });

  final Membership membership;
  final String displayName;
  final OrganizationType orgType;
  final List<EnterpriseRole> allowedRoles;
  final Future<void> Function(EnterpriseRole newRole) onSave;

  static Future<void> show({
    required BuildContext context,
    required Membership membership,
    required String displayName,
    required OrganizationType orgType,
    required List<EnterpriseRole> allowedRoles,
    required Future<void> Function(EnterpriseRole) onSave,
  }) =>
      showDialog<void>(
        context: context,
        builder: (_) => RoleChangeDialog(
          membership: membership,
          displayName: displayName,
          orgType: orgType,
          allowedRoles: allowedRoles,
          onSave: onSave,
        ),
      );

  @override
  State<RoleChangeDialog> createState() => _RoleChangeDialogState();
}

class _RoleChangeDialogState extends State<RoleChangeDialog> {
  late EnterpriseRole _selected;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selected = widget.membership.roles.firstOrNull ??
        widget.allowedRoles.first;
  }

  @override
  Widget build(BuildContext context) {
    final description = EnterpriseRoleLabels.description(_selected);

    return AlertDialog(
      title: const Text('שינוי תפקיד'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<EnterpriseRole>(
            value: _selected,
            decoration: const InputDecoration(
              labelText: 'תפקיד חדש',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              for (final role in widget.allowedRoles)
                DropdownMenuItem(
                  value: role,
                  child: Text(EnterpriseRoleLabels.hebrew(role)),
                ),
            ],
            onChanged: _saving
                ? null
                : (role) {
                    if (role != null) setState(() => _selected = role);
                  },
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border:
                  Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'שינוי הרשאה משפיע על פעולות שהמשתמש יכול לבצע במערכת.',
              style: TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.danger, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('ביטול'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('שמור שינוי'),
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
      await widget.onSave(_selected);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }
}

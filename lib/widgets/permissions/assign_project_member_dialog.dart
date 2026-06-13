import 'package:flutter/material.dart';

import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/membership.dart';
import '../../utils/app_theme.dart';
import '../../utils/project_assignment_roles.dart';

class AssignProjectMemberDialog extends StatefulWidget {
  const AssignProjectMemberDialog({
    super.key,
    required this.members,
    required this.existingUids,
    required this.onSave,
  });

  final List<Membership> members;
  final Set<String> existingUids;
  final Future<void> Function({
    required Membership member,
    required EnterpriseRole role,
  }) onSave;

  static Future<void> show({
    required BuildContext context,
    required List<Membership> members,
    required Set<String> existingUids,
    required Future<void> Function({
      required Membership member,
      required EnterpriseRole role,
    }) onSave,
  }) =>
      showDialog<void>(
        context: context,
        builder: (_) => AssignProjectMemberDialog(
          members: members,
          existingUids: existingUids,
          onSave: onSave,
        ),
      );

  @override
  State<AssignProjectMemberDialog> createState() =>
      _AssignProjectMemberDialogState();
}

class _AssignProjectMemberDialogState extends State<AssignProjectMemberDialog> {
  Membership? _selected;
  EnterpriseRole _role = ProjectAssignmentRoles.assignable.first;
  bool _saving = false;
  String? _error;

  List<Membership> get _available => widget.members
      .where((m) => m.status == 'active' && !widget.existingUids.contains(m.uid))
      .toList();

  @override
  void initState() {
    super.initState();
    if (_available.isNotEmpty) _selected = _available.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('שייך משתמש לפרויקט'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_available.isEmpty)
            const Text('כל חברי החברה כבר משויכים לפרויקט.')
          else ...[
            DropdownButtonFormField<Membership>(
              value: _selected,
              decoration: const InputDecoration(
                labelText: 'משתמש',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final m in _available)
                  DropdownMenuItem(value: m, child: Text(m.uid)),
              ],
              onChanged: _saving ? null : (v) => setState(() => _selected = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<EnterpriseRole>(
              value: _role,
              decoration: const InputDecoration(
                labelText: 'תפקיד בפרויקט',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final r in ProjectAssignmentRoles.assignable)
                  DropdownMenuItem(
                    value: r,
                    child: Text(ProjectAssignmentRoles.label(r)),
                  ),
              ],
              onChanged: _saving ? null : (v) => setState(() => _role = v!),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('ביטול'),
        ),
        if (_available.isNotEmpty)
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('שמור'),
          ),
      ],
    );
  }

  Future<void> _save() async {
    final member = _selected;
    if (member == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(member: member, role: _role);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }
}

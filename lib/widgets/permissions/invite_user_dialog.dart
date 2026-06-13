import 'package:flutter/material.dart';

import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/organization_type.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import '../../utils/user_facing_error.dart';

class InviteUserDialog extends StatefulWidget {
  const InviteUserDialog({
    super.key,
    required this.orgType,
    required this.allowedRoles,
    required this.onSubmit,
  });

  final OrganizationType orgType;
  final List<EnterpriseRole> allowedRoles;
  final Future<void> Function({
    required String name,
    required String email,
    required EnterpriseRole role,
  }) onSubmit;

  static Future<void> show({
    required BuildContext context,
    required OrganizationType orgType,
    required List<EnterpriseRole> allowedRoles,
    required Future<void> Function({
      required String name,
      required String email,
      required EnterpriseRole role,
    }) onSubmit,
  }) =>
      showDialog<void>(
        context: context,
        builder: (_) => InviteUserDialog(
          orgType: orgType,
          allowedRoles: allowedRoles,
          onSubmit: onSubmit,
        ),
      );

  @override
  State<InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<InviteUserDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  late EnterpriseRole _role;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _role = widget.allowedRoles.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('הוסף משתמש'),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width.clamp(280, 420),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'שם',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'אימייל',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<EnterpriseRole>(
            value: _role,
            decoration: const InputDecoration(
              labelText: 'תפקיד',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final r in widget.allowedRoles)
                DropdownMenuItem(
                  value: r,
                  child: Text(EnterpriseRoleLabels.hebrew(r)),
                ),
            ],
            onChanged: _saving ? null : (v) => setState(() => _role = v!),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceTint,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Text(
              'כרגע ניתן להעתיק קישור הזמנה. שליחת מייל אוטומטית תחובר בהמשך.',
              style: TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
          ],
        ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('ביטול'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('צור הזמנה'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'יש להזין כתובת אימייל תקינה');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        name: _nameController.text.trim(),
        email: email,
        role: _role,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = userFacingError(e);
      });
    }
  }
}

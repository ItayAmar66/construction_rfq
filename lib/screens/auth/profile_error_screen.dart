import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_type.dart';
import '../../providers/providers.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/design_system/design_system.dart';

/// Shown when Firebase Auth succeeded but Firestore profile is missing.
class ProfileErrorScreen extends ConsumerStatefulWidget {
  const ProfileErrorScreen({super.key});

  @override
  ConsumerState<ProfileErrorScreen> createState() => _ProfileErrorScreenState();
}

class _ProfileErrorScreenState extends ConsumerState<ProfileErrorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  UserType _userType = UserType.privateCustomer;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _retryProfileCreation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).completeMissingProfile(
            userType: _userType,
            fullName: _nameController.text,
            phone: _phoneController.text,
            city: _cityController.text,
          );
      if (!mounted) return;
      ref.invalidate(authSessionProvider);
      if (!mounted) return;
      context.go('/home');
    } on Exception catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('בעיה בפרופיל')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 64, color: Colors.orange.shade700),
                const SizedBox(height: 24),
                const Text(
                  'פרופיל המשתמש לא נמצא בשרת',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'החשבון קיים בהתחברות אך חסר מסמך משתמש.\n'
                  'ניתן ליצור את הפרופיל מחדש או להתנתק ולהירשם שוב.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _nameController,
                  label: 'שם מלא / שם עסק',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'נא להזין שם' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _phoneController,
                  label: 'טלפון',
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'נא להזין טלפון' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserType>(
                  initialValue: _userType,
                  decoration: const InputDecoration(labelText: 'סוג חשבון'),
                  items: UserType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.registrationLabel),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _userType = v!),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _cityController,
                  label: 'עיר / אזור',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'נא להזין עיר / אזור' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'צור פרופיל והמשך',
                  onPressed: _loading ? null : _retryProfileCreation,
                  isLoading: _loading,
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  label: 'חזור להרשמה',
                  expand: true,
                  onPressed: _loading
                      ? null
                      : () async {
                          await ref.read(authServiceProvider).logout();
                          if (!mounted) return;
                          ref.invalidate(authSessionProvider);
                          context.go('/register');
                        },
                ),
                TertiaryButton(
                  label: 'התנתק וחזור להתחברות',
                  onPressed: _loading
                      ? null
                      : () async {
                          await ref.read(authServiceProvider).logout();
                          if (!mounted) return;
                          ref.invalidate(authSessionProvider);
                          context.go('/login');
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

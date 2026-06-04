import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_type.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_fade_in.dart';
import '../../widgets/auth/auth_shell.dart';
import '../../widgets/auth/role_selector.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();
  UserType _userType = UserType.privateCustomer;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).register(
            fullName: _nameController.text,
            phone: _phoneController.text,
            email: _emailController.text,
            password: _passwordController.text,
            userType: _userType,
            city: _cityController.text,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );
      if (mounted) context.go('/home');
    } on Exception catch (_) {
      setState(() => _error = 'ההרשמה נכשלה. ייתכן שהאימייל כבר בשימוש');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: HebrewStrings.register,
      subtitle: 'פתחו חשבון והתחילו לעבוד עם ספקים אמינים',
      showBack: true,
      onBack: () => context.go('/login'),
      heroBullets: const [
        'פרופיל אחד ללקוח או לספק',
        'ניהול בקשות והצעות בעברית מלאה',
        'מוכן לצמיחה עם Firebase',
      ],
      child: AppFadeIn(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RoleSelector(
                value: _userType,
                onChanged: (v) => setState(() => _userType = v),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.fullName,
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'נא להזין שם' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.phone,
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.isEmpty ? 'נא להזין טלפון' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.email,
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v == null || v.isEmpty ? 'נא להזין אימייל' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.password,
                  prefixIcon: Icon(Icons.lock_outline, size: 20),
                ),
                obscureText: true,
                validator: (v) =>
                    v == null || v.length < 6 ? 'סיסמה לפחות 6 תווים' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.city,
                  prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'נא להזין עיר / אזור' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.extraNotes,
                  hintText: 'תחום פעילות, הערות לספקים…',
                ),
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AuthErrorBanner(message: _error!),
              ],
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(HebrewStrings.registerButton),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text(HebrewStrings.goToLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

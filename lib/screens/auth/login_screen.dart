import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_mode.dart';
import '../../models/user_type.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_fade_in.dart';
import '../../widgets/auth/auth_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _demoLogin(UserType type) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).loginAsDemo(type);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = HebrewStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).login(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (mounted) context.go('/home');
    } on Exception catch (e) {
      setState(() => _error = _mapAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(Exception e) {
    final msg = e.toString();
    if (msg.contains('user-not-found') || msg.contains('wrong-password')) {
      return 'אימייל או סיסמה שגויים';
    }
    if (msg.contains('invalid-email')) return 'כתובת אימייל לא תקינה';
    return HebrewStrings.errorGeneric;
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: HebrewStrings.login,
      subtitle: 'התחברו לניהול בקשות והצעות מחיר',
      heroBullets: const [
        'השוואת הצעות מספקים באזור אחד',
        'מכרזים דיגיטליים עם שקיפות מחיר',
        'מעקב הזמנות מקצה לקצה',
      ],
      child: AppFadeIn(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.email,
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
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
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AuthErrorBanner(message: _error!),
              ],
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(HebrewStrings.loginButton),
              ),
              if (!AppMode.useFirebase) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.borderColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'כניסה מהירה',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppTheme.borderColor)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  HebrewStrings.demoModeHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _demoLogin(UserType.privateCustomer),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text(HebrewStrings.demoLoginCustomer),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _demoLogin(UserType.privateSupplier),
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: const Text(HebrewStrings.demoLoginSupplier),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text(HebrewStrings.goToRegister),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

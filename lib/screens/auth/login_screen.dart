import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_mode.dart';
import '../../models/user_type.dart';
import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/auth_form_layout.dart';
import '../../widgets/demo_mode_banner.dart';

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
    return Scaffold(
      body: SafeArea(
        child: AuthFormLayout(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  Icon(
                    Icons.construction,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    HebrewStrings.login,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'קבלנים מנהלים בקשות חומרים לפי פרויקט. ספקים מקבלים בקשות ומגישים הצעות מחיר.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration:
                        const InputDecoration(labelText: HebrewStrings.email),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'נא להזין אימייל' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                        labelText: HebrewStrings.password),
                    obscureText: true,
                    validator: (v) => v == null || v.length < 6
                        ? 'סיסמה לפחות 6 תווים'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(HebrewStrings.loginButton),
                  ),
                  if (AppMode.showDemoPresentation) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    const DemoModeBanner(),
                    const SizedBox(height: 12),
                    Text(
                      HebrewStrings.demoModeHint,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _demoLogin(UserType.privateCustomer),
                      icon: const Icon(Icons.engineering_outlined),
                      label: const Text(HebrewStrings.demoLoginCustomer),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      HebrewStrings.demoCustomerAccountLabel,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _demoLogin(UserType.privateSupplier),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text(HebrewStrings.demoLoginSupplier),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      HebrewStrings.demoSupplierAccountLabel,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text(HebrewStrings.goToRegister),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

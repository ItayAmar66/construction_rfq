import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_mode.dart';
import '../../models/user_type.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/auth/auth_scaffold.dart';
import '../../widgets/demo_mode_banner.dart';
import '../../widgets/design_system/design_system.dart';

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
  bool _obscure = true;
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
      if (mounted) _goAfterAuth(context);
    } catch (e) {
      if (mounted) setState(() => _error = HebrewStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    if (_loading) return;
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
      if (mounted) _goAfterAuth(context);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goAfterAuth(BuildContext context) {
    ref.read(forceLoginProvider.notifier).state = false;
    final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
    if (redirect != null && redirect.startsWith('/')) {
      context.go(redirect);
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandmark(),
            const SizedBox(height: 26),
            Text(
              HebrewStrings.loginTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              HebrewStrings.loginSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 26),
            const AuthFieldLabel(HebrewStrings.email),
            Semantics(
              label: HebrewStrings.email,
              child: AppTextField(
                controller: _emailController,
                hint: 'you@company.co.il',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (v) =>
                    v == null || v.isEmpty ? 'נא להזין אימייל' : null,
              ),
            ),
            const SizedBox(height: 16),
            const AuthFieldLabel(HebrewStrings.password),
            Semantics(
              label: HebrewStrings.password,
              child: AppTextField(
                controller: _passwordController,
                hint: 'הסיסמה שלך',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                  tooltip: _obscure
                      ? HebrewStrings.showPassword
                      : HebrewStrings.hidePassword,
                ),
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) {
                  if (!_loading) _login();
                },
                validator: (v) =>
                    v == null || v.length < 6 ? 'סיסמה לפחות 6 תווים' : null,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => context.go('/forgot-password'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppTheme.teal,
                ),
                child: Text(
                  HebrewStrings.forgotPassword,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.teal,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthErrorBanner(_error!),
            ],
            const SizedBox(height: 18),
            AuthPrimaryButton(
              label: HebrewStrings.loginButton,
              loading: _loading,
              onPressed: _login,
            ),
            if (AppMode.showDemoPresentation) ...[
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      HebrewStrings.demoModeBadge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
              const DemoModeBanner(),
              const SizedBox(height: 14),
              SecondaryButton(
                label: HebrewStrings.demoLoginCustomer,
                icon: Icons.engineering_outlined,
                expand: true,
                onPressed: _loading
                    ? null
                    : () => _demoLogin(UserType.privateCustomer),
              ),
              const SizedBox(height: 4),
              Text(
                HebrewStrings.demoCustomerAccountLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: HebrewStrings.demoLoginSupplier,
                icon: Icons.storefront_outlined,
                expand: true,
                onPressed: _loading
                    ? null
                    : () => _demoLogin(UserType.privateSupplier),
              ),
              const SizedBox(height: 4),
              Text(
                HebrewStrings.demoSupplierAccountLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: TertiaryButton(
                label: HebrewStrings.goToRegister,
                onPressed: () => context.go('/register'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

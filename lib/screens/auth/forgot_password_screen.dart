import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/auth/auth_scaffold.dart';
import '../../widgets/design_system/design_system.dart';

/// Presentation for the password-reset flow. Delegates the actual reset to the
/// standard Firebase pass-through on [AuthService]; auth wiring is unchanged.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .sendPasswordResetEmail(_emailController.text);
      if (mounted) setState(() => _sent = true);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: _sent ? _buildSent(context) : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthBrandmark(),
          const SizedBox(height: 26),
          Text(
            HebrewStrings.forgotPasswordTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            HebrewStrings.forgotPasswordSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 26),
          const AuthFieldLabel(HebrewStrings.email),
          AppTextField(
            controller: _emailController,
            hint: 'you@company.co.il',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.username],
            onFieldSubmitted: (_) {
              if (!_loading) _submit();
            },
            validator: (v) => v == null || v.trim().isEmpty
                ? 'נא להזין אימייל'
                : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AuthErrorBanner(_error!),
          ],
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: HebrewStrings.forgotPasswordSubmit,
            loading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: TertiaryButton(
              label: HebrewStrings.backToLogin,
              icon: Icons.arrow_forward,
              onPressed: () => context.go('/login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSent(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthBrandmark(),
        const SizedBox(height: 26),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 32,
              color: AppTheme.success,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          HebrewStrings.forgotPasswordSentTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          HebrewStrings.forgotPasswordSentBody(_emailController.text.trim()),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: HebrewStrings.backToLogin,
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}

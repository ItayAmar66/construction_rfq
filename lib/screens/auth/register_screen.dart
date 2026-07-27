import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/app_analytics.dart';
import '../../models/user_type.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/auth/auth_scaffold.dart';
import '../../widgets/design_system/design_system.dart';

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
  final _companyController = TextEditingController();
  final _projectController = TextEditingController();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _cityFocus = FocusNode();
  final _companyFocus = FocusNode();
  final _projectFocus = FocusNode();
  final _notesFocus = FocusNode();
  bool _isSupplierAccount = false;
  bool _obscure = true;
  UserType _userType = UserType.commercialCustomer;
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
    _companyController.dispose();
    _projectController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _cityFocus.dispose();
    _companyFocus.dispose();
    _projectFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _setAccountKind({required bool supplier}) {
    setState(() {
      _isSupplierAccount = supplier;
      _userType =
          supplier ? UserType.commercialSupplier : UserType.commercialCustomer;
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final analytics = ref.read(appAnalyticsProvider);
    analytics.track(
      AppAnalyticsEvents.registrationStarted,
      {'user_type': _userType.value},
    );
    try {
      await ref.read(authServiceProvider).register(
            fullName: _nameController.text,
            phone: _phoneController.text,
            email: _emailController.text,
            password: _passwordController.text,
            userType: _userType,
            city: _cityController.text,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            requestedCompanyName: _companyController.text,
            requestedProjectName: _projectController.text.isEmpty
                ? null
                : _projectController.text,
          );
      analytics.track(
        AppAnalyticsEvents.registrationCompleted,
        {'user_type': _userType.value},
      );
      if (!mounted) return;
      ref.invalidate(authSessionProvider);
      if (!mounted) return;
      context.go(
        '/verify-email?redirect=${Uri.encodeComponent('/pending-approval')}',
      );
    } on Exception catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtypeOptions =
        _isSupplierAccount ? UserType.supplierTypes : UserType.customerTypes;

    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const AuthBrandmark(size: 40),
                const Spacer(),
                IconButton(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.close),
                  color: AppTheme.textSecondary,
                  tooltip: HebrewStrings.back,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              HebrewStrings.registerTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'קבלנים מנהלים בקשות חומרים לפי פרויקט. ספקים מקבלים בקשות ומגישים הצעות מחיר.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            const AuthFieldLabel('סוג חשבון'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.engineering_outlined, size: 18),
                  label: Text('קבלן'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.local_shipping_outlined, size: 18),
                  label: Text('ספק'),
                ),
              ],
              selected: {_isSupplierAccount},
              onSelectionChanged: (selection) {
                _setAccountKind(supplier: selection.first);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _isSupplierAccount
                  ? 'ספק — קבלת בקשות והגשת הצעות מחיר'
                  : 'קבלן — ניהול פרויקטים ובקשות חומרים',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            const AuthFieldLabel('גודל / סוג פעילות'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final type in subtypeOptions)
                  ChoiceChip(
                    label: Text(type.subtypeLabel),
                    selected: _userType == type,
                    onSelected: (_) => setState(() => _userType = type),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            AuthFieldLabel(_userType.fullNameFieldLabel),
            Semantics(
              label: _userType.fullNameFieldLabel,
              child: AppTextField(
                controller: _nameController,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_phoneFocus),
                validator: (v) => v == null || v.isEmpty ? 'נא להזין שם' : null,
              ),
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel(HebrewStrings.phone),
            Semantics(
              label: HebrewStrings.phone,
              child: AppTextField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_emailFocus),
                validator: (v) =>
                    v == null || v.isEmpty ? 'נא להזין טלפון' : null,
              ),
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel(HebrewStrings.email),
            Semantics(
              label: HebrewStrings.email,
              child: AppTextField(
                controller: _emailController,
                focusNode: _emailFocus,
                hint: 'you@company.co.il',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_passwordFocus),
                validator: (v) =>
                    v == null || v.isEmpty ? 'נא להזין אימייל' : null,
              ),
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel(HebrewStrings.password),
            Semantics(
              label: HebrewStrings.password,
              child: AppTextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                hint: 'לפחות 6 תווים',
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
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_cityFocus),
                validator: (v) =>
                    v == null || v.length < 6 ? 'סיסמה לפחות 6 תווים' : null,
              ),
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel(HebrewStrings.city),
            Semantics(
              label: HebrewStrings.city,
              child: AppTextField(
                controller: _cityController,
                focusNode: _cityFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_companyFocus),
                validator: (v) =>
                    v == null || v.isEmpty ? 'נא להזין עיר / אזור' : null,
              ),
            ),
            const SizedBox(height: 14),
            AuthFieldLabel(
                _isSupplierAccount ? 'שם חברת הספק' : 'שם חברת הקבלן'),
            Semantics(
              label: _isSupplierAccount ? 'שם חברת הספק' : 'שם חברת הקבלן',
              child: AppTextField(
                controller: _companyController,
                focusNode: _companyFocus,
                helperText: 'הגישה תאושר על ידי מנהל החברה',
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(
                  _isSupplierAccount ? _notesFocus : _projectFocus,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'נא להזין שם חברה' : null,
              ),
            ),
            if (!_isSupplierAccount) ...[
              const SizedBox(height: 14),
              const AuthFieldLabel('פרויקט / אתר (אופציונלי)'),
              Semantics(
                label: 'פרויקט / אתר (אופציונלי)',
                child: AppTextField(
                  controller: _projectController,
                  focusNode: _projectFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_notesFocus),
                ),
              ),
            ],
            const SizedBox(height: 14),
            const AuthFieldLabel(HebrewStrings.extraNotes),
            Semantics(
              label: HebrewStrings.extraNotes,
              child: AppTextField(
                controller: _notesController,
                focusNode: _notesFocus,
                textInputAction: TextInputAction.done,
                maxLines: 2,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              AuthErrorBanner(_error!),
            ],
            const SizedBox(height: 22),
            AuthPrimaryButton(
              label: HebrewStrings.registerButton,
              loading: _loading,
              onPressed: _register,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TertiaryButton(
                label: HebrewStrings.goToLogin,
                onPressed: () => context.go('/login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

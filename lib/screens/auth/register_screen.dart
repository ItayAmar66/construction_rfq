import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_type.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/auth/auth_scaffold.dart';

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
            requestedProjectName:
                _projectController.text.isEmpty ? null : _projectController.text,
          );
      if (!mounted) return;
      ref.invalidate(authSessionProvider);
      if (!mounted) return;
      context.go('/pending-approval');
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
                  visualDensity: VisualDensity.compact,
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
            TextFormField(
              controller: _nameController,
              validator: (v) => v == null || v.isEmpty ? 'נא להזין שם' : null,
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel(HebrewStrings.phone),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.isEmpty ? 'נא להזין טלפון' : null,
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel(HebrewStrings.email),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(hintText: 'you@company.co.il'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v == null || v.isEmpty ? 'נא להזין אימייל' : null,
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel(HebrewStrings.password),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                hintText: '••••••••',
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
              ),
              obscureText: _obscure,
              validator: (v) =>
                  v == null || v.length < 6 ? 'סיסמה לפחות 6 תווים' : null,
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel(HebrewStrings.city),
            TextFormField(
              controller: _cityController,
              validator: (v) =>
                  v == null || v.isEmpty ? 'נא להזין עיר / אזור' : null,
            ),
            const SizedBox(height: 14),
            AuthFieldLabel(_isSupplierAccount ? 'שם חברת הספק' : 'שם חברת הקבלן'),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(
                helperText: 'הגישה תאושר על ידי מנהל החברה',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'נא להזין שם חברה' : null,
            ),
            if (!_isSupplierAccount) ...[
              const SizedBox(height: 14),
              const AuthFieldLabel('פרויקט / אתר (אופציונלי)'),
              TextFormField(controller: _projectController),
            ],
            const SizedBox(height: 14),
            const AuthFieldLabel(HebrewStrings.extraNotes),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
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
              child: TextButton(
                onPressed: () => context.go('/login'),
                child: const Text(HebrewStrings.goToLogin),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

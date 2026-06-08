import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_type.dart';
import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_back_leading.dart';

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
  bool _isSupplierAccount = false;
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
    super.dispose();
  }

  void _setAccountKind({required bool supplier}) {
    setState(() {
      _isSupplierAccount = supplier;
      _userType = supplier
          ? UserType.commercialSupplier
          : UserType.commercialCustomer;
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
          );
      ref.invalidate(authSessionProvider);
      if (mounted) context.go('/home');
    } on Exception catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtypeOptions =
        _isSupplierAccount ? UserType.supplierTypes : UserType.customerTypes;

    return Scaffold(
      appBar: const SecondaryAppBar(
        title: HebrewStrings.register,
        homeRoute: '/login',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'סוג חשבון',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
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
                      ? 'חשבון ספק — לקבלת בקשות RFQ ושליחת הצעות מחיר'
                      : 'חשבון קבלן — ליצירת בקשות חומרים וקבלת הצעות',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text(
                  'גודל / סוג פעילות',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final type in subtypeOptions)
                      ChoiceChip(
                        label: Text(type.subtypeLabel),
                        selected: _userType == type,
                        onSelected: (_) => setState(() => _userType = type),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: _userType.fullNameFieldLabel,
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'נא להזין שם' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: HebrewStrings.phone),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'נא להזין טלפון' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: HebrewStrings.email),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'נא להזין אימייל' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: HebrewStrings.password),
                  obscureText: true,
                  validator: (v) =>
                      v == null || v.length < 6 ? 'סיסמה לפחות 6 תווים' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: HebrewStrings.city),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'נא להזין עיר / אזור' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: HebrewStrings.extraNotes),
                  maxLines: 2,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
      ),
    );
  }
}

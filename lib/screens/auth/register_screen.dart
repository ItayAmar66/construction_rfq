import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_type.dart';
import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
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
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: HebrewStrings.fullName),
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
                DropdownButtonFormField<UserType>(
                  initialValue: _userType,
                  decoration: const InputDecoration(labelText: HebrewStrings.userType),
                  items: UserType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _userType = v!),
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

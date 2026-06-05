import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/role_permissions.dart';
import '../../utils/supplier_capability_helpers.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/supplier/supplier_capability_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initFields(user) {
    if (_initialized || user == null) return;
    _nameController.text = user.fullName;
    _phoneController.text = user.phone;
    _cityController.text = user.city;
    _notesController.text = user.notes ?? '';
    _initialized = true;
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).updateProfile(
            fullName: _nameController.text,
            phone: _phoneController.text,
            city: _cityController.text,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('הפרופיל עודכן')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(HebrewStrings.errorGeneric)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(authServiceProvider).logout();
    ref.invalidate(authSessionProvider);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.profile),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text(HebrewStrings.errorGeneric)),
        data: (user) {
          _initFields(user);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (user != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(user.email),
                    subtitle: Text(user.userType.label),
                  ),
                  const Divider(),
                  if (RolePermissions.canEditSupplierCapabilities(user)) ...[
                    SupplierCapabilityCard(
                      profile: SupplierCapabilityHelpers.profileFor(user),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: HebrewStrings.fullName),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: HebrewStrings.phone),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: HebrewStrings.city),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: HebrewStrings.extraNotes),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(HebrewStrings.save),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text(HebrewStrings.logout),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

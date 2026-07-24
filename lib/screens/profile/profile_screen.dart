import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/enterprise/permission.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/role_permissions.dart';
import '../../utils/supplier_capability_helpers.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/content_max_width.dart';
import '../../widgets/design_system/design_system.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_section.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/summary_widgets.dart';
import '../../widgets/supplier/supplier_capability_card.dart';

import '../../widgets/status_chip.dart';
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

  /// Presentational preference — local UI state only (not persisted).
  bool _notifications = true;

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
        loading: () => const LoadingView(),
        error: (_, __) => const EmptyState(
          message: HebrewStrings.errorGeneric,
          icon: Icons.error_outline,
        ),
        data: (user) {
          _initFields(user);

          final showAdmin = user != null && ref.watch(showAdminNavProvider);
          final showContractorCompany = user != null &&
              user.userType.isCustomer &&
              ref.watch(effectivePermissionsProvider).any(
                    (p) =>
                        p == Permission.manageUsers ||
                        p == Permission.manageProjects ||
                        p == Permission.inviteMembers,
                  );
          final showSupplierCompany = user != null &&
              user.userType.isSupplier &&
              ref
                  .watch(effectivePermissionsProvider)
                  .contains(Permission.manageUsers);
          final hasManagement =
              showAdmin || showContractorCompany || showSupplierCompany;

          return ContentMaxWidth(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (user != null) ...[
                    _ProfileHeader(
                      name: user.fullName.isNotEmpty ? user.fullName : user.email,
                      email: user.email,
                      typeLabel: user.userType.label,
                      isSupplier: user.userType.isSupplier,
                      verified: user.verified,
                      showAdminBadge: showAdmin,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  FormSection(
                    title: 'פרטים אישיים',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          controller: _nameController,
                          label: HebrewStrings.fullName,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(
                          controller: _phoneController,
                          label: HebrewStrings.phone,
                          prefixIcon: const Icon(Icons.phone_outlined),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(
                          controller: _cityController,
                          label: HebrewStrings.city,
                          prefixIcon: const Icon(Icons.location_city_outlined),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(
                          controller: _notesController,
                          label: HebrewStrings.extraNotes,
                          prefixIcon: const Icon(Icons.notes_outlined),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FormSection(
                    title: 'העדפות',
                    child: SectionCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _notifications,
                            onChanged: (v) =>
                                setState(() => _notifications = v),
                            secondary: const Icon(Icons.notifications_outlined),
                            title: const Text('התראות'),
                            subtitle:
                                const Text('עדכונים על הצעות, הזמנות ומשלוחים'),
                          ),
                          const Divider(height: 1),
                          const ListTile(
                            leading: Icon(Icons.language_outlined),
                            title: Text('שפה'),
                            subtitle: Text('עברית · ימין לשמאל'),
                            trailing: Text('עברית'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (user != null &&
                      RolePermissions.canEditSupplierCapabilities(user)) ...[
                    const SizedBox(height: AppSpacing.lg),
                    FormSection(
                      title: 'הגדרות ספק',
                      child: SupplierCapabilityCard(
                        profile: SupplierCapabilityHelpers.profileFor(user),
                      ),
                    ),
                  ],
                  if (hasManagement) ...[
                    const SizedBox(height: AppSpacing.lg),
                    FormSection(
                      title: 'הארגון וניהול',
                      child: SectionCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            if (showAdmin)
                              _NavRow(
                                icon: Icons.admin_panel_settings_outlined,
                                label: HebrewStrings.adminConsoleTitle,
                                onTap: () => context.push('/admin'),
                              ),
                            if (showContractorCompany)
                              _NavRow(
                                icon: Icons.apartment_outlined,
                                label: HebrewStrings.contractorCompanyTitle,
                                onTap: () => context.push('/company'),
                              ),
                            if (showSupplierCompany)
                              _NavRow(
                                icon: Icons.storefront_outlined,
                                label: HebrewStrings.supplierCompanyTitle,
                                onTap: () => context.push('/supplier-company'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FormSection(
                    title: 'אודות ומשפטי',
                    child: SectionCard(
                      padding: EdgeInsets.zero,
                      child: _NavRow(
                        icon: Icons.info_outline,
                        label: 'אודות, פרטיות ותנאי שימוש',
                        onTap: () => context.push('/about'),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: HebrewStrings.save,
                    onPressed: _loading ? null : _save,
                    isLoading: _loading,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton.danger(
                    icon: Icons.logout,
                    label: HebrewStrings.logout,
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.typeLabel,
    required this.isSupplier,
    required this.verified,
    required this.showAdminBadge,
  });

  final String name;
  final String email;
  final String typeLabel;
  final bool isSupplier;
  final bool verified;
  final bool showAdminBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isSupplier ? AppTheme.amberDark : AppTheme.teal;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EntityAvatar(name: name, color: accent, size: 60),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Pill(label: typeLabel, color: accent),
                    if (verified)
                      const _Pill(
                        label: 'מאומת',
                        color: AppTheme.emerald,
                        icon: Icons.verified_outlined,
                      ),
                    if (showAdminBadge) StatusChip.platformAdmin(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.navy),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
      onTap: onTap,
    );
  }
}

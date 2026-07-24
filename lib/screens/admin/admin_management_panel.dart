import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/membership.dart';
import '../../models/enterprise/organization.dart';
import '../../models/enterprise/organization_type.dart';
import '../../providers/admin_management_providers.dart';
import '../../providers/admin_providers.dart';
import '../../providers/providers.dart';
import '../../services/admin_management_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import '../../widgets/design_system/design_system.dart';
import '../../widgets/loading_view.dart';
import 'admin_company_detail_screen.dart';

class AdminManagementActionsBar extends ConsumerWidget {
  const AdminManagementActionsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        PrimaryButton.icon(
          icon: Icons.business_outlined,
          label: 'הוסף קבלן',
          expand: false,
          onPressed: () => _openCreateOrgDialog(
            context,
            ref,
            OrganizationType.contractor,
          ),
        ),
        PrimaryButton.icon(
          icon: Icons.storefront_outlined,
          label: 'הוסף ספק',
          expand: false,
          onPressed: () => _openCreateOrgDialog(
            context,
            ref,
            OrganizationType.supplier,
          ),
        ),
        SecondaryButton(
          label: 'הוסף משתמש',
          icon: Icons.person_add_outlined,
          onPressed: () => _openCreateUserDialog(context, ref),
        ),
        SecondaryButton(
          label: 'הוסף פרויקט',
          icon: Icons.add_location_alt_outlined,
          onPressed: () => _openCreateProjectDialog(context, ref),
        ),
        TertiaryButton(
          label: 'ניהול משתמשים',
          onPressed: () => _openMembershipDialog(context, ref),
        ),
        TertiaryButton(
          label: 'ניהול חברות',
          onPressed: () => _openCompaniesSheet(context, ref),
        ),
        TertiaryButton(
          label: 'ניהול ספקים',
          onPressed: () => _openSuppliersSheet(context, ref),
        ),
        TertiaryButton(
          label: 'מבנה בדיקה מלא',
          icon: Icons.auto_fix_high_outlined,
          onPressed: () => _showSeedCommand(context, ref),
        ),
      ],
    );
  }

  Future<void> _openCreateOrgDialog(
    BuildContext context,
    WidgetRef ref,
    OrganizationType type,
  ) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(type == OrganizationType.contractor ? 'הוסף קבלן' : 'הוסף ספק'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: nameCtrl,
                  label: 'שם חברה *',
                  textInputAction: TextInputAction.next,
                ),
                AppTextField(
                  controller: phoneCtrl,
                  label: 'טלפון',
                  keyboardType: TextInputType.phone,
                ),
                AppTextField(
                  controller: emailCtrl,
                  label: 'אימייל',
                  keyboardType: TextInputType.emailAddress,
                ),
                AppTextField(
                  controller: addressCtrl,
                  label: 'כתובת',
                ),
              ],
            ),
          ),
          actions: [
            TertiaryButton(label: 'ביטול', onPressed: () => Navigator.pop(ctx, false)),
            PrimaryButton(
              label: 'שמור',
              expand: false,
              isLoading: saving,
              onPressed: saving
                  ? null
                  : () async {
                      setState(() => saving = true);
                      try {
                        final service = ref.read(adminManagementServiceProvider);
                        if (type == OrganizationType.contractor) {
                          await service.createContractorCompany(
                            name: nameCtrl.text,
                            phone: phoneCtrl.text,
                            email: emailCtrl.text,
                            address: addressCtrl.text,
                          );
                        } else {
                          await service.createSupplierCompany(
                            name: nameCtrl.text,
                            phone: phoneCtrl.text,
                            email: emailCtrl.text,
                            address: addressCtrl.text,
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();

    if (saved == true) {
      ref.invalidate(adminOrganizationsProvider);
      ref.invalidate(adminOverviewCountsProvider);
      ref.invalidate(adminSuppliersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${type == OrganizationType.contractor ? 'קבלן' : 'ספק'} נוצר בהצלחה')),
        );
      }
    }
  }

  Future<void> _openCreateUserDialog(BuildContext context, WidgetRef ref) async {
    final orgs = await ref.read(adminOrganizationsProvider.future);
    if (!context.mounted) return;
    if (orgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש ליצור חברה לפני הוספת משתמש')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: '123123');
    final phoneCtrl = TextEditingController();
    Organization selectedOrg = orgs.first;
    EnterpriseRole selectedRole =
        AdminManagementService.rolesForOrgType(selectedOrg.type).first;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('הוסף משתמש'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'יצירת Auth דורשת הרצת סקריפט מנהל (Firebase Admin SDK). '
                  'מלא פרטים וקבל פקודה להרצה בטרמינל.',
                  style: TextStyle(fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: nameCtrl,
                  label: 'שם מלא *',
                ),
                AppTextField(
                  controller: emailCtrl,
                  label: 'אימייל *',
                  keyboardType: TextInputType.emailAddress,
                ),
                AppTextField(
                  controller: passwordCtrl,
                  label: 'סיסמה *',
                  helperText: '123123 — אם נדחה, השתמש ב-Qa123456!',
                ),
                AppTextField(
                  controller: phoneCtrl,
                  label: 'טלפון',
                ),
                DropdownButtonFormField<Organization>(
                  value: selectedOrg,
                  decoration: const InputDecoration(labelText: 'חברה *'),
                  items: orgs
                      .map(
                        (o) => DropdownMenuItem(
                          value: o,
                          child: Text('${o.name} (${o.type.value})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      selectedOrg = v;
                      selectedRole =
                          AdminManagementService.rolesForOrgType(v.type).first;
                    });
                  },
                ),
                DropdownButtonFormField<EnterpriseRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'תפקיד *'),
                  items: AdminManagementService.rolesForOrgType(selectedOrg.type)
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(EnterpriseRoleLabels.hebrew(r)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => selectedRole = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TertiaryButton(label: 'ביטול', onPressed: () => Navigator.pop(ctx)),
            PrimaryButton(
              label: 'הצג פקודה',
              expand: false,
              onPressed: () {
                final service = ref.read(adminManagementServiceProvider);
                final cmd = service.buildCreateUserCommand(
                  email: emailCtrl.text,
                  password: passwordCtrl.text,
                  fullName: nameCtrl.text,
                  orgId: selectedOrg.id,
                  role: selectedRole,
                  orgType: selectedOrg.type,
                  phone: phoneCtrl.text,
                );
                Navigator.pop(ctx);
                _showCommandDialog(
                  context,
                  title: 'הרץ בטרמינל ליצירת משתמש',
                  command: cmd.command,
                  hint:
                      'אחרי ההרצה: רענן את הדף. אם סיסמה חלשה — הרץ שוב עם Qa123456!',
                );
              },
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    phoneCtrl.dispose();
  }

  Future<void> _openCreateProjectDialog(BuildContext context, WidgetRef ref) async {
    final contractors = await ref.read(adminContractorOrganizationsProvider.future);
    if (!context.mounted) return;
    if (contractors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש ליצור קבלן לפני הוספת פרויקט')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final ownerCtrl = TextEditingController();
    Organization selectedOrg = contractors.first;
    ownerCtrl.text = selectedOrg.ownerUid;
    final assigneeCtrls = <EnterpriseRole, TextEditingController>{
      for (final role in const [
        EnterpriseRole.procurementManager,
        EnterpriseRole.engineer,
        EnterpriseRole.projectManager,
      ])
        role: TextEditingController(),
    };
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('הוסף פרויקט'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: nameCtrl,
                  label: 'שם פרויקט *',
                ),
                AppTextField(
                  controller: locationCtrl,
                  label: 'מיקום / אתר',
                ),
                DropdownButtonFormField<Organization>(
                  value: selectedOrg,
                  decoration: const InputDecoration(labelText: 'קבלן *'),
                  items: contractors
                      .map((o) => DropdownMenuItem(value: o, child: Text(o.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      selectedOrg = v;
                      ownerCtrl.text = v.ownerUid;
                    });
                  },
                ),
                AppTextField(
                  controller: ownerCtrl,
                  label: 'UID בעלים (אופציונלי)',
                  helperText: 'אם ריק — placeholder עד יצירת משתמש',
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('שיוך משתמשים (UID)', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                for (final entry in assigneeCtrls.entries)
                  AppTextField(
                    controller: entry.value,
                    label: EnterpriseRoleLabels.hebrew(entry.key),
                  ),
              ],
            ),
          ),
          actions: [
            TertiaryButton(label: 'ביטול', onPressed: () => Navigator.pop(ctx, false)),
            PrimaryButton(
              label: 'שמור',
              expand: false,
              isLoading: saving,
              onPressed: saving
                  ? null
                  : () async {
                      setState(() => saving = true);
                      try {
                        final session = ref.read(authSessionProvider).valueOrNull;
                        final actorUid = session?.uid ?? 'admin';
                        final assignees = <EnterpriseRole, String>{
                          for (final e in assigneeCtrls.entries)
                            if (e.value.text.trim().isNotEmpty)
                              e.key: e.value.text.trim(),
                        };
                        await ref.read(adminManagementServiceProvider).createProject(
                              name: nameCtrl.text,
                              orgId: selectedOrg.id,
                              ownerUid: ownerCtrl.text.trim().isNotEmpty
                                  ? ownerCtrl.text.trim()
                                  : 'pending-owner-${selectedOrg.id}',
                              actorUid: actorUid,
                              location: locationCtrl.text,
                              companyName: selectedOrg.name,
                              assignees: assignees,
                            );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    locationCtrl.dispose();
    ownerCtrl.dispose();
    for (final c in assigneeCtrls.values) {
      c.dispose();
    }

    if (saved == true) {
      ref.invalidate(adminRecentProjectsProvider);
      ref.invalidate(adminOverviewCountsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('פרויקט נוצר')),
        );
      }
    }
  }

  Future<void> _openMembershipDialog(BuildContext context, WidgetRef ref) async {
    final orgs = await ref.read(adminOrganizationsProvider.future);
    if (!context.mounted || orgs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('אין חברות לניהול')),
        );
      }
      return;
    }

    Organization selectedOrg = orgs.first;
    var memberships = <Membership>[];
    var loading = true;
    var loadedOrgId = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> load(String orgId) async {
            if (loadedOrgId == orgId && !loading) return;
            loadedOrgId = orgId;
            setState(() => loading = true);
            memberships = await ref
                .read(adminManagementServiceProvider)
                .fetchMembershipsForOrg(orgId);
            if (ctx.mounted) setState(() => loading = false);
          }

          if (loadedOrgId != selectedOrg.id) {
            load(selectedOrg.id);
          }

          return AlertDialog(
            title: const Text('ניהול משתמשים / חברות'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Organization>(
                    value: selectedOrg,
                    decoration: const InputDecoration(labelText: 'חברה'),
                    items: orgs
                        .map((o) => DropdownMenuItem(value: o, child: Text(o.name)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => selectedOrg = v);
                      load(v.id);
                    },
                  ),
                  const SizedBox(height: 8),
                  if (loading)
                    const LinearProgressIndicator()
                  else if (memberships.isEmpty)
                    const Text('אין חברויות — צור משתמש דרך "הוסף משתמש"')
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: memberships.length,
                        itemBuilder: (_, i) {
                          final m = memberships[i];
                          final role = m.roles.firstOrNull;
                          return ListTile(
                            dense: true,
                            title: Text(m.displayLabel),
                            subtitle: Text(
                              '${role != null ? EnterpriseRoleLabels.hebrew(role) : 'ללא תפקיד'} · ${m.status}',
                            ),
                            trailing: m.status == 'active'
                                ? IconButton(
                                    icon: const Icon(Icons.block_outlined),
                                    tooltip: 'השבת',
                                    onPressed: () async {
                                      final session =
                                          ref.read(authSessionProvider).valueOrNull;
                                      await ref
                                          .read(adminManagementServiceProvider)
                                          .disableMembership(
                                            orgId: selectedOrg.id,
                                            uid: m.uid,
                                            actorUid: session?.uid ?? 'admin',
                                          );
                                      await load(selectedOrg.id);
                                    },
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TertiaryButton(label: 'סגור', onPressed: () => Navigator.pop(ctx)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCompaniesSheet(BuildContext context, WidgetRef ref) async {
    final orgsAsync = ref.read(adminOrganizationsProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => orgsAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const Center(child: Text('שגיאה בטעינה')),
        data: (orgs) {
          if (orgs.isEmpty) return const AdminCompaniesEmptyState();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('חברות (${orgs.length})',
                  style: Theme.of(ctx).textTheme.titleMedium),
              for (final org in orgs)
                ListTile(
                  title: Text(org.name),
                  subtitle: Text('${org.type.value} · ${org.status}'),
                  trailing: const Icon(Icons.chevron_left),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openSuppliersSheet(BuildContext context, WidgetRef ref) async {
    final suppliersAsync = ref.read(adminSupplierOrganizationsProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => suppliersAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const Center(child: Text('שגיאה בטעינה')),
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: AdminCompaniesEmptyState(),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('ספקים (${suppliers.length})',
                  style: Theme.of(ctx).textTheme.titleMedium),
              for (final org in suppliers)
                ListTile(
                  title: Text(org.name),
                  subtitle: Text(org.status),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showSeedCommand(BuildContext context, WidgetRef ref) {
    final command = ref.read(adminManagementServiceProvider).seedLaunchTestCommand;
    _showCommandDialog(
      context,
      title: 'יצירת מבנה בדיקה מלא',
      command: command,
      hint: 'מריץ מ־tools/admin עם Firebase Admin SDK. לא מוחק קטalog.',
    );
  }

  void _showCommandDialog(
    BuildContext context, {
    required String title,
    required String command,
    required String hint,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SelectableText(command),
        actions: [
          TertiaryButton(label: 'סגור', onPressed: () => Navigator.pop(ctx)),
          PrimaryButton(
            label: 'העתק פקודה',
            expand: false,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: command));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(hint)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminCompaniesPanel extends ConsumerWidget {
  const AdminCompaniesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(adminOrganizationsProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.business_outlined, color: AppTheme.navy),
                const SizedBox(width: 8),
                Text('חברות', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            orgsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('שגיאה בטעינת חברות'),
              data: (orgs) {
                if (orgs.isEmpty) return const AdminCompaniesEmptyState();
                return Column(
                  children: [
                    for (final org in orgs)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                org.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${org.type == OrganizationType.contractor ? 'קבלן' : 'ספק'} · ${org.status}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  PrimaryButton(
                                    label: 'פתח',
                                    expand: false,
                                    onPressed: () => context.push(
                                      '/admin/company/${org.id}',
                                    ),
                                  ),
                                  PrimaryButton(
                                    label: 'צוות והרשאות',
                                    expand: false,
                                    onPressed: () => context.push(
                                      '/admin/company/${org.id}?tab=team',
                                    ),
                                  ),
                                  SecondaryButton(
                                    label: 'ערוך חברה',
                                    onPressed: () =>
                                        AdminCompanyDetailScreen.openEditDialog(
                                      context,
                                      ref,
                                      org: org,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AdminCompaniesEmptyState extends StatelessWidget {
  const AdminCompaniesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'אין עדיין חברות. הוסף קבלן או ספק כדי להתחיל.',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}

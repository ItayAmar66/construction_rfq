import 'package:flutter/material.dart';

import '../../models/user_type.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';

/// Premium segmented role picker for registration.
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final UserType value;
  final ValueChanged<UserType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'סוג משתמש',
          style: AppTypography.caption(context).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'בחרו את תפקידכם במערכת',
          style: AppTypography.micro(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        _RoleGroup(
          title: 'לקוח',
          subtitle: 'מבקש הצעות מחיר מספקים',
          options: const [
            UserType.privateCustomer,
            UserType.commercialCustomer,
          ],
          value: value,
          onChanged: onChanged,
          accent: AppTheme.teal,
          icon: Icons.person_outline,
        ),
        const SizedBox(height: AppSpacing.sm),
        _RoleGroup(
          title: 'ספק',
          subtitle: 'מגיש הצעות לבקשות נכנסות',
          options: const [
            UserType.privateSupplier,
            UserType.commercialSupplier,
          ],
          value: value,
          onChanged: onChanged,
          accent: AppTheme.navy,
          icon: Icons.storefront_outlined,
        ),
      ],
    );
  }
}

class _RoleGroup extends StatelessWidget {
  const _RoleGroup({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final List<UserType> options;
  final UserType value;
  final ValueChanged<UserType> onChanged;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(title, style: AppTypography.h2(context)),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTypography.micro(context)),
          const SizedBox(height: AppSpacing.sm),
          ...options.map(
            (type) {
              final selected = value == type;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: selected
                      ? accent.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: InkWell(
                    onTap: () => onChanged(type),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: selected ? accent : AppTheme.borderColor,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 20,
                            color: selected ? accent : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              type.label,
                              style: AppTypography.body(context).copyWith(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../summary_widgets.dart';
import 'enterprise_role_badge.dart';

/// Header card for the organization/company management screens.
///
/// Presentation only — shows an org avatar, title/subtitle and the viewer's
/// enterprise role badge.
class OrgHeaderCard extends StatelessWidget {
  const OrgHeaderCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.apartment_outlined,
    this.accent = AppTheme.navy,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EntityAvatar(name: '', icon: icon, color: accent, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: EnterpriseRoleBadge(),
          ),
        ],
      ),
    );
  }
}

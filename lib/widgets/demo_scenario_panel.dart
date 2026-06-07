import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_mode.dart';
import '../data/enterprise_demo_scenario.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/hebrew_strings.dart';

/// Quick links to pre-seeded enterprise demo scenarios.
class DemoScenarioPanel extends StatelessWidget {
  const DemoScenarioPanel({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppMode.showDemoPresentation) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          HebrewStrings.demoScenarioSection,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          HebrewStrings.demoScenarioSectionHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ScenarioTile(
          title: HebrewStrings.demoScenarioCompareTitle,
          hint: HebrewStrings.demoScenarioCompareHint,
          icon: Icons.compare_arrows,
          color: AppTheme.teal,
          onTap: () => context.push(
            '/compare-quotes/${EnterpriseDemoScenario.compareRequestId}',
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _ScenarioTile(
          title: HebrewStrings.demoScenarioFulfilledTitle,
          hint: HebrewStrings.demoScenarioFulfilledHint,
          icon: Icons.local_shipping_outlined,
          color: AppTheme.emerald,
          onTap: () => context.push('/active-orders'),
        ),
      ],
    );
  }
}

class _ScenarioTile extends StatelessWidget {
  const _ScenarioTile({
    required this.title,
    required this.hint,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String hint;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      hint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

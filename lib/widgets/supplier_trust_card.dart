import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/supplier_public_stats.dart';
import '../providers/supplier_public_profile_provider.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';

/// Compact supplier trust strip for quote flows.
class SupplierTrustCard extends ConsumerWidget {
  const SupplierTrustCard({
    super.key,
    required this.supplierId,
    this.supplierName,
    this.compact = false,
  });

  final String supplierId;
  final String? supplierName;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(supplierPublicProfileProvider(supplierId));

    return profileAsync.when(
      loading: () => _Shell(
        compact: compact,
        child: _Header(
          name: supplierName ?? 'ספק',
          verified: false,
          compact: compact,
        ),
      ),
      error: (_, __) => _Shell(
        compact: compact,
        child: _Header(
          name: supplierName ?? 'ספק',
          verified: false,
          compact: compact,
        ),
      ),
      data: (user) => _Shell(
        compact: compact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              name: user?.fullName ?? supplierName ?? 'ספק',
              verified: user?.verified ?? false,
              compact: compact,
            ),
            if (!compact) ...[
              const SizedBox(height: AppSpacing.xs),
              _StatsRow(stats: user?.stats, city: user?.city),
              if (user != null && user.serviceAreas.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'אזורי שירות: ${user.serviceAreas.take(3).join(' · ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, required this.compact});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.xs : AppSpacing.sm),
      decoration: AppTheme.cardDecoration(elevation: 1).copyWith(
        color: AppTheme.surfaceTint.withValues(alpha: 0.35),
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.verified,
    required this.compact,
  });

  final String name;
  final bool verified;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: compact ? 14 : 16,
          backgroundColor: AppTheme.teal.withValues(alpha: 0.12),
          child: Icon(
            Icons.business_outlined,
            size: compact ? 14 : 16,
            color: AppTheme.teal,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 13 : 14,
                ),
          ),
        ),
        if (verified) const _VerifiedBadge(),
      ],
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 12, color: AppTheme.emerald),
          SizedBox(width: 3),
          Text(
            'מאומת',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.emerald,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, this.city});

  final SupplierPublicStats? stats;
  final String? city;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final deals = s?.completedDeals ?? 0;
    final hours = s?.avgResponseHours ?? 24;
    final win = s?.winRatePercent ?? 0;

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: [
        _StatChip(label: '$deals עסקאות'),
        _StatChip(label: 'מענה ~$hours ש׳'),
        if (win > 0) _StatChip(label: '$win% זכייה'),
        if (city != null && city!.isNotEmpty) _StatChip(label: city!),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppTheme.textSecondary,
          height: 1.1,
        ),
      ),
    );
  }
}

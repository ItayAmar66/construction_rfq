import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/supplier_quote_status.dart';

/// Compact supplier sales pipeline on dashboard.
class SupplierPipelinePanel extends ConsumerWidget {
  const SupplierPipelinePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingRequestsProvider).valueOrNull ?? [];
    final sent = ref.watch(supplierSentQuotesProvider).valueOrNull ?? [];

    final newRequests =
        incoming.where((r) => r.isUnseenBySupplier(_supplierId(ref))).length;
    final awaiting = sent
        .where((q) => q.status == SupplierQuoteStatus.sent && !q.isOutdated)
        .length;
    final outdated = sent.where((q) => q.isOutdated).length;
    final won = sent.where((q) => q.status == SupplierQuoteStatus.approved).length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'צינור מכירות',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/sent-quotes'),
                child: const Text('הצעות שנשלחו'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _StageChip(
                  label: 'חדשות',
                  count: newRequests,
                  color: AppTheme.teal,
                  onTap: () => context.push('/incoming-requests'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StageChip(
                  label: 'ממתין',
                  count: awaiting,
                  color: AppTheme.navy,
                  onTap: () => context.push('/sent-quotes'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StageChip(
                  label: 'מיושנות',
                  count: outdated,
                  color: AppTheme.amber,
                  onTap: () => context.push('/sent-quotes'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StageChip(
                  label: 'זכיות',
                  count: won,
                  color: AppTheme.emerald,
                  onTap: () => context.push('/sent-quotes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _supplierId(WidgetRef ref) =>
      ref.watch(authSessionProvider).valueOrNull?.profile?.id ?? '';
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

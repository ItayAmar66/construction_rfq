import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';

/// Prominent live countdown for active tenders.
class TenderCountdownBanner extends StatefulWidget {
  const TenderCountdownBanner({
    super.key,
    required this.endTime,
    required this.active,
  });

  final DateTime? endTime;
  final bool active;

  @override
  State<TenderCountdownBanner> createState() => _TenderCountdownBannerState();
}

class _TenderCountdownBannerState extends State<TenderCountdownBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format() {
    final end = widget.endTime;
    if (end == null) return '--:--:--';
    final remaining = end.difference(DateTime.now());
    if (remaining.isNegative) return '00:00:00';
    final h = remaining.inHours.remainder(24).toString().padLeft(2, '0');
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (remaining.inDays > 0) {
      return '${remaining.inDays}י $h:$m:$s';
    }
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final urgent = widget.active &&
        widget.endTime != null &&
        widget.endTime!.difference(DateTime.now()).inHours < 6;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: urgent
              ? [
                  AppTheme.amber.withValues(alpha: 0.25),
                  AppTheme.amber.withValues(alpha: 0.08),
                ]
              : [
                  AppTheme.navy.withValues(alpha: 0.12),
                  AppTheme.teal.withValues(alpha: 0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: urgent
              ? AppTheme.amber.withValues(alpha: 0.5)
              : AppTheme.teal.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.active ? Icons.timer_outlined : Icons.lock_clock_outlined,
            color: urgent ? AppTheme.amber : AppTheme.navy,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.active ? 'זמן שנותר למכרז' : 'המכרז הסתיים',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (widget.active)
                  Text(
                    _format(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: urgent ? AppTheme.amber : AppTheme.navy,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

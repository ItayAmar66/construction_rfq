import 'package:flutter/material.dart';

import '../models/request_type.dart';
import '../utils/app_theme.dart';

/// Amber tender label — replaces purple inline text.
class TenderBadge extends StatelessWidget {
  const TenderBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.35)),
      ),
      child: Text(
        RequestType.tender.label,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.amber,
          height: 1.1,
        ),
      ),
    );
  }
}

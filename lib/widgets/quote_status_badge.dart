import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/supplier_quote_status.dart';

class QuoteStatusBadge extends StatelessWidget {
  const QuoteStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = AppStatusColors.forQuote(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Text(
        SupplierQuoteStatus.label(status),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

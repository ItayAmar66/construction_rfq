import 'package:flutter/material.dart';

import '../utils/supplier_quote_status.dart';

class QuoteStatusBadge extends StatelessWidget {
  const QuoteStatusBadge({super.key, required this.status});

  final String status;

  Color _color() {
    switch (status) {
      case SupplierQuoteStatus.sent:
        return Colors.blue;
      case SupplierQuoteStatus.approved:
        return Colors.green;
      case SupplierQuoteStatus.rejected:
        return Colors.red;
      case SupplierQuoteStatus.shipped:
        return Colors.teal;
      case SupplierQuoteStatus.notSelected:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        SupplierQuoteStatus.label(status),
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

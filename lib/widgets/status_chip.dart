import 'package:flutter/material.dart';

import '../models/quote_status.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final QuoteRequestStatus status;

  Color _color() {
    switch (status) {
      case QuoteRequestStatus.draft:
        return Colors.grey;
      case QuoteRequestStatus.sent:
        return Colors.blue;
      case QuoteRequestStatus.quotesReceived:
        return Colors.green;
      case QuoteRequestStatus.ordered:
        return Colors.deepPurple;
      case QuoteRequestStatus.shipped:
        return Colors.teal;
      case QuoteRequestStatus.closed:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _color().withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

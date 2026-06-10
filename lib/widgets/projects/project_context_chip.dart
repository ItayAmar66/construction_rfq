import 'package:flutter/material.dart';

import '../../models/quote_request.dart';

class ProjectContextChip extends StatelessWidget {
  const ProjectContextChip({
    super.key,
    required this.request,
  });

  final QuoteRequest request;

  @override
  Widget build(BuildContext context) {
    final label = request.projectDisplayLabel;
    if (label == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'פרויקט: $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../utils/hebrew_strings.dart';

/// Badge for exact vs alternative supplier quote lines.
class SupplierQuoteMatchBadge extends StatelessWidget {
  const SupplierQuoteMatchBadge({
    super.key,
    required this.isExactMatch,
    required this.isAlternative,
  });

  final bool isExactMatch;
  final bool isAlternative;

  @override
  Widget build(BuildContext context) {
    if (isExactMatch) {
      return Chip(
        label: Text(
          HebrewStrings.exactMatchBadge,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }
    if (isAlternative) {
      return Chip(
        label: Text(
          HebrewStrings.alternativeMatchBadge,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }
    return const SizedBox.shrink();
  }
}

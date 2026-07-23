import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../status_chip.dart';

/// Badge for exact vs alternative supplier quote lines — delegates to the
/// shared [StatusChip] pill.
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
      return StatusChip(
        label: HebrewStrings.exactMatchBadge,
        foreground: AppTheme.emerald,
        background: AppTheme.greenSurface,
        dense: true,
      );
    }
    if (isAlternative) {
      return StatusChip(
        label: HebrewStrings.alternativeMatchBadge,
        foreground: AppTheme.amberDark,
        background: AppTheme.amberSurface,
        dense: true,
      );
    }
    return const SizedBox.shrink();
  }
}

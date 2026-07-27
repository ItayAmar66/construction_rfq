import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';

/// Tertiary / text-only action button — the DS wrapper for [TextButton].
///
/// Lowest emphasis (no fill, no border). Navy foreground, optional leading
/// icon, and an inline spinner via [isLoading].
class TertiaryButton extends StatelessWidget {
  const TertiaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final Widget child = isLoading
        ? Semantics(
            label: HebrewStrings.loading,
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.navy,
              ),
            ),
          )
        : icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  ),
                ],
              );

    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(foregroundColor: AppTheme.navy),
      child: child,
    );
  }
}

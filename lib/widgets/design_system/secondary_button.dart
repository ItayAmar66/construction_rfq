import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';

/// Secondary / low-emphasis action button.
///
/// Wraps [OutlinedButton] so it inherits `AppTheme.lightTheme()`'s
/// [OutlinedButtonThemeData] (navy foreground, bordered, shape). Use
/// [SecondaryButton.loading] for a disabled spinner state.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  });

  const SecondaryButton.loading({
    super.key,
    this.label = '',
    this.expand = false,
  })  : onPressed = null,
        icon = null,
        isLoading = true;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget child = isLoading
        ? Semantics(
            label: HebrewStrings.loading,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
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
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  ),
                ],
              );

    final button = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

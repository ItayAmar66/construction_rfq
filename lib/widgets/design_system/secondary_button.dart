import 'package:flutter/material.dart';

/// Secondary / low-emphasis action button.
///
/// Wraps [OutlinedButton] so it inherits `AppTheme.lightTheme()`'s
/// [OutlinedButtonThemeData] (navy foreground, bordered, `radiusMd` shape)
/// without redefining any of that styling here.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    final button = OutlinedButton(onPressed: onPressed, child: child);

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

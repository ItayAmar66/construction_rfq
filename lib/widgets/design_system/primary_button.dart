import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// Emphasis variants for [PrimaryButton].
enum PrimaryButtonVariant { solid, danger, tonal }

/// Primary call-to-action button.
///
/// Wraps [ElevatedButton] so it inherits `AppTheme.lightTheme()`'s
/// [ElevatedButtonThemeData] (shape, sizing, Heebo text). Variants only
/// override colour, never re-declare the shape/typography.
///
/// * default — navy solid
/// * [PrimaryButton.danger] — destructive red
/// * [PrimaryButton.tonal] — low-emphasis navy tint
/// * [PrimaryButton.icon] — leading icon + label
/// * [PrimaryButton.loading] — disabled spinner
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = PrimaryButtonVariant.solid;

  const PrimaryButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = PrimaryButtonVariant.danger;

  const PrimaryButton.tonal({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = PrimaryButtonVariant.tonal;

  const PrimaryButton.icon({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.expand = true,
  }) : variant = PrimaryButtonVariant.solid;

  const PrimaryButton.loading({
    super.key,
    this.label = '',
    this.expand = true,
  })  : onPressed = null,
        icon = null,
        isLoading = true,
        variant = PrimaryButtonVariant.solid;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final PrimaryButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final foreground = switch (variant) {
      PrimaryButtonVariant.solid || PrimaryButtonVariant.danger => Colors.white,
      PrimaryButtonVariant.tonal => AppTheme.navy,
    };

    final style = switch (variant) {
      PrimaryButtonVariant.solid => null,
      PrimaryButtonVariant.danger => ElevatedButton.styleFrom(
          backgroundColor: AppTheme.danger,
          foregroundColor: Colors.white,
        ),
      PrimaryButtonVariant.tonal => ElevatedButton.styleFrom(
          backgroundColor: AppTheme.navy.withValues(alpha: 0.10),
          foregroundColor: AppTheme.navy,
          elevation: 0,
        ),
    };

    final Widget child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: foreground,
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

    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: child,
    );

    return expand ? button : IntrinsicWidth(child: button);
  }
}

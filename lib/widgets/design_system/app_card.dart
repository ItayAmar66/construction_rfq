import 'package:flutter/material.dart';

import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';

/// Generic container card — the single surface primitive for the app.
///
/// Applies `AppTheme.cardDecoration()` (radius 16 + soft shadow) so any
/// content sits in a consistent card. Named constructors cover the variants
/// that used to be hand-rolled:
///
/// * default — white card, optional [onTap] (ripple)
/// * [AppCard.gradient] — gradient hero surface
/// * [AppCard.border] — custom border/accent (e.g. a coloured left rail)
/// * [AppCard.clip] — clips children to the corners (for `ExpansionTile` etc.)
/// * [AppCard.interactive] — tap ripple + press-scale animation
/// * [AppCard.compact] — tighter padding for dense rows
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.color,
    this.elevation = 2,
    this.border,
    this.gradient,
    this.clipBehavior = Clip.none,
    this.interactive = false,
  });

  const AppCard.gradient({
    super.key,
    required this.gradient,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.elevation = 2,
    this.clipBehavior = Clip.none,
    this.interactive = false,
  })  : color = null,
        border = null;

  const AppCard.border({
    super.key,
    required this.border,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.color,
    this.elevation = 2,
    this.clipBehavior = Clip.none,
    this.interactive = false,
  }) : gradient = null;

  const AppCard.clip({
    super.key,
    required this.child,
    this.clipBehavior = Clip.antiAlias,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.color,
    this.elevation = 2,
    this.border,
    this.interactive = false,
  }) : gradient = null;

  const AppCard.interactive({
    super.key,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.color,
    this.elevation = 2,
    this.border,
    this.gradient,
    this.clipBehavior = Clip.none,
  }) : interactive = true;

  const AppCard.compact({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.elevation = 2,
    this.border,
    this.clipBehavior = Clip.none,
    this.interactive = false,
  })  : padding = const EdgeInsets.all(AppSpacing.sm),
        gradient = null;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double elevation;
  final BoxBorder? border;
  final List<Color>? gradient;
  final Clip clipBehavior;
  final bool interactive;

  BoxDecoration get _decoration {
    if (gradient != null) {
      return AppTheme.gradientCardDecoration(
        colors: gradient!,
        radius: AppTheme.radiusLg,
      );
    }
    final base = AppTheme.cardDecoration(color: color, elevation: elevation);
    return border != null ? base.copyWith(border: border) : base;
  }

  @override
  Widget build(BuildContext context) {
    final decoration = _decoration;
    final radius = BorderRadius.circular(AppTheme.radiusLg);
    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return Container(
        decoration: decoration,
        clipBehavior: clipBehavior,
        child: content,
      );
    }

    if (interactive) {
      return _InteractiveCard(
        decoration: decoration,
        radius: radius,
        clipBehavior: clipBehavior,
        onTap: onTap!,
        child: content,
      );
    }

    Widget card = Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(onTap: onTap, borderRadius: radius, child: content),
      ),
    );
    if (clipBehavior != Clip.none) {
      card = ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: card,
      );
    }
    return card;
  }
}

/// Tap ripple + press-scale, matching the former hand-rolled `dashboard_tile`
/// / `V2StatCard` interaction.
class _InteractiveCard extends StatefulWidget {
  const _InteractiveCard({
    required this.decoration,
    required this.radius,
    required this.clipBehavior,
    required this.onTap,
    required this.child,
  });

  final BoxDecoration decoration;
  final BorderRadius radius;
  final Clip clipBehavior;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget card = Material(
      color: Colors.transparent,
      child: Ink(
        decoration: widget.decoration,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: widget.radius,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: widget.child,
        ),
      ),
    );
    if (widget.clipBehavior != Clip.none) {
      card = ClipRRect(
        borderRadius: widget.radius,
        clipBehavior: widget.clipBehavior,
        child: card,
      );
    }
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: card,
    );
  }
}

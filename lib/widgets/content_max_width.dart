import 'package:flutter/material.dart';

/// Responsive shell content: full width with padding on desktop/tablet rail.
class ContentMaxWidth extends StatelessWidget {
  const ContentMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.desktopBreakpoint = defaultDesktopBreakpoint,
    this.desktopHorizontalPadding = defaultDesktopHorizontalPadding,
  });

  static const double defaultDesktopBreakpoint = 900;
  static const double defaultDesktopHorizontalPadding = 28;

  final Widget child;
  final double maxWidth;
  final double desktopBreakpoint;
  final double desktopHorizontalPadding;

  bool expandsOnWidth(double width) => width >= desktopBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (expandsOnWidth(constraints.maxWidth)) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: desktopHorizontalPadding),
            child: child,
          );
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}

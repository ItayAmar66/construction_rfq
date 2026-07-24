import 'package:flutter/material.dart';

import '../utils/breakpoints.dart';

/// Responsive shell content: wide operational canvas with desktop padding.
class ContentMaxWidth extends StatelessWidget {
  const ContentMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = defaultDesktopMaxWidth,
    this.desktopBreakpoint = defaultDesktopBreakpoint,
    this.desktopHorizontalPadding = defaultDesktopHorizontalPadding,
  });

  static const double defaultDesktopBreakpoint = kShellDesktopBreakpoint;
  static const double defaultDesktopHorizontalPadding = 28;

  /// Capped operational-canvas width on desktop — content sits in a centred
  /// column of at most this width instead of stretching edge-to-edge.
  static const double defaultDesktopMaxWidth = 1280;

  final Widget child;
  final double maxWidth;
  final double desktopBreakpoint;
  final double desktopHorizontalPadding;

  bool expandsOnWidth(double width) => width >= desktopBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop: cap the operational canvas so content stays a centred column
        // (~[maxWidth]) instead of stretching edge-to-edge, matching the
        // reference's capped layout. Narrow screens fill the available width.
        if (expandsOnWidth(constraints.maxWidth)) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: desktopHorizontalPadding,
                ),
                child: child,
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}

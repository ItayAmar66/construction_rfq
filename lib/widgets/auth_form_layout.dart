import 'package:flutter/material.dart';

/// Centers auth forms on wide screens with a readable max width.
class AuthFormLayout extends StatelessWidget {
  const AuthFormLayout({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  static const double defaultMaxWidth = 480;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth + 48) {
          return child;
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

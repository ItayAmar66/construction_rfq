import 'package:flutter/material.dart';

/// Generic in-place "you can't be here" view for screen-level authorization
/// fallbacks (e.g. a role-restricted route reached via a deep link). Renders
/// in place rather than navigating away, so it composes with any gate widget
/// that already decided access is denied.
class NoAccessView extends StatelessWidget {
  const NoAccessView({
    super.key,
    required this.message,
    this.title,
  });

  final String message;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null ? null : AppBar(title: Text(title!)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

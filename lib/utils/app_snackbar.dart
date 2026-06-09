import 'package:flutter/material.dart';

/// Snackbar that floats above bottom CTAs and is dismissible.
void showAppSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      dismissDirection: DismissDirection.down,
      showCloseIcon: true,
      action: action,
    ),
  );
}

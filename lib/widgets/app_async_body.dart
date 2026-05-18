import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/hebrew_strings.dart';
import 'error_message.dart';
import 'loading_view.dart';

/// Standard async body: loading / error / empty / data.
class AppAsyncBody<T> extends StatelessWidget {
  const AppAsyncBody({
    super.key,
    required this.async,
    required this.builder,
    this.empty,
    this.onRetry,
  });

  final AsyncValue<T> async;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? empty;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorMessage.fromError(e, onRetry: onRetry),
      data: (data) {
        if (data is List && data.isEmpty && empty != null) {
          return empty!;
        }
        return builder(context, data);
      },
    );
  }
}

/// Simple centered error text fallback (lists).
class AppErrorCenter extends StatelessWidget {
  const AppErrorCenter({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorMessage(
      message: HebrewStrings.errorGeneric,
      onRetry: onRetry,
    );
  }
}

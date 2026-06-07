import 'package:flutter/material.dart';

import '../config/app_mode.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';

class ErrorMessage extends StatelessWidget {
  const ErrorMessage({
    super.key,
    required this.message,
    this.hint,
    this.onRetry,
  });

  final String message;
  final String? hint;
  final VoidCallback? onRetry;

  factory ErrorMessage.fromError(Object error, {VoidCallback? onRetry}) {
    return ErrorMessage(
      message: FirebaseErrorHelper.toHebrewMessage(error),
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (hint != null && hint!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('נסה שוב'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

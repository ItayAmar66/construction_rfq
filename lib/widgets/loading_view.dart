import 'package:flutter/material.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/hebrew_strings.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: AppTheme.cardDecoration(elevation: 1),
            child: const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.navy,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message ?? HebrewStrings.loading,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

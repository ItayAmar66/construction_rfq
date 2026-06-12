import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// Sticky context when catalog is opened from a project workspace.
class CatalogProjectBanner extends StatelessWidget {
  const CatalogProjectBanner({
    super.key,
    required this.projectName,
    this.projectLocation,
  });

  final String projectName;
  final String? projectLocation;

  @override
  Widget build(BuildContext context) {
    final location = projectLocation?.trim() ?? '';
    final subtitle = location.isNotEmpty ? ' · $location' : '';

    return Material(
      color: AppTheme.navy.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.apartment_outlined,
              size: 20,
              color: AppTheme.navy.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'הזמנה לפרויקט: $projectName$subtitle',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.navy,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

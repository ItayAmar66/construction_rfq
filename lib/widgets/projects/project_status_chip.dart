import 'package:flutter/material.dart';

import '../../models/enterprise/project.dart';
import '../../utils/app_theme.dart';

class ProjectStatusChip extends StatelessWidget {
  const ProjectStatusChip({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (project.status) {
      _ when project.isDeletionPending => (Colors.orange.shade900, Colors.orange.shade50),
      _ when project.isCompleted => (AppTheme.navy, AppTheme.navy.withValues(alpha: 0.08)),
      _ => (AppTheme.teal, AppTheme.teal.withValues(alpha: 0.12)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        project.statusLabel,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

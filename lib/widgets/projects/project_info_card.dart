import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/enterprise/project.dart';
import '../../utils/app_theme.dart';

import '../status_chip.dart';
/// Compact, reusable panel exposing project metadata — manager, contact, key
/// dates and a schedule-progress bar. Renders nothing when there is no
/// metadata worth showing.
class ProjectInfoCard extends StatelessWidget {
  const ProjectInfoCard({super.key, required this.project});

  final Project project;

  bool get _hasContact =>
      (project.managerName?.trim().isNotEmpty ?? false) ||
      (project.managerPhone?.trim().isNotEmpty ?? false);

  bool get _hasDates =>
      project.startDate != null || project.estimatedCompletionDate != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasContact && !_hasDates) return const SizedBox.shrink();
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'פרטי הפרויקט',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                StatusChip.project(project),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                if (project.managerName?.trim().isNotEmpty ?? false)
                  _MetaItem(
                    icon: Icons.person_outline,
                    label: 'מנהל פרויקט',
                    value: project.managerName!.trim(),
                  ),
                if (project.managerPhone?.trim().isNotEmpty ?? false)
                  _MetaItem(
                    icon: Icons.phone_outlined,
                    label: 'טלפון',
                    value: project.managerPhone!.trim(),
                  ),
                if (project.startDate != null)
                  _MetaItem(
                    icon: Icons.event_outlined,
                    label: 'תאריך התחלה',
                    value: dateFormat.format(project.startDate!),
                  ),
                if (project.estimatedCompletionDate != null)
                  _MetaItem(
                    icon: Icons.flag_outlined,
                    label: 'צפי סיום',
                    value: dateFormat.format(project.estimatedCompletionDate!),
                  ),
              ],
            ),
            if (_scheduleProgress() case final progress?) ...[
              const SizedBox(height: 16),
              _ScheduleBar(
                progress: progress.$1,
                caption: progress.$2,
                overdue: progress.$3,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// (fraction 0..1, caption, overdue) for the schedule bar, or null.
  (double, String, bool)? _scheduleProgress() {
    final start = project.startDate;
    final end = project.estimatedCompletionDate;
    if (start == null || end == null || !end.isAfter(start)) return null;
    if (project.isCompleted) return (1, 'הפרויקט הושלם', false);

    final now = DateTime.now();
    final total = end.difference(start).inDays;
    if (total <= 0) return null;
    final elapsed = now.difference(start).inDays;
    final fraction = (elapsed / total).clamp(0.0, 1.0);
    final daysLeft = end.difference(now).inDays;

    if (daysLeft < 0) {
      return (1, 'חריגה מהצפי ב-${-daysLeft} ימים', true);
    }
    if (daysLeft == 0) {
      return (fraction, 'צפי הסיום היום', false);
    }
    return (fraction, 'נותרו $daysLeft ימים לצפי הסיום', false);
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ScheduleBar extends StatelessWidget {
  const _ScheduleBar({
    required this.progress,
    required this.caption,
    required this.overdue,
  });

  final double progress;
  final String caption;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final color = overdue ? AppTheme.danger : AppTheme.navy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppTheme.borderColor,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              overdue ? Icons.warning_amber_rounded : Icons.schedule,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              caption,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

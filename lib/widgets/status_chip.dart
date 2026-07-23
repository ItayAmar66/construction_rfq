import 'package:flutter/material.dart';

import '../models/enterprise/hierarchy_node.dart';
import '../models/enterprise/project.dart';
import '../models/quote_status.dart';
import '../models/request_type.dart';
import '../theme/app_radius.dart';
import '../utils/app_theme.dart';
import '../utils/count_badge.dart';
import '../utils/supplier_quote_status.dart';

/// The single status / label pill for the whole app.
///
/// Fully-rounded (pill), muted tint background, bold foreground, optional
/// leading icon — matches the Bonim reference. Domain named-constructors keep
/// call sites declarative and absorb the former `QuoteStatusBadge`,
/// `ProjectStatusChip`, `TenderBadge`, `CountBadge`, `PlatformAdminRoleBadge`
/// and `PermissionScopeBadge`.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.foreground,
    this.background,
    this.icon,
    this.dense = false,
    this.bordered = true,
  });

  final String label;
  final Color foreground;
  final Color? background;
  final IconData? icon;
  final bool dense;
  final bool bordered;

  /// Quote-request lifecycle status.
  factory StatusChip.request(QuoteRequestStatus status, {bool dense = false}) {
    final (bg, fg, icon) = AppStatusColors.forRequest(status);
    return StatusChip(
      label: status.label,
      foreground: fg,
      background: bg,
      icon: icon,
      dense: dense,
    );
  }

  /// Supplier-quote status (string-keyed).
  factory StatusChip.quote(String status, {bool dense = false}) {
    final (bg, fg) = AppStatusColors.forQuote(status);
    return StatusChip(
      label: SupplierQuoteStatus.displayLabel(status),
      foreground: fg,
      background: bg,
      dense: dense,
    );
  }

  /// Project lifecycle status.
  factory StatusChip.project(Project project, {bool dense = false}) {
    final (fg, bg) = AppStatusColors.forProject(
      isDeletionPending: project.isDeletionPending,
      isCompleted: project.isCompleted,
    );
    return StatusChip(
      label: project.statusLabel,
      foreground: fg,
      background: bg,
      dense: dense,
      bordered: false,
    );
  }

  /// Amber "tender" request-type label.
  factory StatusChip.tender({bool dense = false}) => StatusChip(
        label: RequestType.tender.label,
        foreground: AppTheme.amber,
        background: AppTheme.amber.withValues(alpha: 0.12),
        dense: dense,
      );

  /// Numeric count pill. Renders nothing when [count] is hidden.
  factory StatusChip.count(
    int count, {
    bool showEmptyLabel = false,
    bool dense = false,
  }) {
    final label = countBadgeLabel(count, showEmptyLabel: showEmptyLabel);
    final isEmpty = count <= 0;
    return StatusChip(
      label: label ?? '',
      foreground: isEmpty ? AppTheme.textSecondary : AppTheme.teal,
      background:
          isEmpty ? AppTheme.surfaceTint : AppTheme.teal.withValues(alpha: 0.15),
      dense: dense,
      bordered: isEmpty,
    );
  }

  /// Platform-admin role pill.
  factory StatusChip.platformAdmin({bool dense = false}) => StatusChip(
        label: 'מנהל מערכת',
        foreground: AppTheme.navy,
        background: AppTheme.navy.withValues(alpha: 0.1),
        icon: Icons.admin_panel_settings_outlined,
        dense: dense,
      );

  /// Permission-scope pill.
  factory StatusChip.scope(RoleScopeType scope, {bool dense = false}) {
    final color = switch (scope) {
      RoleScopeType.platform => AppTheme.navy,
      RoleScopeType.company => AppTheme.teal,
      RoleScopeType.project => AppTheme.emerald,
      RoleScopeType.supplier => AppTheme.amber,
    };
    return StatusChip(
      label: scope.label,
      foreground: color,
      background: color.withValues(alpha: 0.12),
      dense: dense,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty && icon == null) return const SizedBox.shrink();

    final bg = background ?? foreground.withValues(alpha: 0.12);
    final horizontal = dense ? 10.0 : 12.0;
    final vertical = dense ? 4.0 : 6.0;
    final fontSize = dense ? 11.0 : 12.0;
    final iconSize = dense ? 12.0 : 14.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border:
            bordered ? Border.all(color: foreground.withValues(alpha: 0.25)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: foreground),
            const SizedBox(width: 5),
          ],
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: fontSize,
                height: 1.1,
              ),
            ),
        ],
      ),
    );
  }
}

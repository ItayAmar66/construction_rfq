import 'package:flutter/material.dart';

/// Central icon-glyph tokens for cross-cutting, non-domain-specific actions.
///
/// Status-specific icon choices (per [QuoteRequestStatus], etc.) remain in
/// `AppStatusColors` in `app_theme.dart` — this class only covers generic
/// chrome (search, empty states, navigation) shared across the app.
abstract final class AppIcons {
  static const IconData search = Icons.search;
  static const IconData clear = Icons.close;
  static const IconData empty = Icons.inbox_outlined;
  static const IconData loading = Icons.hourglass_top_outlined;
  static const IconData back = Icons.chevron_left;
  static const IconData forward = Icons.chevron_right;
  static const IconData add = Icons.add;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline;
  static const IconData more = Icons.more_horiz;
  static const IconData success = Icons.check_circle_outline;
  static const IconData warning = Icons.report_problem_outlined;
  static const IconData error = Icons.error_outline;
  static const IconData info = Icons.info_outline;
}

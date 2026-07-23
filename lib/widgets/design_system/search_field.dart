import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';

/// Standard search input — RTL-safe, themed via the global
/// `InputDecorationTheme` set in `AppTheme.lightTheme()`.
///
/// Supports [onSubmitted] (immediate search), a [loading] spinner, and extra
/// [trailingActions] rendered alongside the clear button.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.loading = false,
    this.trailingActions,
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final bool loading;
  final List<Widget>? trailingActions;

  @override
  Widget build(BuildContext context) {
    final hasText = controller?.text.isNotEmpty ?? false;

    final suffixChildren = <Widget>[
      if (loading)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      if (hasText && !loading)
        IconButton(
          tooltip: HebrewStrings.clear,
          icon: const Icon(AppIcons.clear),
          onPressed: () {
            controller?.clear();
            onChanged?.call('');
            onClear?.call();
          },
        ),
      ...?trailingActions,
    ];

    return TextField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText ?? HebrewStrings.searchHint,
        prefixIcon: const Icon(AppIcons.search),
        suffixIcon: suffixChildren.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: suffixChildren),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../utils/hebrew_strings.dart';

/// Standard search input — RTL-safe, themed via the global
/// `InputDecorationTheme` set in `AppTheme.lightTheme()`.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final hasText = controller?.text.isNotEmpty ?? false;

    return TextField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText ?? HebrewStrings.searchHint,
        prefixIcon: const Icon(AppIcons.search),
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(AppIcons.clear),
                onPressed: () {
                  controller?.clear();
                  onChanged?.call('');
                  onClear?.call();
                },
              )
            : null,
      ),
    );
  }
}

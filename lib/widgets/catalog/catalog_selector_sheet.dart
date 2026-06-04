import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalog/catalog_rfq_line_draft.dart';
import '../../screens/catalog/catalog_selector_screen.dart';

/// Modal sheet wrapper for [CatalogSelectorScreen].
class CatalogSelectorSheet {
  CatalogSelectorSheet._();

  static Future<CatalogRfqLineDraft?> show(BuildContext context) {
    return showModalBottomSheet<CatalogRfqLineDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return const FractionallySizedBox(
          heightFactor: 0.92,
          child: CatalogSelectorScreen(embeddedInSheet: true),
        );
      },
    );
  }

  /// Convenience for Riverpod callers (e.g. demo screens).
  static Future<CatalogRfqLineDraft?> showWithRef(WidgetRef ref, BuildContext context) {
    return show(context);
  }
}

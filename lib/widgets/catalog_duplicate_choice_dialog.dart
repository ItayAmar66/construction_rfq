import 'package:flutter/material.dart';

import '../utils/hebrew_strings.dart';

enum CatalogDuplicateChoice { mergeQuantity, separateLine }

/// Ask whether to merge quantity or add a separate catalog line.
class CatalogDuplicateChoiceDialog {
  CatalogDuplicateChoiceDialog._();

  static Future<CatalogDuplicateChoice?> show(
    BuildContext context, {
    required String displayName,
  }) {
    return showDialog<CatalogDuplicateChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('פריט כבר בבקשה'),
        content: Text(
          '«$displayName» כבר קיים בטיוטה. להוסיף כמות לשורה הקיימת או כשורה נפרדת?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, CatalogDuplicateChoice.mergeQuantity),
            child: const Text('הוסף כמות'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, CatalogDuplicateChoice.separateLine),
            child: const Text('שורה נפרדת'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(HebrewStrings.cancel),
          ),
        ],
      ),
    );
  }
}

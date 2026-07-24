import 'package:flutter/material.dart';

import '../utils/hebrew_strings.dart';
import 'design_system/primary_button.dart';
import 'design_system/tertiary_button.dart';

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
          TertiaryButton(
            label: HebrewStrings.cancel,
            onPressed: () => Navigator.pop(ctx),
          ),
          TertiaryButton(
            label: 'הוסף כמות',
            onPressed: () =>
                Navigator.pop(ctx, CatalogDuplicateChoice.mergeQuantity),
          ),
          PrimaryButton(
            label: 'שורה נפרדת',
            onPressed: () =>
                Navigator.pop(ctx, CatalogDuplicateChoice.separateLine),
            expand: false,
          ),
        ],
      ),
    );
  }
}

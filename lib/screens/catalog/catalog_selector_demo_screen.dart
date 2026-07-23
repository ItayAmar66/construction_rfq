import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/catalog/catalog_rfq_line_draft.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/catalog/catalog_selector_sheet.dart';
import '../../widgets/design_system/design_system.dart';
import 'catalog_selector_screen.dart';

/// Debug-only demo entry for catalog selector (not linked from RFQ create).
class CatalogSelectorDemoScreen extends StatelessWidget {
  const CatalogSelectorDemoScreen({super.key});

  static bool get isAvailable => kDebugMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(HebrewStrings.catalogSelectorDemo)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'דמו בלבד — לא מחובר ליצירת RFQ חיה.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'פתח מסך בוחר',
              onPressed: () => _openFullScreen(context),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'פתח גיליון בוחר',
              expand: true,
              onPressed: () => _openSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFullScreen(BuildContext context) async {
    final draft = await Navigator.of(context).push<CatalogRfqLineDraft>(
      MaterialPageRoute(builder: (_) => const CatalogSelectorScreen()),
    );
    if (draft != null && context.mounted) {
      _showDraftSnackBar(context, draft);
    }
  }

  Future<void> _openSheet(BuildContext context) async {
    final draft = await CatalogSelectorSheet.show(context);
    if (draft != null && context.mounted) {
      _showDraftSnackBar(context, draft);
    }
  }

  void _showDraftSnackBar(BuildContext context, CatalogRfqLineDraft draft) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('נבחר: ${draft.displayName} (${draft.variantId})')),
    );
  }
}

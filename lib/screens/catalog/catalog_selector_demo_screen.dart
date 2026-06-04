import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/catalog/catalog_rfq_line_draft.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/catalog/catalog_selector_sheet.dart';
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
            FilledButton(
              onPressed: () => _openFullScreen(context),
              child: const Text('פתח מסך בוחר'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _openSheet(context),
              child: const Text('פתח גיליון בוחר'),
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

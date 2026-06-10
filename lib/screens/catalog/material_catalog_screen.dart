import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/rfq_draft_provider.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import 'catalog_selector_screen.dart';

/// Customer-facing real Firestore catalog (categories + search + variants).
class MaterialCatalogScreen extends ConsumerWidget {
  const MaterialCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftCount = ref.watch(rfqDraftProvider).length;

    return CatalogSelectorScreen(
      standaloneMode: true,
      appBar: SecondaryAppBar(
        title: HebrewStrings.catalogMaterialsTitle,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/rfq-draft'),
            icon: const Icon(Icons.request_quote_outlined, size: 20),
            label: Text(
              draftCount > 0
                  ? '${HebrewStrings.rfqDraftTitle} ($draftCount)'
                  : HebrewStrings.rfqDraftTitle,
            ),
          ),
        ],
      ),
      onItemAdded: (draft) async {
        ref.read(rfqDraftProvider.notifier).addCatalogDraft(draft);
        if (!context.mounted) return;
        showAppSnackBar(
          context,
          message: HebrewStrings.productAddedToRfq(draft.displayName),
          action: SnackBarAction(
            label: HebrewStrings.rfqDraftTitle,
            onPressed: () => context.push('/rfq-draft'),
          ),
        );
      },
    );
  }
}

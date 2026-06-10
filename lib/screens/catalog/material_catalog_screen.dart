import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/rfq_draft_provider.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import 'catalog_selector_screen.dart';

/// Customer-facing real Firestore catalog (categories + search + variants).
class MaterialCatalogScreen extends ConsumerWidget {
  const MaterialCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(rfqDraftCountProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return CatalogSelectorScreen(
      standaloneMode: true,
      appBar: SecondaryAppBar(
        title: HebrewStrings.catalogMaterialsTitle,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton.tonalIcon(
              onPressed: () => context.push('/rfq-draft'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.teal.withValues(alpha: 0.14),
                foregroundColor: AppTheme.teal,
                disabledBackgroundColor:
                    colorScheme.surfaceContainerHighest,
                disabledForegroundColor: colorScheme.onSurfaceVariant,
              ),
              icon: const Icon(Icons.shopping_bag_outlined, size: 20),
              label: Text(
                HebrewStrings.catalogCartWithCount(cartCount),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
            label: HebrewStrings.catalogCartLabel,
            onPressed: () => context.push('/rfq-draft'),
          ),
        );
      },
    );
  }
}

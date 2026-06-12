import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/project_providers.dart';
import '../../providers/rfq_draft_provider.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/project_order_helpers.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/projects/catalog_project_banner.dart';
import 'catalog_selector_screen.dart';

/// Customer-facing real Firestore catalog (categories + search + variants).
class MaterialCatalogScreen extends ConsumerWidget {
  const MaterialCatalogScreen({super.key});

  String? _projectId(BuildContext context) {
    final id = GoRouterState.of(context).uri.queryParameters['projectId'];
    if (id == null || id.isEmpty) return null;
    return id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(rfqDraftCountProvider);
    final projectId = _projectId(context);
    final projectAsync =
        projectId != null ? ref.watch(projectProvider(projectId)) : null;
    final backRoute =
        projectId != null ? '/projects/$projectId' : '/home';

    return CatalogSelectorScreen(
      standaloneMode: true,
      topBanner: projectId != null
          ? projectAsync?.when(
                loading: () => const CatalogProjectBanner(
                  projectName: '…',
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (p) => p == null
                    ? const SizedBox.shrink()
                    : CatalogProjectBanner(
                        projectName: p.name,
                        projectLocation: p.locationLine,
                      ),
              ) ??
              const SizedBox.shrink()
          : null,
      appBar: SecondaryAppBar(
        title: HebrewStrings.catalogMaterialsTitle,
        homeRoute: backRoute,
        preferHomeOnBack: projectId != null,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton.icon(
              onPressed: () {
                final route = projectId != null
                    ? ProjectOrderHelpers.rfqDraftRouteForProject(projectId)
                    : '/rfq-draft';
                context.push(route);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.navy,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.55),
                disabledForegroundColor: AppTheme.navy.withValues(alpha: 0.45),
                elevation: 1,
                shadowColor: Colors.black26,
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
        final draftRoute = projectId != null
            ? ProjectOrderHelpers.rfqDraftRouteForProject(projectId)
            : '/rfq-draft';
        showAppSnackBar(
          context,
          message: HebrewStrings.productAddedToRfq(draft.displayName),
          action: SnackBarAction(
            label: HebrewStrings.catalogCartLabel,
            onPressed: () => context.push(draftRoute),
          ),
        );
      },
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/catalog_admin_ops_provider.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/error_message.dart';
import '../../widgets/loading_view.dart';

/// Debug-only read-only catalog ops dashboard.
class CatalogAdminOpsScreen extends ConsumerWidget {
  const CatalogAdminOpsScreen({super.key});

  static bool get isAvailable => kDebugMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isAvailable) {
      return const Scaffold(
        body: Center(child: Text('Admin ops available in debug builds only')),
      );
    }

    final snapshotAsync = ref.watch(catalogOpsSnapshotProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Catalog Ops (read-only)')),
      body: snapshotAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorMessage.fromError(
          e,
          onRetry: () => ref.invalidate(catalogOpsSnapshotProvider),
        ),
        data: (snapshot) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _Section(
                title: 'catalogMeta/current',
                children: [
                  _Row('version', snapshot.version.isEmpty ? '—' : snapshot.version),
                  _Row('products', '${snapshot.productCount}'),
                  _Row('variants', '${snapshot.variantCount}'),
                  _Row('categories', '${snapshot.categoryCount}'),
                  _Row('searchMode', snapshot.searchMode),
                  _Row(
                    'importedAt',
                    snapshot.importedAt != null
                        ? dateFormat.format(snapshot.importedAt!)
                        : '—',
                  ),
                  _Row('isDemoSlice', snapshot.isDemoSlice ? 'yes' : 'no'),
                  if (snapshot.loadedAt != null)
                    _Row(
                      'loadedAt',
                      dateFormat.format(snapshot.loadedAt!),
                    ),
                ],
              ),
              if (snapshot.warnings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: 'Warnings',
                  children: snapshot.warnings
                      .map(
                        (w) => ListTile(
                          leading: const Icon(Icons.warning_amber_outlined),
                          title: Text(w),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _Section(
                title: 'Quick references',
                children: [
                  ListTile(
                    leading: const Icon(Icons.manage_search_outlined),
                    title: const Text('Catalog selector demo'),
                    subtitle: const Text('/dev/catalog-selector'),
                    onTap: () => context.push('/dev/catalog-selector'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.terminal_outlined),
                    title: Text('Emulator gate'),
                    subtitle: Text(
                      './tools/catalog_import/run_emulator_gate.sh',
                    ),
                  ),
                  const ListTile(
                    leading: Icon(Icons.checklist_outlined),
                    title: Text('Production checklist'),
                    subtitle: Text('CATALOG_PRODUCTION_DEPLOY_CHECKLIST.md'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Read-only — no import, delete, or write actions.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

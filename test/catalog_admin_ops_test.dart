import 'package:construction_rfq/models/catalog/catalog_meta.dart';
import 'package:construction_rfq/models/catalog/catalog_ops_snapshot.dart';
import 'package:construction_rfq/providers/catalog_providers.dart';
import 'package:construction_rfq/repositories/catalog/memory_catalog_repository.dart';
import 'package:construction_rfq/services/catalog_admin_ops_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:construction_rfq/screens/dev/catalog_admin_ops_screen.dart';

void main() {
  group('CatalogOpsSnapshot', () {
    test('fromMeta renders counts and warnings when not imported', () {
      const meta = CatalogMeta(version: '');
      final snapshot = CatalogOpsSnapshot.fromMeta(meta);

      expect(snapshot.productCount, 0);
      expect(snapshot.warnings, isNotEmpty);
    });

    test('demo snapshot has expected scale counts', () {
      final snapshot = demoCatalogOpsSnapshot();
      expect(snapshot.variantCount, 31551);
      expect(snapshot.searchMode, 'firestore');
    });
  });

  group('CatalogAdminOpsScreen', () {
    testWidgets('has no mutation action buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              MemoryCatalogRepository(
                meta: const CatalogMeta(version: 'test', productCount: 1),
              ),
            ),
          ],
          child: const MaterialApp(home: CatalogAdminOpsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.upload), findsNothing);
    });
  });
}

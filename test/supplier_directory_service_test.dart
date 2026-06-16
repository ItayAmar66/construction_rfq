import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/enterprise/organization.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/supplier_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppMode.enableDemoMode();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

  test('supplier directory includes QA ספק גדול בע"מ', () {
    final suppliers = MockStore.listTargetableSuppliers();
    expect(
      suppliers.any((s) => s.fullName.contains('QA ספק גדול')),
      isTrue,
    );
    expect(
      suppliers.any((s) => s.supplierOrgId == 'DRy60MnQjwPQCe6ARmf08cqGsM12'),
      isTrue,
    );
  });

  test('supplier directory includes QA ספק קטן', () {
    final suppliers = MockStore.listTargetableSuppliers();
    expect(suppliers.any((s) => s.fullName == 'QA ספק קטן'), isTrue);
    expect(
      suppliers.any((s) => s.supplierOrgId == 'C5EKNz88l2UBn506FmFUzfyMhFi2'),
      isTrue,
    );
  });

  test('procurement picker search QA returns both QA suppliers', () {
    final suppliers = MockStore.listTargetableSuppliers();
    final filtered = SupplierDirectoryService.filterByQuery(suppliers, 'QA');
    expect(filtered.length, greaterThanOrEqualTo(2));
    expect(filtered.any((s) => s.fullName.contains('גדול')), isTrue);
    expect(filtered.any((s) => s.fullName.contains('קטן')), isTrue);
  });

  test('organization mapping uses company name and org id', () {
    final mapped = SupplierDirectoryService.organizationToAppUser(
      Organization(
        id: 'DRy60MnQjwPQCe6ARmf08cqGsM12',
        type: OrganizationType.supplier,
        name: 'QA ספק גדול בע"מ',
        ownerUid: 'owner-1',
        status: 'active',
      ),
    );
    expect(mapped.fullName, 'QA ספק גדול בע"מ');
    expect(mapped.supplierOrgId, 'DRy60MnQjwPQCe6ARmf08cqGsM12');
    expect(mapped.id, 'owner-1');
  });
}

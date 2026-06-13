import 'package:construction_rfq/utils/enterprise_hierarchy_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnterpriseHierarchyPresets', () {
    test('contractor tree contains manager > procurement manager > procurement',
        () {
      final root = EnterpriseHierarchyPresets.contractorCompany.root;
      expect(
        EnterpriseHierarchyPresets.hasNestedPath(
          root.children.first,
          'מנהל רכש',
          'רכש',
        ),
        isTrue,
      );
    });

    test('contractor tree contains project manager > engineer', () {
      final root = EnterpriseHierarchyPresets.contractorCompany.root;
      expect(
        EnterpriseHierarchyPresets.hasNestedPath(
          root.children.first,
          'מנהל פרויקט',
          'מהנדס',
        ),
        isTrue,
      );
    });

    test('project tree contains assigned procurement', () {
      final root = EnterpriseHierarchyPresets.projectTeam.root;
      expect(
        EnterpriseHierarchyPresets.treeContainsChildTitle(root, 'רכש משויך'),
        isTrue,
      );
    });

    test('supplier tree contains owner > sales manager > sales rep', () {
      final root = EnterpriseHierarchyPresets.supplierCompany.root;
      expect(
        EnterpriseHierarchyPresets.hasNestedPath(
          root.children.first,
          'מנהל מכירות',
          'נציג מכירות',
        ),
        isTrue,
      );
    });

    test('platform tree contains platform admin', () {
      final root = EnterpriseHierarchyPresets.platform.root;
      expect(root.title, 'מנהל מערכת');
    });

    test('contractor matrix has expected roles', () {
      final titles = EnterpriseHierarchyPresets.contractorMatrix
          .map((s) => s.title)
          .toList();
      expect(titles, contains('מנהל חברה'));
      expect(titles, contains('רכש'));
      expect(titles, contains('מהנדס'));
    });

    test('capabilities render from preset nodes', () {
      final root = EnterpriseHierarchyPresets.contractorCompany.root;
      final manager = root.children.first;
      expect(manager.capabilities, isNotEmpty);
      expect(manager.capabilities, contains('ניהול משתמשים והרשאות'));
    });
  });
}

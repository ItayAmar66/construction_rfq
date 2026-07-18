import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/enterprise/project.dart';
import 'package:construction_rfq/widgets/permissions/project_access_matrix.dart';
import 'package:construction_rfq/widgets/permissions/role_comparison_table.dart';
import 'package:construction_rfq/widgets/permissions/user_access_panel.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

const _projects = [
  Project(id: 'p1', ownerUid: 'owner', name: 'מגדל הים'),
  Project(id: 'p2', ownerUid: 'owner', name: 'שכונת הפרחים'),
];

const _orgWideMember = Membership(
  uid: 'u1',
  orgId: 'org1',
  orgType: OrganizationType.contractor,
  roles: [EnterpriseRole.contractorAdmin],
  displayName: 'דנה לוי',
);

const _pinnedMember = Membership(
  uid: 'u2',
  orgId: 'org1',
  orgType: OrganizationType.contractor,
  roles: [EnterpriseRole.engineer],
  projectIds: ['p1'],
  displayName: 'יוסי כהן',
);

void main() {
  group('ProjectAccessMatrix', () {
    testWidgets('shows members, projects and org-wide marker', (tester) async {
      await tester.pumpWidget(_wrap(const ProjectAccessMatrix(
        members: [_orgWideMember, _pinnedMember],
        projects: _projects,
      )));

      expect(find.text('מטריצת גישה לפרויקטים'), findsOneWidget);
      expect(find.text('דנה לוי'), findsOneWidget);
      expect(find.text('יוסי כהן'), findsOneWidget);
      expect(find.text('מגדל הים'), findsOneWidget);
      expect(find.text('שכונת הפרחים'), findsOneWidget);
      // Org-wide member row carries the globe marker.
      expect(find.byIcon(Icons.public_outlined), findsOneWidget);
      // Org-wide access renders outlined checks for both projects; the pinned
      // member gets one filled check (p1 only).
      expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(2));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('excludes disabled members', (tester) async {
      const disabled = Membership(
        uid: 'u3',
        orgId: 'org1',
        orgType: OrganizationType.contractor,
        roles: [EnterpriseRole.engineer],
        status: 'disabled',
        displayName: 'מושבת',
      );
      await tester.pumpWidget(_wrap(const ProjectAccessMatrix(
        members: [_pinnedMember, disabled],
        projects: _projects,
      )));

      expect(find.text('יוסי כהן'), findsOneWidget);
      expect(find.text('מושבת'), findsNothing);
    });
  });

  group('RoleComparisonTable', () {
    testWidgets('lists contractor roles as columns', (tester) async {
      await tester.pumpWidget(_wrap(
        const RoleComparisonTable(orgType: OrganizationType.contractor),
      ));

      expect(find.text('השוואת תפקידים'), findsOneWidget);
      expect(find.text('בעלים'), findsOneWidget);
      expect(find.text('מנהל חברה'), findsOneWidget);
      expect(find.text('מהנדס'), findsOneWidget);
      expect(find.text('צפייה בלבד'), findsOneWidget);
    });

    testWidgets('lists supplier roles as columns', (tester) async {
      await tester.pumpWidget(_wrap(
        const RoleComparisonTable(orgType: OrganizationType.supplier),
      ));

      expect(find.text('בעלים'), findsOneWidget);
      expect(find.text('מנהל ספק'), findsOneWidget);
      expect(find.text('מכירות'), findsOneWidget);
      expect(find.text('תפעול'), findsOneWidget);
    });
  });

  group('UserAccessPanel', () {
    testWidgets('shows identity, project access and permission sources',
        (tester) async {
      await tester.pumpWidget(_wrap(const UserAccessPanel(
        membership: _pinnedMember,
        orgName: 'בונים בע"מ',
        projects: _projects,
      )));

      expect(find.text('יוסי כהן'), findsOneWidget);
      expect(find.text('בונים בע"מ'), findsOneWidget);
      expect(find.text('גישה לפרויקטים'), findsOneWidget);
      expect(find.text('מגדל הים'), findsOneWidget);
      expect(find.text('שכונת הפרחים'), findsNothing);
      expect(find.text('הרשאות בפועל'), findsOneWidget);
    });
  });
}

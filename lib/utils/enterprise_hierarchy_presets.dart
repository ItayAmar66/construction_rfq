import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/hierarchy_node.dart';

/// Read-only hierarchy presets for permission UX.
abstract final class EnterpriseHierarchyPresets {
  static const platform = HierarchyTreePreset(
    id: 'platform',
    title: 'עץ הרשאות מערכת',
    subtitle: 'מנהל מערכת ≠ מנהל חברה',
    root: HierarchyNode(
      title: 'מנהל מערכת',
      description: 'בעלים/מנהל פלטפורמה — ניהול כל החברות, הספקים והנתונים.',
      scope: RoleScopeType.platform,
      canManageChildren: true,
      futureRoleKey: EnterpriseRole.platformAdmin,
      capabilities: [
        'ניהול חברות קבלן וספקים',
        'צפייה בכל המשתמשים והפרויקטים',
        'ניטור בקשות, הצעות והזמנות',
        'הגדרות ואבטחה',
      ],
      children: [
        HierarchyNode(
          title: 'חברות קבלן',
          description: 'ארגוני קבלן וצוותיהם.',
          scope: RoleScopeType.platform,
          capabilities: ['צפייה וניהול ארגונים'],
        ),
        HierarchyNode(
          title: 'ספקים',
          description: 'ארגוני ספק וצוותי מכירות/תפעול.',
          scope: RoleScopeType.platform,
          capabilities: ['צפייה וניהול ספקים'],
        ),
        HierarchyNode(
          title: 'משתמשים',
          description: 'כל המשתמשים במערכת.',
          scope: RoleScopeType.platform,
        ),
        HierarchyNode(
          title: 'פרויקטים',
          description: 'פרויקטים בכל החברות.',
          scope: RoleScopeType.platform,
        ),
        HierarchyNode(
          title: 'בקשות / הצעות / הזמנות',
          description: 'מחזור RFQ מלא.',
          scope: RoleScopeType.platform,
        ),
        HierarchyNode(
          title: 'הגדרות ואבטחה',
          description: 'כללי אבטחה והרשאות.',
          scope: RoleScopeType.platform,
        ),
      ],
    ),
  );

  static const contractorCompany = HierarchyTreePreset(
    id: 'contractor_company',
    title: 'עץ חברה',
    subtitle: 'מי מנהל את מי — הרשאות חברה',
    root: HierarchyNode(
      title: 'חברת קבלן',
      description: 'ארגון הקבלן — תפקידי חברה קובעים מה כל אחד יכול לעשות.',
      scope: RoleScopeType.company,
      children: [
        HierarchyNode(
          title: 'מנהל חברה',
          description: 'מנהל חברה יכול לנהל פרויקטים, משתמשים והרשאות.',
          scope: RoleScopeType.company,
          canManageChildren: true,
          futureRoleKey: EnterpriseRole.contractorCompanyOwner,
          capabilities: [
            'ניהול משתמשים והרשאות',
            'ניהול פרויקטים',
            'אישור הצעות',
            'צפייה בעלויות',
          ],
          children: [
            HierarchyNode(
              title: 'מנהל רכש',
              description: 'מנהל את צוות הרכש.',
              scope: RoleScopeType.company,
              canManageChildren: true,
              futureRoleKey: EnterpriseRole.procurementManager,
              children: [
                HierarchyNode(
                  title: 'רכש',
                  description: 'רכש יכול לשלוח בקשות לספקים ולאשר הצעות.',
                  scope: RoleScopeType.company,
                  futureRoleKey: EnterpriseRole.procurementManager,
                  capabilities: [
                    'יצירת בקשות',
                    'שליחה לספקים',
                    'אישור/דחיית הצעות',
                  ],
                ),
              ],
            ),
            HierarchyNode(
              title: 'מנהל פרויקט',
              description: 'מנהל פרויקט באתר.',
              scope: RoleScopeType.company,
              canManageChildren: true,
              futureRoleKey: EnterpriseRole.projectManager,
              children: [
                HierarchyNode(
                  title: 'מהנדס',
                  description:
                      'מהנדס יכול להכין רשימת חומרים ולשלוח לאישור רכש.',
                  scope: RoleScopeType.company,
                  futureRoleKey: EnterpriseRole.engineer,
                  capabilities: [
                    'הכנת רשימת חומרים',
                    'טיוטות RFQ',
                    'שליחה לאישור רכש',
                  ],
                ),
                HierarchyNode(
                  title: 'צוות אתר',
                  description: 'עובדי שטח — שיוך לפרויקט.',
                  scope: RoleScopeType.project,
                ),
              ],
            ),
            HierarchyNode(
              title: 'חשבונות',
              description: 'צפייה בעלויות ודוחות — בקרוב.',
              scope: RoleScopeType.company,
            ),
            HierarchyNode(
              title: 'צפייה בלבד',
              description: 'צפייה בפרויקטים שהוקצו.',
              scope: RoleScopeType.company,
              futureRoleKey: EnterpriseRole.contractorViewer,
            ),
          ],
        ),
      ],
    ),
  );

  static const projectTeam = HierarchyTreePreset(
    id: 'project_team',
    title: 'צוות והרשאות בפרויקט',
    subtitle: 'שיוך לפרויקט קובע באיזה פרויקט ניתן לעבוד',
    root: HierarchyNode(
      title: 'פרויקט',
      description:
          'הרשאות החברה קובעות מה המשתמש יכול לעשות. שיוך לפרויקט קובע באיזה פרויקט.',
      scope: RoleScopeType.project,
      children: [
        HierarchyNode(
          title: 'מנהל פרויקט',
          description: 'אחראי על הפרויקט וצוותו.',
          scope: RoleScopeType.project,
          futureRoleKey: EnterpriseRole.projectManager,
          capabilities: ['ניהול צוות פרויקט', 'מעקב בקשות'],
        ),
        HierarchyNode(
          title: 'מהנדסים',
          description: 'הכנת חומרים וטיוטות RFQ.',
          scope: RoleScopeType.project,
          futureRoleKey: EnterpriseRole.engineer,
        ),
        HierarchyNode(
          title: 'רכש משויך',
          description: 'שליחה לספקים ואישור הצעות בפרויקט.',
          scope: RoleScopeType.project,
          futureRoleKey: EnterpriseRole.procurementManager,
        ),
        HierarchyNode(
          title: 'צופים',
          description: 'צפייה בלבד בפרויקט.',
          scope: RoleScopeType.project,
          futureRoleKey: EnterpriseRole.contractorViewer,
        ),
      ],
    ),
  );

  static const supplierCompany = HierarchyTreePreset(
    id: 'supplier_company',
    title: 'עץ ספק',
    subtitle: 'מי מנהל את מי — הרשאות ספק',
    root: HierarchyNode(
      title: 'חברת ספק',
      description: 'מכירות מטפלים בהצעות. תפעול מטפל בהזמנות שאושרו.',
      scope: RoleScopeType.supplier,
      children: [
        HierarchyNode(
          title: 'מנהל ספק',
          description: 'ניהול צוות, צפייה בכל ההצעות וההזמנות.',
          scope: RoleScopeType.supplier,
          canManageChildren: true,
          futureRoleKey: EnterpriseRole.supplierOwner,
          capabilities: [
            'ניהול צוות',
            'צפייה בכל ההצעות וההזמנות',
          ],
          children: [
            HierarchyNode(
              title: 'מנהל מכירות',
              description: 'ניהול הצעות ונציגי מכירות.',
              scope: RoleScopeType.supplier,
              canManageChildren: true,
              futureRoleKey: EnterpriseRole.supplierSalesManager,
              children: [
                HierarchyNode(
                  title: 'נציג מכירות',
                  description: 'מענה לבקשות והגשת הצעות.',
                  scope: RoleScopeType.supplier,
                  futureRoleKey: EnterpriseRole.supplierSalesRep,
                  capabilities: ['מענה לבקשות', 'הגשת הצעות'],
                ),
              ],
            ),
            HierarchyNode(
              title: 'מנהל תפעול',
              description: 'ניהול צוות תפעול.',
              scope: RoleScopeType.supplier,
              canManageChildren: true,
              children: [
                HierarchyNode(
                  title: 'תפעול',
                  description:
                      'טיפול בהזמנות שאושרו וסימון נשלח/סופק.',
                  scope: RoleScopeType.supplier,
                  futureRoleKey: EnterpriseRole.supplierOps,
                  capabilities: ['סימון נשלח', 'סימון סופק'],
                ),
              ],
            ),
            HierarchyNode(
              title: 'חשבונות',
              description: 'דוחות וחשבוניות — בקרוב.',
              scope: RoleScopeType.supplier,
            ),
            HierarchyNode(
              title: 'צפייה בלבד',
              description: 'צפייה בלבד.',
              scope: RoleScopeType.supplier,
              futureRoleKey: EnterpriseRole.supplierViewer,
            ),
          ],
        ),
      ],
    ),
  );

  static List<RoleCapabilitySummary> contractorMatrix = const [
    RoleCapabilitySummary(
      title: 'מנהל חברה',
      capabilities: [
        'ניהול משתמשים',
        'ניהול פרויקטים',
        'הרשאות',
        'אישור הצעות',
        'צפייה בעלויות',
      ],
    ),
    RoleCapabilitySummary(
      title: 'רכש',
      capabilities: [
        'יצירת בקשות',
        'שליחה לספקים',
        'בחירת ספקים',
        'אישור/דחיית הצעות',
      ],
    ),
    RoleCapabilitySummary(
      title: 'מהנדס',
      capabilities: [
        'הכנת רשימת חומרים',
        'טיוטות',
        'שליחה לאישור רכש',
      ],
    ),
    RoleCapabilitySummary(
      title: 'צפייה בלבד',
      capabilities: ['צפייה בפרויקטים שהוקצו'],
    ),
  ];

  static List<RoleCapabilitySummary> supplierMatrix = const [
    RoleCapabilitySummary(
      title: 'מנהל ספק',
      capabilities: ['ניהול צוות', 'צפייה בכל ההצעות וההזמנות'],
    ),
    RoleCapabilitySummary(
      title: 'מנהל מכירות',
      capabilities: ['ניהול הצעות', 'ניהול נציגי מכירות'],
    ),
    RoleCapabilitySummary(
      title: 'נציג מכירות',
      capabilities: ['מענה לבקשות', 'הגשת הצעות'],
    ),
    RoleCapabilitySummary(
      title: 'תפעול',
      capabilities: ['טיפול בהזמנות שאושרו', 'סימון נשלח/סופק'],
    ),
    RoleCapabilitySummary(
      title: 'צפייה בלבד',
      capabilities: ['צפייה בלבד'],
    ),
  ];

  static bool treeContainsChildTitle(HierarchyNode node, String title) {
    if (node.title == title) return true;
    for (final child in node.children) {
      if (treeContainsChildTitle(child, title)) return true;
    }
    return false;
  }

  static bool hasNestedPath(
    HierarchyNode parent,
    String childTitle,
    String grandchildTitle,
  ) {
    for (final child in parent.children) {
      if (child.title == childTitle) {
        return treeContainsChildTitle(child, grandchildTitle);
      }
    }
    return false;
  }
}

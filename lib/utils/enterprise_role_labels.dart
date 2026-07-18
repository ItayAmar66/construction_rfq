import '../models/app_user.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/permission.dart';
import 'role_invitation_policy.dart';

/// Shared Hebrew labels and descriptions for roles and permissions.
/// The single place role/permission names are humanized — never show raw
/// enum names in UI.
abstract final class EnterpriseRoleLabels {
  static String hebrew(EnterpriseRole role) {
    switch (role) {
      case EnterpriseRole.platformAdmin:
        return 'מנהל מערכת';
      case EnterpriseRole.contractorOwner:
        return 'בעלים';
      case EnterpriseRole.contractorAdmin:
        return 'מנהל חברה';
      case EnterpriseRole.procurementManager:
        return 'מנהל רכש';
      case EnterpriseRole.projectManager:
        return 'מנהל פרויקט';
      case EnterpriseRole.engineer:
        return 'מהנדס';
      case EnterpriseRole.contractorViewer:
        return 'צפייה בלבד';
      case EnterpriseRole.supplierOwner:
        return 'בעלים';
      case EnterpriseRole.supplierAdmin:
        return 'מנהל ספק';
      case EnterpriseRole.supplierSales:
        return 'מכירות';
      case EnterpriseRole.supplierOperations:
        return 'תפעול';
      case EnterpriseRole.supplierViewer:
        return 'צפייה בלבד';
    }
  }

  static String description(EnterpriseRole role) {
    switch (role) {
      case EnterpriseRole.platformAdmin:
        return 'שולט בפלטפורמה כולה. זה אינו תפקיד חברה רגיל.';
      case EnterpriseRole.contractorOwner:
        return 'בעלי החברה — שליטה מלאה בצוות, בפרויקטים, בהרשאות ובאישורי רכש.';
      case EnterpriseRole.contractorAdmin:
        return 'מנהל את החברה: צוות, פרויקטים, הרשאות ואישורי רכש — ללא בעלות.';
      case EnterpriseRole.procurementManager:
        return 'שולח בקשות לספקים, משווה הצעות, מאשר או דוחה הצעות והזמנות.';
      case EnterpriseRole.projectManager:
        return 'מנהל את עבודת הפרויקט ומשייך חברי צוות לפרויקטים שלו.';
      case EnterpriseRole.engineer:
        return 'מכין בקשות חומרים וטיוטות; אינו שולח לספקים ישירות.';
      case EnterpriseRole.contractorViewer:
        return 'צפייה בלבד בפרויקטים ובבקשות שהוקצו.';
      case EnterpriseRole.supplierOwner:
        return 'בעלי הספק — שליטה מלאה בצוות המכירות, בתפעול ובהגדרות.';
      case EnterpriseRole.supplierAdmin:
        return 'מנהל את צוות הספק וההגדרות — ללא בעלות.';
      case EnterpriseRole.supplierSales:
        return 'מקבל בקשות מקבלנים ומגיש הצעות מחיר.';
      case EnterpriseRole.supplierOperations:
        return 'מטפל בהזמנות שאושרו, משלוחים וסימון נשלח.';
      case EnterpriseRole.supplierViewer:
        return 'צפייה בלבד בפעילות הספק.';
    }
  }

  static String permissionHebrew(Permission permission) {
    switch (permission) {
      case Permission.viewOrganization:
        return 'צפייה בפרטי הארגון';
      case Permission.manageOrganizationSettings:
        return 'ניהול הגדרות הארגון';
      case Permission.viewUsers:
        return 'צפייה במשתמשים';
      case Permission.inviteUsers:
        return 'הזמנת משתמשים';
      case Permission.manageUsers:
        return 'ניהול משתמשים';
      case Permission.manageRoles:
        return 'ניהול תפקידים';
      case Permission.viewProjects:
        return 'צפייה בפרויקטים';
      case Permission.manageProjects:
        return 'ניהול פרויקטים';
      case Permission.assignProjectMembers:
        return 'שיוך חברי צוות לפרויקטים';
      case Permission.viewRfqs:
        return 'צפייה בבקשות הצעות מחיר';
      case Permission.createRfqDraft:
        return 'יצירת טיוטת בקשה';
      case Permission.editRfqDraft:
        return 'עריכת טיוטת בקשה';
      case Permission.submitRfq:
        return 'שליחת בקשה לספקים';
      case Permission.approveRfq:
        return 'אישור בקשות רכש';
      case Permission.rejectRfq:
        return 'דחיית בקשות רכש';
      case Permission.viewQuotes:
        return 'צפייה בהצעות מחיר';
      case Permission.createSupplierQuote:
        return 'יצירת הצעת מחיר';
      case Permission.editSupplierQuote:
        return 'עריכת הצעת מחיר';
      case Permission.submitSupplierQuote:
        return 'הגשת הצעת מחיר';
      case Permission.approveQuote:
        return 'אישור הצעות מחיר';
      case Permission.rejectQuote:
        return 'דחיית הצעות מחיר';
      case Permission.viewOrders:
        return 'צפייה בהזמנות';
      case Permission.placeOrder:
        return 'ביצוע הזמנה';
      case Permission.manageOrders:
        return 'ניהול הזמנות';
      case Permission.markOrderShipped:
        return 'סימון הזמנה כנשלחה';
      case Permission.viewDeliveries:
        return 'צפייה במשלוחים';
      case Permission.manageDeliveries:
        return 'ניהול משלוחים';
      case Permission.confirmDeliveryReceipt:
        return 'אישור קבלת משלוח';
      case Permission.reportDeliveryIssue:
        return 'דיווח על בעיה במשלוח';
      case Permission.viewAnalytics:
        return 'צפייה בדוחות';
      case Permission.viewFinancialData:
        return 'צפייה בנתונים כספיים';
      case Permission.viewCatalog:
        return 'צפייה בקטלוג';
      case Permission.manageCatalog:
        return 'ניהול קטלוג';
      case Permission.viewAuditLog:
        return 'צפייה ביומן פעילות';
      case Permission.manageSecurity:
        return 'ניהול אבטחה';
    }
  }

  static String domainHebrew(PermissionDomain domain) {
    switch (domain) {
      case PermissionDomain.organization:
        return 'ארגון ומשתמשים';
      case PermissionDomain.projects:
        return 'פרויקטים';
      case PermissionDomain.rfqs:
        return 'בקשות הצעות מחיר';
      case PermissionDomain.quotes:
        return 'הצעות מחיר';
      case PermissionDomain.orders:
        return 'הזמנות';
      case PermissionDomain.deliveries:
        return 'משלוחים';
      case PermissionDomain.analytics:
        return 'דוחות וכספים';
      case PermissionDomain.catalog:
        return 'קטלוג';
      case PermissionDomain.security:
        return 'יומן ואבטחה';
    }
  }

  static String legacyLabel(AppUser user) {
    if (user.userType.isSupplier) return 'מכירות';
    return 'מנהל רכש';
  }

  static const contractorAssignableRoles =
      RoleInvitationPolicy.contractorLaunchRoles;

  static const supplierLaunchRoles = RoleInvitationPolicy.supplierLaunchRoles;

  static const supplierAssignableRoles =
      RoleInvitationPolicy.supplierLaunchRoles;

  static String primaryLabel({
    required AppUser? user,
    List<Membership> memberships = const [],
  }) {
    if (memberships.isNotEmpty) {
      final role = memberships.first.role;
      if (role != null) return hebrew(role);
    }
    if (user != null) return legacyLabel(user);
    return 'משתמש';
  }
}

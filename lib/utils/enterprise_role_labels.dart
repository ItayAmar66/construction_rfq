import '../models/app_user.dart';
import '../models/enterprise/enterprise_role.dart';
import 'role_invitation_policy.dart';
import '../models/enterprise/membership.dart';

abstract final class EnterpriseRoleLabels {
  static String hebrew(EnterpriseRole role) {
    switch (role) {
      case EnterpriseRole.platformAdmin:
        return 'מנהל מערכת';
      case EnterpriseRole.contractorCompanyOwner:
        return 'מנהל חברה';
      case EnterpriseRole.procurementManager:
        return 'רכש';
      case EnterpriseRole.projectManager:
        return 'מנהל פרויקט';
      case EnterpriseRole.engineer:
        return 'מהנדס';
      case EnterpriseRole.contractorViewer:
        return 'צפייה בלבד';
      case EnterpriseRole.supplierOwner:
        return 'מנהל ספק';
      case EnterpriseRole.supplierSalesManager:
        return 'מנהל מכירות';
      case EnterpriseRole.supplierSalesRep:
        return 'רכש ספק';
      case EnterpriseRole.supplierOps:
        return 'תפעול';
      case EnterpriseRole.supplierViewer:
        return 'צפייה בלבד';
    }
  }

  static String description(EnterpriseRole role) {
    switch (role) {
      case EnterpriseRole.platformAdmin:
        return 'מנהל מערכת שולט בפלטפורמה כולה. זה אינו תפקיד חברה רגיל.';
      case EnterpriseRole.contractorCompanyOwner:
        return 'מנהל חברה מנהל צוות, פרויקטים, הרשאות ואישור פעילות רכש.';
      case EnterpriseRole.procurementManager:
        return 'רכש יכול לשלוח בקשות לספקים, לבחור ספקים ולאשר או לדחות הצעות.';
      case EnterpriseRole.projectManager:
        return 'מנהל פרויקט מנהל את עבודת הפרויקט והשיוכים אליו.';
      case EnterpriseRole.engineer:
        return 'מהנדס מכין בקשות חומרים וטיוטות, בדרך כלל לא שולח לספקים ישירות.';
      case EnterpriseRole.contractorViewer:
        return 'צפייה בלבד בפרויקטים ובבקשות שהוקצו.';
      case EnterpriseRole.supplierOwner:
        return 'מנהל ספק מנהל צוות מכירות, תפעול והגדרות ספק.';
      case EnterpriseRole.supplierSalesManager:
        return 'מנהל מכירות מנהל נציגים ומעקב אחר הצעות.';
      case EnterpriseRole.supplierSalesRep:
        return 'נציג מכירות מקבל בקשות ומגיש הצעות מחיר.';
      case EnterpriseRole.supplierOps:
        return 'תפעול מטפל בהזמנות שאושרו ובסימון נשלח או סופק.';
      case EnterpriseRole.supplierViewer:
        return 'צפייה בלבד בפעילות הספק.';
    }
  }

  static String legacyLabel(AppUser user) {
    if (user.userType.isSupplier) return 'נציג מכירות';
    return 'רכש';
  }

  static const contractorAssignableRoles = [
    EnterpriseRole.contractorCompanyOwner,
    EnterpriseRole.procurementManager,
    EnterpriseRole.engineer,
    EnterpriseRole.contractorViewer,
  ];

  static const supplierLaunchRoles = RoleInvitationPolicy.supplierLaunchRoles;

  static const supplierAssignableRoles = [
    EnterpriseRole.supplierOwner,
    EnterpriseRole.supplierSalesRep,
    EnterpriseRole.supplierViewer,
  ];

  static String primaryLabel({
    required AppUser? user,
    List<Membership> memberships = const [],
  }) {
    if (memberships.isNotEmpty) {
      final role = memberships.first.roles.firstOrNull;
      if (role != null) return hebrew(role);
    }
    if (user != null) return legacyLabel(user);
    return 'משתמש';
  }
}

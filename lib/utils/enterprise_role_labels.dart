import '../models/app_user.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';

abstract final class EnterpriseRoleLabels {
  static String hebrew(EnterpriseRole role) {
    switch (role) {
      case EnterpriseRole.platformAdmin:
        return 'מנהל מערכת';
      case EnterpriseRole.contractorCompanyOwner:
        return 'בעל חברה';
      case EnterpriseRole.procurementManager:
        return 'רכש';
      case EnterpriseRole.projectManager:
        return 'מנהל פרויקט';
      case EnterpriseRole.engineer:
        return 'מהנדס';
      case EnterpriseRole.contractorViewer:
        return 'צפייה';
      case EnterpriseRole.supplierOwner:
        return 'בעל ספק';
      case EnterpriseRole.supplierSalesManager:
        return 'מנהל מכירות';
      case EnterpriseRole.supplierSalesRep:
        return 'נציג מכירות';
      case EnterpriseRole.supplierOps:
        return 'תפעול';
      case EnterpriseRole.supplierViewer:
        return 'צפייה';
    }
  }

  static String legacyLabel(AppUser user) {
    if (user.userType.isSupplier) return 'נציג מכירות';
    return 'רכש';
  }

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

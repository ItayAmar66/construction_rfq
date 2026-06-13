import '../models/enterprise/enterprise_role.dart';

/// Roles assignable at project level (contractor org).
abstract final class ProjectAssignmentRoles {
  static const assignable = [
    EnterpriseRole.projectManager,
    EnterpriseRole.engineer,
    EnterpriseRole.procurementManager,
    EnterpriseRole.contractorViewer,
  ];

  static String label(EnterpriseRole role) {
    switch (role) {
      case EnterpriseRole.projectManager:
        return 'מנהל פרויקט';
      case EnterpriseRole.engineer:
        return 'מהנדס';
      case EnterpriseRole.procurementManager:
        return 'רכש משויך';
      case EnterpriseRole.contractorViewer:
        return 'צופה';
      default:
        return role.value;
    }
  }

  static bool isAssignable(EnterpriseRole role) => assignable.contains(role);
}

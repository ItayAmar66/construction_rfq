import '../models/enterprise/project.dart';

/// When a project can accept a new catalog order / RFQ.
abstract final class ProjectOrderHelpers {
  static bool canStartNewOrder(Project project) => project.isActive;

  static String? blockedMessage(Project project) {
    if (project.isDeletionPending) {
      return 'לא ניתן לפתוח הזמנה חדשה בפרויקט שממתין למחיקה';
    }
    if (project.isArchived) {
      return 'לא ניתן לפתוח הזמנה חדשה בפרויקט בארכיון';
    }
    if (project.isCompleted) {
      return 'הפרויקט הסתיים. יש להחזיר אותו לפעיל לפני פתיחת הזמנה חדשה.';
    }
    return null;
  }

  static String catalogRouteForProject(String projectId) =>
      '/catalog?projectId=$projectId';

  static String rfqDraftRouteForProject(String projectId) =>
      '/rfq-draft?projectId=$projectId';
}

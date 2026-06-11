/// Project lifecycle status values stored in Firestore.
abstract final class ProjectStatus {
  static const active = 'active';
  static const completed = 'completed';
  static const deletionPending = 'deletionPending';
  static const archived = 'archived';

  static const all = [active, completed, deletionPending, archived];

  static String label(String status) {
    switch (status) {
      case completed:
        return 'הסתיים';
      case deletionPending:
        return 'מתוזמן למחיקה';
      case archived:
        return 'בארכיון';
      case active:
      default:
        return 'פעיל';
    }
  }

  static bool isVisibleOnDashboard(String status) =>
      status == active || status == completed;
}

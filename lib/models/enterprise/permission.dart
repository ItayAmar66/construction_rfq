/// Canonical permission catalog. Every entry corresponds to a real
/// application behavior and has a matching Firestore rule enforcement path.
///
/// Grouped by [PermissionDomain]; keep this list aligned with
/// `EnterprisePermissionService` and `firestore.rules`.
enum Permission {
  // Organization & users
  viewOrganization('viewOrganization', PermissionDomain.organization),
  manageOrganizationSettings(
      'manageOrganizationSettings', PermissionDomain.organization),
  viewUsers('viewUsers', PermissionDomain.organization),
  inviteUsers('inviteUsers', PermissionDomain.organization),
  manageUsers('manageUsers', PermissionDomain.organization),
  manageRoles('manageRoles', PermissionDomain.organization),

  // Projects
  viewProjects('viewProjects', PermissionDomain.projects),
  manageProjects('manageProjects', PermissionDomain.projects),
  assignProjectMembers('assignProjectMembers', PermissionDomain.projects),

  // RFQs (material requests / quote requests)
  viewRfqs('viewRfqs', PermissionDomain.rfqs),
  createRfqDraft('createRfqDraft', PermissionDomain.rfqs),
  editRfqDraft('editRfqDraft', PermissionDomain.rfqs),
  submitRfq('submitRfq', PermissionDomain.rfqs),
  approveRfq('approveRfq', PermissionDomain.rfqs),
  rejectRfq('rejectRfq', PermissionDomain.rfqs),

  // Quotes
  viewQuotes('viewQuotes', PermissionDomain.quotes),
  createSupplierQuote('createSupplierQuote', PermissionDomain.quotes),
  editSupplierQuote('editSupplierQuote', PermissionDomain.quotes),
  submitSupplierQuote('submitSupplierQuote', PermissionDomain.quotes),
  approveQuote('approveQuote', PermissionDomain.quotes),
  rejectQuote('rejectQuote', PermissionDomain.quotes),

  // Orders
  viewOrders('viewOrders', PermissionDomain.orders),
  placeOrder('placeOrder', PermissionDomain.orders),
  manageOrders('manageOrders', PermissionDomain.orders),
  markOrderShipped('markOrderShipped', PermissionDomain.orders),

  // Deliveries
  viewDeliveries('viewDeliveries', PermissionDomain.deliveries),
  manageDeliveries('manageDeliveries', PermissionDomain.deliveries),
  confirmDeliveryReceipt('confirmDeliveryReceipt', PermissionDomain.deliveries),
  reportDeliveryIssue('reportDeliveryIssue', PermissionDomain.deliveries),

  // Analytics & finance
  viewAnalytics('viewAnalytics', PermissionDomain.analytics),
  viewFinancialData('viewFinancialData', PermissionDomain.analytics),

  // Catalog
  viewCatalog('viewCatalog', PermissionDomain.catalog),
  manageCatalog('manageCatalog', PermissionDomain.catalog),

  // Audit & security
  viewAuditLog('viewAuditLog', PermissionDomain.security),
  manageSecurity('manageSecurity', PermissionDomain.security);

  const Permission(this.value, this.domain);

  /// Stable string value — persisted in membership `grants` / `revokes`.
  final String value;
  final PermissionDomain domain;

  static Permission? fromValue(String? raw) {
    if (raw == null) return null;
    for (final p in values) {
      if (p.value == raw) return p;
    }
    return null;
  }

  /// Permissions that may be granted/revoked as membership-level exceptions.
  /// Security-sensitive management capabilities are excluded — those come
  /// only from the role itself.
  bool get isGrantable => !{
        Permission.manageOrganizationSettings,
        Permission.manageUsers,
        Permission.manageRoles,
        Permission.manageSecurity,
        Permission.manageCatalog,
      }.contains(this);
}

enum PermissionDomain {
  organization('organization'),
  projects('projects'),
  rfqs('rfqs'),
  quotes('quotes'),
  orders('orders'),
  deliveries('deliveries'),
  analytics('analytics'),
  catalog('catalog'),
  security('security');

  const PermissionDomain(this.value);
  final String value;
}

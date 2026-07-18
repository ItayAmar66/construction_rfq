/// Canonical organization roles. Exactly one role per active membership.
///
/// Legacy stored values (`contractorCompanyOwner`, `supplierSalesManager`,
/// `supplierSalesRep`, `supplierOps`) remain readable via [fromValue] during
/// the transition, but all new writes must use the canonical [value].
enum EnterpriseRole {
  platformAdmin('platformAdmin'),
  contractorOwner('contractorOwner'),
  contractorAdmin('contractorAdmin'),
  procurementManager('procurementManager'),
  projectManager('projectManager'),
  engineer('engineer'),
  contractorViewer('contractorViewer'),
  supplierOwner('supplierOwner'),
  supplierAdmin('supplierAdmin'),
  supplierSales('supplierSales'),
  supplierOperations('supplierOperations'),
  supplierViewer('supplierViewer');

  const EnterpriseRole(this.value);
  final String value;

  /// Deprecated persisted role values still present in older documents.
  static const Map<String, EnterpriseRole> legacyAliases = {
    'contractorCompanyOwner': EnterpriseRole.contractorOwner,
    'supplierSalesManager': EnterpriseRole.supplierSales,
    'supplierSalesRep': EnterpriseRole.supplierSales,
    'supplierOps': EnterpriseRole.supplierOperations,
  };

  static EnterpriseRole? fromValue(String? raw) {
    if (raw == null) return null;
    for (final r in values) {
      if (r.value == raw) return r;
    }
    return legacyAliases[raw];
  }

  bool get isContractorRole =>
      this == contractorOwner ||
      this == contractorAdmin ||
      this == procurementManager ||
      this == projectManager ||
      this == engineer ||
      this == contractorViewer;

  bool get isSupplierRole =>
      this == supplierOwner ||
      this == supplierAdmin ||
      this == supplierSales ||
      this == supplierOperations ||
      this == supplierViewer;

  /// Owner roles carry organization ownership protections (cannot be demoted
  /// or removed by non-platform actors while listed as org owner).
  bool get isOwnerRole => this == contractorOwner || this == supplierOwner;

  /// Roles that administer their organization (owner-level capability set).
  bool get isOrgAdminRole =>
      this == contractorOwner ||
      this == contractorAdmin ||
      this == supplierOwner ||
      this == supplierAdmin;
}

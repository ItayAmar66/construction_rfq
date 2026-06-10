enum EnterpriseRole {
  platformAdmin('platformAdmin'),
  contractorCompanyOwner('contractorCompanyOwner'),
  procurementManager('procurementManager'),
  projectManager('projectManager'),
  engineer('engineer'),
  contractorViewer('contractorViewer'),
  supplierOwner('supplierOwner'),
  supplierSalesManager('supplierSalesManager'),
  supplierSalesRep('supplierSalesRep'),
  supplierOps('supplierOps'),
  supplierViewer('supplierViewer');

  const EnterpriseRole(this.value);
  final String value;

  static EnterpriseRole? fromValue(String? raw) {
    if (raw == null) return null;
    for (final r in values) {
      if (r.value == raw) return r;
    }
    return null;
  }

  bool get isContractorRole =>
      this == contractorCompanyOwner ||
      this == procurementManager ||
      this == projectManager ||
      this == engineer ||
      this == contractorViewer;

  bool get isSupplierRole =>
      this == supplierOwner ||
      this == supplierSalesManager ||
      this == supplierSalesRep ||
      this == supplierOps ||
      this == supplierViewer;
}

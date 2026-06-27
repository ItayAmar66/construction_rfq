import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/organization.dart';
import '../models/enterprise/organization_type.dart';
import '../models/enterprise/project.dart';
import '../models/supplier_directory_entry.dart';
import '../repositories/admin_management_repository.dart';

class AdminCreateUserCommand {
  const AdminCreateUserCommand({
    required this.command,
    required this.email,
    required this.password,
  });

  final String command;
  final String email;
  final String password;
}

class AdminManagementService {
  AdminManagementService({AdminManagementRepository? repository})
      : _repository = repository ?? AdminManagementRepository();

  final AdminManagementRepository _repository;

  Future<List<Organization>> fetchOrganizations() =>
      _repository.fetchOrganizations();

  Future<Organization?> fetchOrganizationById(String orgId) =>
      _repository.fetchOrganizationById(orgId);

  Future<Organization> updateOrganizationDetails({
    required String orgId,
    required String name,
    String? phone,
    String? email,
  }) {
    return _repository.updateOrganizationDetails(
      orgId: orgId,
      name: name,
      phone: phone,
      email: email,
    );
  }

  Future<List<Project>> fetchProjectsForOrg(String orgId) =>
      _repository.fetchProjectsForOrg(orgId);

  Future<List<SupplierDirectoryEntry>> fetchSupplierDirectoryForOrg(
    String orgId,
  ) =>
      _repository.fetchSupplierDirectoryForOrg(orgId);

  Future<List<Membership>> fetchAllMemberships() =>
      _repository.fetchAllMemberships();

  Future<Organization> createContractorCompany({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? orgId,
  }) {
    return _repository.createOrganization(
      type: OrganizationType.contractor,
      name: name,
      orgId: orgId,
      phone: phone,
      email: email,
      address: address,
    );
  }

  Future<Organization> createSupplierCompany({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? orgId,
    String? ownerUid,
    String? city,
  }) async {
    final org = await _repository.createOrganization(
      type: OrganizationType.supplier,
      name: name,
      orgId: orgId,
      ownerUid: ownerUid ?? '',
      phone: phone,
      email: email,
      address: address,
    );

    if (ownerUid != null && ownerUid.trim().isNotEmpty) {
      await _repository.upsertSupplierDirectory(
        uid: ownerUid.trim(),
        displayName: name.trim(),
        orgId: org.id,
        city: city ?? '',
      );
    }

    return org;
  }

  Future<Organization> setOrganizationOwner({
    required String orgId,
    required String ownerUid,
    required OrganizationType orgType,
    required String displayName,
    String city = '',
  }) async {
    final org = await _repository.updateOrganizationOwner(
      orgId: orgId,
      ownerUid: ownerUid,
    );
    if (orgType == OrganizationType.supplier) {
      await _repository.upsertSupplierDirectory(
        uid: ownerUid,
        displayName: displayName,
        orgId: orgId,
        city: city,
      );
    }
    return org;
  }

  Future<Membership> assignMembership({
    required String orgId,
    required OrganizationType orgType,
    required String uid,
    required EnterpriseRole role,
    required String actorUid,
    String? email,
    String? displayName,
    List<String> projectIds = const [],
    String status = 'active',
  }) {
    return _repository.upsertMembership(
      orgId: orgId,
      orgType: orgType,
      uid: uid,
      role: role,
      actorUid: actorUid,
      email: email,
      displayName: displayName,
      projectIds: projectIds,
      status: status,
    );
  }

  Future<Membership> updateMembership({
    required String orgId,
    required String uid,
    required String actorUid,
    EnterpriseRole? role,
    String? status,
    List<String>? projectIds,
  }) {
    return _repository.updateMembership(
      orgId: orgId,
      uid: uid,
      role: role,
      status: status,
      projectIds: projectIds,
      actorUid: actorUid,
    );
  }

  Future<Membership> disableMembership({
    required String orgId,
    required String uid,
    required String actorUid,
  }) {
    return updateMembership(
      orgId: orgId,
      uid: uid,
      actorUid: actorUid,
      status: 'disabled',
    );
  }

  Future<List<Membership>> fetchMembershipsForOrg(String orgId) =>
      _repository.fetchMembershipsForOrg(orgId);

  Future<Project> createProject({
    required String name,
    required String orgId,
    required String ownerUid,
    required String actorUid,
    String location = '',
    String cityOrArea = '',
    String? companyName,
    Map<EnterpriseRole, String> assignees = const {},
  }) async {
    final managerUids = assignees.values
        .where((uid) => uid.trim().isNotEmpty)
        .toSet()
        .toList();

    final project = await _repository.createProjectAsAdmin(
      ownerUid: ownerUid,
      name: name,
      orgId: orgId,
      location: location,
      cityOrArea: cityOrArea,
      companyName: companyName,
      managerUids: managerUids,
      actorUid: actorUid,
    );

    OrganizationType orgType = OrganizationType.contractor;
    final orgs = await _repository.fetchOrganizations();
    final match = orgs.where((o) => o.id == orgId).firstOrNull;
    if (match != null) orgType = match.type;

    for (final entry in assignees.entries) {
      final uid = entry.value.trim();
      if (uid.isEmpty) continue;
      await _repository.upsertMembership(
        orgId: orgId,
        orgType: orgType,
        uid: uid,
        role: entry.key,
        actorUid: actorUid,
        projectIds: [project.id],
      );
      await _repository.assignProjectMember(
        projectId: project.id,
        orgId: orgId,
        uid: uid,
        role: entry.key,
        actorUid: actorUid,
      );
    }

    return project;
  }

  Future<SupplierDirectoryEntry> upsertSupplierDirectory({
    required String uid,
    required String displayName,
    required String orgId,
    String city = '',
  }) {
    return _repository.upsertSupplierDirectory(
      uid: uid,
      displayName: displayName,
      orgId: orgId,
      city: city,
    );
  }

  AdminCreateUserCommand buildCreateUserCommand({
    required String email,
    required String password,
    required String fullName,
    required String orgId,
    required EnterpriseRole role,
    required OrganizationType orgType,
    String? phone,
    String? city,
  }) {
    final userType =
        orgType == OrganizationType.supplier ? 'commercialSupplier' : 'commercialCustomer';
    final command = _repository.buildCreateUserCommand(
      email: email.trim(),
      password: password,
      fullName: fullName.trim(),
      orgId: orgId,
      role: role.value,
      userType: userType,
      phone: phone,
      city: city,
    );
    return AdminCreateUserCommand(
      command: command,
      email: email.trim(),
      password: password,
    );
  }

  String get seedLaunchTestCommand => _repository.seedLaunchTestCommand;

  static List<EnterpriseRole> rolesForOrgType(OrganizationType type) {
    if (type == OrganizationType.supplier) {
      return const [
        EnterpriseRole.supplierOwner,
        EnterpriseRole.supplierOps,
        EnterpriseRole.supplierSalesRep,
        EnterpriseRole.supplierSalesManager,
        EnterpriseRole.supplierViewer,
      ];
    }
    return const [
      EnterpriseRole.contractorCompanyOwner,
      EnterpriseRole.procurementManager,
      EnterpriseRole.engineer,
      EnterpriseRole.projectManager,
      EnterpriseRole.contractorViewer,
    ];
  }
}

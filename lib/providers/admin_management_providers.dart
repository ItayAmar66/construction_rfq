import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enterprise/membership.dart';
import '../models/enterprise/organization.dart';
import '../models/enterprise/organization_type.dart';
import '../models/enterprise/project.dart';
import '../models/supplier_directory_entry.dart';
import '../repositories/admin_management_repository.dart';
import '../services/admin_management_service.dart';

final adminManagementRepositoryProvider = Provider<AdminManagementRepository>(
  (ref) => AdminManagementRepository(),
);

final adminManagementServiceProvider = Provider<AdminManagementService>(
  (ref) => AdminManagementService(
    repository: ref.watch(adminManagementRepositoryProvider),
  ),
);

final adminOrganizationsProvider = FutureProvider<List<Organization>>((ref) {
  return ref.watch(adminManagementServiceProvider).fetchOrganizations();
});

final adminContractorOrganizationsProvider =
    FutureProvider<List<Organization>>((ref) async {
  final orgs = await ref.watch(adminOrganizationsProvider.future);
  return orgs.where((o) => o.type == OrganizationType.contractor).toList();
});

final adminSupplierOrganizationsProvider =
    FutureProvider<List<Organization>>((ref) async {
  final orgs = await ref.watch(adminOrganizationsProvider.future);
  return orgs.where((o) => o.type == OrganizationType.supplier).toList();
});

class AdminOrgSummary {
  const AdminOrgSummary({
    required this.userCount,
    required this.projectCount,
  });

  final int userCount;
  final int projectCount;
}

final adminOrganizationProvider =
    FutureProvider.family<Organization?, String>((ref, orgId) {
  return ref.watch(adminManagementServiceProvider).fetchOrganizationById(orgId);
});

final adminOrgSummaryProvider =
    FutureProvider.family<AdminOrgSummary, String>((ref, orgId) async {
  final service = ref.watch(adminManagementServiceProvider);
  final memberships = await service.fetchMembershipsForOrg(orgId);
  final projects = await service.fetchProjectsForOrg(orgId);
  return AdminOrgSummary(
    userCount: memberships.length,
    projectCount: projects.length,
  );
});

final adminProjectsForOrgProvider =
    FutureProvider.family<List<Project>, String>((ref, orgId) {
  return ref.watch(adminManagementServiceProvider).fetchProjectsForOrg(orgId);
});

final adminSupplierDirectoryForOrgProvider =
    FutureProvider.family<List<SupplierDirectoryEntry>, String>((ref, orgId) {
  return ref
      .watch(adminManagementServiceProvider)
      .fetchSupplierDirectoryForOrg(orgId);
});

final adminAllMembershipsProvider = FutureProvider<List<Membership>>((ref) {
  return ref.watch(adminManagementServiceProvider).fetchAllMemberships();
});

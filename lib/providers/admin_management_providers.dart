import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enterprise/organization.dart';
import '../models/enterprise/organization_type.dart';
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_request.dart';
import '../models/enterprise/organization_type.dart';
import '../repositories/access_request_repository.dart';
import '../services/user_approval_service.dart';

final accessRequestRepositoryProvider = Provider<AccessRequestRepository>(
  (ref) => AccessRequestRepository(),
);

final userApprovalServiceProvider = Provider<UserApprovalService>(
  (ref) => UserApprovalService(
    accessRequestRepository: ref.watch(accessRequestRepositoryProvider),
  ),
);

final pendingAccessRequestsForOrgProvider =
    FutureProvider.family<List<AccessRequest>, String>((ref, orgId) {
  return ref.watch(userApprovalServiceProvider).fetchPendingForOrg(orgId);
});

final allPendingAccessRequestsProvider = FutureProvider<List<AccessRequest>>((ref) {
  return ref.watch(userApprovalServiceProvider).fetchAllPending();
});

final orgProjectsForApprovalProvider =
    FutureProvider.family<List<dynamic>, String>((ref, orgId) async {
  return ref.watch(userApprovalServiceProvider).fetchProjectsForOrg(orgId);
});

final pendingOrgTypeProvider = Provider.family<OrganizationType, String>((ref, orgId) {
  if (orgId.startsWith('launch-org-supplier') || orgId.contains('supplier')) {
    return OrganizationType.supplier;
  }
  return OrganizationType.contractor;
});

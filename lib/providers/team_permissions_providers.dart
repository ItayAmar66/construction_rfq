import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/enterprise/project.dart';
import '../repositories/admin_management_repository.dart';
import '../services/team_permissions_service.dart';

final teamPermissionsServiceProvider = Provider<TeamPermissionsService>(
  (ref) => TeamPermissionsService(),
);

final teamMemberUserProfileProvider =
    FutureProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(teamPermissionsServiceProvider).fetchUserProfile(uid);
});

final teamOrgProjectsProvider =
    FutureProvider.family<List<Project>, String>((ref, orgId) {
  return ref.watch(teamPermissionsServiceProvider).fetchProjectsForOrg(orgId);
});

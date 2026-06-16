import 'firestore_parsing.dart';
import 'org_id_helpers.dart';

/// Resolves organization ids for direct membership doc reads.
abstract final class UserOrgIdResolver {
  static const _profileOrgFields = [
    'primaryOrgId',
    'orgId',
    'organizationId',
    'companyId',
    'contractorOrgId',
    'supplierOrgId',
  ];

  static Set<String> candidateOrgIds({
    required String uid,
    Map<String, dynamic>? profile,
  }) {
    final out = <String>{};
    if (uid.isNotEmpty) out.add(uid);

    final map = profile;
    if (map == null) return out;

    for (final field in _profileOrgFields) {
      final value = FirestoreParsing.parseNullableString(map[field]);
      if (OrgIdHelpers.isRealOrgId(value)) out.add(value!);
    }

    final membershipOrgIds = map['membershipOrgIds'];
    if (membershipOrgIds is List) {
      for (final entry in membershipOrgIds) {
        final value = entry?.toString().trim() ?? '';
        if (OrgIdHelpers.isRealOrgId(value)) out.add(value);
      }
    }

    return out;
  }
}

import '../utils/firestore_parsing.dart';
import 'enterprise/organization_type.dart';

class AccessRequest {
  const AccessRequest({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.userType,
    required this.requestedOrgType,
    this.requestedOrgId = '',
    this.requestedOrgName = '',
    this.requestedRole = '',
    this.requestedProjectName = '',
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
    this.resolvedByUid,
  });

  final String uid;
  final String email;
  final String fullName;
  final String userType;
  final OrganizationType requestedOrgType;
  final String requestedOrgId;
  final String requestedOrgName;
  final String requestedRole;
  final String requestedProjectName;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? resolvedByUid;

  bool get isPending => status == 'pending';

  factory AccessRequest.fromMap(String id, Map<String, dynamic> map) {
    return AccessRequest(
      uid: FirestoreParsing.parseString(map['uid'], defaultValue: id),
      email: FirestoreParsing.parseString(map['email']),
      fullName: FirestoreParsing.parseString(
        map['fullName'] ?? map['name'],
      ),
      userType: FirestoreParsing.parseString(map['userType']),
      requestedOrgType: OrganizationType.fromValue(
            map['requestedOrgType']?.toString(),
          ) ??
          OrganizationType.contractor,
      requestedOrgId: FirestoreParsing.parseString(map['requestedOrgId']),
      requestedOrgName: FirestoreParsing.parseString(map['requestedOrgName']),
      requestedRole: FirestoreParsing.parseString(map['requestedRole']),
      requestedProjectName:
          FirestoreParsing.parseString(map['requestedProjectName']),
      status: FirestoreParsing.parseString(map['status'], defaultValue: 'pending'),
      createdAt: FirestoreParsing.parseDate(map['createdAt']),
      updatedAt: FirestoreParsing.parseDate(map['updatedAt']),
      resolvedByUid: FirestoreParsing.parseNullableString(map['resolvedByUid']),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'fullName': fullName,
        'userType': userType,
        'requestedOrgType': requestedOrgType.value,
        'requestedOrgId': requestedOrgId,
        'requestedOrgName': requestedOrgName,
        if (requestedRole.isNotEmpty) 'requestedRole': requestedRole,
        if (requestedProjectName.isNotEmpty)
          'requestedProjectName': requestedProjectName,
        'status': status,
        if (resolvedByUid != null) 'resolvedByUid': resolvedByUid,
      };
}

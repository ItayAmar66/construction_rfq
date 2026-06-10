import '../../utils/firestore_parsing.dart';
import 'organization_type.dart';

class Organization {
  const Organization({
    required this.id,
    required this.type,
    required this.name,
    required this.ownerUid,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final OrganizationType type;
  final String name;
  final String ownerUid;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Organization.fromMap(String id, Map<String, dynamic> map) {
    return Organization(
      id: id,
      type: OrganizationType.fromValue(map['type']?.toString()) ??
          OrganizationType.contractor,
      name: FirestoreParsing.parseString(map['name']),
      ownerUid: FirestoreParsing.parseString(map['ownerUid']),
      status: FirestoreParsing.parseString(map['status'], defaultValue: 'active'),
      createdAt: FirestoreParsing.parseDate(map['createdAt']),
      updatedAt: FirestoreParsing.parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.value,
        'name': name,
        'ownerUid': ownerUid,
        'status': status,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };
}

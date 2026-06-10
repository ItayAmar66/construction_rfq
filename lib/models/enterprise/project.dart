import '../../utils/firestore_parsing.dart';

/// Contractor project/site — owner-scoped until org hierarchy migration.
class Project {
  const Project({
    required this.id,
    required this.ownerUid,
    required this.name,
    this.orgId,
    this.companyName,
    this.location = '',
    this.cityOrArea = '',
    this.notes,
    this.status = 'active',
    this.managerUids = const [],
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUid;
  final String? orgId;
  final String? companyName;
  final String name;
  final String location;
  final String cityOrArea;
  final String? notes;
  final String status;
  final List<String> managerUids;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  String get locationLine {
    final parts = <String>[];
    if (location.trim().isNotEmpty) parts.add(location.trim());
    if (cityOrArea.trim().isNotEmpty) parts.add(cityOrArea.trim());
    return parts.join(' · ');
  }

  String get displayLabel {
    if (locationLine.isEmpty) return name;
    return '$name · $locationLine';
  }

  /// Snapshot written onto quoteRequests for suppliers.
  String get snapshotLocation => locationLine;

  factory Project.fromMap(String id, Map<String, dynamic> map) {
    final legacySite = FirestoreParsing.parseString(map['siteName']);
    final legacyCity = FirestoreParsing.parseString(map['city']);
    return Project(
      id: id,
      ownerUid: FirestoreParsing.parseString(
        map['ownerUid'] ?? map['createdBy'],
      ),
      orgId: FirestoreParsing.parseNullableString(map['orgId']),
      companyName: FirestoreParsing.parseNullableString(map['companyName']),
      name: FirestoreParsing.parseString(map['name']),
      location: FirestoreParsing.parseString(
        map['location'].toString().isNotEmpty ? map['location'] : legacySite,
      ),
      cityOrArea: FirestoreParsing.parseString(
        map['cityOrArea'].toString().isNotEmpty ? map['cityOrArea'] : legacyCity,
      ),
      notes: FirestoreParsing.parseNullableString(map['notes']),
      status: FirestoreParsing.parseString(map['status'], defaultValue: 'active'),
      managerUids: FirestoreParsing.parseStringList(map['managerUids']),
      createdBy: FirestoreParsing.parseNullableString(map['createdBy']),
      createdAt: FirestoreParsing.parseDate(map['createdAt']),
      updatedAt: FirestoreParsing.parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        if (orgId != null && orgId!.isNotEmpty) 'orgId': orgId,
        if (companyName != null && companyName!.isNotEmpty)
          'companyName': companyName,
        'name': name,
        if (location.isNotEmpty) 'location': location,
        if (cityOrArea.isNotEmpty) 'cityOrArea': cityOrArea,
        if (location.isNotEmpty) 'siteName': location,
        if (cityOrArea.isNotEmpty) 'city': cityOrArea,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'status': status,
        'managerUids': managerUids,
        if (createdBy != null) 'createdBy': createdBy,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };
}

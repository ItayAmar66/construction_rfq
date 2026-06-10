import '../utils/firestore_parsing.dart';

/// Public supplier profile for contractor targeting (no private user data).
class SupplierDirectoryEntry {
  const SupplierDirectoryEntry({
    required this.uid,
    required this.displayName,
    this.orgId = '',
    this.city = '',
    this.categoryIds = const [],
    this.serviceAreas = const [],
    this.active = true,
  });

  final String uid;
  final String displayName;
  final String orgId;
  final String city;
  final List<String> categoryIds;
  final List<String> serviceAreas;
  final bool active;

  factory SupplierDirectoryEntry.fromMap(String uid, Map<String, dynamic> map) {
    return SupplierDirectoryEntry(
      uid: uid,
      displayName: FirestoreParsing.parseString(
        map['displayName'] ?? map['fullName'] ?? map['name'],
      ),
      orgId: FirestoreParsing.parseString(map['orgId']),
      city: FirestoreParsing.parseString(map['city']),
      categoryIds: FirestoreParsing.parseStringList(
        map['categoryIds'] ?? map['supplierCategoryIds'],
      ),
      serviceAreas: FirestoreParsing.parseStringList(map['serviceAreas']),
      active: FirestoreParsing.parseBool(map['active'], defaultValue: true),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import 'account_status.dart';
import 'supplier_public_stats.dart';
import 'supplier_quote_defaults.dart';
import 'user_type.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.userType,
    required this.city,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.accountStatus = AccountStatus.active,
    this.verified = false,
    this.serviceAreas = const [],
    this.supplierCategoryIds = const [],
    this.stats = SupplierPublicStats.defaults,
    this.supplierDefaults = const SupplierQuoteDefaults(),
    this.supplierOrgId,
    this.requestedOrgId,
    this.requestedOrgName,
    this.requestedOrgType,
    this.requestedRole,
    this.requestedProjectName,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserType userType;
  final String city;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final AccountStatus accountStatus;
  final bool verified;
  final List<String> serviceAreas;
  final List<String> supplierCategoryIds;
  final SupplierPublicStats stats;
  final SupplierQuoteDefaults supplierDefaults;
  final String? supplierOrgId;
  final String? requestedOrgId;
  final String? requestedOrgName;
  final String? requestedOrgType;
  final String? requestedRole;
  final String? requestedProjectName;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    final areasRaw = map['serviceAreas'];
    final areas = areasRaw is List
        ? areasRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final categoriesRaw = map['supplierCategoryIds'];
    final categories = categoriesRaw is List
        ? categoriesRaw
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    final statsRaw = map['stats'];
    final stats = statsRaw is Map<String, dynamic>
        ? SupplierPublicStats.fromMap(statsRaw)
        : SupplierPublicStats.defaults;

    return AppUser(
      id: map['uid'] as String? ?? id,
      fullName: map['name'] as String? ??
          map['fullName'] as String? ??
          map['businessName'] as String? ??
          '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      userType: UserType.fromString(map['userType'] as String? ?? ''),
      city: map['city'] as String? ?? '',
      notes: map['notes'] as String?,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']),
      accountStatus: AccountStatus.fromValue(
        map['accountStatus'] as String? ?? map['status'] as String?,
      ),
      verified: map['verified'] == true,
      serviceAreas: areas.isEmpty && (map['city'] as String?)?.isNotEmpty == true
          ? [map['city'] as String]
          : areas,
      supplierCategoryIds: categories,
      stats: stats,
      supplierDefaults: SupplierQuoteDefaults.fromMap(
        map['supplierDefaults'] is Map<String, dynamic>
            ? map['supplierDefaults'] as Map<String, dynamic>
            : null,
      ),
      supplierOrgId: map['orgId'] as String? ??
          map['supplierOrgId'] as String? ??
          map['primaryOrgId'] as String?,
      requestedOrgId: map['requestedOrgId'] as String?,
      requestedOrgName: map['requestedOrgName'] as String?,
      requestedOrgType: map['requestedOrgType'] as String?,
      requestedRole: map['requestedRole'] as String?,
      requestedProjectName: map['requestedProjectName'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toRegistrationMap({
    String? requestedOrgId,
    String? requestedOrgName,
    String? requestedOrgType,
    String? requestedRole,
    String? requestedProjectName,
  }) {
    return {
      'uid': id,
      'name': fullName,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'userType': userType.value,
      'city': city,
      'notes': notes,
      'verified': false,
      'accountStatus': AccountStatus.pendingApproval.value,
      if (requestedOrgId != null && requestedOrgId.isNotEmpty)
        'requestedOrgId': requestedOrgId,
      if (requestedOrgName != null && requestedOrgName.isNotEmpty)
        'requestedOrgName': requestedOrgName,
      if (requestedOrgType != null && requestedOrgType.isNotEmpty)
        'requestedOrgType': requestedOrgType,
      if (requestedRole != null && requestedRole.isNotEmpty)
        'requestedRole': requestedRole,
      if (requestedProjectName != null && requestedProjectName.isNotEmpty)
        'requestedProjectName': requestedProjectName,
      'serviceAreas': serviceAreas.isEmpty ? [city] : serviceAreas,
      'stats': stats.toMap(),
      'supplierDefaults': supplierDefaults.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap({
    required String fullName,
    required String phone,
    required String city,
    String? notes,
  }) {
    return {
      'name': fullName,
      'fullName': fullName,
      'phone': phone,
      'city': city,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

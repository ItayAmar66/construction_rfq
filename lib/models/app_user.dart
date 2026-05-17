import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
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
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toRegistrationMap() {
    return {
      'uid': id,
      'name': fullName,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'userType': userType.value,
      'city': city,
      'notes': notes,
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

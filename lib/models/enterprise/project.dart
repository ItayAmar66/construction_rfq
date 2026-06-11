import '../../utils/firestore_parsing.dart';
import 'project_status.dart';

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
    this.status = ProjectStatus.active,
    this.statusBeforeDeletion,
    this.managerUids = const [],
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.deletionRequestedAt,
    this.deletionScheduledFor,
    this.deletionRequestedByUid,
    this.deletedAt,
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
  final String? statusBeforeDeletion;
  final List<String> managerUids;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final DateTime? deletionRequestedAt;
  final DateTime? deletionScheduledFor;
  final String? deletionRequestedByUid;
  final DateTime? deletedAt;

  bool get isActive => status == ProjectStatus.active;

  bool get isCompleted => status == ProjectStatus.completed;

  bool get isDeletionPending => status == ProjectStatus.deletionPending;

  bool get isArchived => status == ProjectStatus.archived;

  bool get isDeleted => deletedAt != null;

  bool get showOnDashboard => ProjectStatus.isVisibleOnDashboard(status);

  String get statusLabel => ProjectStatus.label(status);

  Duration? get deletionTimeRemaining {
    final target = deletionScheduledFor;
    if (target == null || !isDeletionPending) return null;
    final remaining = target.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

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

  String get snapshotLocation => locationLine;

  Project copyWith({
    String? status,
    String? statusBeforeDeletion,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? deletionRequestedAt,
    DateTime? deletionScheduledFor,
    String? deletionRequestedByUid,
    DateTime? deletedAt,
    bool clearCompletedAt = false,
    bool clearDeletionFields = false,
  }) {
    return Project(
      id: id,
      ownerUid: ownerUid,
      orgId: orgId,
      companyName: companyName,
      name: name,
      location: location,
      cityOrArea: cityOrArea,
      notes: notes,
      status: status ?? this.status,
      statusBeforeDeletion:
          clearDeletionFields ? null : (statusBeforeDeletion ?? this.statusBeforeDeletion),
      managerUids: managerUids,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      deletionRequestedAt: clearDeletionFields
          ? null
          : (deletionRequestedAt ?? this.deletionRequestedAt),
      deletionScheduledFor: clearDeletionFields
          ? null
          : (deletionScheduledFor ?? this.deletionScheduledFor),
      deletionRequestedByUid: clearDeletionFields
          ? null
          : (deletionRequestedByUid ?? this.deletionRequestedByUid),
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

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
      status: FirestoreParsing.parseString(
        map['status'],
        defaultValue: ProjectStatus.active,
      ),
      statusBeforeDeletion:
          FirestoreParsing.parseNullableString(map['statusBeforeDeletion']),
      managerUids: FirestoreParsing.parseStringList(map['managerUids']),
      createdBy: FirestoreParsing.parseNullableString(map['createdBy']),
      createdAt: FirestoreParsing.parseDate(map['createdAt']),
      updatedAt: FirestoreParsing.parseDate(map['updatedAt']),
      completedAt: FirestoreParsing.parseDate(map['completedAt']),
      deletionRequestedAt:
          FirestoreParsing.parseDate(map['deletionRequestedAt']),
      deletionScheduledFor:
          FirestoreParsing.parseDate(map['deletionScheduledFor']),
      deletionRequestedByUid:
          FirestoreParsing.parseNullableString(map['deletionRequestedByUid']),
      deletedAt: FirestoreParsing.parseDate(map['deletedAt']),
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
        if (statusBeforeDeletion != null && statusBeforeDeletion!.isNotEmpty)
          'statusBeforeDeletion': statusBeforeDeletion,
        'managerUids': managerUids,
        if (createdBy != null) 'createdBy': createdBy,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
        if (completedAt != null) 'completedAt': completedAt,
        if (deletionRequestedAt != null)
          'deletionRequestedAt': deletionRequestedAt,
        if (deletionScheduledFor != null)
          'deletionScheduledFor': deletionScheduledFor,
        if (deletionRequestedByUid != null &&
            deletionRequestedByUid!.isNotEmpty)
          'deletionRequestedByUid': deletionRequestedByUid,
        if (deletedAt != null) 'deletedAt': deletedAt,
      };
}

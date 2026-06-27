import '../../utils/firestore_parsing.dart';
import 'organization_type.dart';

/// Persisted audit trail entry (client-written; server audit recommended for production).
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.actorUid,
    this.actorEmail,
    this.actorName,
    this.orgId,
    this.orgType,
    this.projectId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.summaryHebrew,
    this.metadata = const {},
    this.createdAt,
  });

  final String id;
  final String actorUid;
  final String? actorEmail;
  final String? actorName;
  final String? orgId;
  final OrganizationType? orgType;
  final String? projectId;
  final String entityType;
  final String entityId;
  final String action;
  final String summaryHebrew;
  final Map<String, String> metadata;
  final DateTime? createdAt;

  factory AuditEvent.fromMap(String id, Map<String, dynamic> map) {
    final rawMeta = map['metadata'];
    final metadata = rawMeta is Map
        ? rawMeta.map((k, v) => MapEntry(k.toString(), v.toString()))
        : const <String, String>{};

    return AuditEvent(
      id: id,
      actorUid: FirestoreParsing.parseString(map['actorUid']),
      actorEmail: FirestoreParsing.parseNullableString(map['actorEmail']),
      actorName: FirestoreParsing.parseNullableString(map['actorName']),
      orgId: FirestoreParsing.parseNullableString(map['orgId']),
      orgType: map['orgType'] != null
          ? OrganizationType.fromValue(map['orgType']?.toString())
          : null,
      projectId: FirestoreParsing.parseNullableString(map['projectId']),
      entityType: FirestoreParsing.parseString(map['entityType']),
      entityId: FirestoreParsing.parseString(map['entityId']),
      action: FirestoreParsing.parseString(map['action']),
      summaryHebrew: FirestoreParsing.parseString(map['summaryHebrew']),
      metadata: metadata,
      createdAt: FirestoreParsing.parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'actorUid': actorUid,
        if (actorEmail != null) 'actorEmail': actorEmail,
        if (actorName != null) 'actorName': actorName,
        if (orgId != null) 'orgId': orgId,
        if (orgType != null) 'orgType': orgType!.value,
        if (projectId != null) 'projectId': projectId,
        'entityType': entityType,
        'entityId': entityId,
        'action': action,
        'summaryHebrew': summaryHebrew,
        if (metadata.isNotEmpty) 'metadata': metadata,
        if (createdAt != null) 'createdAt': createdAt,
      };
}

/// Known audit action constants.
abstract final class AuditAction {
  static const invitationCreated = 'invitationCreated';
  static const invitationCancelled = 'invitationCancelled';
  static const invitationAccepted = 'invitationAccepted';
  static const roleChanged = 'roleChanged';
  static const membershipApproved = 'membershipApproved';
  static const membershipRejected = 'membershipRejected';
  static const projectAssigned = 'projectAssigned';
  static const projectAssignmentUpdated = 'projectAssignmentUpdated';
  static const projectAssignmentRemoved = 'projectAssignmentRemoved';
  static const projectCompleted = 'projectCompleted';
  static const projectDeletionRequested = 'projectDeletionRequested';
  static const projectDeletionCancelled = 'projectDeletionCancelled';
  static const projectCreated = 'projectCreated';
  static const rfqSent = 'rfqSent';
  static const quoteSubmitted = 'quoteSubmitted';
  static const quoteApproved = 'quoteApproved';
  static const quoteRejected = 'quoteRejected';
  static const orderMarkedShipped = 'orderMarkedShipped';
  static const shipmentReceiptConfirmed = 'shipmentReceiptConfirmed';
  static const adminApprovedContractorManager = 'adminApprovedContractorManager';
  static const adminApprovedSupplierManager = 'adminApprovedSupplierManager';
  static const procurementApprovedRfq = 'procurementApprovedRfq';
  static const procurementRejectedRfq = 'procurementRejectedRfq';
  static const procurementAddedEngineer = 'procurementAddedEngineer';
  static const supplierOwnerAddedProcurement = 'supplierOwnerAddedProcurement';
}

abstract final class AuditEntityType {
  static const invitation = 'invitation';
  static const membership = 'membership';
  static const projectAssignment = 'projectAssignment';
  static const project = 'project';
  static const rfq = 'rfq';
  static const quote = 'quote';
  static const order = 'order';
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/audit_repository.dart';
import '../services/admin_approval_service.dart';

final adminApprovalServiceProvider = Provider<AdminApprovalService>(
  (ref) => AdminApprovalService(
    auditRepository: ref.watch(auditRepositoryProvider),
  ),
);

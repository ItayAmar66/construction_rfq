import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/quote_request.dart';
import '../../models/quote_status.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/project_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/app_theme.dart';
import '../../utils/user_facing_error.dart';
import '../design_system/app_text_field.dart';
import '../design_system/primary_button.dart';
import '../design_system/secondary_button.dart';
import '../design_system/tertiary_button.dart';
import '../procurement_panel.dart';
import '../procurement_supplier_send_dialog.dart';
import '../status_chip.dart';

/// Pending engineer requests awaiting procurement or manager approval.
class PendingProcurementRequestsSection extends ConsumerWidget {
  const PendingProcurementRequestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canApprove = ref.watch(canApproveProcurementRfqProvider);
    if (!canApprove) return const SizedBox.shrink();

    final pendingAsync = ref.watch(orgPendingProcurementRequestsProvider);
    return pendingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (requests) {
        if (requests.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProcurementScreenIntro(
              title: 'בקשות ממתינות לאישור',
              subtitle: 'בקשות מהנדסים שממתינות לאישור רכש לפני שליחה לספקים',
              icon: Icons.pending_actions_outlined,
            ),
            const SizedBox(height: 8),
            ...requests.map(
              (request) => _PendingRequestCard(request: request),
            ),
          ],
        );
      },
    );
  }
}

class _PendingRequestCard extends ConsumerStatefulWidget {
  const _PendingRequestCard({required this.request});

  final QuoteRequest request;

  @override
  ConsumerState<_PendingRequestCard> createState() =>
      _PendingRequestCardState();
}

class _PendingRequestCardState extends ConsumerState<_PendingRequestCard> {
  bool _busy = false;

  Future<void> _approve() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final session = ref.read(authSessionProvider).valueOrNull;
      await ref.read(quoteServiceProvider).approveProcurementRequest(
            requestId: widget.request.id,
            actorUid: session?.uid ?? '',
            orgId: ref.read(primaryOrgIdProvider),
          );
      ref.invalidate(orgPendingProcurementRequestsProvider);
      ref.invalidate(customerRequestsProvider);
      ref.invalidate(contractorOrgRequestsProvider);
      if (mounted) {
        showAppSnackBar(context, message: 'הבקשה אושרה — ניתן לשלוח לספקים');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: userFacingError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    final note = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('החזר למהנדס'),
          content: AppTextField(
            controller: controller,
            label: 'הערה למהנדס (אופציונלי)',
            maxLines: 3,
          ),
          actions: [
            TertiaryButton(
              label: 'ביטול',
              onPressed: () => Navigator.pop(ctx),
            ),
            PrimaryButton(
              label: 'דחה',
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              expand: false,
            ),
          ],
        );
      },
    );
    if (note == null && !mounted) return;
    setState(() => _busy = true);
    try {
      final session = ref.read(authSessionProvider).valueOrNull;
      await ref.read(quoteServiceProvider).rejectProcurementRequest(
            requestId: widget.request.id,
            actorUid: session?.uid ?? '',
            note: note?.isEmpty == true ? null : note,
            orgId: ref.read(primaryOrgIdProvider),
          );
      ref.invalidate(orgPendingProcurementRequestsProvider);
      ref.invalidate(customerRequestsProvider);
      ref.invalidate(contractorOrgRequestsProvider);
      if (mounted) {
        showAppSnackBar(context, message: 'הבקשה הוחזרה למהנדס');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: userFacingError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendToSuppliers() async {
    if (_busy) return;
    if (widget.request.status != QuoteRequestStatus.procurementApproved) {
      return;
    }
    final selection = await showProcurementSupplierSendDialog(context);
    if (selection == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final session = ref.read(authSessionProvider).valueOrNull;
      if (session == null) throw Exception('לא מחובר');
      final actorUid = session.uid;
      if (actorUid == null || actorUid.isEmpty) {
        throw Exception('לא מחובר');
      }
      final memberships =
          ref.read(currentUserMembershipsProvider).valueOrNull ?? const [];
      await ref.read(quoteServiceProvider).sendPendingApprovalToSuppliers(
            requestId: widget.request.id,
            actorUid: actorUid,
            memberships: memberships,
            orgId: ref.read(primaryOrgIdProvider),
            invitedSupplierIds: selection.ids,
            invitedSupplierNames: selection.names,
            invitedSupplierOrgIds: selection.orgIds,
          );
      ref.invalidate(orgPendingProcurementRequestsProvider);
      ref.invalidate(customerRequestsProvider);
      ref.invalidate(contractorOrgRequestsProvider);
      if (mounted) {
        showAppSnackBar(context, message: 'הבקשה נשלחה לספקים');
        context.push('/compare-quotes/${widget.request.id}');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: userFacingError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final fmt = DateFormat('dd/MM HH:mm', 'he');
    final isApproved = request.status == QuoteRequestStatus.procurementApproved;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.projectName?.isNotEmpty == true
                        ? request.projectName!
                        : request.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip.request(request.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${request.items.length} פריטים · ${fmt.format(request.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 10),
            if (isApproved)
              PrimaryButton.icon(
                icon: Icons.send_outlined,
                label: 'המשך לשליחת בקשה לספקים',
                onPressed: _busy ? null : _sendToSuppliers,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'מאושר',
                      onPressed: _busy ? null : _approve,
                      isLoading: _busy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SecondaryButton(
                      label: 'דחה / החזר למהנדס',
                      onPressed: _busy ? null : _reject,
                      expand: true,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

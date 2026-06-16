import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/quote_request.dart';
import '../../models/quote_status.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/app_theme.dart';
import '../../utils/user_facing_error.dart';
import '../procurement_panel.dart';
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
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'הערה למהנדס (אופציונלי)',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ביטול'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('דחה'),
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
    setState(() => _busy = true);
    try {
      final session = ref.read(authSessionProvider).valueOrNull;
      if (session == null) throw Exception('לא מחובר');
      final memberships =
          ref.read(currentUserMembershipsProvider).valueOrNull ?? const [];
      await ref.read(quoteServiceProvider).sendPendingApprovalToSuppliers(
            requestId: widget.request.id,
            actorUid: session.uid,
            memberships: memberships,
            orgId: ref.read(primaryOrgIdProvider),
          );
      ref.invalidate(orgPendingProcurementRequestsProvider);
      ref.invalidate(customerRequestsProvider);
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
                StatusChip(status: request.status),
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
              FilledButton.icon(
                onPressed: _busy ? null : _sendToSuppliers,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('המשך לשליחת בקשה לספקים'),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _approve,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('מאושר'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _reject,
                      child: const Text('דחה / החזר למהנדס'),
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

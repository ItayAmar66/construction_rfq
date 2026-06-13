import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/quote_request.dart';
import '../../models/request_type.dart';
import '../../providers/providers.dart';
import '../../utils/request_display_helpers.dart';
import '../../utils/supplier_targeting_helpers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/count_badge.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/procurement_panel.dart';
import '../../widgets/mark_seen_on_open.dart';
import '../../widgets/tender_badge.dart';

class IncomingRequestsScreen extends ConsumerWidget {
  const IncomingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingRequestsProvider);
    final incomingCount = ref.watch(incomingRequestsCountProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');
    final supplierId =
        ref.watch(authSessionProvider).valueOrNull?.profile?.id ?? '';
    final supplier = ref.watch(authSessionProvider).valueOrNull?.profile;

    return MarkSeenOnOpen(
      onMarkSeen: (ref) async {
        final user = ref.read(authSessionProvider).valueOrNull?.profile;
        if (user == null) return;
        await ref
            .read(quoteServiceProvider)
            .markIncomingRequestsSeenBySupplier(user.id);
      },
      child: Scaffold(
        appBar: SecondaryAppBar(
          title: HebrewStrings.incomingRequests,
          count: incomingCount,
        ),
        body: requestsAsync.when(
          loading: () =>
              const LoadingView(message: HebrewStrings.loadingRequests),
          error: (_, __) => AppErrorCenter(
            onRetry: () => ref.invalidate(incomingRequestsProvider),
          ),
          data: (requests) {
            final visible = supplier == null
                ? requests
                : requests
                    .where(
                      (r) => SupplierTargetingHelpers.shouldShowToSupplier(
                        request: r,
                        supplierId: supplier.id,
                        supplierName: supplier.fullName,
                      ),
                    )
                    .toList();

            if (visible.isEmpty) {
              return ProcurementPanel(
                child: EmptyState(
                  message: HebrewStrings.emptyIncoming,
                  icon: Icons.inbox_outlined,
                  hint: HebrewStrings.emptyIncomingHint,
                  accentGradient: AppTheme.gradientTeal,
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: ProcurementScreenIntro(
                    title: HebrewStrings.incomingRequests,
                    subtitle: 'בקשות RFQ פתוחות לתמחור — מדויק או חלופה',
                    icon: Icons.inbox_outlined,
                    tint: AppTheme.navy,
                  ),
                ),
                Expanded(
                  child: DateGroupedListView<QuoteRequest>(
                    items: visible,
                    dateFor: (r) => r.createdAt,
                    itemBuilder: (context, request) {
                      final unseen = request.isUnseenBySupplier(supplierId);
                      final closedTender =
                          request.isTender && !request.isTenderActive;
                      final relevance = supplier == null
                          ? null
                          : SupplierTargetingHelpers.relevanceLabel(
                              supplier: supplier,
                              request: request,
                              items: request.items,
                            );
                      return Opacity(
                        opacity: closedTender ? 0.65 : 1,
                        child: AppListCard(
                          onTap: closedTender
                              ? null
                              : () {
                                  final path =
                                      request.requestType == RequestType.tender
                                          ? '/tender/${request.id}'
                                          : '/respond/${request.id}';
                                  context.push(path);
                                },
                          title: request.customerName,
                          subtitle:
                              RequestDisplayHelpers.supplierRequestSubtitle(
                                  request),
                          meta:
                              '${request.requestType.label} · ${dateFormat.format(request.createdAt)}',
                          topChip: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (closedTender) ...[
                                _ClosedTenderChip(),
                                const SizedBox(width: 6),
                              ],
                              if (request.isTender && !closedTender)
                                const TenderBadge(compact: true),
                              if (relevance != null) ...[
                                if (request.isTender) const SizedBox(width: 6),
                                _RelevanceChip(label: relevance),
                              ],
                            ],
                          ),
                          badge: unseen
                              ? const CountBadge(count: 1, compact: true)
                              : null,
                          trailing: closedTender
                              ? const _ClosedTenderChip()
                              : FilledButton.tonal(
                                  onPressed: () {
                                    final path = request.requestType ==
                                            RequestType.tender
                                        ? '/tender/${request.id}'
                                        : '/respond/${request.id}';
                                    context.push(path);
                                  },
                                  child: const Text(
                                      HebrewStrings.respondToRequest),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ClosedTenderChip extends StatelessWidget {
  const _ClosedTenderChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.35)),
      ),
      child: const Text(
        'המכרז נסגר',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.amber,
        ),
      ),
    );
  }
}

class _RelevanceChip extends StatelessWidget {
  const _RelevanceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isMatch = label == 'מתאים לתחומי הספק';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isMatch ? AppTheme.teal : AppTheme.navy).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isMatch ? AppTheme.teal : AppTheme.navy,
        ),
      ),
    );
  }
}

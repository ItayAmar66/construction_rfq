import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/quote_request.dart';
import '../../models/request_type.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../utils/request_display_helpers.dart';
import '../../utils/supplier_targeting_helpers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/filterable_list_view.dart';
import '../../widgets/rfq_list_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/procurement_panel.dart';
import '../../widgets/mark_seen_on_open.dart';

import '../../widgets/status_chip.dart';
import '../../widgets/design_system/design_system.dart';
class IncomingRequestsScreen extends ConsumerWidget {
  const IncomingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingRequestsProvider);
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
                        supplierOrgId: ref.watch(primaryOrgIdProvider) ??
                            supplier.supplierOrgId,
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

            final filters = <ListFilter<QuoteRequest>>[
              ListFilter<QuoteRequest>.all(),
              ListFilter<QuoteRequest>(
                label: HebrewStrings.filterTenders,
                color: AppTheme.amber,
                test: (r) => r.isTender,
              ),
              ListFilter<QuoteRequest>(
                label: HebrewStrings.filterRegular,
                color: AppTheme.navy,
                test: (r) => !r.isTender,
              ),
              if (supplier != null)
                ListFilter<QuoteRequest>(
                  label: HebrewStrings.filterRelevant,
                  color: AppTheme.teal,
                  // "Relevant to me" = invited or category-matched, i.e. any
                  // label other than the open-to-all one.
                  test: (r) =>
                      SupplierTargetingHelpers.relevanceLabel(
                        supplier: supplier,
                        request: r,
                        items: r.items,
                      ) !=
                      'פתוח לכל הספקים',
                ),
            ];

            return FilterableListView<QuoteRequest>(
              items: visible,
              dateFor: (r) => r.createdAt,
              searchHint: HebrewStrings.searchIncomingHint,
              searchTextFor: _incomingSearchText,
              filters: filters,
              header: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ProcurementScreenIntro(
                  title: HebrewStrings.incomingRequests,
                  subtitle: 'בקשות RFQ פתוחות לתמחור — מדויק או חלופה',
                  icon: Icons.inbox_outlined,
                  tint: AppTheme.navy,
                ),
              ),
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
                final path = request.requestType == RequestType.tender
                    ? '/tender/${request.id}'
                    : '/respond/${request.id}';
                return Opacity(
                  opacity: closedTender ? 0.65 : 1,
                  child: RfqListCard(
                    onTap: closedTender ? null : () => context.push(path),
                    number: RequestDisplayHelpers.shortNumber(request),
                    title: request.customerName,
                    subtitle:
                        RequestDisplayHelpers.supplierRequestSubtitle(request),
                    meta:
                        '${request.requestType.label} · ${dateFormat.format(request.createdAt)}',
                    chips: [
                      if (request.isTender && !closedTender)
                        StatusChip.tender(dense: true),
                      if (relevance != null) _RelevanceChip(label: relevance),
                    ],
                    badge: unseen ? StatusChip.count(1, dense: true) : null,
                    status: closedTender ? const _ClosedTenderChip() : null,
                    action: closedTender
                        ? null
                        : PrimaryButton.tonal(
                            label: HebrewStrings.respondToRequest,
                            expand: false,
                            onPressed: () => context.push(path),
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String _incomingSearchText(QuoteRequest r) => [
      r.customerName,
      RequestDisplayHelpers.supplierRequestSubtitle(r),
      r.projectName ?? '',
      r.requestType.label,
    ].join(' ');

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

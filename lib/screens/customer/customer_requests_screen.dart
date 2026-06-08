import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/quote_request.dart';
import '../../models/request_type.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/quote_count_label.dart';
import '../../utils/request_display_helpers.dart';
import '../../utils/supplier_targeting_helpers.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/count_badge.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/mark_seen_on_open.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/tender_badge.dart';

class CustomerRequestsScreen extends ConsumerWidget {
  const CustomerRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(customerRequestsProvider);
    final quoteCountsAsync = ref.watch(quoteCountByRequestProvider);
    final unreadCountsAsync = ref.watch(unreadQuoteCountByRequestProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');
    final quoteCounts = quoteCountsAsync.valueOrNull ?? {};
    final unreadCounts = unreadCountsAsync.valueOrNull ?? {};
    final requestsCount = ref.watch(customerRequestsCountProvider);

    return MarkSeenOnOpen(
      onMarkSeen: (ref) async {
        final user = ref.read(authSessionProvider).valueOrNull?.profile;
        if (user == null) return;
        await ref
            .read(quoteServiceProvider)
            .markCustomerRequestsStatusSeen(user.id);
      },
      child: Scaffold(
        appBar: SecondaryAppBar(
          title: HebrewStrings.myRequests,
          count: requestsCount,
        ),
        body: requestsAsync.when(
          loading: () => const LoadingView(),
          error: (_, __) => AppErrorCenter(
            message: HebrewStrings.errorLoadRequests,
            onRetry: () => ref.invalidate(customerRequestsProvider),
          ),
          data: (requests) {
            if (requests.isEmpty) {
              return const EmptyState(
                message: HebrewStrings.emptyRequests,
                icon: Icons.assignment_outlined,
                hint: HebrewStrings.emptyRequestsHint,
                accentGradient: AppTheme.gradientNavy,
              );
            }
            return DateGroupedListView<QuoteRequest>(
              items: requests,
              dateFor: (r) => r.sortDate,
              itemBuilder: (context, request) {
                final quoteCount = quoteCounts[request.id] ?? 0;
                final unreadCount = unreadCounts[request.id] ?? 0;
                return _RequestCard(
                  request: request,
                  quoteCount: quoteCount,
                  unreadQuoteCount: unreadCount,
                  dateFormat: dateFormat,
                  onTap: () => context.push('/compare-quotes/${request.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.quoteCount,
    required this.unreadQuoteCount,
    required this.dateFormat,
    required this.onTap,
  });

  final QuoteRequest request;
  final int quoteCount;
  final int unreadQuoteCount;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final countLabel = receivedQuotesCountLabel(quoteCount);
    final hasStatusUpdate = request.hasUnreadStatusForCustomer();
    final showBadge = unreadQuoteCount > 0 || hasStatusUpdate;

    return AppListCard(
      onTap: onTap,
      title: RequestDisplayHelpers.customerRequestTitle(request),
      subtitle: _requestSubtitle(request),
      topChip: request.requestType == RequestType.tender
          ? const TenderBadge(compact: true)
          : null,
      meta:
          '${HebrewStrings.requestDate}: ${dateFormat.format(request.createdAt)} · $countLabel',
      badge: showBadge
          ? CountBadge(
              count: unreadQuoteCount > 0 ? unreadQuoteCount : 1,
              compact: true,
            )
          : null,
      trailing: StatusChip(status: request.status),
    );
  }
}

String _requestSubtitle(QuoteRequest request) {
  final parts = <String>[RequestDisplayHelpers.customerRequestSubtitle(request)];
  if (request.invitedSupplierNames.isNotEmpty) {
    parts.add('יעד: ${request.invitedSupplierNames.join(' · ')}');
  } else if (request.invitedSupplierIds.isNotEmpty) {
    parts.add('יעד: ${request.invitedSupplierIds.length} ספקים');
  } else {
    parts.add(
      SupplierTargetingHelpers.customerTargetingSummary(items: request.items).title,
    );
  }
  return parts.join(' · ');
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/quote_request.dart';
import '../../models/quote_status.dart';
import '../../models/request_type.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../screens/auth/no_permission_screen.dart';
import '../../utils/app_theme.dart';
import '../../utils/customer_requests_access.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/quote_count_label.dart';
import '../../utils/request_display_helpers.dart';
import '../../utils/request_status_group.dart';
import '../../utils/supplier_targeting_helpers.dart';
import '../../utils/project_display_helpers.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/filterable_list_view.dart';
import '../../widgets/rfq_list_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/mark_seen_on_open.dart';
import '../../widgets/status_chip.dart';
import '../../utils/platform_access_gate.dart';

class CustomerRequestsScreen extends ConsumerWidget {
  const CustomerRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(platformAccessGateProvider);
    if (gate == PlatformAccessGate.loading) {
      return const Scaffold(
        body: LoadingView(message: HebrewStrings.loadingRequests),
      );
    }
    if (gate != PlatformAccessGate.granted) {
      return const NoPermissionScreen();
    }

    final requestsAsync = ref.watch(customerRequestsProvider);
    final quoteCountsAsync = ref.watch(quoteCountByRequestProvider);
    final unreadCountsAsync = ref.watch(unreadQuoteCountByRequestProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');
    final quoteCounts = quoteCountsAsync.valueOrNull ?? {};
    final unreadCounts = unreadCountsAsync.valueOrNull ?? {};

    return MarkSeenOnOpen(
      onMarkSeen: (ref) async {
        final user = ref.read(authSessionProvider).valueOrNull?.profile;
        if (user == null) return;
        await ref
            .read(quoteServiceProvider)
            .markCustomerRequestsStatusSeen(user.id);
      },
      child: Scaffold(
        body: requestsAsync.when(
          loading: () =>
              const LoadingView(message: HebrewStrings.loadingRequests),
          error: (error, _) {
            if (error is CustomerRequestsAccessDenied) {
              return const NoPermissionScreen();
            }
            return AppErrorCenter(
              message: HebrewStrings.errorLoadRequests,
              onRetry: () => ref.invalidate(customerRequestsProvider),
            );
          },
          data: (requests) {
            if (requests.isEmpty) {
              return const EmptyState(
                message: HebrewStrings.emptyRequestsList,
                icon: Icons.assignment_outlined,
                hint: HebrewStrings.emptyRequestsHint,
                accentGradient: AppTheme.gradientNavy,
              );
            }
            return FilterableListView<QuoteRequest>(
              items: requests,
              dateFor: (r) => r.sortDate,
              searchHint: HebrewStrings.searchRequestsHint,
              searchTextFor: _requestSearchText,
              filters: _customerRequestFilters(),
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

    return RfqListCard(
      onTap: onTap,
      number: RequestDisplayHelpers.shortNumber(request),
      title: RequestDisplayHelpers.customerRequestTitle(request),
      subtitle: _requestSubtitle(request),
      chips: [
        if (request.requestType == RequestType.tender)
          StatusChip.tender(dense: true),
      ],
      meta:
          '${HebrewStrings.requestDate}: ${dateFormat.format(request.createdAt)} · $countLabel',
      badge: showBadge
          ? StatusChip.count(unreadQuoteCount > 0 ? unreadQuoteCount : 1, dense: true)
          : null,
      status: StatusChip.request(request.status, dense: true),
    );
  }
}

List<ListFilter<QuoteRequest>> _customerRequestFilters() => [
      ListFilter<QuoteRequest>.all(),
      ListFilter<QuoteRequest>(
        label: HebrewStrings.filterOpen,
        color: AppTheme.navy,
        test: (r) => requestStatusGroup(r.status) == RequestStatusGroup.open,
      ),
      ListFilter<QuoteRequest>(
        label: HebrewStrings.filterInProgress,
        color: AppTheme.teal,
        test: (r) =>
            requestStatusGroup(r.status) == RequestStatusGroup.inProgress,
      ),
      ListFilter<QuoteRequest>(
        label: HebrewStrings.filterCompleted,
        color: AppTheme.emerald,
        test: (r) => requestStatusGroup(r.status) == RequestStatusGroup.done,
      ),
      ListFilter<QuoteRequest>(
        label: HebrewStrings.filterDrafts,
        color: AppTheme.amber,
        test: (r) => requestStatusGroup(r.status) == RequestStatusGroup.drafts,
      ),
    ];

String _requestSearchText(QuoteRequest request) => [
      RequestDisplayHelpers.customerRequestTitle(request),
      _requestSubtitle(request),
      request.projectName ?? '',
      request.status.label,
      '#${request.id}',
    ].join(' ');

String _requestSubtitle(QuoteRequest request) {
  final parts = <String>[
    RequestDisplayHelpers.customerRequestSubtitle(request)
  ];
  final projectLabel = ProjectDisplayHelpers.chipLabel(request);
  if (projectLabel != null) {
    parts.insert(0, projectLabel);
  }
  if (request.invitedSupplierNames.isNotEmpty) {
    parts.add('יעד: ${request.invitedSupplierNames.join(' · ')}');
  } else if (request.invitedSupplierIds.isNotEmpty) {
    parts.add('יעד: ${request.invitedSupplierIds.length} ספקים');
  } else {
    parts.add(
      SupplierTargetingHelpers.customerTargetingSummary(items: request.items)
          .title,
    );
  }
  return parts.join(' · ');
}

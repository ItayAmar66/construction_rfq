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
import '../../widgets/app_back_leading.dart';
import '../../widgets/count_badge.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/mark_seen_on_open.dart';
import '../../widgets/status_chip.dart';

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
          error: (_, __) =>
              const Center(child: Text(HebrewStrings.errorGeneric)),
          data: (requests) {
            if (requests.isEmpty) {
              return const EmptyState(
                message: HebrewStrings.emptyRequests,
                icon: Icons.assignment_outlined,
                hint: 'הוסף מוצרים מהקטלוג ושלח בקשת הצעת מחיר חדשה',
                accentGradient: AppTheme.gradientPrimary,
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
    final theme = Theme.of(context);
    final countLabel = receivedQuotesCountLabel(quoteCount);
    final hasStatusUpdate = request.hasUnreadStatusForCustomer();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'בקשה ${request.id.substring(0, 8)}...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (request.requestType == RequestType.tender) ...[
                      const SizedBox(height: 4),
                      Text(
                        RequestType.tender.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${HebrewStrings.requestDate}: ${dateFormat.format(request.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      countLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: quoteCount > 0
                            ? theme.colorScheme.primary
                            : Colors.grey.shade600,
                        fontWeight: quoteCount > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (unreadQuoteCount > 0) ...[
                CountBadge(count: unreadQuoteCount, compact: true),
                const SizedBox(width: 6),
              ] else if (hasStatusUpdate) ...[
                CountBadge(count: 1, compact: true),
                const SizedBox(width: 6),
              ],
              StatusChip(status: request.status),
            ],
          ),
        ),
      ),
    );
  }
}

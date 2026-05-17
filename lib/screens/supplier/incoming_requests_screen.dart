import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/quote_request.dart';
import '../../models/request_type.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/count_badge.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/mark_seen_on_open.dart';
import '../../widgets/status_chip.dart';

class IncomingRequestsScreen extends ConsumerWidget {
  const IncomingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingRequestsProvider);
    final incomingCount = ref.watch(incomingRequestsCountProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');
    final supplierId =
        ref.watch(authSessionProvider).valueOrNull?.profile?.id ?? '';

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
          loading: () => const LoadingView(),
          error: (_, __) =>
              const Center(child: Text(HebrewStrings.errorGeneric)),
          data: (requests) {
            if (requests.isEmpty) {
              return const EmptyState(
                message: HebrewStrings.emptyIncoming,
                icon: Icons.inbox_outlined,
                hint: 'בקשות חדשות מלקוחות יופיעו כאן בזמן אמת',
                accentGradient: AppTheme.gradientCyan,
              );
            }

            return DateGroupedListView<QuoteRequest>(
              items: requests,
              dateFor: (r) => r.createdAt,
              itemBuilder: (context, request) {
                final unseen = request.isUnseenBySupplier(supplierId);
                return Card(
                  child: InkWell(
                    onTap: () {
                      final path = request.requestType == RequestType.tender
                          ? '/tender/${request.id}'
                          : '/respond/${request.id}';
                      context.push(path);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.customerName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${request.customerCity} · ${request.customerPhone}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateFormat.format(request.createdAt),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (unseen) const CountBadge(count: 1, compact: true),
                              if (unseen) const SizedBox(height: 6),
                              if (request.isTender)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    RequestType.tender.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.deepPurple.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              StatusChip(status: request.status),
                            ],
                          ),
                        ],
                      ),
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

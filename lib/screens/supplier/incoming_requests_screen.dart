import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/quote_request.dart';
import '../../models/request_type.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
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
          error: (_, __) => AppErrorCenter(
            onRetry: () => ref.invalidate(incomingRequestsProvider),
          ),
          data: (requests) {
            if (requests.isEmpty) {
              return const EmptyState(
                message: HebrewStrings.emptyIncoming,
                icon: Icons.inbox_outlined,
                hint: 'בקשות חדשות מלקוחות יופיעו כאן בזמן אמת',
                accentGradient: AppTheme.gradientTeal,
              );
            }

            return DateGroupedListView<QuoteRequest>(
              items: requests,
              dateFor: (r) => r.createdAt,
              itemBuilder: (context, request) {
                final unseen = request.isUnseenBySupplier(supplierId);
                return AppListCard(
                  onTap: () {
                    final path = request.requestType == RequestType.tender
                        ? '/tender/${request.id}'
                        : '/respond/${request.id}';
                    context.push(path);
                  },
                  title: request.customerName,
                  subtitle: '${request.customerCity} · ${request.customerPhone}',
                  meta: dateFormat.format(request.createdAt),
                  topChip:
                      request.isTender ? const TenderBadge(compact: true) : null,
                  badge: unseen ? const CountBadge(count: 1, compact: true) : null,
                  trailing: StatusChip(status: request.status),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

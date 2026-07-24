import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/design_system/design_system.dart';

class RequestConfirmationScreen extends ConsumerWidget {
  const RequestConfirmationScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = GoRouterState.of(context).uri.queryParameters['mode'] ?? '';
    final sentToProcurement = mode == 'procurement';
    final routeProjectId =
        GoRouterState.of(context).uri.queryParameters['projectId'];
    final request = ref.watch(quoteRequestProvider(requestId)).valueOrNull;
    final projectId = routeProjectId ?? request?.projectId;

    return Scaffold(
      appBar: SecondaryAppBar(
        title: sentToProcurement
            ? HebrewStrings.sentToProcurement
            : HebrewStrings.requestSubmitted,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      sentToProcurement
                          ? HebrewStrings.sentToProcurement
                          : HebrewStrings.requestSubmitted,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      sentToProcurement
                          ? HebrewStrings.requestConfirmationProcurementBody
                          : HebrewStrings.requestConfirmationBody,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      label: 'צפייה בסטטוס הבקשה',
                      expand: false,
                      onPressed: () => context.go('/compare-quotes/$requestId'),
                    ),
                    const SizedBox(height: 12),
                    if (projectId != null && projectId.isNotEmpty) ...[
                      SecondaryButton(
                        label: 'חזרה לפרויקט',
                        onPressed: () => context.go('/projects/$projectId'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    PrimaryButton(
                      label: HebrewStrings.myRequests,
                      onPressed: () => context.go('/my-requests'),
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: HebrewStrings.home,
                      onPressed: () => context.go('/home'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

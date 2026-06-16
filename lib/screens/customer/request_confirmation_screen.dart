import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';

class RequestConfirmationScreen extends StatelessWidget {
  const RequestConfirmationScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final mode =
        GoRouterState.of(context).uri.queryParameters['mode'] ?? '';
    final sentToProcurement = mode == 'procurement';

    return Scaffold(
      appBar: SecondaryAppBar(
        title: sentToProcurement
            ? HebrewStrings.sentToProcurement
            : HebrewStrings.requestSubmitted,
      ),
      body: SafeArea(
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/my-requests'),
                child: const Text(HebrewStrings.myRequests),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/home'),
                child: const Text(HebrewStrings.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

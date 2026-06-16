import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/enterprise_providers.dart';

/// Shown when membership discovery fails (distinct from pending approval).
class MembershipLoadErrorScreen extends ConsumerWidget {
  const MembershipLoadErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('טעינת הרשאות')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_reset_outlined,
                  size: 64, color: Colors.orange.shade700),
              const SizedBox(height: 24),
              const Text(
                'לא הצלחנו לטעון הרשאות. נסה לרענן',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'החשבון פעיל אך לא הצלחנו לטעון את חברות והרשאות מהשרת.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    ref.invalidate(currentUserMembershipsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('רענון'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

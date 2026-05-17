import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';

/// Shown when Firebase Auth succeeded but Firestore profile is missing.
class ProfileErrorScreen extends ConsumerWidget {
  const ProfileErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('בעיה בפרופיל')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 64, color: Colors.orange.shade700),
            const SizedBox(height: 24),
            const Text(
              'פרופיל המשתמש לא נמצא בשרת',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'החשבון קיים בהתחברות אך חסר מסמך משתמש ב-Firestore.\n'
              'נסה להירשם מחדש או פנה לתמיכה.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                await ref.read(authServiceProvider).logout();
                ref.invalidate(authSessionProvider);
                if (context.mounted) context.go('/login');
              },
              child: const Text('התנתק וחזור להתחברות'),
            ),
          ],
        ),
      ),
    );
  }
}

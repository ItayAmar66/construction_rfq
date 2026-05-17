// =============================================================================
// DEV / MVP ONLY — one-time Firestore data reset entry point
// =============================================================================
// NEVER set this as the default app entry in pubspec. NEVER call on app startup.
// NOT for production databases.
//
// Run locally (see tool/RESET_FIRESTORE_DEV.md):
//   flutter run -t lib/dev/reset_firestore_dev_main.dart -d chrome -- --confirm
// =============================================================================

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/dev/firestore_dev_reset.dart';
import 'package:construction_rfq/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

const _confirmationPhrase = 'DELETE ALL DEV DATA';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final includeAppMeta = args.contains('--include-app-meta');
  final skipPhrase = args.contains('--yes-phrase');

  if (!args.contains('--confirm')) {
    stderr.writeln('');
    stderr.writeln('Aborted: missing required flag --confirm');
    stderr.writeln('Read tool/RESET_FIRESTORE_DEV.md before running.');
    stderr.writeln('');
    stderr.writeln('Example:');
    stderr.writeln(
      '  flutter run -t lib/dev/reset_firestore_dev_main.dart -d chrome -- --confirm',
    );
    exit(1);
  }

  if (!skipPhrase) {
    stdout.writeln('');
    stdout.writeln('⚠️  DEV ONLY — This permanently deletes Firestore documents.');
    stdout.writeln('    Firebase Auth accounts are NOT deleted.');
    stdout.writeln('');
    stdout.writeln('Type exactly: $_confirmationPhrase');
    stdout.write('> ');
    final typed = stdin.readLineSync()?.trim();
    if (typed != _confirmationPhrase) {
      stderr.writeln('Aborted: confirmation phrase did not match.');
      exit(1);
    }
  }

  stdout.writeln('Initializing Firebase...');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final firestore = FirebaseFirestore.instance;
  final projectId = Firebase.app().options.projectId;

  stdout.writeln('');
  stdout.writeln('Target Firebase project: $projectId');
  stdout.writeln('Collections: ${FirestoreDevResetCollections.dataCollections}');
  if (includeAppMeta) {
    stdout.writeln('Also deleting: ${FirestoreDevResetCollections.metaCollection}');
  }
  stdout.writeln('');
  stdout.write('Proceed? (y/N) ');
  final proceed = stdin.readLineSync()?.trim().toLowerCase();
  if (proceed != 'y' && proceed != 'yes') {
    stderr.writeln('Aborted.');
    exit(1);
  }

  stdout.writeln('');
  stdout.writeln('Deleting documents...');

  try {
    final result = await resetFirestoreDevData(
      firestore,
      includeAppMeta: includeAppMeta,
      onLog: stdout.writeln,
    );

    stdout.writeln('');
    stdout.writeln('Done. Total documents deleted: ${result.totalDocumentsDeleted}');
    for (final entry in result.deletedByCollection.entries) {
      stdout.writeln('  ${entry.key}: ${entry.value}');
    }
    stdout.writeln('');
    stdout.writeln(
      'Note: Firebase Authentication users still exist. '
      'Remove them in Firebase Console → Authentication if you want a full reset.',
    );
    stdout.writeln(
      'Re-run the app to re-seed products (appMeta) if you used --include-app-meta.',
    );
  } catch (e, st) {
    stderr.writeln('Reset failed: $e');
    stderr.writeln(st);
    exit(1);
  }

  exit(0);
}

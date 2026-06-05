import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production deploy checklist covers gate rollback and staging', () {
    final doc =
        File('${Directory.current.path}/CATALOG_PRODUCTION_DEPLOY_CHECKLIST.md')
            .readAsStringSync();
    expect(doc, contains('run_emulator_gate.sh'));
    expect(doc, contains('firestore.rules'));
    expect(doc, contains('Rollback'));
    expect(doc, contains('Staging import'));
    expect(doc, contains('firestore_rules_security_test'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ensures production rules stay locked down while emulator gate uses import rules.
void main() {
  final root = Directory.current.path;

  test('production firestore.rules denies catalog client writes', () {
    final rules = File('$root/firestore.rules').readAsStringSync();
    expect(rules, contains('match /catalogCategories/{categoryId}'));
    expect(rules, contains('allow write: if false'));
    expect(rules, isNot(contains('allow read, write: if true')));
  });

  test('firestore.import_emulator.rules allows catalog import on emulator only', () {
    final path = '$root/firestore.import_emulator.rules';
    expect(File(path).existsSync(), isTrue);
    final rules = File(path).readAsStringSync();
    expect(rules, contains('EMULATOR IMPORT GATE ONLY'));
    expect(rules, contains('match /catalogCategories/{document=**}'));
    expect(rules, contains('allow read, write: if true'));
  });

  test('run_emulator_gate.sh references import emulator rules not production', () {
    final script = File('$root/tools/catalog_import/run_emulator_gate.sh')
        .readAsStringSync();
    expect(script, contains('firestore.import_emulator.rules'));
    expect(script, contains('production rules unchanged'));
    expect(script, isNot(contains(r'cp "$ROOT/firestore.rules"')));
    expect(script, contains('firestore.import_emulator.rules'));
    expect(script, contains(r'cp "$ROOT/'));
  });

  test('production firebase.json still points to firestore.rules', () {
    final json = File('$root/firebase.json').readAsStringSync();
    expect(json, contains('"rules": "firestore.rules"'));
    expect(json, isNot(contains('firestore.import_emulator.rules')));
  });
}

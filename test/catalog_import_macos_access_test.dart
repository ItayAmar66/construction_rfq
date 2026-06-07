import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DebugProfile entitlements disable sandbox for import tooling', () {
    final entitlements = File('macos/Runner/DebugProfile.entitlements');
    expect(entitlements.existsSync(), isTrue);
    final body = entitlements.readAsStringSync();
    expect(body, contains('com.apple.security.app-sandbox'));
    expect(body, contains('<false/>'));
    expect(body, contains('com.apple.security.network.client'));
  });

  test('Release entitlements keep app sandbox enabled', () {
    final entitlements = File('macos/Runner/Release.entitlements');
    expect(entitlements.existsSync(), isTrue);
    final body = entitlements.readAsStringSync();
    expect(body, contains('com.apple.security.app-sandbox'));
    expect(body, contains('<true/>'));
  });

  test('run_import_cli.sh exists and documents VM runner', () {
    final script = File('tools/catalog_import/run_import_cli.sh');
    expect(script.existsSync(), isTrue);
    final body = script.readAsStringSync();
    expect(body, contains('catalog_import_runner_test.dart'));
    expect(body, contains('CATALOG_IMPORT_CLI_ARGS'));
  });
}

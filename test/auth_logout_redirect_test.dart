import 'package:construction_rfq/utils/auth_logout_redirect_stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stub does not use hard web redirect by default', () {
    expect(usesHardWebLoginRedirect, isFalse);
  });
}

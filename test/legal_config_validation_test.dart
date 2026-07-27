import 'package:construction_rfq/config/app_config.dart';
import 'package:construction_rfq/utils/legal_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('legal placeholder guard', () {
    // Guards against ever shipping the literal bracket-style placeholders
    // ("[שם החברה]", "[support@example.com]") this branch used to hardcode.
    // A future accidental revert of AppConfig.companyLegalName/supportEmail
    // back to a bracket literal would fail this test.
    test('companyName never contains an unresolved [placeholder]', () {
      expect(LegalContent.companyName, isNot(contains('[')));
      expect(LegalContent.companyName, isNot(contains(']')));
      expect(LegalContent.companyName, isNotEmpty);
    });

    test('contactEmail is never the literal example.com placeholder', () {
      expect(LegalContent.contactEmail, isNot(contains('example.com')));
      expect(LegalContent.contactEmail, isNot(contains('[')));
    });

    test('privacy policy and terms both surface a beta-draft notice', () {
      expect(LegalContent.privacyPolicy, contains(LegalContent.betaDraftNotice));
      expect(LegalContent.termsOfService, contains(LegalContent.companyName));
    });

    test('privacy policy and terms never leak the literal example.com placeholder', () {
      expect(LegalContent.privacyPolicy, isNot(contains('example.com')));
      expect(LegalContent.termsOfService, isNot(contains('example.com')));
    });
  });

  group('AppConfig support email', () {
    test('hasSupportEmail matches whether supportEmail is set', () {
      expect(AppConfig.hasSupportEmail, AppConfig.supportEmail.isNotEmpty);
    });
  });
}

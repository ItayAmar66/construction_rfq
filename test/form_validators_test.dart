import 'package:construction_rfq/utils/decimal_input_formatters.dart';
import 'package:construction_rfq/utils/form_validators.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates typing [text] one keystroke at a time, the way a real TextField
/// feeds formatters — a single `formatEditUpdate` over the whole pasted
/// string behaves differently (an anchored regex like `^\d*` rejects a
/// leading '-' outright rather than dropping just that character).
TextEditingValue _apply(String text) {
  var value = const TextEditingValue();
  for (final char in text.split('')) {
    final candidate = TextEditingValue(
      text: value.text + char,
      selection: TextSelection.collapsed(offset: value.text.length + 1),
    );
    for (final formatter in nonNegativeDecimalInputFormatters) {
      value = formatter.formatEditUpdate(value, candidate);
    }
  }
  return value;
}

void main() {
  group('FormValidators.email', () {
    test('rejects empty input', () {
      expect(FormValidators.email(''), isNotNull);
      expect(FormValidators.email(null), isNotNull);
    });

    test('rejects malformed input', () {
      expect(FormValidators.email('asdf'), isNotNull);
      expect(FormValidators.email('asdf@'), isNotNull);
      expect(FormValidators.email('asdf@example'), isNotNull);
    });

    test('accepts a well-formed address', () {
      expect(FormValidators.email('user@example.com'), isNull);
    });
  });

  group('nonNegativeDecimalInputFormatters', () {
    test('blocks a leading minus sign', () {
      expect(_apply('-50').text, '50');
    });

    test('allows digits and a decimal point', () {
      expect(_apply('12.50').text, '12.50');
    });

    test('caps to two decimal places', () {
      expect(_apply('12.5678').text, '12.56');
    });
  });
}

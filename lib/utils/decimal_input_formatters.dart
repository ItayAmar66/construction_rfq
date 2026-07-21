import 'package:flutter/services.dart';

/// Input formatters restricting a numeric TextField to non-negative decimal
/// amounts (prices, VAT %, delivery cost) — blocks '-' and stray characters
/// that would otherwise silently parse to 0 via `double.tryParse(v) ?? 0`.
final nonNegativeDecimalInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
];

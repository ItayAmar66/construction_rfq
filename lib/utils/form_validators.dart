/// Shared TextFormField validators (Hebrew copy).
abstract final class FormValidators {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'נא להזין אימייל';
    if (!_emailPattern.hasMatch(trimmed)) return 'כתובת אימייל לא תקינה';
    return null;
  }
}

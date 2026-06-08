/// Strips wrapper noise from thrown errors for UI display.
String userFacingError(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  return text;
}

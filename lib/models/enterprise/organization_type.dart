enum OrganizationType {
  platform('platform'),
  contractor('contractor'),
  supplier('supplier');

  const OrganizationType(this.value);
  final String value;

  static OrganizationType? fromValue(String? raw) {
    if (raw == null) return null;
    for (final t in values) {
      if (t.value == raw) return t;
    }
    return null;
  }
}

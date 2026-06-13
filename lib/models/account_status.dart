/// Platform access state for registered users.
enum AccountStatus {
  pendingApproval('pendingApproval'),
  active('active'),
  blocked('blocked');

  const AccountStatus(this.value);
  final String value;

  static AccountStatus fromValue(String? raw) {
    if (raw == null || raw.isEmpty) return AccountStatus.active;
    for (final s in values) {
      if (s.value == raw) return s;
    }
    return AccountStatus.active;
  }

  String get label {
    switch (this) {
      case AccountStatus.pendingApproval:
        return 'ממתין לאישור מנהל מערכת';
      case AccountStatus.active:
        return 'פעיל';
      case AccountStatus.blocked:
        return 'חסום';
    }
  }

  bool get canUsePlatform => this == AccountStatus.active;
}

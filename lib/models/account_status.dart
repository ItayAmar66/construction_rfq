/// Platform access state for registered users.
enum AccountStatus {
  pendingApproval('pendingApproval'),
  active('active'),
  disabled('disabled'),
  rejected('rejected'),
  blocked('blocked');

  const AccountStatus(this.value);
  final String value;

  static AccountStatus fromValue(String? raw) {
    if (raw == null || raw.isEmpty) return AccountStatus.active;
    if (raw == 'blocked') return AccountStatus.disabled;
    for (final s in values) {
      if (s.value == raw) return s;
    }
    return AccountStatus.active;
  }

  String get label {
    switch (this) {
      case AccountStatus.pendingApproval:
        return 'ממתין לאישור';
      case AccountStatus.active:
        return 'פעיל';
      case AccountStatus.disabled:
      case AccountStatus.blocked:
        return 'מושבת';
      case AccountStatus.rejected:
        return 'נדחה';
    }
  }

  bool get canUsePlatform => this == AccountStatus.active;

  bool get isPendingGate =>
      this == AccountStatus.pendingApproval ||
      this == AccountStatus.rejected ||
      this == AccountStatus.disabled ||
      this == AccountStatus.blocked;
}

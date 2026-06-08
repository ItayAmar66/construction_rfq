enum UserType {
  privateSupplier,
  commercialSupplier,
  privateCustomer,
  commercialCustomer;

  String get label {
    switch (this) {
      case UserType.privateSupplier:
        return 'ספק פרטי (טמבוריה)';
      case UserType.commercialSupplier:
        return 'ספק מסחרי (מרלוג)';
      case UserType.privateCustomer:
        return 'לקוח פרטי (קבלן קטן)';
      case UserType.commercialCustomer:
        return 'לקוח מסחרי (קבלן גדול)';
    }
  }

  /// Short label for registration subtype chips.
  String get subtypeLabel {
    switch (this) {
      case UserType.privateSupplier:
        return 'ספק פרטי';
      case UserType.commercialSupplier:
        return 'ספק מסחרי';
      case UserType.privateCustomer:
        return 'קבלן קטן';
      case UserType.commercialCustomer:
        return 'קבלן גדול';
    }
  }

  /// Full registration dropdown label (role + subtype).
  String get registrationLabel {
    return '${accountRoleLabel} · $subtypeLabel';
  }

  String get accountRoleLabel =>
      isSupplier ? 'ספק' : 'קבלן (לקוח)';

  String get fullNameFieldLabel =>
      isSupplier ? 'שם הספק / חברה' : 'שם הקבלן / חברה';

  static List<UserType> get customerTypes => [
        UserType.privateCustomer,
        UserType.commercialCustomer,
      ];

  static List<UserType> get supplierTypes => [
        UserType.privateSupplier,
        UserType.commercialSupplier,
      ];

  String get value => name;

  bool get isCustomer =>
      this == UserType.privateCustomer || this == UserType.commercialCustomer;

  bool get isSupplier =>
      this == UserType.privateSupplier || this == UserType.commercialSupplier;

  static UserType fromString(String value) {
    return UserType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserType.privateCustomer,
    );
  }
}

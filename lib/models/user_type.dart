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

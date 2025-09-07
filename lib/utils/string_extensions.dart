// lib/utils/string_extensions.dart
extension StringCapitalizeExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

extension StringNullIfEmptyExtension on String {
  String? get nullIfEmpty {
    final trimmedValue = trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }
}

/*
extension EmailValidatorExtension on String {
  bool isValidEmail() {
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(this);
  }
}
*/

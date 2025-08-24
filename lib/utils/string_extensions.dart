// lib/utils/string_extensions.dart
extension StringCapitalizeExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

// You can add other useful string extensions here in the future.
// For example:
/*
extension EmailValidatorExtension on String {
  bool isValidEmail() {
    // Basic email validation, consider using a package for more robust validation
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(this);
  }
}
*/

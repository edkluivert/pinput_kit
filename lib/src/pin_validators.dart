/// Ready-made validator functions for pin fields and OTP inputs.
///
/// Each validator returns an error message string when validation fails,
/// or null when the pin passes. These compose freely with custom closures
/// and `forms_kit`'s `Validators`.
library;

typedef PinValidator = String? Function(String? value);

abstract final class PinValidators {
  static final _digitsOnly = RegExp(r'^[0-9]+$');

  /// Rejects null, empty or pins that do not have exactly [length] characters.
  static PinValidator length(int length, {String? message}) =>
      (value) => (value == null || value.length != length)
      ? message ?? 'Enter all $length digits'
      : null;

  /// Ensures the pin consists of numbers (0-9) only.
  static PinValidator digitsOnly({String message = 'Digits only'}) =>
      (value) =>
          (value == null || !_digitsOnly.hasMatch(value)) ? message : null;

  /// Rejects weak pins such as repeated digits ('1111') or simple sequences ('1234').
  static PinValidator notSequential({
    String message = 'Avoid simple sequences',
  }) => (value) {
    if (value == null || value.length < 3) return null;

    // Check all identical (e.g. 0000, 1111)
    if (value.split('').every((c) => c == value[0])) {
      return message;
    }

    // Check ascending sequence (e.g. 1234, 4567)
    bool isAscending = true;
    for (int i = 0; i < value.length - 1; i++) {
      final a = int.tryParse(value[i]);
      final b = int.tryParse(value[i + 1]);
      if (a == null || b == null || b != a + 1) {
        isAscending = false;
        break;
      }
    }
    if (isAscending) return message;

    // Check descending sequence (e.g. 4321, 9876)
    bool isDescending = true;
    for (int i = 0; i < value.length - 1; i++) {
      final a = int.tryParse(value[i]);
      final b = int.tryParse(value[i + 1]);
      if (a == null || b == null || b != a - 1) {
        isDescending = false;
        break;
      }
    }
    if (isDescending) return message;

    return null;
  };

  /// Passes when the pin equals what [other] returns at validation time.
  /// Helpful for confirm-pin fields.
  static PinValidator matches(
    String? Function() other, {
    String message = 'PINs do not match',
  }) =>
      (value) => value == other() ? null : message;

  /// Runs [validators] in order and returns the first error encountered.
  static PinValidator compose(List<PinValidator> validators) => (value) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  };
}

/// Pure-Dart extraction of a pin code from a message body.
///
/// Kept free of `dartnative` imports so it can be unit tested on the VM and
/// reused by any [PinCodeStrategy] implementation.
library;

/// Signature for extracting a pin code from an incoming SMS or notification
/// string. Returns null when no code is found.
typedef PinCodeParser = String? Function(String rawMessage);

/// Finds the first run of exactly [length] digits in [raw] that stands on
/// its own (not part of a longer number such as a phone number, order id or
/// date). Digits may be grouped with a single space or hyphen, so `123-456`
/// and `123 456` are recognised as `123456`.
///
/// Returns null when [raw] contains no such code.
String? extractPinCode(String raw, int length) {
  if (length <= 0 || raw.isEmpty) return null;

  // Exact run of `length` digits with no digit on either side.
  final exact = RegExp('(?<!\\d)(\\d{$length})(?!\\d)');
  final exactMatch = exact.firstMatch(raw);
  if (exactMatch != null) return exactMatch.group(1);

  // Grouped digits separated by a single space or hyphen, e.g. "123-456".
  final grouped = RegExp(r'(?<![\d-])(\d(?:[ -]?\d)+)(?![\d-])');
  for (final match in grouped.allMatches(raw)) {
    final digits = match.group(1)!.replaceAll(RegExp(r'[ -]'), '');
    if (digits.length == length) return digits;
  }
  return null;
}

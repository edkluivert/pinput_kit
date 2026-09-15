import 'package:pinput_kit/src/pin_parser.dart';
import 'package:test/test.dart';

void main() {
  group('extractPinCode', () {
    test('finds a stand-alone run of digits', () {
      expect(
        extractPinCode('Your Tharwa code is 123456. Valid for 5 min.', 6),
        '123456',
      );
    });

    test('returns the code when it is the whole message', () {
      expect(extractPinCode('4321', 4), '4321');
    });

    test('ignores longer numbers such as order ids and dates', () {
      expect(
        extractPinCode('Order #20260914 confirmed. Code 654321', 6),
        '654321',
      );
    });

    test('does not build a code out of a phone number', () {
      expect(extractPinCode('Call 0800123 for help', 6), isNull);
    });

    test('does not take the prefix of a longer number', () {
      expect(extractPinCode('Ref 1234567', 6), isNull);
    });

    test('accepts hyphen and space grouping', () {
      expect(extractPinCode('Your code: 123-456', 6), '123456');
      expect(extractPinCode('Your code: 123 456', 6), '123456');
    });

    test('prefers an exact run over a grouped one', () {
      expect(extractPinCode('Use 111-222 or 333444', 6), '333444');
    });

    test('rejects grouped digits of the wrong total length', () {
      expect(extractPinCode('Call 0800-123', 6), isNull);
    });

    test('returns null for empty input or non-positive length', () {
      expect(extractPinCode('', 6), isNull);
      expect(extractPinCode('123456', 0), isNull);
    });

    test('takes the first matching code', () {
      expect(extractPinCode('Codes 111111 and 222222', 6), '111111');
    });
  });
}

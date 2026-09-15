import 'package:pinput_kit/src/pin_validators.dart';
import 'package:test/test.dart';

void main() {
  group('PinValidators.length', () {
    final v6 = PinValidators.length(6);
    test('rejects null, empty, and shorter pins', () {
      expect(v6(null), 'Enter all 6 digits');
      expect(v6(''), 'Enter all 6 digits');
      expect(v6('12345'), 'Enter all 6 digits');
    });

    test('rejects longer pins', () {
      expect(v6('1234567'), 'Enter all 6 digits');
    });

    test('accepts exact length', () {
      expect(v6('123456'), isNull);
    });

    test('custom error message', () {
      final custom = PinValidators.length(4, message: 'Need 4 digits');
      expect(custom('12'), 'Need 4 digits');
      expect(custom('1234'), isNull);
    });
  });

  group('PinValidators.digitsOnly', () {
    final v = PinValidators.digitsOnly();
    test('rejects non-numeric characters', () {
      expect(v(null), 'Digits only');
      expect(v('123a5'), 'Digits only');
      expect(v('12-45'), 'Digits only');
      expect(v(' 1234 '), 'Digits only');
    });

    test('accepts purely numeric strings', () {
      expect(v('0123456789'), isNull);
    });
  });

  group('PinValidators.notSequential', () {
    final v = PinValidators.notSequential();
    test('rejects all identical digits', () {
      expect(v('000000'), 'Avoid simple sequences');
      expect(v('1111'), 'Avoid simple sequences');
      expect(v('999999'), 'Avoid simple sequences');
    });

    test('rejects ascending sequences', () {
      expect(v('123456'), 'Avoid simple sequences');
      expect(v('3456'), 'Avoid simple sequences');
    });

    test('rejects descending sequences', () {
      expect(v('654321'), 'Avoid simple sequences');
      expect(v('4321'), 'Avoid simple sequences');
    });

    test('accepts non-trivial pins', () {
      expect(v('839102'), isNull);
      expect(v('5193'), isNull);
      expect(v('1324'), isNull);
    });
  });

  group('PinValidators.matches', () {
    var other = '123456';
    final v = PinValidators.matches(() => other);

    test('compares against live value', () {
      expect(v('123456'), isNull);
      expect(v('654321'), 'PINs do not match');

      other = '999888';
      expect(v('123456'), 'PINs do not match');
      expect(v('999888'), isNull);
    });
  });

  group('PinValidators.compose', () {
    final v = PinValidators.compose([
      PinValidators.length(6),
      PinValidators.digitsOnly(),
      PinValidators.notSequential(),
    ]);

    test('returns first error in chain', () {
      expect(v('123'), 'Enter all 6 digits');
      expect(v('123a56'), 'Digits only');
      expect(v('123456'), 'Avoid simple sequences');
      expect(v('839102'), isNull);
    });
  });
}

import 'dart:async';

import 'package:pinput_kit/src/pin_strategy.dart';
import 'package:test/test.dart';

void main() {
  group('TestPinStrategy', () {
    test('delivers code after delay', () async {
      const strategy = TestPinStrategy(
        code: '123456',
        delay: Duration(milliseconds: 50),
      );

      final result = await strategy.listenForCode();
      expect(result, '123456');
    });

    test('delivers code immediately if delay is zero', () async {
      const strategy = TestPinStrategy(code: '987654', delay: Duration.zero);

      final result = await strategy.listenForCode();
      expect(result, '987654');
    });
  });

  group('StreamPinStrategy', () {
    test('delivers first emitted event from stream', () async {
      final controller = StreamController<String>();
      final strategy = StreamPinStrategy(controller.stream);

      final future = strategy.listenForCode();
      controller.add('Your code is 654321');

      final result = await future;
      expect(result, 'Your code is 654321');
      await controller.close();
    });
  });

  group('Regex parsing logic for SMS', () {
    String? parsePin(String raw, int length) {
      final exp = RegExp('\\b(\\d{$length})\\b');
      final match = exp.firstMatch(raw);
      if (match != null) return match.group(1);
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= length) return digits.substring(0, length);
      return null;
    }

    test('extracts 6-digit pin from full SMS text', () {
      expect(
        parsePin('Your Tharwa verification code is 839102. Do not share.', 6),
        '839102',
      );
      expect(parsePin('<#> 741258 is your code. FA+9qCX9VSu', 6), '741258');
      expect(parsePin('Code: 1234', 4), '1234');
    });

    test('returns null if no code is present', () {
      expect(parsePin('Welcome to our service!', 6), isNull);
    });
  });
}

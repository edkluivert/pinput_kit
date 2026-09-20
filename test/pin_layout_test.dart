import 'package:pinput_kit/src/pin_layout.dart';
import 'package:test/test.dart';

void main() {
  group('slotOffsets', () {
    test('spaces slots by width plus spacing', () {
      expect(
        slotOffsets(length: 4, slotWidth: 48, spacing: 8, separatorAfter: {}, separatorWidth: 16),
        equals([0, 56, 112, 168]),
      );
      expect(
        slotsRowWidth(length: 4, slotWidth: 48, spacing: 8, separatorAfter: {}, separatorWidth: 16),
        equals(216),
      );
    });

    test('widens the gap where a separator cell sits', () {
      // 123 — 456: separator after slot 3 (positions use the next index).
      final offsets = slotOffsets(
        length: 6,
        slotWidth: 48,
        spacing: 8,
        separatorAfter: {3},
        separatorWidth: 16,
      );
      expect(offsets, equals([0, 56, 112, 112 + 48 + 16 + 8, 240, 296]));
      expect(offsets[3] - offsets[2], equals(48 + 24));
    });

    test('ignores separator positions outside the row', () {
      expect(
        slotOffsets(length: 3, slotWidth: 40, spacing: 4, separatorAfter: {0, 3, 7}, separatorWidth: 10),
        equals([0, 44, 88]),
      );
      expect(slotsRowWidth(length: 0, slotWidth: 40, spacing: 4, separatorAfter: {}, separatorWidth: 10), 0);
    });
  });
}

/// Geometry of the slots row, kept pure so the focus ring can be positioned
/// without measuring native views.
library;

/// Horizontal offset of each slot's left edge inside the slots row.
///
/// Slots are [slotWidth] wide with [spacing] between them; where a separator
/// follows slot `i` ([separatorAfter] contains `i + 1`, matching
/// `PinField.separatorPositions`) the gap is [separatorWidth] plus [spacing]
/// instead, which is the width of the separator cell.
List<double> slotOffsets({
  required int length,
  required double slotWidth,
  required double spacing,
  required Set<int> separatorAfter,
  required double separatorWidth,
}) {
  final offsets = <double>[];
  var x = 0.0;
  for (var i = 0; i < length; i++) {
    offsets.add(x);
    x += slotWidth;
    if (i < length - 1) {
      x += separatorAfter.contains(i + 1) ? separatorWidth + spacing : spacing;
    }
  }
  return offsets;
}

/// Total width of the slots row, see [slotOffsets].
double slotsRowWidth({
  required int length,
  required double slotWidth,
  required double spacing,
  required Set<int> separatorAfter,
  required double separatorWidth,
}) {
  if (length == 0) return 0;
  final offsets = slotOffsets(
    length: length,
    slotWidth: slotWidth,
    spacing: spacing,
    separatorAfter: separatorAfter,
    separatorWidth: separatorWidth,
  );
  return offsets.last + slotWidth;
}

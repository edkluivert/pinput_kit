/// Colours, shapes and sizes for pin field slots, with a native default per
/// platform.
library;

import 'dart:io' show Platform;

import 'package:dartnative/dartnative.dart';

// ---------------------------------------------------------------------------
// Slot visual style
// ---------------------------------------------------------------------------

/// How individual pin slots are drawn.
enum PinSlotStyle {
  /// Rounded rectangle boxes with optional fill and border.
  box,

  /// A horizontal line under each digit.
  underline,

  /// Circular slots.
  circle,
}

// ---------------------------------------------------------------------------
// Entry animation type
// ---------------------------------------------------------------------------

/// How a digit appears when the user types it.
enum PinAnimationType {
  /// No animation; the digit is shown immediately.
  none,

  /// The digit fades in.
  fade,

  /// The digit scales up from zero.
  scale,
}

// ---------------------------------------------------------------------------
// Slot state (resolved at render time)
// ---------------------------------------------------------------------------

/// The visual state of a single pin slot.
enum PinSlotState {
  /// No character entered yet, and this slot is not the active one.
  empty,

  /// The currently active slot (cursor shown here).
  focused,

  /// Has a character.
  filled,

  /// The field has a validation error.
  error,

  /// The field is disabled.
  disabled,

  /// Successful validation (optional green accent).
  success,
}

// ---------------------------------------------------------------------------
// PinThemeData
// ---------------------------------------------------------------------------

class PinThemeData {
  /// Width of each individual slot.
  final double width;

  /// Height of each individual slot.
  final double height;

  /// Horizontal gap between slots.
  final double spacing;

  /// The visual shape of each slot.
  final PinSlotStyle style;

  /// Corner radius for [PinSlotStyle.box].
  final double borderRadius;

  // --- Per-state border colours ---

  /// Border colour for an empty, unfocused slot.
  final Color defaultColor;

  /// Border colour for the currently focused slot.
  final Color focusedColor;

  /// Border colour for a slot that already has a digit.
  final Color filledColor;

  /// Border colour when the field is in the error state.
  final Color errorColor;

  /// Border colour when the field is disabled.
  final Color disabledColor;

  /// Border colour for the success state.
  final Color successColor;

  // --- Fill colours ---

  /// Background colour for slots in the default state.
  final Color fillColor;

  /// Background colour for the focused slot; falls back to [fillColor].
  final Color focusedFillColor;

  /// Background colour when the field is in the error state.
  final Color errorFillColor;

  // --- Border widths ---

  /// Border width in the default state.
  final double borderWidth;

  /// Border width when focused.
  final double focusedBorderWidth;

  // --- Text ---

  /// Text style for the digit character.
  final TextStyle textStyle;

  /// The character shown when the digit is obscured.
  final String obscureCharacter;

  const PinThemeData({
    required this.width,
    required this.height,
    required this.spacing,
    required this.style,
    required this.borderRadius,
    required this.defaultColor,
    required this.focusedColor,
    required this.filledColor,
    required this.errorColor,
    required this.disabledColor,
    required this.successColor,
    required this.fillColor,
    required this.focusedFillColor,
    required this.errorFillColor,
    required this.borderWidth,
    required this.focusedBorderWidth,
    required this.textStyle,
    required this.obscureCharacter,
  });

  /// Apple-flavoured preset: filled rounded rectangles, system grey 6
  /// background, blue focus ring, SF-style typography.
  static const ios = PinThemeData(
    width: 48,
    height: 52,
    spacing: 8,
    style: PinSlotStyle.box,
    borderRadius: 10,
    defaultColor: Color(0xFFD1D1D6),
    focusedColor: Color(0xFF007AFF),
    filledColor: Color(0xFFC7C7CC),
    errorColor: Color(0xFFFF3B30),
    disabledColor: Color(0xFF8E8E93),
    successColor: Color(0xFF34C759),
    fillColor: Color(0xFFF2F2F7),
    focusedFillColor: Color(0xFFFFFFFF),
    errorFillColor: Color(0xFFFFF2F2),
    borderWidth: 1,
    focusedBorderWidth: 2,
    textStyle: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: Color(0xFF000000),
    ),
    obscureCharacter: '•',
  );

  /// Material 3 preset: outlined rectangles with 8 dp corners, purple accent,
  /// no fill by default.
  static const material = PinThemeData(
    width: 48,
    height: 56,
    spacing: 8,
    style: PinSlotStyle.box,
    borderRadius: 8,
    defaultColor: Color(0xFF79747E),
    focusedColor: Color(0xFF6750A4),
    filledColor: Color(0xFF49454F),
    errorColor: Color(0xFFB3261E),
    disabledColor: Color(0x611D1B20),
    successColor: Color(0xFF386A20),
    fillColor: Color(0x00000000),
    focusedFillColor: Color(0x00000000),
    errorFillColor: Color(0x00000000),
    borderWidth: 1,
    focusedBorderWidth: 2,
    textStyle: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1D1B20),
    ),
    obscureCharacter: '•',
  );

  /// The platform's own look.
  static PinThemeData get platform => Platform.isAndroid ? material : ios;

  PinThemeData copyWith({
    double? width,
    double? height,
    double? spacing,
    PinSlotStyle? style,
    double? borderRadius,
    Color? defaultColor,
    Color? focusedColor,
    Color? filledColor,
    Color? errorColor,
    Color? disabledColor,
    Color? successColor,
    Color? fillColor,
    Color? focusedFillColor,
    Color? errorFillColor,
    double? borderWidth,
    double? focusedBorderWidth,
    TextStyle? textStyle,
    String? obscureCharacter,
  }) => PinThemeData(
    width: width ?? this.width,
    height: height ?? this.height,
    spacing: spacing ?? this.spacing,
    style: style ?? this.style,
    borderRadius: borderRadius ?? this.borderRadius,
    defaultColor: defaultColor ?? this.defaultColor,
    focusedColor: focusedColor ?? this.focusedColor,
    filledColor: filledColor ?? this.filledColor,
    errorColor: errorColor ?? this.errorColor,
    disabledColor: disabledColor ?? this.disabledColor,
    successColor: successColor ?? this.successColor,
    fillColor: fillColor ?? this.fillColor,
    focusedFillColor: focusedFillColor ?? this.focusedFillColor,
    errorFillColor: errorFillColor ?? this.errorFillColor,
    borderWidth: borderWidth ?? this.borderWidth,
    focusedBorderWidth: focusedBorderWidth ?? this.focusedBorderWidth,
    textStyle: textStyle ?? this.textStyle,
    obscureCharacter: obscureCharacter ?? this.obscureCharacter,
  );
}

// ---------------------------------------------------------------------------
// PinTheme — InheritedWidget
// ---------------------------------------------------------------------------

/// Overrides the pin field look for a subtree. Without one, fields use
/// [PinThemeData.platform].
class PinTheme extends InheritedWidget {
  final PinThemeData data;

  const PinTheme({super.key, required this.data, required super.child});

  static PinThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PinTheme>()?.data ??
      PinThemeData.platform;

  @override
  bool updateShouldNotify(PinTheme oldWidget) => data != oldWidget.data;
}

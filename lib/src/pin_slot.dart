/// Renders a single digit slot in the pin field.
///
/// Each slot is a composed `Container` whose decoration, text and cursor
/// change based on its [PinSlotState]. The slot is a pure view with no
/// input handling — all keyboard input goes through the hidden `TextField`
/// in [PinField].
library;

import 'package:dartnative/dartnative.dart';

import 'pin_cursor.dart';
import 'pin_theme.dart';

class PinSlot extends StatelessWidget {
  /// The digit character to display, or null when the slot is empty.
  final String? character;

  /// The current visual state of this slot.
  final PinSlotState state;

  /// Theme data driving colours, sizes and shape.
  final PinThemeData theme;

  /// Whether to obscure the character (show [theme.obscureCharacter]).
  final bool obscureText;

  /// Whether to show the blinking cursor in this slot.
  final bool showCursor;

  /// Custom cursor widget; when null the default [PinCursor] is used.
  final Widget? cursor;

  /// Cursor colour; forwarded to [PinCursor].
  final Color? cursorColor;

  /// Cursor bar width; forwarded to [PinCursor].
  final double cursorWidth;

  /// Cursor bar height; forwarded to [PinCursor].
  final double? cursorHeight;

  /// Entry animation type for the digit.
  final PinAnimationType animationType;

  /// Duration of the entry animation.
  final Duration animationDuration;

  /// Curve of the entry animation.
  final Curve animationCurve;

  /// Placeholder widget shown in empty slots (e.g. a dash or dot).
  final Widget? preFilledWidget;

  const PinSlot({
    super.key,
    required this.character,
    required this.state,
    required this.theme,
    this.obscureText = false,
    this.showCursor = false,
    this.cursor,
    this.cursorColor,
    this.cursorWidth = 2,
    this.cursorHeight,
    this.animationType = PinAnimationType.none,
    this.animationDuration = const Duration(milliseconds: 160),
    this.animationCurve = Curves.easeOut,
    this.preFilledWidget,
  });

  @override
  Widget build(BuildContext context) {
    final borderInfo = _resolvedBorder();
    final borderColor = borderInfo.$1;
    final borderW = borderInfo.$2;
    final fill = borderInfo.$3;

    if (theme.style == PinSlotStyle.underline) {
      // DartNative renders only uniform borders, so the underline is drawn
      // as its own thin Container row beneath the slot. The decoration is
      // explicit so a style change resets the native shape (see
      // _boxDecoration).
      return Container(
        width: theme.width,
        height: theme.height,
        decoration: _boxDecoration(borderColor, borderW, fill),
        child: Column(
          children: [
            Expanded(child: Center(child: _content())),
            Container(height: borderW, color: borderColor),
          ],
        ),
      );
    }

    return Container(
      width: theme.width,
      height: theme.height,
      decoration: _boxDecoration(borderColor, borderW, fill),
      child: Center(child: _content()),
    );
  }

  // -----------------------------------------------------------------------
  // Decoration per state & style
  // -----------------------------------------------------------------------

  (Color, double, Color) _resolvedBorder() {
    final Color borderColor;
    final double borderW;
    final Color fill;

    switch (state) {
      case PinSlotState.focused:
        borderColor = theme.focusedColor;
        borderW = theme.focusedBorderWidth;
        fill = theme.focusedFillColor;
      case PinSlotState.filled:
        borderColor = theme.filledColor;
        borderW = theme.borderWidth;
        fill = theme.fillColor;
      case PinSlotState.error:
        borderColor = theme.errorColor;
        borderW = theme.focusedBorderWidth;
        fill = theme.errorFillColor;
      case PinSlotState.disabled:
        borderColor = theme.disabledColor;
        borderW = theme.borderWidth;
        fill = theme.fillColor;
      case PinSlotState.success:
        borderColor = theme.successColor;
        borderW = theme.focusedBorderWidth;
        fill = theme.fillColor;
      case PinSlotState.empty:
        borderColor = theme.defaultColor;
        borderW = theme.borderWidth;
        fill = theme.fillColor;
    }

    return (borderColor, borderW, fill);
  }

  BoxDecoration _boxDecoration(Color borderColor, double borderW, Color fill) {
    switch (theme.style) {
      // Every style names shape, radius and border explicitly. Slots are
      // reused by index when the style changes, and a property left unset
      // keeps the previous style's native value.
      case PinSlotStyle.box:
        return BoxDecoration(
          color: fill,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(theme.borderRadius),
          border: Border.all(color: borderColor, width: borderW),
        );

      case PinSlotStyle.circle:
        // A rectangle with a half-size radius rather than BoxShape.circle:
        // a radius change is applied cleanly on every style switch, while
        // the native circle path can keep a previous corner radius for the
        // fill. A square slot is a true circle; a non-square one is a stadium.
        final radius =
            (theme.width < theme.height ? theme.width : theme.height) / 2;
        return BoxDecoration(
          color: fill,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: borderW),
        );

      case PinSlotStyle.underline:
        return BoxDecoration(
          color: fill,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: const Color(0x00000000), width: 0),
        );
    }
  }

  // -----------------------------------------------------------------------
  // Content: cursor, character, placeholder
  // -----------------------------------------------------------------------

  Widget _content() {
    // Cursor in the focused empty slot.
    if (showCursor && character == null) {
      return cursor ??
          PinCursor(
            color: cursorColor ?? theme.focusedColor,
            width: cursorWidth,
            height: cursorHeight,
          );
    }

    // No character yet.
    if (character == null) {
      return preFilledWidget ?? const SizedBox();
    }

    // Determine displayed text.
    final displayChar = obscureText ? theme.obscureCharacter : character!;
    final Widget charWidget = animationType == PinAnimationType.none
        ? Text(displayChar, style: theme.textStyle)
        : _SlotEntry(
            type: animationType,
            duration: animationDuration,
            curve: animationCurve,
            child: Text(displayChar, style: theme.textStyle),
          );

    // A filled slot is always a Row, whether or not it shows the cursor, so
    // the digit widget is kept when the cursor appears or disappears and the
    // entry animation does not play again. When this slot is the active one
    // (the user tapped it, or deleted back into it) the cursor is drawn right
    // after the digit, like the caret in a normal text field.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        charWidget,
        if (showCursor) ...[
          const SizedBox(width: 2),
          cursor ??
              PinCursor(
                color: cursorColor ?? theme.focusedColor,
                width: cursorWidth,
                height: cursorHeight,
              ),
        ],
      ],
    );
  }
}

/// Plays the digit entry animation once, when the digit first appears.
///
/// `AnimatedOpacity` / `AnimatedScale` animate *changes* of their value, so
/// the first frame is rendered at the hidden value and the visible value is
/// applied one frame later, which drives the transition. The widget is
/// created fresh each time a slot goes from empty to filled (the slot's
/// child changes type), so each new digit animates in.
class _SlotEntry extends StatefulWidget {
  final PinAnimationType type;
  final Duration duration;
  final Curve curve;
  final Widget child;

  const _SlotEntry({
    required this.type,
    required this.duration,
    required this.curve,
    required this.child,
  });

  @override
  State<_SlotEntry> createState() => _SlotEntryState();
}

class _SlotEntryState extends State<_SlotEntry> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case PinAnimationType.none:
        return widget.child;
      case PinAnimationType.fade:
        return AnimatedOpacity(
          opacity: _shown ? 1.0 : 0.0,
          duration: widget.duration,
          curve: widget.curve,
          child: widget.child,
        );
      case PinAnimationType.scale:
        return AnimatedScale(
          scale: _shown ? 1.0 : 0.0,
          duration: widget.duration,
          curve: widget.curve,
          child: widget.child,
        );
    }
  }
}

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

const _transparent = Color(0x00000000);

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

  /// Whether this slot draws its own focus border and fill. `PinField` sets
  /// this to false when it animates a [PinFocusRing] beneath the slots, in
  /// which case the focused slot is drawn transparent so the ring shows
  /// through.
  final bool drawFocus;

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
    this.drawFocus = true,
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
    final idle = (theme.defaultColor, theme.borderWidth, theme.fillColor);
    final filled = theme.highlightFilled
        ? (theme.filledColor, theme.borderWidth, theme.fillColor)
        : idle;

    switch (state) {
      case PinSlotState.focused:
        if (!drawFocus) {
          // The animated ring beneath supplies border and fill.
          return (_transparent, theme.borderWidth, _transparent);
        }
        return (
          theme.focusedColor,
          theme.focusedBorderWidth,
          theme.focusedFillColor,
        );
      case PinSlotState.filled:
        return filled;
      case PinSlotState.error:
        return (theme.errorColor, theme.focusedBorderWidth, theme.errorFillColor);
      case PinSlotState.disabled:
        return (theme.disabledColor, theme.borderWidth, theme.fillColor);
      case PinSlotState.success:
        if (theme.highlightSuccess) {
          return (theme.successColor, theme.focusedBorderWidth, theme.fillColor);
        }
        return character != null ? filled : idle;
      case PinSlotState.empty:
        return idle;
    }
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

/// Which part of the focus highlight a [PinFocusRing] draws.
enum PinFocusRingPart {
  /// Border and fill together.
  full,

  /// Only the fill; `PinField` slides this beneath the slots.
  fill,

  /// Only the border; `PinField` slides this above the slots so the ring
  /// stays visible while it moves.
  border,
}

/// The focus highlight `PinField` slides from slot to slot: the focused
/// border and fill of [theme], drawn in the slot's shape.
class PinFocusRing extends StatelessWidget {
  final PinThemeData theme;

  /// Border colour; defaults to [PinThemeData.focusedColor].
  final Color? color;

  /// Which part to draw.
  final PinFocusRingPart part;

  const PinFocusRing({
    super.key,
    required this.theme,
    this.color,
    this.part = PinFocusRingPart.full,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = part == PinFocusRingPart.fill
        ? _transparent
        : (color ?? theme.focusedColor);
    final fill = part == PinFocusRingPart.border
        ? _transparent
        : theme.focusedFillColor;
    final borderW = theme.focusedBorderWidth;
    final isUnderline = theme.style == PinSlotStyle.underline;

    // One tree shape for every style: the slot views are reused by index when
    // the style changes, and a child that exists in one style but not another
    // would survive the switch (an underline bar showing up under a box). So
    // the bar is always there and simply transparent for box and circle.
    final BoxDecoration decoration;
    switch (theme.style) {
      case PinSlotStyle.box:
        decoration = BoxDecoration(
          color: fill,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(theme.borderRadius),
          border: Border.all(color: borderColor, width: borderW),
        );
      case PinSlotStyle.circle:
        final radius =
            (theme.width < theme.height ? theme.width : theme.height) / 2;
        decoration = BoxDecoration(
          color: fill,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: borderW),
        );
      case PinSlotStyle.underline:
        decoration = BoxDecoration(
          color: fill,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: _transparent, width: 0),
        );
    }

    return Container(
      width: theme.width,
      height: theme.height,
      decoration: decoration,
      child: Column(
        children: [
          const Expanded(child: SizedBox()),
          Container(
            height: isUnderline ? borderW : 0,
            color: isUnderline ? borderColor : _transparent,
          ),
        ],
      ),
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

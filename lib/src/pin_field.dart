/// Core pin code / OTP input field widget for DartNative.
///
/// Architecture:
/// Uses a single native [TextField] (hidden / transparent) as the underlying
/// input engine, and renders individual decorative [PinSlot] boxes in a [Row]
/// on top. This avoids all known multi-field bugs (keyboard backspace issues,
/// broken paste, SMS autofill fragmentation).
library;

import 'dart:async';

import 'package:dartnative/dartnative.dart';
import 'package:dartnative/plugin.dart' show DartNativeReconciler;

import 'debug.dart';
import 'native/one_time_code_hint.dart';
import 'native/pinput_kit_ffi_bindings.dart';
import 'pin_layout.dart';
import 'pin_slot.dart';
import 'pin_theme.dart';

// ---------------------------------------------------------------------------
// Custom slot builder details
// ---------------------------------------------------------------------------

/// Details passed to [PinSlotBuilder] for custom slot rendering and animation.
class PinSlotDetails {
  /// Zero-based slot index (0 to length - 1).
  final int index;

  /// The character in this slot, or null if empty.
  final String? character;

  /// The visual state of this slot.
  final PinSlotState state;

  /// Resolved theme data for this slot.
  final PinThemeData theme;

  /// Whether this slot character should be obscured.
  final bool obscureText;

  /// Whether the blinking cursor should appear in this slot.
  final bool showCursor;

  /// Whether the pin field currently has keyboard focus.
  final bool isFocused;

  const PinSlotDetails({
    required this.index,
    required this.character,
    required this.state,
    required this.theme,
    required this.obscureText,
    required this.showCursor,
    required this.isFocused,
  });
}

/// Signature for building a custom pin slot widget.
typedef PinSlotBuilder =
    Widget Function(BuildContext context, PinSlotDetails details);

// ---------------------------------------------------------------------------
// PinField
// ---------------------------------------------------------------------------

/// A pin code / OTP input widget with per-digit slots.
///
/// [PinField] manages input via a single native [TextField], rendering a row
/// of decorated slot boxes according to [PinThemeData].
///
/// ```dart
/// PinField(
///   length: 6,
///   onCompleted: (pin) => verifyCode(pin),
/// )
/// ```
class PinField extends StatefulWidget {
  /// Number of pin digits. Defaults to 6.
  final int length;

  /// Controls the pin text. If null, [PinField] creates and manages its own.
  final TextEditingController? controller;

  /// Focus node for keyboard interactions.
  final FocusNode? focusNode;

  /// Optional theme override for this field. When null, [PinTheme.of] is used.
  final PinThemeData? theme;

  /// Whether to mask the entered characters (e.g. for passcodes).
  final bool obscureText;

  /// The obscuring character (defaults to theme's [PinThemeData.obscureCharacter]).
  final String? obscureCharacter;

  /// If set, a newly entered digit is displayed for this duration before
  /// being obscured (helpful on mobile to confirm typing).
  final Duration? peekDuration;

  /// Whether the field is interactive.
  final bool enabled;

  /// Whether the field takes focus automatically when rendered.
  final bool autofocus;

  /// Keyboard type; defaults to [TextInputType.number].
  final TextInputType keyboardType;

  /// Keyboard action (e.g. [TextInputAction.done], [TextInputAction.next]).
  final TextInputAction? textInputAction;

  /// Formatters applied to input; defaults to [FilteringTextInputFormatter.digitsOnly].
  final List<TextInputFormatter>? inputFormatters;

  /// Called whenever the pin value changes.
  final ValueChanged<String>? onChanged;

  /// Called when all [length] digits have been entered.
  final ValueChanged<String>? onCompleted;

  /// Called when the keyboard action (e.g. Done) is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Whether to display a blinking cursor in the active slot.
  final bool showCursor;

  /// Custom cursor widget; when null, the built-in [PinCursor] is used.
  final Widget? cursor;

  /// Cursor colour override.
  final Color? cursorColor;

  /// Cursor bar thickness; defaults to 2.
  final double cursorWidth;

  /// Cursor bar height; defaults to 24.
  final double? cursorHeight;

  /// Entry animation for newly entered digits.
  final PinAnimationType animationType;

  /// Duration of the digit entry animation.
  final Duration animationDuration;

  /// Curve of the digit entry animation.
  final Curve animationCurve;

  /// When non-null, places all slots into [PinSlotState.error].
  final String? errorText;

  /// Whether the field has an active error.
  final bool hasError;

  /// When true (and there is no error), all slots render in
  /// [PinSlotState.success], e.g. after the code has been verified.
  final bool success;

  /// Optional widget displayed in empty slots (e.g. a dash or dot).
  final Widget? preFilledWidget;

  /// Optional separator widget placed between slot groups (e.g. a hyphen).
  final Widget? separator;

  /// Slot indices after which [separator] is rendered (e.g. `[3]` for `123 — 456`).
  final List<int>? separatorPositions;

  /// Width reserved for [separator]; the separator is centred in it and
  /// [PinThemeData.spacing] is added on top. Defaults to 16.
  final double separatorWidth;

  /// Whether the focus highlight is a single ring that slides from slot to
  /// slot (drawn beneath the slots) instead of each slot switching its own
  /// border. Defaults to true; ignored when [slotBuilder] is set.
  final bool animateFocus;

  /// How long the focus ring takes to reach the next slot.
  final Duration focusAnimationDuration;

  /// Easing of the focus ring movement.
  final Curve focusAnimationCurve;

  /// Whether to dismiss the keyboard automatically when [length] digits are reached.
  final bool closeKeyboardWhenCompleted;

  /// Whether to trigger a subtle haptic feedback on each keystroke.
  final bool hapticFeedback;

  /// Alignment of the slots row. Defaults to [MainAxisAlignment.center].
  final MainAxisAlignment mainAxisAlignment;

  /// Custom slot builder for complete control over slot appearance and animations.
  final PinSlotBuilder? slotBuilder;

  /// Whether the native field is marked as a one-time-code field, so the
  /// system keyboard offers an incoming SMS code (iOS QuickType bar; Android
  /// autofill / Gboard chip). Defaults to true; turn off for passcodes that
  /// never arrive by SMS.
  final bool oneTimeCodeHint;

  const PinField({
    super.key,
    this.length = 6,
    this.controller,
    this.focusNode,
    this.theme,
    this.obscureText = false,
    this.obscureCharacter,
    this.peekDuration,
    this.enabled = true,
    this.autofocus = false,
    this.keyboardType = TextInputType.number,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onCompleted,
    this.onSubmitted,
    this.showCursor = true,
    this.cursor,
    this.cursorColor,
    this.cursorWidth = 2,
    this.cursorHeight,
    this.animationType = PinAnimationType.none,
    this.animationDuration = const Duration(milliseconds: 160),
    this.animationCurve = Curves.easeOut,
    this.errorText,
    this.hasError = false,
    this.success = false,
    this.preFilledWidget,
    this.separator,
    this.separatorPositions,
    this.separatorWidth = 16,
    this.animateFocus = true,
    this.focusAnimationDuration = const Duration(milliseconds: 220),
    this.focusAnimationCurve = Curves.easeOut,
    this.closeKeyboardWhenCompleted = true,
    this.hapticFeedback = true,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.slotBuilder,
    this.oneTimeCodeHint = true,
  }) : assert(length > 0, 'Pin length must be greater than 0');

  @override
  State<PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<PinField> {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;

  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController!;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode!;

  int? _peekIndex;
  Timer? _peekTimer;
  String _previousText = '';

  /// Set when the keyboard was dismissed on completion. Android keeps
  /// reporting the field as focused after that, so the next slot tap must
  /// re-request focus to bring the keyboard back.
  bool _keyboardDismissed = false;

  /// Finds the hidden native field's element (and so its native view id)
  /// for the one-time-code hint.
  final GlobalKey _hiddenFieldKey = GlobalKey();
  bool _hintApplied = false;

  void _scheduleOneTimeCodeHint() {
    if (!widget.oneTimeCodeHint || _hintApplied) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hintApplied) return;
      final element = DartNativeReconciler.findGlobalKeyElement(
        _hiddenFieldKey,
      );
      final viewId = element?.viewId;
      if (viewId == null) {
        pinputKitLog('one-time-code hint: hidden field has no view yet');
        return;
      }
      _hintApplied = applyOneTimeCodeHint(viewId);
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    _effectiveController.addListener(_handleControllerChanged);
    _previousText = _effectiveController.text;

    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    _effectiveFocusNode.addListener(_handleFocusChanged);

    pinputKitLog('PinField.initState length=${widget.length}');
    _scheduleOneTimeCodeHint();
  }

  @override
  void didUpdateWidget(covariant PinField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      if (widget.controller == null) {
        _internalController = TextEditingController.fromValue(
          oldWidget.controller!.value,
        );
      } else {
        _internalController?.dispose();
        _internalController = null;
      }
      _effectiveController.addListener(_handleControllerChanged);
    }

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChanged);
      if (widget.focusNode == null) {
        _internalFocusNode = FocusNode();
      } else {
        _internalFocusNode?.dispose();
        _internalFocusNode = null;
      }
      _effectiveFocusNode.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    pinputKitLog('PinField.dispose');
    _peekTimer?.cancel();
    _effectiveController.removeListener(_handleControllerChanged);
    _effectiveFocusNode.removeListener(_handleFocusChanged);
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final newText = _effectiveController.text;
    pinputKitLog('PinField._handleControllerChanged "$newText" sel=${_effectiveController.selection}');

    // Handle peek duration when typing a new character.
    if (widget.peekDuration != null &&
        widget.peekDuration! > Duration.zero &&
        widget.obscureText &&
        newText.length > _previousText.length &&
        newText.isNotEmpty) {
      _peekTimer?.cancel();
      _peekIndex = newText.length - 1;
      _peekTimer = Timer(widget.peekDuration!, () {
        if (!mounted) return;
        setState(() => _peekIndex = null);
      });
    }

    // Keystroke haptic feedback.
    if (widget.hapticFeedback && newText != _previousText) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {
        // Platform without haptics or running in test.
      }
    }

    final oldText = _previousText;
    _previousText = newText;

    setState(() {});

    // Completion callback.
    // Fires whenever a change leaves the pin complete, including a digit
    // corrected in place after the pin was already full.
    if (newText.length == widget.length && newText != oldText) {
      widget.onCompleted?.call(newText);
      if (widget.closeKeyboardWhenCompleted) {
        // Defer past this frame: when the text was set programmatically (an
        // autofill strategy, a paste through the controller) the native field
        // still holds the old text until the rebuild pushes the new value.
        // Unfocusing synchronously ends native editing with that stale text,
        // which then flows back into the controller and truncates the pin.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_effectiveController.text.length == widget.length) {
            _keyboardDismissed = true;
            _effectiveFocusNode.unfocus();
          }
        });
      }
    }
  }

  void _handleFocusChanged() {
    pinputKitLog(
      'PinField focus changed -> hasFocus=${_effectiveFocusNode.hasFocus}',
    );
    // Defer rebuild after frame to avoid racing native first-responder sync.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _handleSubmitted(String value) {
    widget.onSubmitted?.call(value);
  }

  /// The slot being edited: the selection start when the controller reports
  /// one inside the text, else the end of the text.
  int _activeIndex(String text) {
    final len = text.length;
    final sel = _effectiveController.selection;
    final start = sel.baseOffset < sel.extentOffset
        ? sel.baseOffset
        : sel.extentOffset;
    if (start < 0 || start > len) return len;
    return start;
  }

  /// Tapping a slot moves editing there: a filled slot is selected so the
  /// next digit replaces it; an empty slot puts the caret at the end.
  void _handleSlotTap(int index) {
    if (!widget.enabled) return;
    final len = _effectiveController.text.length;
    final selection = index < len
        ? TextSelection(baseOffset: index, extentOffset: index + 1)
        : TextSelection.collapsed(offset: len);
    pinputKitLog('PinField slot tap $index -> $selection');
    if (!_effectiveFocusNode.hasFocus || _keyboardDismissed) {
      // Focus first (dropping a stale focus so the keyboard really comes
      // back), then apply the selection once the native field has focus;
      // focusing resets the caret to the end.
      _keyboardDismissed = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_effectiveFocusNode.hasFocus) _effectiveFocusNode.unfocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _effectiveFocusNode.requestFocus();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _effectiveController.selection = selection;
            setState(() {});
          });
        });
      });
      return;
    }
    // The field already has focus. On Android that is still true after the
    // back button hid the keyboard, so requesting focus again would do
    // nothing. Ask the platform to show the keyboard directly, then apply
    // the tapped selection. Showing the keyboard may move the native caret,
    // so check again two frames later and put the selection back if it did.
    _showNativeKeyboard();
    _effectiveController.selection = selection;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_effectiveController.selection != selection) {
          pinputKitLog(
            'PinField selection moved to ${_effectiveController.selection} '
            'after keyboard show; restoring $selection',
          );
          _effectiveController.selection = selection;
        }
        setState(() {});
      });
    });
  }

  /// Asks the platform to show the soft keyboard for the hidden native
  /// field. Used when the field is focused but the keyboard is hidden.
  void _showNativeKeyboard() {
    if (!PinputKitFFIBindings.isLoaded) return;
    final viewId = DartNativeReconciler.findGlobalKeyElement(
      _hiddenFieldKey,
    )?.viewId;
    if (viewId == null) return;
    final rc = PinputKitFFIBindings.showKeyboard(viewId);
    pinputKitLog('PinField show keyboard on view $viewId -> rc=$rc');
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? PinTheme.of(context);
    final text = _effectiveController.text;
    final isFocused = _effectiveFocusNode.hasFocus;
    final hasError = widget.hasError || widget.errorText != null;

    final List<Widget> slotWidgets = [];
    final separatorIndices =
        widget.separatorPositions ??
        (widget.separator != null ? [widget.length ~/ 2] : const <int>[]);
    final separatorAfter = widget.separator == null
        ? const <int>{}
        : separatorIndices.where((i) => i > 0 && i < widget.length).toSet();

    final activeIndex = _activeIndex(text);
    final useRing = widget.animateFocus && widget.slotBuilder == null;

    for (int i = 0; i < widget.length; i++) {
      final character = i < text.length ? text[i] : null;
      final slotIsActive = isFocused && i == activeIndex;

      final PinSlotState state;
      if (!widget.enabled) {
        state = PinSlotState.disabled;
      } else if (hasError) {
        state = PinSlotState.error;
      } else if (widget.success) {
        state = PinSlotState.success;
      } else if (slotIsActive) {
        state = PinSlotState.focused;
      } else if (character != null) {
        state = PinSlotState.filled;
      } else {
        state = PinSlotState.empty;
      }

      final shouldObscure =
          widget.obscureText &&
          (widget.peekDuration == null || i != _peekIndex);

      final slotTheme = widget.obscureCharacter != null
          ? theme.copyWith(obscureCharacter: widget.obscureCharacter)
          : theme;

      final Widget slotWidget;
      if (widget.slotBuilder != null) {
        slotWidget = widget.slotBuilder!(
          context,
          PinSlotDetails(
            index: i,
            character: character,
            state: state,
            theme: slotTheme,
            obscureText: shouldObscure,
            showCursor: widget.showCursor && slotIsActive,
            isFocused: isFocused,
          ),
        );
      } else {
        slotWidget = PinSlot(
          character: character,
          state: state,
          theme: slotTheme,
          obscureText: shouldObscure,
          showCursor: widget.showCursor && slotIsActive,
          cursor: widget.cursor,
          cursorColor: widget.cursorColor,
          cursorWidth: widget.cursorWidth,
          cursorHeight: widget.cursorHeight,
          animationType: widget.animationType,
          animationDuration: widget.animationDuration,
          animationCurve: widget.animationCurve,
          preFilledWidget: widget.preFilledWidget,
          drawFocus: !useRing,
        );
      }

      slotWidgets.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleSlotTap(i),
          child: slotWidget,
        ),
      );

      // Separator cell: a fixed width so slot positions stay computable for
      // the focus ring (see slotOffsets).
      if (i < widget.length - 1) {
        if (separatorAfter.contains(i + 1)) {
          slotWidgets.add(
            SizedBox(
              width: widget.separatorWidth + theme.spacing,
              height: theme.height,
              child: Center(child: widget.separator!),
            ),
          );
        } else {
          slotWidgets.add(SizedBox(width: theme.spacing));
        }
      }
    }

    // Formatters: default to digits-only and limit to `length`.
    final formatters =
        widget.inputFormatters ??
        [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(widget.length),
        ];

    // Visible slots row, content-sized so the ring offsets below are exact;
    // the outer Row applies mainAxisAlignment.
    final slotsRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: slotWidgets,
    );

    // Focus ring: one highlight that slides to the active slot, in two
    // layers. The fill slides beneath the slots (the active slot is drawn
    // transparent, so the digit and cursor stay on top of it) and the border
    // slides above them, so the ring is visible for the whole move. The top
    // layer is wrapped in IgnorePointer so it never takes a touch on iOS; on
    // Android a plain view passes touches through anyway, and the slot
    // beneath must stay tappable to bring the keyboard back.
    Widget? ringFill;
    Widget? ringBorder;
    if (useRing) {
      final offsets = slotOffsets(
        length: widget.length,
        slotWidth: theme.width,
        spacing: theme.spacing,
        separatorAfter: separatorAfter,
        separatorWidth: widget.separatorWidth,
      );
      final ringIndex = activeIndex.clamp(0, widget.length - 1);
      final ringVisible = isFocused && widget.enabled && !hasError;

      Widget layer(PinFocusRingPart part) => AnimatedPositioned(
        left: offsets[ringIndex],
        top: 0,
        width: theme.width,
        height: theme.height,
        duration: widget.focusAnimationDuration,
        curve: widget.focusAnimationCurve,
        child: AnimatedOpacity(
          opacity: ringVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 120),
          child: PinFocusRing(theme: theme, part: part),
        ),
      );

      ringFill = layer(PinFocusRingPart.fill);
      ringBorder = IgnorePointer(child: layer(PinFocusRingPart.border));
    }

    // Hidden native TextField that captures keyboard and autofill input.
    // The field is 1x1 behind the slots (listed before the Row, so it is
    // beneath it), so touches reach the slot GestureDetectors instead of the
    // native field: an EditText covering the row would take Android touches
    // and show its own caret and selection handle. IgnorePointer is not an
    // option: on iOS it disables user interaction on the UITextField and
    // UIKit then resigns first responder.
    final hiddenInput = Positioned(
      left: 0,
      top: 0,
      width: 1,
      height: 1,
      child: Opacity(
        opacity: 0.0,
        child: TextField(
          key: _hiddenFieldKey,
          controller: _effectiveController,
          focusNode: _effectiveFocusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction ?? TextInputAction.done,
          inputFormatters: formatters,
          maxLength: widget.length,
          cursorColor: const Color(0x00000000),
          style: const TextStyle(fontSize: 1, color: Color(0x00000000)),
          decoration: const InputDecoration(contentPadding: EdgeInsets.zero),
          onChanged: widget.onChanged,
          onSubmitted: _handleSubmitted,
        ),
      ),
    );

    // The Row is the first non-positioned child, so it sizes the Stack; the
    // Positioned field and ring before it sit beneath the slots.
    final stack = Stack(
      alignment: Alignment.center,
      children: [
        hiddenInput,
        ?ringFill,
        slotsRow,
        ?ringBorder,
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // A tap between or beside the slots edits at the end of the pin.
      onTap: () => _handleSlotTap(widget.length),
      child: Row(
        mainAxisAlignment: widget.mainAxisAlignment,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [stack],
      ),
    );
  }
}

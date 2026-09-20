/// Form integration for [PinField] with Flutter's Form API via `forms_kit`.
library;

import 'package:dartnative/dartnative.dart';
import 'package:forms_kit/forms_kit.dart';

import 'debug.dart';
import 'pin_field.dart';
import 'pin_theme.dart';

/// A [FormField] that contains a [PinField].
///
/// Integrates [PinField] seamlessly into forms_kit's [Form], enabling
/// [FormState.validate], [FormState.save], [FormState.reset],
/// [FormState.focusFirstInvalid], and [FormState.isValid].
///
/// ```dart
/// PinFormField(
///   length: 6,
///   validator: (pin) => (pin == null || pin.length < 6)
///       ? 'Enter the complete 6-digit code'
///       : null,
///   onSaved: (pin) => _otp = pin,
/// )
/// ```
///
/// **Validation while typing.** A pin is entered one digit at a time, so a
/// `length` validator fails after the very first keystroke. To keep the slots
/// from turning red mid-entry, a partial pin is not counted as a user
/// interaction: with `AutovalidateMode.onUserInteraction` (on this field or
/// on the enclosing [Form]) automatic validation first runs when the pin is
/// complete. An explicit [FormState.validate] always runs the validator, so a
/// submit button still reports an incomplete pin. Set
/// [validateWhileIncomplete] to `true` to validate on every keystroke
/// instead. `AutovalidateMode.always` validates on every build regardless.
///
/// The widget tree returned for the field keeps the same shape whether or
/// not an error is shown, so the underlying native text field is never
/// remounted.
class PinFormField extends FormField<String> {
  /// Controls the pin text.
  final TextEditingController? controller;

  /// Called when the pin text changes.
  final ValueChanged<String>? onChanged;

  /// Number of pin digits.
  final int length;

  /// Whether automatic validation may run while the pin is shorter than
  /// [length]. Defaults to `false`; see the class documentation.
  final bool validateWhileIncomplete;

  final FocusNode? _focusNode;

  PinFormField({
    super.key,
    this.controller,
    String? initialValue,
    FocusNode? focusNode,
    super.forceErrorText,
    super.validator,
    super.onSaved,
    super.onReset,
    super.errorBuilder,
    AutovalidateMode? autovalidateMode,
    bool? enabled,
    this.length = 6,
    this.validateWhileIncomplete = false,
    PinThemeData? theme,
    bool obscureText = false,
    String? obscureCharacter,
    Duration? peekDuration,
    bool autofocus = false,
    TextInputType keyboardType = TextInputType.number,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    this.onChanged,
    ValueChanged<String>? onCompleted,
    ValueChanged<String>? onSubmitted,
    bool showCursor = true,
    Widget? cursor,
    Color? cursorColor,
    double cursorWidth = 2,
    double? cursorHeight,
    PinAnimationType animationType = PinAnimationType.none,
    Duration animationDuration = const Duration(milliseconds: 160),
    Curve animationCurve = Curves.easeOut,
    bool success = false,
    Widget? preFilledWidget,
    Widget? separator,
    List<int>? separatorPositions,
    double separatorWidth = 16,
    bool animateFocus = true,
    Duration focusAnimationDuration = const Duration(milliseconds: 220),
    Curve focusAnimationCurve = Curves.easeOut,
    bool closeKeyboardWhenCompleted = true,
    bool hapticFeedback = true,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.center,
    PinSlotBuilder? slotBuilder,
    TextStyle? errorStyle,
    EdgeInsets errorPadding = const EdgeInsets.only(top: 8),
  }) : assert(initialValue == null || controller == null),
       assert(length > 0, 'Pin length must be greater than 0'),
       _focusNode = focusNode,
       super(
         initialValue: controller != null
             ? controller.text
             : (initialValue ?? ''),
         enabled: enabled ?? true,
         autovalidateMode: autovalidateMode ?? AutovalidateMode.disabled,
         builder: (FormFieldState<String> field) {
           final state = field as _PinFormFieldState;
           final isEnabled = enabled ?? true;
           final effectiveTheme = theme ?? PinTheme.of(state.context);
           final errorText = field.errorText;

           void onChangedHandler(String value) {
             pinputKitLog('PinFormField.onChanged "$value"');
             field.didChange(value);
             state._pinFormField.onChanged?.call(value);
           }

           final pinWidget = PinField(
             length: length,
             controller: state._effectiveController,
             focusNode: state._effectiveFocusNode,
             theme: effectiveTheme,
             obscureText: obscureText,
             obscureCharacter: obscureCharacter,
             peekDuration: peekDuration,
             enabled: isEnabled,
             autofocus: autofocus,
             keyboardType: keyboardType,
             textInputAction: textInputAction,
             inputFormatters: inputFormatters,
             onChanged: onChangedHandler,
             onCompleted: onCompleted,
             onSubmitted: onSubmitted,
             showCursor: showCursor,
             cursor: cursor,
             cursorColor: cursorColor,
             cursorWidth: cursorWidth,
             cursorHeight: cursorHeight,
             animationType: animationType,
             animationDuration: animationDuration,
             animationCurve: animationCurve,
             errorText: errorText,
             hasError: field.hasError,
             success: success,
             preFilledWidget: preFilledWidget,
             separator: separator,
             separatorPositions: separatorPositions,
             separatorWidth: separatorWidth,
             animateFocus: animateFocus,
             focusAnimationDuration: focusAnimationDuration,
             focusAnimationCurve: focusAnimationCurve,
             closeKeyboardWhenCompleted: closeKeyboardWhenCompleted,
             hapticFeedback: hapticFeedback,
             mainAxisAlignment: mainAxisAlignment,
             slotBuilder: slotBuilder,
           );

           // The PinField stays at index 0 of this Column whether or not an
           // error is shown, so its element (and the native text field
           // inside it) survives the rebuild.
           return Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.center,
             children: [
               pinWidget,
               if (errorText != null)
                 Padding(
                   padding: errorPadding,
                   child: errorBuilder != null
                       ? errorBuilder(state.context, errorText)
                       : Text(
                           errorText,
                           style:
                               errorStyle ??
                               TextStyle(
                                 color: effectiveTheme.errorColor,
                                 fontSize: 13,
                               ),
                         ),
                 ),
             ],
           );
         },
       );

  @override
  FormFieldState<String> createState() => _PinFormFieldState();
}

class _PinFormFieldState extends FormFieldState<String> {
  TextEditingController? _controller;
  FocusNode? _focusNode;
  late final String? _initialValue;

  TextEditingController get _effectiveController =>
      _pinFormField.controller ?? _controller!;

  FocusNode get _effectiveFocusNode => _pinFormField._focusNode ?? _focusNode!;

  PinFormField get _pinFormField => super.widget as PinFormField;

  @override
  void initState() {
    super.initState();
    if (_pinFormField.controller == null) {
      _controller = TextEditingController(text: widget.initialValue);
    } else {
      _pinFormField.controller!.addListener(_handleControllerChanged);
    }
    _initialValue = _pinFormField.controller?.text ?? widget.initialValue;

    if (_pinFormField._focusNode == null) {
      _focusNode = FocusNode();
    }
    _effectiveFocusNode.addListener(_handleFocusChanged);
    pinputKitLog('PinFormField.initState');
  }

  @override
  void didUpdateWidget(FormField<String> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget as PinFormField;
    if (_pinFormField.controller != old.controller) {
      old.controller?.removeListener(_handleControllerChanged);
      _pinFormField.controller?.addListener(_handleControllerChanged);

      if (old.controller != null && _pinFormField.controller == null) {
        _controller = TextEditingController.fromValue(old.controller!.value);
      }

      if (_pinFormField.controller != null) {
        setValue(_pinFormField.controller!.text);
        if (old.controller == null) {
          _controller?.dispose();
          _controller = null;
        }
      }
    }

    if (_pinFormField._focusNode != old._focusNode) {
      (old._focusNode ?? _focusNode)?.removeListener(_handleFocusChanged);
      if (old._focusNode == null && _pinFormField._focusNode != null) {
        _focusNode?.dispose();
        _focusNode = null;
      } else if (_pinFormField._focusNode == null) {
        _focusNode = FocusNode();
      }
      _effectiveFocusNode.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    pinputKitLog('PinFormField.dispose');
    _pinFormField.controller?.removeListener(_handleControllerChanged);
    _effectiveFocusNode.removeListener(_handleFocusChanged);
    _controller?.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  /// Whether [value] holds a complete pin of [PinFormField.length] digits.
  bool _isComplete(String? value) =>
      (value ?? '').length >= _pinFormField.length;

  @override
  void didChange(String? value) {
    if (!_pinFormField.validateWhileIncomplete && !_isComplete(value)) {
      // A partial pin: store the value and notify the Form (so Form.onChanged
      // and FormState.isValid stay current) without counting it as a user
      // interaction, so that `onUserInteraction` auto-validation waits for
      // the pin to be complete. An explicit FormState.validate() still runs.
      pinputKitLog('PinFormField.didChange partial "$value"');
      setState(() => setValue(value));
      Form.maybeOf(context)?.fieldDidChange();
    } else {
      super.didChange(value);
    }
    if (_effectiveController.text != value) {
      _effectiveController.text = value ?? '';
    }
  }

  @override
  void reset() {
    _effectiveController.text = _initialValue ?? '';
    super.reset();
    _pinFormField.onChanged?.call(_initialValue ?? '');
  }

  void _handleControllerChanged() {
    if (_effectiveController.text != value) {
      didChange(_effectiveController.text);
    }
  }

  void _handleFocusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void Function()? get requestFocus {
    final node = _effectiveFocusNode;
    return () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) node.requestFocus();
      });
    };
  }
}

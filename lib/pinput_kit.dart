/// Pin code / OTP fields and SMS autofill for DartNative.
///
/// DartNative provides a native `TextField`, but no pin code or OTP input
/// widget. This package provides [PinField] and [PinFormField] with individual
/// slot boxes, multiple visual styles (box, underline, circle), full
/// configurability, and seamless integration with `forms_kit`'s [Form] API.
///
/// Built on a single underlying native `TextField` with composed decorative
/// slots on top, ensuring reliable backspace, paste, and autofill behavior
/// across iOS and Android.
///
/// ```dart
/// PinField(
///   length: 6,
///   onCompleted: (pin) => print('Entered pin: $pin'),
/// )
/// ```
///
/// With `forms_kit`:
/// ```dart
/// PinFormField(
///   length: 6,
///   validator: (pin) => (pin == null || pin.length < 6)
///       ? 'Enter all 6 digits'
///       : null,
///   onSaved: (pin) => _otp = pin,
/// )
/// ```
library;

/// forms_kit's Form API (`Form`, `FormState`, `FormField`, `AutovalidateMode`,
/// `Validators`, ...) is re-exported so an OTP screen needs only
/// `package:pinput_kit/pinput_kit.dart` next to `package:dartnative`.
export 'package:forms_kit/forms_kit.dart';

export 'src/debug.dart';
export 'src/native/pinput_kit_ffi_bindings.dart' show PinputKitFFIBindings;
export 'src/pin_controller.dart';
export 'src/pin_cursor.dart';
export 'src/pin_field.dart';
export 'src/pin_form_field.dart';
export 'src/pin_parser.dart';
export 'src/pin_layout.dart' show slotOffsets, slotsRowWidth;
export 'src/pin_slot.dart';
export 'src/pin_strategy.dart';
export 'src/pin_theme.dart';
export 'src/pin_validators.dart';
export 'src/sms/sms_retriever_strategy.dart';

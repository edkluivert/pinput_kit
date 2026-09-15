/// Applies the one-time-code hint to the hidden native text field.
library;

import '../debug.dart';
import 'pinput_kit_ffi_bindings.dart';

bool _warned = false;

/// Marks the native field behind [viewId] as a one-time-code field so the
/// system keyboard suggests an incoming SMS code (iOS QuickType, Android
/// autofill). Returns true when applied.
bool applyOneTimeCodeHint(int viewId) {
  if (!PinputKitFFIBindings.isLoaded) {
    if (!_warned) {
      _warned = true;
      pinputKitLog(
        'one-time-code hint skipped: native symbols not loaded '
        '(run `dn pub get` so the registrant calls '
        'PinputKitFFIBindings.loadSymbols())',
      );
    }
    return false;
  }
  final rc = PinputKitFFIBindings.setOneTimeCodeHint(viewId);
  pinputKitLog('one-time-code hint on view $viewId -> rc=$rc');
  return rc == 0;
}

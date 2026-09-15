/// FFI bindings to pinput_kit's native side.
///
/// iOS: `@_cdecl` functions in `ios/Classes/PinputKit.swift`, resolved from
/// the app binary. Android: exported C functions in
/// `android/src/main/cpp/pinput_kit.cpp` (libpinput_kit.so), which call into
/// `PinputKitBridge.kt` over JNI.
///
/// Events that native delivers later (an SMS arriving, a timeout) come back
/// through one dispatcher pointer for the whole plugin, routed by token.
/// Native re-checks the framework's restart counter before every delivery,
/// so a hot restart never invokes a stale pointer.
library;

import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

import '../debug.dart';

typedef _SetDispatcherC = Void Function(Int64);
typedef _SetDispatcherD = void Function(int);

typedef _SmsStartC = Int32 Function(Int64, Int32);
typedef _SmsStartD = int Function(int, int);

typedef _SmsStopC = Void Function(Int64);
typedef _SmsStopD = void Function(int);

typedef _AppSignatureC = Pointer<Utf8> Function();
typedef _AppSignatureD = Pointer<Utf8> Function();

typedef _SetOneTimeCodeC = Int32 Function(Int64);
typedef _SetOneTimeCodeD = int Function(int);

typedef _ShowKeyboardC = Int32 Function(Int64);
typedef _ShowKeyboardD = int Function(int);

/// (token, eventType, payload) — the one C signature every native event
/// arrives with.
typedef _DispatchC = Void Function(Int64, Int32, Pointer<Utf8>);

/// Signature for a handler registered under a token.
typedef PinputKitEventHandler = void Function(int type, String payload);

abstract final class PinputKitFFIBindings {
  static bool _loaded = false;

  /// Whether [loadSymbols] ran on a supported platform. False on a platform
  /// without native support or when the app's registrant was not regenerated
  /// with `dn pub get`.
  static bool get isLoaded => _loaded;

  static _SetOneTimeCodeD? _setOneTimeCode;
  static _ShowKeyboardD? _showKeyboard;
  static _SmsStartD? _smsStart;
  static _SmsStopD? _smsStop;
  static _AppSignatureD? _appSignature;

  /// Loads the native symbols. Called by the generated
  /// `DartNativePluginRegistrant.registerAll()`; safe to call more than once.
  static void loadSymbols() {
    if (_loaded) return;
    if (!Platform.isIOS && !Platform.isAndroid) return; // platform guard
    try {
      final lib = Platform.isAndroid
          ? DynamicLibrary.open('libpinput_kit.so')
          : DynamicLibrary.process();
      _setOneTimeCode = lib.lookupFunction<_SetOneTimeCodeC, _SetOneTimeCodeD>(
        'PinputKitTextFieldSetOneTimeCode',
      );
      _showKeyboard = lib.lookupFunction<_ShowKeyboardC, _ShowKeyboardD>(
        'PinputKitTextFieldShowKeyboard',
      );
      if (Platform.isAndroid) {
        final setDispatcher = lib
            .lookupFunction<_SetDispatcherC, _SetDispatcherD>(
              'PinputKitSetDispatcher',
            );
        _smsStart = lib.lookupFunction<_SmsStartC, _SmsStartD>(
          'PinputKitSmsStart',
        );
        _smsStop = lib.lookupFunction<_SmsStopC, _SmsStopD>('PinputKitSmsStop');
        _appSignature = lib.lookupFunction<_AppSignatureC, _AppSignatureD>(
          'PinputKitAppSignature',
        );
        // Hand native the dispatcher address — once per Dart session; the
        // native side re-registers its generation stamp with it.
        setDispatcher(_dispatchPtr.address);
      }
      _loaded = true;
      pinputKitLog('PinputKitFFIBindings loaded (${Platform.operatingSystem})');
    } catch (error) {
      pinputKitLog('PinputKitFFIBindings.loadSymbols failed: $error');
    }
  }

  // ── Dispatcher ─────────────────────────────────────────────────────────

  static final Map<int, PinputKitEventHandler> _handlers = {};
  static int _nextToken = 1;

  static void _dispatch(int token, int type, Pointer<Utf8> payload) {
    final handler = _handlers[token];
    if (handler == null) return; // a token from before a hot restart
    handler(type, payload == nullptr ? '' : payload.toDartString());
  }

  static final Pointer<NativeFunction<_DispatchC>> _dispatchPtr =
      Pointer.fromFunction<_DispatchC>(_dispatch);

  /// Registers [handler] and returns its token.
  static int registerHandler(PinputKitEventHandler handler) {
    final token = _nextToken++;
    _handlers[token] = handler;
    return token;
  }

  /// Removes the handler registered under [token].
  static void removeHandler(int token) => _handlers.remove(token);

  // ── SMS (Android) ──────────────────────────────────────────────────────

  /// Whether the SMS listener is available (Android with symbols loaded).
  static bool get supportsSms => _loaded && _smsStart != null;

  /// Starts listening; events arrive at the handler registered under
  /// [token]. Returns 0 on success, else a native error code.
  static int smsStart(int token, int mode) =>
      _smsStart?.call(token, mode) ?? -1;

  /// Stops the listener started with [token].
  static void smsStop(int token) => _smsStop?.call(token);

  /// The app's SMS Retriever hash(es), comma separated; empty when
  /// unavailable. The native side caches the string for the app lifetime.
  static String appSignature() {
    final fn = _appSignature;
    if (fn == null) return '';
    final ptr = fn();
    return ptr == nullptr ? '' : ptr.toDartString();
  }

  // ── One-time-code hint ─────────────────────────────────────────────────

  /// Marks the native text field with view id [viewId] as a one-time-code
  /// field (`UITextContentType.oneTimeCode` on iOS, the `smsOTPCode`
  /// autofill hint on Android). Returns 0 on success.
  static int setOneTimeCodeHint(int viewId) =>
      _setOneTimeCode?.call(viewId) ?? -1;

  // ── Soft keyboard ──────────────────────────────────────────────────────

  /// Shows the soft keyboard for the native field with view id [viewId].
  /// Android calls `InputMethodManager.showSoftInput`; iOS makes the field
  /// first responder. Used after the Android back button hides the keyboard
  /// while the field keeps focus. Returns 0 on success.
  static int showKeyboard(int viewId) => _showKeyboard?.call(viewId) ?? -1;
}

/// Android SMS autofill through Google Play services' SMS Retriever and
/// User Consent APIs, as a [PinCodeStrategy].
library;

import 'dart:async';
import 'dart:io' show Platform;

import '../debug.dart';
import '../native/pinput_kit_ffi_bindings.dart';
import '../pin_strategy.dart';

/// Which Play services API delivers the message.
enum SmsRetrieverMode {
  /// SMS Retriever API: no permission and no prompt, but the SMS must end
  /// with the app's 11-character hash ([SmsRetrieverPinStrategy.appSignature]).
  retriever,

  /// SMS User Consent API: any SMS containing a 4–10 digit code; the system
  /// shows a one-tap consent prompt before the message is handed over.
  userConsent,
}

/// Listens for the verification SMS on Android and resolves with its body,
/// which [PinEditingController] then parses with [extractPinCode].
///
/// ```dart
/// final controller = PinEditingController(
///   pinLength: 6,
///   strategies: [if (SmsRetrieverPinStrategy.isSupported) SmsRetrieverPinStrategy()],
/// );
/// ```
///
/// On iOS and other platforms [isSupported] is false and [listenForCode]
/// fails with [UnsupportedError]; the controller logs it and keeps listening
/// to the other strategies. Play services stops the listener after five
/// minutes ([timeout]); call `startListening` again (e.g. from "resend").
class SmsRetrieverPinStrategy extends PinCodeStrategy {
  final SmsRetrieverMode mode;

  SmsRetrieverPinStrategy({this.mode = SmsRetrieverMode.retriever});

  /// Play services' own listening window.
  static const Duration timeout = Duration(minutes: 5);

  /// Whether this platform delivers SMS (Android with native symbols loaded).
  static bool get isSupported =>
      Platform.isAndroid && PinputKitFFIBindings.supportsSms;

  /// The hash the SMS must end with for [SmsRetrieverMode.retriever], e.g.
  /// `FA+9qCX9VSu`. Several comma-separated values appear when the app is
  /// signed with more than one certificate (debug vs release). Empty when
  /// unsupported. Print it during development and give it to whoever sends
  /// the SMS.
  static String get appSignature =>
      isSupported ? PinputKitFFIBindings.appSignature() : '';

  Completer<String>? _completer;
  int? _token;

  @override
  Future<String> listenForCode() {
    if (!isSupported) {
      return Future<String>.error(
        UnsupportedError('SmsRetrieverPinStrategy is Android-only'),
      );
    }
    stopListening();
    final completer = Completer<String>();
    _completer = completer;
    final token = PinputKitFFIBindings.registerHandler((type, payload) {
      if (completer.isCompleted) return;
      switch (type) {
        case _eventMessage:
          pinputKitLog('SmsRetrieverPinStrategy: message received');
          completer.complete(payload);
        case _eventTimeout:
          completer.completeError(
            TimeoutException('No verification SMS received', timeout),
          );
        default:
          completer.completeError(StateError('SMS listener error: $payload'));
      }
      _release();
    });
    _token = token;
    final rc = PinputKitFFIBindings.smsStart(token, mode.index);
    pinputKitLog('SmsRetrieverPinStrategy: start ${mode.name} -> rc=$rc');
    if (rc != 0) {
      _release();
      completer.completeError(
        StateError('SMS listener failed to start (code $rc)'),
      );
    }
    return completer.future;
  }

  @override
  void stopListening() {
    final completer = _completer;
    _release();
    if (completer != null && !completer.isCompleted) {
      completer.completeError(StateError('SMS listening stopped'));
    }
  }

  void _release() {
    final token = _token;
    if (token != null) {
      PinputKitFFIBindings.smsStop(token);
      PinputKitFFIBindings.removeHandler(token);
    }
    _token = null;
    _completer = null;
  }

  static const int _eventMessage = 1;
  static const int _eventTimeout = 2;
}

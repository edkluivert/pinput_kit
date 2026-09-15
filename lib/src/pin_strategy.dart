/// Strategy interface and implementations for receiving OTP / PIN codes
/// from different sources (SMS, push notifications, websockets, or tests).
///
/// Inspired by the strategy pattern in `surfstudio/flutter-otp-autofill`.
library;

import 'dart:async';

/// Base contract for an OTP code source.
///
/// Implement this to deliver verification codes from any source:
/// - Push notification payload
/// - In-app chat or websocket
/// - Integration test / mock
/// - A platform SMS listener you provide (there is no built-in one yet)
///
/// The returned message may be a full SMS body; the controller extracts the
/// digits with [extractPinCode] or a custom parser.
abstract class PinCodeStrategy {
  const PinCodeStrategy();

  /// Listens for and returns an incoming verification message or code.
  Future<String> listenForCode();

  /// Called by the controller when it stops listening (a code arrived from
  /// another strategy, the controller was disposed, or `stopListening()` was
  /// called). Override to cancel platform subscriptions. The default is a
  /// no-op.
  void stopListening() {}
}

/// A strategy for testing that emits a predetermined [code] after an optional
/// [delay].
class TestPinStrategy extends PinCodeStrategy {
  final String code;
  final Duration delay;

  const TestPinStrategy({
    required this.code,
    this.delay = const Duration(seconds: 2),
  });

  @override
  Future<String> listenForCode() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return code;
  }
}

/// A strategy that resolves with the first event of a [Stream] of incoming
/// messages (e.g. push-notification payloads).
///
/// Pass a broadcast stream if the controller may start listening more than
/// once (for example after "resend code"); a single-subscription stream can
/// only be listened to once and the second attempt fails.
class StreamPinStrategy extends PinCodeStrategy {
  final Stream<String> stream;

  const StreamPinStrategy(this.stream);

  @override
  Future<String> listenForCode() => stream.first;
}

/// Dedicated controller for pin fields with autofill strategy support.
///
/// Extends DartNative's [TextEditingController] and adds support for
/// listening to [PinCodeStrategy] instances (e.g. [TestPinStrategy],
/// push notifications, SMS receivers) with code extraction.
library;

import 'package:dartnative/dartnative.dart';

import 'debug.dart';
import 'pin_parser.dart';
import 'pin_strategy.dart';

export 'pin_parser.dart' show PinCodeParser;

/// A controller for [PinField] and [PinFormField] that can automatically
/// ingest codes from one or more [PinCodeStrategy] sources.
class PinEditingController extends TextEditingController {
  /// Expected length of the pin code.
  final int pinLength;

  /// Optional callback when a code is received and populated.
  final ValueChanged<String>? onCodeReceived;

  /// Custom parser for extracting the numeric code from raw message text.
  /// If null, [defaultParser] is used.
  final PinCodeParser? parser;

  final List<PinCodeStrategy> _strategies = [];
  int _generation = 0;
  bool _disposed = false;

  PinEditingController({
    super.text,
    this.pinLength = 6,
    this.onCodeReceived,
    this.parser,
    List<PinCodeStrategy>? strategies,
  }) {
    if (strategies != null && strategies.isNotEmpty) {
      startListening(strategies);
    }
  }

  /// Whether at least one strategy is currently being listened to.
  bool get isListening => _strategies.isNotEmpty;

  /// Default parser: the first stand-alone run of [pinLength] digits in the
  /// message, allowing `123-456` / `123 456` grouping. See [extractPinCode].
  String? defaultParser(String raw) => extractPinCode(raw, pinLength);

  /// Starts listening to the provided [strategies] concurrently. Any
  /// strategies from a previous call are stopped first.
  ///
  /// When a strategy yields a message, it is parsed and, if a code is found,
  /// written to [text]; [onCodeReceived] fires and the remaining strategies
  /// are stopped. A message with no code is ignored and listening continues.
  void startListening(List<PinCodeStrategy> strategies) {
    if (_disposed) return;
    stopListening();
    _strategies.addAll(strategies);
    final generation = ++_generation;

    pinputKitLog(
      'PinEditingController: listening to ${strategies.length} strategies',
    );

    for (final strategy in strategies) {
      strategy
          .listenForCode()
          .then((rawMessage) {
            if (_disposed || generation != _generation) return;

            final extracted = (parser ?? defaultParser)(rawMessage);
            if (extracted == null || extracted.isEmpty) {
              pinputKitLog('PinEditingController: no code in "$rawMessage"');
              return;
            }

            pinputKitLog(
              'PinEditingController: strategy received "$extracted"',
            );
            stopListening();
            text = extracted;
            onCodeReceived?.call(extracted);
          })
          .catchError((Object error) {
            pinputKitLog('PinEditingController: strategy error: $error');
          });
    }
  }

  /// Stops listening to all active strategies, calling
  /// [PinCodeStrategy.stopListening] on each.
  void stopListening() {
    if (_strategies.isEmpty) return;
    _generation++;
    final active = List<PinCodeStrategy>.of(_strategies);
    _strategies.clear();
    for (final strategy in active) {
      try {
        strategy.stopListening();
      } catch (error) {
        pinputKitLog('PinEditingController: stopListening error: $error');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopListening();
    super.dispose();
  }
}

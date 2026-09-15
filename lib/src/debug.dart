/// Debug tracing for pinput_kit.
///
/// Set [pinputKitDebug] to true and every lifecycle step in [PinField] and
/// [PinFormField] prints a line prefixed `[pinput_kit]` with milliseconds
/// since the first line, so the order of focus changes, rebuilds and
/// keyboard actions can be read from the device log.
library;

bool pinputKitDebug = false;

final Stopwatch _clock = Stopwatch();

void pinputKitLog(String message) {
  if (!pinputKitDebug) return;
  if (!_clock.isRunning) _clock.start();
  final ms = _clock.elapsedMilliseconds.toString().padLeft(6);
  // ignore: avoid_print
  print('[pinput_kit] $ms ms  $message');
}

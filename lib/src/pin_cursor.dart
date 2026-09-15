/// A blinking vertical-bar cursor for the focused pin slot.
///
/// Uses a [Timer] to toggle visibility at ~530 ms, the same cadence iOS and
/// Android use for their native text cursor. No [AnimationController] is
/// needed, keeping the dependency surface minimal.
library;

import 'dart:async';

import 'package:dartnative/dartnative.dart';

class PinCursor extends StatefulWidget {
  /// Colour of the cursor bar; defaults to the theme's primary/focused colour.
  final Color color;

  /// Thickness of the vertical bar.
  final double width;

  /// Height of the bar; when null, fills the parent's height.
  final double? height;

  const PinCursor({
    super.key,
    this.color = const Color(0xFF007AFF),
    this.width = 2,
    this.height,
  });

  @override
  State<PinCursor> createState() => _PinCursorState();
}

class _PinCursorState extends State<PinCursor> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startBlinking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startBlinking() {
    _timer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (!mounted) return;
      setState(() => _visible = !_visible);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: widget.width,
        height: widget.height ?? 24,
        decoration: BoxDecoration(
          color: _visible ? widget.color : const Color(0x00000000),
          borderRadius: BorderRadius.circular(widget.width / 2),
        ),
      ),
    );
  }
}

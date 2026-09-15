// pinput_kit example: an OTP verification screen on native fields,
// following the same design language and conventions as forms_kit.
//
//   dn run -d <ios-simulator-id>
//   dn run -d <android-emulator-id>
//
// Keyboard input drives a single native TextField under the hood, while
// individual slot boxes render the digits, animations, and active cursor.

import 'dart:async';

import 'package:dartnative/dartnative.dart';
import 'package:pinput_kit/pinput_kit.dart';

import 'dartnative_plugin_registrant.dart';

void main() {
  DartNativePluginRegistrant.registerAll();
  SystemChrome.defaultStyle = const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  );
  runApp(const OtpVerificationScreen());
}

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const _brand = Color(0xFF0F7A69);
  static const _ink = Color(0xFF16191F);
  static const _muted = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();

  // LOOK: PinEditingController ingests codes from strategies. On Android the
  // SMS Retriever strategy delivers the verification SMS (no permission; the
  // message must end with the app hash shown on screen). Elsewhere the list
  // is empty and the controller behaves like a plain TextEditingController.
  late final PinEditingController _pinController = PinEditingController(
    pinLength: 6,
    strategies: _smsStrategies(),
    onCodeReceived: (code) => showToast(context, 'Code $code read from SMS'),
  );

  static List<PinCodeStrategy> _smsStrategies() =>
      SmsRetrieverPinStrategy.isSupported
      ? [SmsRetrieverPinStrategy()]
      : const [];

  bool _busy = false;
  bool _canSubmit = false;
  String? _verifiedPin;
  int _styleIndex = 0; // 0: Platform, 1: Underline, 2: Passcode (obscured)
  int _countdown = 45;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = 45);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verify([String? pin]) async {
    final code = pin ?? _pinController.text;
    if (code.length < 6) {
      _formKey.currentState?.validate();
      return;
    }

    setState(() => _busy = true);
    await Future<void>.delayed(
      const Duration(seconds: 1),
    ); // simulated API call
    if (!mounted) return;
    setState(() {
      _busy = false;
      _verifiedPin = code;
    });
    showToast(context, 'Verified successfully with code $code!');
  }

  PinThemeData _resolvedTheme(BuildContext context) {
    final base = PinTheme.of(context);
    switch (_styleIndex) {
      case 1:
        // Underline style
        return base.copyWith(
          style: PinSlotStyle.underline,
          width: 44,
          height: 50,
          borderWidth: 2,
          focusedBorderWidth: 3,
          focusedColor: _brand,
        );
      case 2:
        // Passcode / Circle style
        return base.copyWith(
          style: PinSlotStyle.circle,
          width: 46,
          height: 46,
          focusedColor: _brand,
        );
      default:
        // Rounded box style with brand accent
        return base.copyWith(focusedColor: _brand, focusedBorderWidth: 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isObscured = _styleIndex == 2;

    return Scaffold(
      backgroundColor: Colors.white,
      brightness: Brightness.light,
      appBar: AppBar(
        title: const Text(
          'Verification',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: () {
          setState(() {
            _canSubmit = _pinController.text.length == 6;
          });
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
          children: [
            const Text(
              'Enter SMS code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We sent a 6-digit verification code to\n+234 801 234 5678',
              style: TextStyle(fontSize: 15, color: _muted, height: 1.4),
            ),
            if (SmsRetrieverPinStrategy.isSupported) ...[
              const SizedBox(height: 8),
              Text(
                'SMS autofill on: end the SMS with '
                '${SmsRetrieverPinStrategy.appSignature}',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
            const SizedBox(height: 32),

            // LOOK: PinFormField wraps PinField in forms_kit's FormField.
            // Features separator at position 3 ('123 — 456'), cursor,
            // error text handling, and onCompleted auto-verification.
            PinFormField(
              controller: _pinController,
              length: 6,
              theme: _resolvedTheme(context),
              obscureText: isObscured,
              peekDuration: isObscured
                  ? const Duration(milliseconds: 600)
                  : null,
              cursorColor: _brand,
              autofocus: true,
              animationType: PinAnimationType.scale,
              animationCurve: Curves.easeOutBack,
              success: _verifiedPin != null,
              separator: const Text(
                '—',
                style: TextStyle(fontSize: 18, color: _muted),
              ),
              separatorPositions: const [3],
              validator: (v) => (v == null || v.length < 6)
                  ? 'Please enter all 6 digits'
                  : null,
              onCompleted: (pin) {
                pinputKitLog('Pin completed: $pin');
                _verify(pin);
              },
            ),

            const SizedBox(height: 24),

            // Resend code countdown
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Didn't receive code? ",
                  style: TextStyle(fontSize: 14, color: _muted),
                ),
                if (_countdown > 0)
                  Text(
                    'Resend in ${_countdown}s',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _brand,
                    ),
                  )
                else
                  Button(
                    title: 'Resend SMS',
                    variant: ButtonVariant.plain,
                    color: _brand,
                    onPressed: () {
                      _startCountdown();
                      // Play services listens for five minutes per start;
                      // a resend re-arms the SMS strategy.
                      _pinController.startListening(_smsStrategies());
                      showToast(context, 'New SMS code dispatched!');
                    },
                  ),
              ],
            ),

            const SizedBox(height: 32),

            // Verify Action Button
            Button(
              title: _busy ? 'Verifying…' : 'Verify Code',
              variant: ButtonVariant.filled,
              color: _brand,
              foregroundColor: Colors.white,
              height: 48,
              onPressed: _busy || !_canSubmit ? null : () => _verify(),
            ),

            const SizedBox(height: 12),

            Button(
              title: 'Clear',
              variant: ButtonVariant.plain,
              color: _brand,
              onPressed: () {
                _pinController.clear();
                _formKey.currentState?.reset();
                setState(() {
                  _verifiedPin = null;
                  _canSubmit = false;
                });
              },
            ),

            const SizedBox(height: 36),

            // Style Switcher Section
            const Text(
              'STYLE PRESETS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _muted,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Button(
                    title: 'Box',
                    variant: _styleIndex == 0
                        ? ButtonVariant.filled
                        : ButtonVariant.tinted,
                    color: _brand,
                    onPressed: () => setState(() => _styleIndex = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Button(
                    title: 'Underline',
                    variant: _styleIndex == 1
                        ? ButtonVariant.filled
                        : ButtonVariant.tinted,
                    color: _brand,
                    onPressed: () => setState(() => _styleIndex = 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Button(
                    title: 'Passcode',
                    variant: _styleIndex == 2
                        ? ButtonVariant.filled
                        : ButtonVariant.tinted,
                    color: _brand,
                    onPressed: () => setState(() => _styleIndex = 2),
                  ),
                ),
              ],
            ),

            if (_verifiedPin != null) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATUS: VERIFIED',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verified OTP code: $_verifiedPin',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF14532D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

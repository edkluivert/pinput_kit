## 0.2.2

- `focusAnimation` chooses how the ring reaches the next slot: `slide`
  (default), `pop` (scales in with a small overshoot), `fade`, or `none`.
- Fix: with an entrance animation, the ring could reappear on the last slot
  after the code was completed and the keyboard dismissed.

## 0.2.0

- The focus highlight is now one ring that slides from slot to slot
  (`animateFocus`, on by default; `focusAnimationDuration`,
  `focusAnimationCurve`). It is drawn beneath the slots and the focused slot is
  drawn transparent, so no slot loses its tap. Pass `animateFocus: false` for
  the previous per-slot border switch; custom `slotBuilder`s are unaffected.
- Filled slots and a field marked `success` keep the idle look, so only the
  active slot stands out and a verified code looks the way it did before
  typing. `PinThemeData.highlightFilled` / `highlightSuccess` restore the
  `filledColor` / `successColor` outlines.
- The separator sits in a fixed-width cell (`separatorWidth`, default 16, plus
  the theme spacing) instead of its intrinsic width, so slot positions are
  exact for the ring. `slotOffsets` / `slotsRowWidth` are exported for custom
  layouts.

## 0.1.1

- Android: the keyboard comes back when a slot is tapped after the system back
  button hid it. The field kept focus in that case, so a focus request did
  nothing; the plugin now asks the platform to show the keyboard directly
  (`PinputKitTextFieldShowKeyboard`, Android `showSoftInput`, iOS first
  responder). Apps must rebuild their native side once (`dn pub get`).
- The cursor is drawn in the active slot even when it holds a digit (tap a
  filled slot, or delete back into one), right after the digit. It was only
  drawn in an empty slot before.
- README: how to set slot width, height and spacing.

## 0.1.0

Initial release: pin code / OTP fields for DartNative.

- `PinField`: a single native `TextField` drives input while a `Row` of slot
  boxes renders the digits. The native field is hidden; only the slots are
  visible.
- Six slot states: `empty`, `focused`, `filled`, `error`, `disabled`, `success`
  (`success: true` turns every slot green, e.g. once the code is verified).
- Three slot styles: `box`, `underline`, `circle`.
- Entry animations: `none`, `fade`, `scale`, with `animationDuration` and
  `animationCurve`. `slotBuilder` for fully custom slots.
- Blinking cursor in the active slot, with configurable colour, width and
  height.
- `obscureText` with `obscureCharacter` and an optional `peekDuration` that
  shows the digit briefly before masking it.
- `separator` widget at configurable `separatorPositions` (e.g. `[3]` for
  `123 — 456`).
- Tap a slot to edit it: a filled slot is selected so the next digit replaces
  it; an empty slot or a gap continues at the end.
- `onChanged`, `onCompleted`, `onSubmitted`. `onCompleted` fires on every
  change that leaves the pin complete, including a digit corrected in place.
- `closeKeyboardWhenCompleted` and haptic feedback per keystroke.
- `PinFormField`: `PinField` inside forms_kit's `FormField<String>`, with
  `validator`, `onSaved`, `forceErrorText`, `errorBuilder`, keyboard "next"
  traversal and `Form.focusFirstInvalid()`. Automatic validation waits until
  the pin is complete (`validateWhileIncomplete: false` by default); an
  explicit `FormState.validate()` always runs.
- `PinThemeData` / `PinTheme`: `.ios`, `.material`, `.platform` presets with
  `copyWith`.
- `PinEditingController` + `PinCodeStrategy`: feed a code from any
  asynchronous source (`TestPinStrategy`, `StreamPinStrategy`, your own).
  `extractPinCode` finds a stand-alone run of N digits (also `123-456` /
  `123 456`) and never builds a code out of a longer number. Strategies receive
  `stopListening()` when a code arrives or the controller is disposed.
- `SmsRetrieverPinStrategy` (Android): SMS Retriever and User Consent modes
  over Play services, with `appSignature` for the SMS hash.
- `oneTimeCodeHint`: the hidden field is marked as a one-time-code field
  (`UITextContentType.oneTimeCode` on iOS, the `smsOTPCode` autofill hint on
  Android), so the keyboard offers an incoming SMS code.
- `pinputKitDebug`: timestamped lifecycle tracing.

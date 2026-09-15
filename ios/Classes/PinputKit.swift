// pinput_kit — iOS FFI entry points.
//
// Resolved by Dart from the app binary (DynamicLibrary.process()). The
// framework's view registry is reached through dlsym at runtime rather than
// `import dartnative_ios`, which would create a circular pod dependency.

import UIKit

private func dnLog(_ msg: String) { print("[PinputKit] \(msg)") }

private typealias _GetViewFn = @convention(c) (Int64) -> Int64
private let _dnGetView: _GetViewFn? = {
    guard let s = dlsym(dlopen(nil, RTLD_NOLOAD), "DNViewRegistryGetView") else { return nil }
    return unsafeBitCast(s, to: _GetViewFn.self)
}()

private func _viewFor(_ id: Int64) -> UIView? {
    guard let fn = _dnGetView else { return nil }
    let p = fn(id)
    guard p != 0, let raw = UnsafeRawPointer(bitPattern: Int(p)) else { return nil }
    return Unmanaged<UIView>.fromOpaque(raw).takeUnretainedValue()
}

private func _findTextField(_ view: UIView) -> UITextField? {
    if let field = view as? UITextField { return field }
    for sub in view.subviews {
        if let field = _findTextField(sub) { return field }
    }
    return nil
}

/// Marks the framework text field behind `viewId` as a one-time-code field.
/// iOS then offers a code from an incoming SMS in the QuickType bar.
/// Returns 0 on success, 1 when the view is unknown, 2 when it holds no
/// UITextField.
@_cdecl("PinputKitTextFieldSetOneTimeCode")
public func PinputKitTextFieldSetOneTimeCode(_ viewId: Int64) -> Int32 {
    guard let view = _viewFor(viewId) else {
        dnLog("oneTimeCode: no view for id \(viewId)")
        return 1
    }
    guard let field = _findTextField(view) else {
        dnLog("oneTimeCode: view \(viewId) holds no UITextField")
        return 2
    }
    field.textContentType = .oneTimeCode
    dnLog("oneTimeCode set on view \(viewId)")
    return 0
}

/// Shows the keyboard for the text field behind `viewId` by making it the
/// first responder. Does nothing when it already is. Returns 0 on success,
/// 1 when the view id is unknown, 2 when the view holds no UITextField.
@_cdecl("PinputKitTextFieldShowKeyboard")
public func PinputKitTextFieldShowKeyboard(_ viewId: Int64) -> Int32 {
    guard let view = _viewFor(viewId) else { return 1 }
    guard let field = _findTextField(view) else { return 2 }
    if !field.isFirstResponder {
        field.becomeFirstResponder()
    }
    return 0
}

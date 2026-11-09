import CoreGraphics
import Foundation

/// AppleScript error number for "not authorized to send Apple events".
private let appleEventNotPermitted = -1743

/// Triggers the `kTCCServiceAppleEvents` TCC dialog by sending Finder a
/// harmless read-only Apple event (the same mechanism `osascript` uses).
///
/// `NSAppleScript.executeAndReturnError` blocks while the dialog is up, so the
/// process stays alive and inspectable without a semaphore.
func triggerAppleEvents() {
    let source = "tell application \"Finder\" to get name of startup disk"
    guard let script = NSAppleScript(source: source) else {
        print("[WardTrigger] AppleScript could not be compiled.")
        return
    }
    var errorInfo: NSDictionary?
    let result = script.executeAndReturnError(&errorInfo)
    guard let errorInfo else {
        let name = result.stringValue ?? "unknown"
        print("[WardTrigger] Automation access granted (Finder replied: \(name)).")
        return
    }
    let number = errorInfo[NSAppleScript.errorNumber] as? Int
    if number == appleEventNotPermitted {
        print("[WardTrigger] Automation access denied by TCC — the permission prompt should have appeared.")
    } else {
        let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "unknown error"
        print("[WardTrigger] AppleScript error: \(message)")
    }
}

/// Seconds the screen-capture trigger waits for the user to answer before
/// giving up.
private let screenCaptureWaitSeconds = 60

/// Triggers the `kTCCServiceScreenCapture` TCC dialog via
/// `CGRequestScreenCaptureAccess()`.
///
/// That call returns immediately, so the process polls
/// `CGPreflightScreenCaptureAccess()` for up to 60 seconds to stay in the
/// process table while the dialog is on screen. macOS may require a restart of
/// the app before a grant takes effect, so a timeout is not an error.
func triggerScreenCapture() {
    if CGPreflightScreenCaptureAccess() {
        print("[WardTrigger] Screen recording access already granted — no prompt will appear.")
        return
    }
    _ = CGRequestScreenCaptureAccess()
    for _ in 0..<(screenCaptureWaitSeconds * 2) {
        if CGPreflightScreenCaptureAccess() {
            print("[WardTrigger] Screen recording access granted.")
            return
        }
        Thread.sleep(forTimeInterval: 0.5)
    }
    print("[WardTrigger] Screen recording access not granted (denied, or restart required).")
}

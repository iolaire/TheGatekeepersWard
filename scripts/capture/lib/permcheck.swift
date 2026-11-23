// Permission status and request helper for the capture framework.
//
// Usage: swift permcheck.swift status|request <name>
//   names: accessibility, screen-recording, automation-system-events, automation-finder
//   (full-disk-access is not handled here: setup.sh probes it through tcc_probe)
//
// `status` never prompts the user and prints "granted" or "missing".
// `request` triggers the system prompt for the permission and then prints the
// resulting status. Exit code 0 on success, 2 on a usage error.
// Never touches the TCC database. For Automation checks it starts the target
// app hidden (open -g -j) when it is not running; see ensureRunning.

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Bundle ID of the Automation target for a permission name, or nil when the
/// name is not an Automation permission.
func automationTarget(for name: String) -> String? {
    switch name {
    case "automation-system-events": return "com.apple.systemevents"
    case "automation-finder": return "com.apple.finder"
    default: return nil
    }
}

/// Starts the target hidden and in the background when it is not running, and
/// waits up to 5 s for it. AEDeterminePermissionToAutomateTarget returns
/// procNotFound (-600) for a target that is not running, which would read as
/// "missing" even when the permission is granted. System Events quits on its
/// own when idle, so this is needed before every check. No prompt is shown.
func ensureRunning(bundleID: String) {
    if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty { return }
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    open.arguments = ["-g", "-j", "-b", bundleID]
    do { try open.run() } catch { return }
    open.waitUntilExit()
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
        if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty { return }
        Thread.sleep(forTimeInterval: 0.1)
    }
}

/// Checks (or requests, when `ask` is true) Automation permission for a target app.
func automationGranted(bundleID: String, ask: Bool) -> Bool {
    ensureRunning(bundleID: bundleID)
    var desc = AEDesc()
    let bytes = Array(bundleID.utf8)
    let created = bytes.withUnsafeBufferPointer { buf -> OSErr in
        AECreateDesc(DescType(typeApplicationBundleID), buf.baseAddress, buf.count, &desc)
    }
    guard created == noErr else { return false }
    defer { AEDisposeDesc(&desc) }
    let status = AEDeterminePermissionToAutomateTarget(
        &desc, AEEventClass(typeWildCard), AEEventID(typeWildCard), ask)
    return status == noErr
}

/// Returns true when the named permission is granted. `ask` triggers the system
/// request where macOS offers one.
func isGranted(_ name: String, ask: Bool) -> Bool? {
    switch name {
    case "accessibility":
        if ask {
            // The key's value is the string "AXTrustedCheckOptionPrompt".
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    case "screen-recording":
        if ask { return CGRequestScreenCaptureAccess() }
        return CGPreflightScreenCaptureAccess()
    default:
        guard let target = automationTarget(for: name) else { return nil }
        return automationGranted(bundleID: target, ask: ask)
    }
}

let args = CommandLine.arguments
guard args.count == 3, args[1] == "status" || args[1] == "request" else {
    FileHandle.standardError.write(Data("usage: permcheck.swift status|request <name>\n".utf8))
    exit(2)
}
let ask = args[1] == "request"
guard let granted = isGranted(args[2], ask: ask) else {
    FileHandle.standardError.write(Data("unknown permission: \(args[2])\n".utf8))
    exit(2)
}
// After a request, re-read the status without asking so the answer is current.
let final = ask ? (isGranted(args[2], ask: false) ?? granted) : granted
print(final ? "granted" : "missing")
exit(0)

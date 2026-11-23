// Exposes an Electron app's web content to Accessibility for the capture framework.
//
// Usage: swift axmanual.swift <bundle-id>
//
// Electron apps build their accessibility tree only when an assistive client
// asks for it. Setting AXManualAccessibility on the app element does that
// without turning on VoiceOver-style enhanced UI. The attribute lasts until the
// app quits, so app.sh runs this after every launch for profiles that set
// ax_manual_accessibility = true. Needs Accessibility for the Capture_Host.
//
// Prints "ok" and exits 0 when the attribute was set, prints the AXError code
// and exits 1 when it was not, exits 2 on bad arguments or when the app is not
// running.
import AppKit
import ApplicationServices

let args = CommandLine.arguments
guard args.count == 2, !args[1].isEmpty else {
    FileHandle.standardError.write(Data("usage: axmanual.swift <bundle-id>\n".utf8))
    exit(2)
}
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: args[1]).first else {
    FileHandle.standardError.write(Data("not running: \(args[1])\n".utf8))
    exit(2)
}
let element = AXUIElementCreateApplication(app.processIdentifier)
let result = AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
if result == .success {
    print("ok")
    exit(0)
}
FileHandle.standardError.write(Data("AXManualAccessibility not set: AXError \(result.rawValue)\n".utf8))
exit(1)

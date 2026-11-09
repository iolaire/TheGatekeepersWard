import Foundation

/// Probes a protected home-folder by enumerating it read-only.
///
/// Directory enumeration is the operation `tccd` gates for the folder
/// services; a plain `stat` is not intercepted. Nothing is created or
/// modified. Outcomes:
/// - Access already granted → prints the "previously granted" message.
/// - TCC denial error → prints that the prompt should have appeared.
/// - Any other file-system error → prints the localized description.
///
/// All messages go to stdout; this function never exits the process.
///
/// - Parameters:
///   - folderName: The folder under the home directory (e.g. `"Desktop"`).
///   - label: The human-readable name used in messages (e.g. `"Desktop"`).
func probeProtectedFolder(folderName: String, label: String) {
    let path = NSHomeDirectory() + "/" + folderName
    do {
        _ = try FileManager.default.contentsOfDirectory(atPath: path)
        print("[WardTrigger] \(label) access already granted — no prompt will appear.")
    } catch {
        let nsError = error as NSError
        let isPermissionDenial = nsError.domain == NSCocoaErrorDomain
            && (nsError.code == NSFileReadNoPermissionError
                || nsError.code == NSFileWriteNoPermissionError)
        if isPermissionDenial {
            print("[WardTrigger] \(label) access denied by TCC — the permission prompt should have appeared.")
        } else {
            print("[WardTrigger] File system error: \(error.localizedDescription)")
        }
    }
}

/// Triggers the `kTCCServiceSystemPolicyDesktopFolder` TCC dialog by a
/// read-only listing of `~/Desktop`.
func triggerDesktop() {
    probeProtectedFolder(folderName: "Desktop", label: "Desktop")
}

/// Triggers the `kTCCServiceSystemPolicyDownloadsFolder` TCC dialog by a
/// read-only listing of `~/Downloads`.
func triggerDownloads() {
    probeProtectedFolder(folderName: "Downloads", label: "Downloads")
}
